// Package store keeps AvA's content in PostgreSQL: the editable,
// normalized tables and the published snapshots the app downloads.
package store

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"sort"
	"strconv"
	"strings"
	"time"

	_ "github.com/lib/pq" // PostgreSQL driver

	"github.com/mmdshin/ava/server/internal/content"
)

//go:embed migrations/*.sql
var migrations embed.FS

// Store wraps the database.
type Store struct {
	DB *sql.DB
}

// Open connects to PostgreSQL (e.g. "postgres://user:pass@host/ava").
func Open(ctx context.Context, url string) (*Store, error) {
	db, err := sql.Open("postgres", url)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(10)
	db.SetConnMaxIdleTime(5 * time.Minute)
	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("connect to database: %w", err)
	}
	return &Store{DB: db}, nil
}

func (s *Store) Close() error { return s.DB.Close() }

// Migrate applies the embedded migrations that haven't run yet, in
// order, each in its own transaction.
func (s *Store) Migrate(ctx context.Context) ([]string, error) {
	if _, err := s.DB.ExecContext(ctx, `create table if not exists schema_migrations (
		name text primary key, applied_at timestamptz not null default now())`); err != nil {
		return nil, err
	}
	files, err := fs.Glob(migrations, "migrations/*.sql")
	if err != nil {
		return nil, err
	}
	sort.Strings(files)
	var applied []string
	for _, f := range files {
		name := strings.TrimPrefix(f, "migrations/")
		var exists bool
		if err := s.DB.QueryRowContext(ctx,
			`select exists(select 1 from schema_migrations where name = $1)`, name,
		).Scan(&exists); err != nil {
			return applied, err
		}
		if exists {
			continue
		}
		body, err := migrations.ReadFile(f)
		if err != nil {
			return applied, err
		}
		err = s.inTx(ctx, func(tx *sql.Tx) error {
			if _, err := tx.ExecContext(ctx, string(body)); err != nil {
				return fmt.Errorf("%s: %w", name, err)
			}
			_, err := tx.ExecContext(ctx, `insert into schema_migrations (name) values ($1)`, name)
			return err
		})
		if err != nil {
			return applied, err
		}
		applied = append(applied, name)
	}
	return applied, nil
}

func (s *Store) inTx(ctx context.Context, fn func(*sql.Tx) error) error {
	tx, err := s.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	if err := fn(tx); err != nil {
		tx.Rollback()
		return err
	}
	return tx.Commit()
}

// ErrNotEmpty is returned by Import when content already exists and
// replace wasn't requested.
var ErrNotEmpty = errors.New("the database already has content (use --replace to overwrite it)")

