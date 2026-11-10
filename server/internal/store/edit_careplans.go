package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/mmdshin/ava/server/internal/content"
)

// EditCarePlan is a care plan as editors see it.
type EditCarePlan struct {
	content.CarePlan
	Meta
}

// CarePlanSummary is a row in the editors' list.
type CarePlanSummary struct {
	ID    string   `json:"id"`
	Kind  string   `json:"kind"`
	Title string   `json:"title"`
	Tags  []string `json:"tags"`
	Meta
}

// CarePlanInput is what an editor sends to create or update a plan.
type CarePlanInput struct {
	Kind     string            `json:"kind"` // only on create
	Title    string            `json:"title"`
	Tags     []string          `json:"tags"`
	Sections []content.Section `json:"sections"`
}

func (in CarePlanInput) plan(id, kind string) content.CarePlan {
	sections := in.Sections
	for i := range sections {
		sections[i].Title = strings.TrimSpace(sections[i].Title)
		for j := range sections[i].Items {
			sections[i].Items[j] = strings.TrimSpace(sections[i].Items[j])
		}
	}
	return content.CarePlan{ID: id, Kind: kind, Title: strings.TrimSpace(in.Title), Tags: in.Tags, Sections: sections}
}

// ListCarePlans lists every plan (archived included), by kind and order.
func (s *Store) ListCarePlans(ctx context.Context) ([]CarePlanSummary, error) {
	rows, err := s.DB.QueryContext(ctx, `select p.id, p.kind, p.title,
		coalesce((select array_to_json(array_agg(t.tag order by t.position)) from care_plan_tags t where t.plan_id = p.id), '[]'),
		`+metaCols("p")+`
		from care_plans p
		order by (select c.position from categories c where c.id = p.kind), p.position, p.id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []CarePlanSummary{}
	for rows.Next() {
		var c CarePlanSummary
		var tags []byte
		if err := rows.Scan(&c.ID, &c.Kind, &c.Title, &tags, &c.Revision, &c.Archived, &c.UpdatedAt, &c.UpdatedBy); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(tags, &c.Tags); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// GetCarePlan returns one plan with its sections (archived included).
func (s *Store) GetCarePlan(ctx context.Context, id string) (*EditCarePlan, error) {
	return getCarePlan(ctx, s.DB, id)
}

func getCarePlan(ctx context.Context, q querier, id string) (*EditCarePlan, error) {
	var p EditCarePlan
	var tags, sections []byte
	err := q.QueryRowContext(ctx, `select p.id, p.kind, p.title,
		coalesce((select array_to_json(array_agg(t.tag order by t.position)) from care_plan_tags t where t.plan_id = p.id), '[]'),
		coalesce((select json_agg(json_build_object(
			'type', s.type, 'title', coalesce(s.title, ''),
			'items', coalesce((select array_to_json(array_agg(i.text order by i.position))
			                   from care_plan_section_items i where i.section_id = s.id), '[]')
		) order by s.position) from care_plan_sections s where s.plan_id = p.id), '[]'),
		`+metaCols("p")+`
		from care_plans p where p.id = $1`, id,
	).Scan(&p.ID, &p.Kind, &p.Title, &tags, &sections, &p.Revision, &p.Archived, &p.UpdatedAt, &p.UpdatedBy)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(tags, &p.Tags); err != nil {
		return nil, err
	}
	if err := json.Unmarshal(sections, &p.Sections); err != nil {
		return nil, err
	}
	return &p, nil
}

// writePlanBody replaces a plan's tags and sections.
func writePlanBody(ctx context.Context, tx *sql.Tx, p content.CarePlan) error {
	if err := requireTags(ctx, tx, p.Tags); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `delete from care_plan_tags where plan_id = $1`, p.ID); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `delete from care_plan_sections where plan_id = $1`, p.ID); err != nil {
		return err
	}
	for i, t := range p.Tags {
		if _, err := tx.ExecContext(ctx, `insert into care_plan_tags (plan_id, tag, position) values ($1, $2, $3)`, p.ID, t, i); err != nil {
			return err
		}
	}
	for i, sec := range p.Sections {
		var sid int64
		if err := tx.QueryRowContext(ctx, `insert into care_plan_sections (plan_id, position, type, title)
			values ($1, $2, $3, $4) returning id`, p.ID, i, sec.Type, nullable(sec.Title)).Scan(&sid); err != nil {
			return err
		}
		for j, item := range sec.Items {
			if _, err := tx.ExecContext(ctx, `insert into care_plan_section_items (section_id, position, text)
				values ($1, $2, $3)`, sid, j, item); err != nil {
				return err
			}
		}
	}
	return nil
}

// CreateCarePlan adds a plan with the next free id of its kind
// (e.g. acs-05) at the end of that kind's list.
func (s *Store) CreateCarePlan(ctx context.Context, in CarePlanInput, by Actor) (*EditCarePlan, error) {
	p := in.plan("", in.Kind)
	if issues := content.CheckCarePlan(p); len(issues) > 0 {
		return nil, invalid(issues...)
	}
	var created *EditCarePlan
	err := s.inTx(ctx, func(tx *sql.Tx) error {
		if err := requireCategory(ctx, tx, p.Kind); err != nil {
			return err
		}
		// Serialize id allocation per kind.
		if _, err := tx.ExecContext(ctx, `select pg_advisory_xact_lock(hashtext('care_plan_id:' || $1))`, p.Kind); err != nil {
			return err
		}
		var n int
		if err := tx.QueryRowContext(ctx, `select coalesce(max(substring(id from '-(\d+)$')::int), 0) + 1
			from care_plans where kind = $1`, p.Kind).Scan(&n); err != nil {
			return err
		}
		p.ID = fmt.Sprintf("%s-%02d", p.Kind, n)
		pos, err := nextPosition(ctx, tx, "care_plans", "kind = $1", p.Kind)
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `insert into care_plans (id, kind, title, position, updated_by)
			values ($1, $2, $3, $4, $5)`, p.ID, p.Kind, p.Title, pos, by.userID()); err != nil {
			if isUniqueViolation(err) {
				return invalid("another plan of this kind already has this title")
			}
			return err
		}
		if err := writePlanBody(ctx, tx, p); err != nil {
			return err
		}
		if created, err = getCarePlan(ctx, tx, p.ID); err != nil {
			return err
		}
		return audit(ctx, tx, by, "create", "care_plan", p.ID, nil, created.CarePlan)
	})
	return created, err
}

// UpdateCarePlan replaces a plan's title, tags and sections. revision
// must be the one the editor started from.
func (s *Store) UpdateCarePlan(ctx context.Context, id string, revision int, in CarePlanInput, by Actor) (*EditCarePlan, error) {
	var updated *EditCarePlan
	err := s.inTx(ctx, func(tx *sql.Tx) error {
		if err := lockRevision(ctx, tx, "care_plans", id, revision); err != nil {
			return err
		}
		before, err := getCarePlan(ctx, tx, id)
		if err != nil {
			return err
		}
		p := in.plan(id, before.Kind)
		if issues := content.CheckCarePlan(p); len(issues) > 0 {
			return invalid(issues...)
		}
		if _, err := tx.ExecContext(ctx, `update care_plans set title = $2 where id = $1`, id, p.Title); err != nil {
			if isUniqueViolation(err) {
				return invalid("another plan of this kind already has this title")
			}
			return err
		}
		if err := writePlanBody(ctx, tx, p); err != nil {
			return err
		}
		if err := touch(ctx, tx, "care_plans", id, by); err != nil {
			return err
		}
		if updated, err = getCarePlan(ctx, tx, id); err != nil {
			return err
		}
		return audit(ctx, tx, by, "update", "care_plan", id, before.CarePlan, updated.CarePlan)
	})
	return updated, err
}

// ArchiveCarePlan hides a plan from the next published version (or
// brings it back). Ids are never reused.
func (s *Store) ArchiveCarePlan(ctx context.Context, id string, archived bool, by Actor) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if err := setArchived(ctx, tx, "care_plans", id, archived, by); err != nil {
			if isUniqueViolation(err) {
				return invalid("another active plan of this kind has the same title")
			}
			return err
		}
		return audit(ctx, tx, by, archiveAction(archived), "care_plan", id, nil, nil)
	})
}

// ReorderCarePlans sets the order of one kind's plans.
func (s *Store) ReorderCarePlans(ctx context.Context, kind string, ids []string, by Actor) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if err := reorder(ctx, tx, "care_plans", "kind = $1", []any{kind}, ids); err != nil {
			return err
		}
		return audit(ctx, tx, by, "reorder", "care_plan", kind, nil, ids)
	})
}

func archiveAction(archived bool) string {
	if archived {
		return "archive"
	}
	return "restore"
}
