package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"

	"github.com/mmdshin/ava/server/internal/content"
)

// EditCategory is a disease category as editors see it, with how much
// content uses it.
type EditCategory struct {
	content.Category
	// Active (not archived) care plans and quizzes in this category.
	Plans   int `json:"plans"`
	Quizzes int `json:"quizzes"`
	Meta
}

// CategoryInput creates or edits a category. The id is only used on
// create (it is part of care plan ids, so it never changes).
type CategoryInput struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	Abbr  string `json:"abbr"`
	Color string `json:"color"`
	Icon  string `json:"icon"`
}

// ErrCategoryInUse: the category still has active care plans or quizzes,
// or it is the "general" category, which can't be removed.
var ErrCategoryInUse = errors.New("the category is still used")

func (in CategoryInput) category() content.Category {
	return content.Category{
		ID:    strings.TrimSpace(in.ID),
		Title: strings.TrimSpace(in.Title),
		Abbr:  strings.TrimSpace(in.Abbr),
		Color: strings.ToUpper(strings.TrimSpace(in.Color)),
		Icon:  strings.TrimSpace(in.Icon),
	}
}

func listCategories(ctx context.Context, q querier, cond string, args ...any) ([]EditCategory, error) {
	rows, err := q.QueryContext(ctx, `select c.id, c.title, c.abbr, c.color, c.icon,
		(select count(*) from care_plans p where p.kind = c.id and not p.archived),
		(select count(*) from quizzes z where z.kind = c.id and not z.archived),
		`+metaCols("c")+`
		from categories c where `+cond+` order by c.position, c.id`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []EditCategory{}
	for rows.Next() {
		var c EditCategory
		if err := rows.Scan(&c.ID, &c.Title, &c.Abbr, &c.Color, &c.Icon, &c.Plans, &c.Quizzes,
			&c.Revision, &c.Archived, &c.UpdatedAt, &c.UpdatedBy); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func getCategory(ctx context.Context, q querier, id string) (*EditCategory, error) {
	cs, err := listCategories(ctx, q, "c.id = $1", id)
	if err != nil {
		return nil, err
	}
	if len(cs) == 0 {
		return nil, ErrNotFound
	}
	return &cs[0], nil
}

// requireCategory checks that a care plan or quiz can be put in this
// category (it exists and isn't archived).
func requireCategory(ctx context.Context, q querier, id string) error {
	var archived bool
	err := q.QueryRowContext(ctx, `select archived from categories where id = $1`, id).Scan(&archived)
	if errors.Is(err, sql.ErrNoRows) || (err == nil && archived) {
		return invalid(fmt.Sprintf("unknown disease category %q", id))
	}
	return err
}

// ListCategories returns every category (archived included), in order.
func (s *Store) ListCategories(ctx context.Context) ([]EditCategory, error) {
	return listCategories(ctx, s.DB, "true")
}

// CreateCategory adds a category at the end of the list.
func (s *Store) CreateCategory(ctx context.Context, in CategoryInput, by Actor) (*EditCategory, error) {
	c := in.category()
	c.ID = strings.ToLower(c.ID)
	issues := content.CheckCategory(c)
	if c.ID == "" {
		issues = append(issues, "id is required (lowercase English, e.g. copd)")
	}
	if len(issues) > 0 {
		return nil, invalid(issues...)
	}
	var created *EditCategory
	err := s.inTx(ctx, func(tx *sql.Tx) error {
		pos, err := nextPosition(ctx, tx, "categories", "true")
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `insert into categories (id, title, abbr, color, icon, position, updated_by)
			values ($1, $2, $3, $4, $5, $6, $7)`, c.ID, c.Title, c.Abbr, c.Color, c.Icon, pos, by.userID()); err != nil {
			if isUniqueViolation(err) {
				return ErrIDTaken
			}
			return err
		}
		if created, err = getCategory(ctx, tx, c.ID); err != nil {
			return err
		}
		return audit(ctx, tx, by, "create", "category", c.ID, nil, c)
	})
	return created, err
}

// UpdateCategory changes a category's name, short code, color or icon.
func (s *Store) UpdateCategory(ctx context.Context, id string, revision int, in CategoryInput, by Actor) (*EditCategory, error) {
	c := in.category()
	c.ID = id
	if issues := content.CheckCategory(content.Category{Title: c.Title, Abbr: c.Abbr, Color: c.Color, Icon: c.Icon}); len(issues) > 0 {
		return nil, invalid(issues...)
	}
	var updated *EditCategory
	err := s.inTx(ctx, func(tx *sql.Tx) error {
		if err := lockRevision(ctx, tx, "categories", id, revision); err != nil {
			return err
		}
		before, err := getCategory(ctx, tx, id)
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `update categories set title = $2, abbr = $3, color = $4, icon = $5 where id = $1`,
			id, c.Title, c.Abbr, c.Color, c.Icon); err != nil {
			return err
		}
		if err := touch(ctx, tx, "categories", id, by); err != nil {
			return err
		}
		if updated, err = getCategory(ctx, tx, id); err != nil {
			return err
		}
		return audit(ctx, tx, by, "update", "category", id, before.Category, c)
	})
	return updated, err
}

// ArchiveCategory removes a category from the next version (or brings
// it back). Only empty categories can be archived, and never "general".
func (s *Store) ArchiveCategory(ctx context.Context, id string, archived bool, by Actor) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if archived {
			if id == content.GeneralCategory {
				return ErrCategoryInUse
			}
			c, err := getCategory(ctx, tx, id)
			if err != nil {
				return err
			}
			if c.Plans > 0 || c.Quizzes > 0 {
				return ErrCategoryInUse
			}
		}
		if err := setArchived(ctx, tx, "categories", id, archived, by); err != nil {
			return err
		}
		return audit(ctx, tx, by, archiveAction(archived), "category", id, nil, nil)
	})
}

// ReorderCategories sets the order categories are shown in the app.
func (s *Store) ReorderCategories(ctx context.Context, ids []string, by Actor) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if err := reorder(ctx, tx, "categories", "true", nil, ids); err != nil {
			return err
		}
		return audit(ctx, tx, by, "reorder", "category", "", nil, ids)
	})
}