// Import loads a whole bundle into the editable tables, keeping the
// order of everything. With replace, existing content is deleted first
// (published versions are kept).
func (s *Store) Import(ctx context.Context, b *content.Bundle, replace bool) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		var count int
		if err := tx.QueryRowContext(ctx, `select
			(select count(*) from care_plans) + (select count(*) from quizzes) +
			(select count(*) from gordon_domains)`).Scan(&count); err != nil {
			return err
		}
		if count > 0 {
			if !replace {
				return ErrNotEmpty
			}
			for _, t := range []string{
				"care_plan_section_items", "care_plan_sections", "care_plan_tags", "care_plans",
				"quiz_question_options", "quiz_questions", "quizzes",
				"gordon_finding_tags", "gordon_findings", "gordon_domains",
			} {
				if _, err := tx.ExecContext(ctx, "delete from "+t); err != nil {
					return err
				}
			}
		}

		// The bundle's categories replace the current list (plans and
		// quizzes are gone at this point, so nothing refers to them).
		if len(b.Categories) > 0 {
			if _, err := tx.ExecContext(ctx, "delete from categories"); err != nil {
				return err
			}
			for i, c := range b.Categories {
				if _, err := tx.ExecContext(ctx,
					`insert into categories (id, title, abbr, color, icon, position) values ($1, $2, $3, $4, $5, $6)`,
					c.ID, c.Title, c.Abbr, c.Color, c.Icon, i); err != nil {
					return fmt.Errorf("category %s: %w", c.ID, err)
				}
			}
		}

		ensureTag := func(tag string) error {
			_, err := tx.ExecContext(ctx,
				`insert into tags (name) values ($1) on conflict do nothing`, tag)
			return err
		}

		for _, d := range b.GordonDomains {
			if _, err := tx.ExecContext(ctx,
				`insert into gordon_domains (id, title, position) values ($1, $2, $3)`,
				d.ID, d.Title, d.Order); err != nil {
				return fmt.Errorf("domain %s: %w", d.ID, err)
			}
			for j, f := range d.Items {
				if _, err := tx.ExecContext(ctx,
					`insert into gordon_findings (id, domain_id, title, position) values ($1, $2, $3, $4)`,
					f.ID, d.ID, f.Title, j); err != nil {
					return fmt.Errorf("finding %s: %w", f.ID, err)
				}
				for k, t := range f.Tags {
					if err := ensureTag(t); err != nil {
						return fmt.Errorf("finding %s tag %s: %w", f.ID, t, err)
					}
					if _, err := tx.ExecContext(ctx,
						`insert into gordon_finding_tags (finding_id, tag, position) values ($1, $2, $3)`,
						f.ID, t, k); err != nil {
						return fmt.Errorf("finding %s tag %s: %w", f.ID, t, err)
					}
				}
			}
		}

		for i, p := range b.CarePlans {
			if _, err := tx.ExecContext(ctx,
				`insert into care_plans (id, kind, title, position) values ($1, $2, $3, $4)`,
				p.ID, p.Kind, p.Title, i); err != nil {
				return fmt.Errorf("care plan %s: %w", p.ID, err)
			}
			for k, t := range p.Tags {
				if err := ensureTag(t); err != nil {
					return fmt.Errorf("care plan %s tag %s: %w", p.ID, t, err)
				}
				if _, err := tx.ExecContext(ctx,
					`insert into care_plan_tags (plan_id, tag, position) values ($1, $2, $3)`,
					p.ID, t, k); err != nil {
					return fmt.Errorf("care plan %s tag %s: %w", p.ID, t, err)
				}
			}
			for j, sec := range p.Sections {
				var sectionID int64
				if err := tx.QueryRowContext(ctx,
					`insert into care_plan_sections (plan_id, position, type, title)
					 values ($1, $2, $3, $4) returning id`,
					p.ID, j, sec.Type, nullable(sec.Title)).Scan(&sectionID); err != nil {
					return fmt.Errorf("care plan %s section %d: %w", p.ID, j+1, err)
				}
				for k, item := range sec.Items {
					if _, err := tx.ExecContext(ctx,
						`insert into care_plan_section_items (section_id, position, text) values ($1, $2, $3)`,
						sectionID, k, item); err != nil {
						return fmt.Errorf("care plan %s section %d item %d: %w", p.ID, j+1, k+1, err)
					}
				}
			}
		}

		for i, q := range b.Quizzes {
			if _, err := tx.ExecContext(ctx,
				`insert into quizzes (id, title, kind, position) values ($1, $2, $3, $4)`,
				q.ID, q.Title, nullable(q.Kind), i); err != nil {
				return fmt.Errorf("quiz %s: %w", q.ID, err)
			}
			for j, qu := range q.Questions {
				if _, err := tx.ExecContext(ctx,
					`insert into quiz_questions (id, quiz_id, position, text, correct_index, explanation, hint)
					 values ($1, $2, $3, $4, $5, $6, $7)`,
					qu.ID, q.ID, j, qu.Text, qu.CorrectIndex, nullable(qu.Explanation), nullable(qu.Hint),
				); err != nil {
					return fmt.Errorf("question %s: %w", qu.ID, err)
				}
				for k, o := range qu.Options {
					if _, err := tx.ExecContext(ctx,
						`insert into quiz_question_options (question_id, position, text) values ($1, $2, $3)`,
						qu.ID, k, o); err != nil {
						return fmt.Errorf("question %s option %d: %w", qu.ID, k+1, err)
					}
				}
			}
		}
		return nil
	})
}

func nullable(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// Draft builds the current (unpublished) content from the editable
// tables, leaving out archived rows.
func (s *Store) Draft(ctx context.Context) (*content.Bundle, error) {
	b := &content.Bundle{
		SchemaVersion: content.SchemaVersion,
		Categories:    []content.Category{},
		CarePlans:     []content.CarePlan{},
		Quizzes:       []content.Quiz{},
		GordonDomains: []content.Domain{},
	}
	if err := s.loadCategories(ctx, b); err != nil {
		return nil, err
	}
	if err := s.loadDomains(ctx, b); err != nil {
		return nil, err
	}
	if err := s.loadCarePlans(ctx, b); err != nil {
		return nil, err
	}
	if err := s.loadQuizzes(ctx, b); err != nil {
		return nil, err
	}
	return b, nil
}

func (s *Store) loadCategories(ctx context.Context, b *content.Bundle) error {
	rows, err := s.DB.QueryContext(ctx, `select id, title, abbr, color, icon from categories
		where not archived order by position, id`)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var c content.Category
		if err := rows.Scan(&c.ID, &c.Title, &c.Abbr, &c.Color, &c.Icon); err != nil {
			return err
		}
		b.Categories = append(b.Categories, c)
	}
	return rows.Err()
}

func (s *Store) loadDomains(ctx context.Context, b *content.Bundle) error {
	rows, err := s.DB.QueryContext(ctx, `
		select d.id, d.title, d.position, f.id, f.title,
		       coalesce((select array_to_json(array_agg(t.tag order by t.position))
		                 from gordon_finding_tags t where t.finding_id = f.id), '[]')
		from gordon_domains d
		left join gordon_findings f on f.domain_id = d.id and not f.archived
		where not d.archived
		order by d.position, d.id, f.position, f.id`)
	if err != nil {
		return err
	}
	defer rows.Close()
	index := map[string]int{}
	for rows.Next() {
		var d content.Domain
		var fid, ftitle sql.NullString
		var tags []byte
		if err := rows.Scan(&d.ID, &d.Title, &d.Order, &fid, &ftitle, &tags); err != nil {
			return err
		}
		i, ok := index[d.ID]
		if !ok {
			d.Items = []content.Finding{}
			b.GordonDomains = append(b.GordonDomains, d)
			i = len(b.GordonDomains) - 1
			index[d.ID] = i
		}
		if fid.Valid {
			f := content.Finding{ID: fid.String, Title: ftitle.String}
			if err := json.Unmarshal(tags, &f.Tags); err != nil {
				return err
			}
			b.GordonDomains[i].Items = append(b.GordonDomains[i].Items, f)
		}
	}
	return rows.Err()
}

func (s *Store) loadCarePlans(ctx context.Context, b *content.Bundle) error {
	rows, err := s.DB.QueryContext(ctx, `
		select p.id, p.kind, p.title,
		       coalesce((select array_to_json(array_agg(t.tag order by t.position))
		                 from care_plan_tags t where t.plan_id = p.id), '[]'),
		       coalesce((select json_agg(json_build_object(
		                   'type', s.type,
		                   'title', coalesce(s.title, ''),
		                   'items', coalesce((select array_to_json(array_agg(i.text order by i.position))
		                                      from care_plan_section_items i where i.section_id = s.id), '[]')
		                 ) order by s.position)
		                 from care_plan_sections s where s.plan_id = p.id), '[]')
		from care_plans p
		join categories c on c.id = p.kind
		where not p.archived
		order by c.position, p.position, p.id`)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var p content.CarePlan
		var tags, sections []byte
		if err := rows.Scan(&p.ID, &p.Kind, &p.Title, &tags, &sections); err != nil {
			return err
		}
		if err := json.Unmarshal(tags, &p.Tags); err != nil {
			return err
		}
		if err := json.Unmarshal(sections, &p.Sections); err != nil {
			return err
		}
		b.CarePlans = append(b.CarePlans, p)
	}
	return rows.Err()
}

func (s *Store) loadQuizzes(ctx context.Context, b *content.Bundle) error {
	rows, err := s.DB.QueryContext(ctx, `
		select q.id, q.title, coalesce(q.kind, ''),
		       coalesce((select json_agg(json_build_object(
		                   'id', qu.id,
		                   'text', qu.text,
		                   'correctIndex', qu.correct_index,
		                   'explanation', coalesce(qu.explanation, ''),
		                   'hint', coalesce(qu.hint, ''),
		                   'options', coalesce((select array_to_json(array_agg(o.text order by o.position))
		                                        from quiz_question_options o where o.question_id = qu.id), '[]')
		                 ) order by qu.position)
		                 from quiz_questions qu where qu.quiz_id = q.id and not qu.archived), '[]')
		from quizzes q
		where not q.archived
		order by q.position, q.id`)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var q content.Quiz
		var questions []byte
		if err := rows.Scan(&q.ID, &q.Title, &q.Kind, &questions); err != nil {
			return err
		}
		if err := json.Unmarshal(questions, &q.Questions); err != nil {
			return err
		}
		b.Quizzes = append(b.Quizzes, q)
	}
	return rows.Err()
}

// Version is one published snapshot.
type Version struct {
	Version       int       `json:"version"`
	SchemaVersion int       `json:"schemaVersion"`
	SHA256        string    `json:"sha256"`
	Notes         string    `json:"notes"`
	PublishedBy   string    `json:"publishedBy"`
	PublishedAt   time.Time `json:"publishedAt"`
	Bundle        []byte    `json:"-"`
}

// ErrNothingChanged: the draft is identical to the latest version.
var ErrNothingChanged = errors.New("nothing changed since the latest published version")

// ValidationError: the draft has errors and can't be published.
type ValidationError struct{ Issues content.Issues }

func (e *ValidationError) Error() string {
	return fmt.Sprintf("content has %d error(s), e.g.: %s", len(e.Issues.Errors), e.Issues.Errors[0])
}

// PublishRequest says who publishes and why.
type PublishRequest struct {
	Notes string
	By    Actor
	// Publish even while publishing is frozen (command line only).
	IgnoreFreeze bool
}

// Publish validates the draft and, if it differs from the latest
// version, stores it as the next version.
func (s *Store) Publish(ctx context.Context, req PublishRequest) (*Version, content.Issues, error) {
	if !req.IgnoreFreeze {
		freeze, err := s.Freeze(ctx)
		if err != nil {
			return nil, content.Issues{}, err
		}
		if freeze.Frozen {
			return nil, content.Issues{}, ErrFrozen
		}
	}
	notes, by := req.Notes, req.By.Email
	draft, err := s.Draft(ctx)
	if err != nil {
		return nil, content.Issues{}, err
	}
	issues := content.Validate(draft)
	if !issues.OK() {
		return nil, issues, &ValidationError{issues}
	}

	var published *Version
	err = s.inTx(ctx, func(tx *sql.Tx) error {
		// One publisher at a time.
		if _, err := tx.ExecContext(ctx, `lock table content_versions in exclusive mode`); err != nil {
			return err
		}
		var latest int
		var latestHash string
		err := tx.QueryRowContext(ctx,
			`select version, sha256 from content_versions order by version desc limit 1`,
		).Scan(&latest, &latestHash)
		if err != nil && !errors.Is(err, sql.ErrNoRows) {
			return err
		}
		// Compare content only (not version number or date).
		if latest > 0 && contentHash(draft) == latestHash {
			return ErrNothingChanged
		}

		now := time.Now().UTC()
		draft.Version = latest + 1
		draft.PublishedAt = now.Format(time.RFC3339)
		bundle, err := json.Marshal(draft)
		if err != nil {
			return err
		}
		v := &Version{
			Version:       draft.Version,
			SchemaVersion: content.SchemaVersion,
			SHA256:        contentHash(draft),
			Notes:         notes,
			PublishedBy:   by,
			PublishedAt:   now,
			Bundle:        bundle,
		}
		if _, err := tx.ExecContext(ctx, `insert into content_versions
			(version, schema_version, bundle, sha256, notes, published_by, published_at)
			values ($1, $2, $3, $4, $5, $6, $7)`,
			v.Version, v.SchemaVersion, string(v.Bundle), v.SHA256, v.Notes, v.PublishedBy, v.PublishedAt,
		); err != nil {
			return err
		}
		published = v
		return audit(ctx, tx, req.By, "publish", "version", strconv.Itoa(v.Version), nil,
			map[string]any{"version": v.Version, "notes": v.Notes})
	})
	return published, issues, err
}

// contentHash hashes the content itself, ignoring version and date, so
// "publish" without changes is detected.
func contentHash(b *content.Bundle) string {
	c := *b
	c.Version, c.PublishedAt = 0, ""
	raw, _ := json.Marshal(c)
	sum := sha256.Sum256(raw)
	return hex.EncodeToString(sum[:])
}

// ErrNoVersion: nothing has been published (yet), or no such version.
var ErrNoVersion = errors.New("no published content")

// Latest returns the newest published version (with its bundle).
func (s *Store) Latest(ctx context.Context) (*Version, error) {
	return s.version(ctx, `order by version desc limit 1`)
}

// GetVersion returns one published version (with its bundle).
func (s *Store) GetVersion(ctx context.Context, version int) (*Version, error) {
	return s.version(ctx, `where version = `+strconv.Itoa(version))
}

func (s *Store) version(ctx context.Context, where string) (*Version, error) {
	var v Version
	var bundle string
	err := s.DB.QueryRowContext(ctx, `select version, schema_version, sha256, notes,
		published_by, published_at, bundle from content_versions `+where,
	).Scan(&v.Version, &v.SchemaVersion, &v.SHA256, &v.Notes, &v.PublishedBy, &v.PublishedAt, &bundle)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNoVersion
	}
	if err != nil {
		return nil, err
	}
	v.Bundle = []byte(bundle)
	return &v, nil
}

// Versions lists published versions, newest first (without bundles).
func (s *Store) Versions(ctx context.Context) ([]Version, error) {
	rows, err := s.DB.QueryContext(ctx, `select version, schema_version, sha256, notes,
		published_by, published_at from content_versions order by version desc`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Version
	for rows.Next() {
		var v Version
		if err := rows.Scan(&v.Version, &v.SchemaVersion, &v.SHA256, &v.Notes, &v.PublishedBy, &v.PublishedAt); err != nil {
			return nil, err
		}
		out = append(out, v)
	}
	return out, rows.Err()
}
