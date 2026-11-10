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

// EditDomain is a Gordon domain with all its findings (archived included).
type EditDomain struct {
	ID       string        `json:"id"`
	Title    string        `json:"title"`
	Findings []EditFinding `json:"findings"`
	Meta
}

// EditFinding is one assessment finding as editors see it.
type EditFinding struct {
	content.Finding
	DomainID string `json:"domainId"`
	// Ids of active care plans this finding leads to (by shared tags).
	Plans []string `json:"plans"`
	Meta
}

type DomainInput struct {
	ID    string `json:"id"` // only on create
	Title string `json:"title"`
}

type FindingInput struct {
	ID    string   `json:"id"` // only on create; generated when empty
	Title string   `json:"title"`
	Tags  []string `json:"tags"`
}

// ListDomains returns every domain with its findings, in order.
func (s *Store) ListDomains(ctx context.Context) ([]EditDomain, error) {
	rows, err := s.DB.QueryContext(ctx, `select d.id, d.title, `+metaCols("d")+`
		from gordon_domains d order by d.position, d.id`)
	if err != nil {
		return nil, err
	}
	var out []EditDomain
	for rows.Next() {
		var d EditDomain
		if err := rows.Scan(&d.ID, &d.Title, &d.Revision, &d.Archived, &d.UpdatedAt, &d.UpdatedBy); err != nil {
			rows.Close()
			return nil, err
		}
		d.Findings = []EditFinding{}
		out = append(out, d)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}
	findings, err := listFindings(ctx, s.DB, "true")
	if err != nil {
		return nil, err
	}
	index := map[string]int{}
	for i, d := range out {
		index[d.ID] = i
	}
	for _, f := range findings {
		if i, ok := index[f.DomainID]; ok {
			out[i].Findings = append(out[i].Findings, f)
		}
	}
	if out == nil {
		out = []EditDomain{}
	}
	return out, nil
}

func listFindings(ctx context.Context, q querier, cond string, args ...any) ([]EditFinding, error) {
	rows, err := q.QueryContext(ctx, `select f.id, f.domain_id, f.title,
		coalesce((select array_to_json(array_agg(t.tag order by t.position)) from gordon_finding_tags t where t.finding_id = f.id), '[]'),
		coalesce((select array_to_json(array_agg(distinct p.id order by p.id))
		          from gordon_finding_tags ft
		          join care_plan_tags pt on pt.tag = ft.tag
		          join care_plans p on p.id = pt.plan_id and not p.archived
		          where ft.finding_id = f.id), '[]'),
		`+metaCols("f")+`
		from gordon_findings f join gordon_domains d on d.id = f.domain_id
		where `+cond+` order by d.position, f.position, f.id`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []EditFinding
	for rows.Next() {
		var f EditFinding
		var tags, plans []byte
		if err := rows.Scan(&f.ID, &f.DomainID, &f.Title, &tags, &plans, &f.Revision, &f.Archived, &f.UpdatedAt, &f.UpdatedBy); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(tags, &f.Tags); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(plans, &f.Plans); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

func getFinding(ctx context.Context, q querier, id string) (*EditFinding, error) {
	fs, err := listFindings(ctx, q, "f.id = $1", id)
	if err != nil {
		return nil, err
	}
	if len(fs) == 0 {
		return nil, ErrNotFound
	}
	return &fs[0], nil
}

func (s *Store) GetFinding(ctx context.Context, id string) (*EditFinding, error) {
	return getFinding(ctx, s.DB, id)
}

func getDomain(ctx context.Context, q querier, id string) (*EditDomain, error) {
	var d EditDomain
	err := q.QueryRowContext(ctx, `select d.id, d.title, `+metaCols("d")+` from gordon_domains d where d.id = $1`, id).
		Scan(&d.ID, &d.Title, &d.Revision, &d.Archived, &d.UpdatedAt, &d.UpdatedBy)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	fs, err := listFindings(ctx, q, "f.domain_id = $1", id)
	if err != nil {
		return nil, err
	}
	d.Findings = fs
	if d.Findings == nil {
		d.Findings = []EditFinding{}
	}
	return &d, nil
}

func (s *Store) CreateDomain(ctx context.Context, in DomainInput, by Actor) (*EditDomain, error) {
	in.ID, in.Title = strings.TrimSpace(in.ID), strings.TrimSpace(in.Title)
	issues := content.CheckDomain(content.Domain{ID: in.ID, Title: in.Title})
	if in.ID == "" {
		issues = append(issues, "id is required (lowercase snake_case, e.g. health_promotion)")
	}
	if len(issues) > 0 {
		return nil, invalid(issues...)
	}
	var created *EditDomain
	err := s.inTx(ctx, func(tx *sql.Tx) error {
		// Positions are the published "order", starting at 1.
		pos, err := nextPosition(ctx, tx, "gordon_domains", "true")
		if err != nil {
			return err
		}
		pos = max(pos, 1)
		if _, err := tx.ExecContext(ctx, `insert into gordon_domains (id, title, position, updated_by) values ($1, $2, $3, $4)`,
			in.ID, in.Title, pos, by.userID()); err != nil {
			if isUniqueViolation(err) {
				return ErrIDTaken
			}
			return err
		}
		if created, err = getDomain(ctx, tx, in.ID); err != nil {
			return err
		}
		return audit(ctx, tx, by, "create", "domain", in.ID, nil, in)
	})
	return created, err
}

func (s *Store) UpdateDomain(ctx context.Context, id string, revision int, in DomainInput, by Actor) (*EditDomain, error) {
	in.Title = strings.TrimSpace(in.Title)
	if issues := content.CheckDomain(content.Domain{Title: in.Title}); len(issues) > 0 {
		return nil, invalid(issues...)
	}
	var updated *EditDomain
	err := s.inTx(ctx, func(tx *sql.Tx) error {
		if err := lockRevision(ctx, tx, "gordon_domains", id, revision); err != nil {
			return err
		}
		before, err := getDomain(ctx, tx, id)
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `update gordon_domains set title = $2 where id = $1`, id, in.Title); err != nil {
			return err
		}
		if err := touch(ctx, tx, "gordon_domains", id, by); err != nil {
			return err
		}
		if updated, err = getDomain(ctx, tx, id); err != nil {
			return err
		}
		return audit(ctx, tx, by, "update", "domain", id, DomainInput{Title: before.Title}, DomainInput{Title: in.Title})
	})
	return updated, err
}

func (s *Store) ArchiveDomain(ctx context.Context, id string, archived bool, by Actor) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if err := setArchived(ctx, tx, "gordon_domains", id, archived, by); err != nil {
			return err
		}
		return audit(ctx, tx, by, archiveAction(archived), "domain", id, nil, nil)
	})
}

// ReorderDomains sets the order of the domains. The published "order"
// of a domain is its position + 1.
func (s *Store) ReorderDomains(ctx context.Context, ids []string, by Actor) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if err := reorder(ctx, tx, "gordon_domains", "true", nil, ids); err != nil {
			return err
		}
		// Published order starts at 1.
		if _, err := tx.ExecContext(ctx, `update gordon_domains set position = position + 1`); err != nil {
			return err
		}
		return audit(ctx, tx, by, "reorder", "domain", "", nil, ids)
	})
}

func writeFindingTags(ctx context.Context, tx *sql.Tx, id string, tags []string) error {
	if err := requireTags(ctx, tx, tags); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `delete from gordon_finding_tags where finding_id = $1`, id); err != nil {
		return err
	}
	for i, t := range tags {
		if _, err := tx.ExecContext(ctx, `insert into gordon_finding_tags (finding_id, tag, position) values ($1, $2, $3)`, id, t, i); err != nil {
			return err
		}
	}
	return nil
}

// CreateFinding adds a finding at the end of a domain. Without an id,
// one is generated from the domain (e.g. comfort_3).
func (s *Store) CreateFinding(ctx context.Context, domainID string, in FindingInput, by Actor) (*EditFinding, error) {
	f := content.Finding{ID: strings.TrimSpace(in.ID), Title: strings.TrimSpace(in.Title), Tags: in.Tags}
	if issues := content.CheckFinding(f); len(issues) > 0 {
		return nil, invalid(issues...)
	}
	var created *EditFinding
	err := s.inTx(ctx, func(tx *sql.Tx) error {
		if _, err := getDomain(ctx, tx, domainID); err != nil {
			return err
		}
		if f.ID == "" {
			if _, err := tx.ExecContext(ctx, `select pg_advisory_xact_lock(hashtext('finding_id:' || $1))`, domainID); err != nil {
				return err
			}
			var n int
			if err := tx.QueryRowContext(ctx, `select coalesce(max(substring(id from '_(\d+)$')::int), 0) + 1
				from gordon_findings where id ~ ('^' || $1 || '_\d+$')`, domainID).Scan(&n); err != nil {
				return err
			}
			f.ID = fmt.Sprintf("%s_%d", domainID, n)
		}
		pos, err := nextPosition(ctx, tx, "gordon_findings", "domain_id = $1", domainID)
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `insert into gordon_findings (id, domain_id, title, position, updated_by)
			values ($1, $2, $3, $4, $5)`, f.ID, domainID, f.Title, pos, by.userID()); err != nil {
			if isUniqueViolation(err) {
				return ErrIDTaken
			}
			return err
		}
		if err := writeFindingTags(ctx, tx, f.ID, f.Tags); err != nil {
			return err
		}
		if created, err = getFinding(ctx, tx, f.ID); err != nil {
			return err
		}
		return audit(ctx, tx, by, "create", "finding", f.ID, nil, created.Finding)
	})
	return created, err
}

func (s *Store) UpdateFinding(ctx context.Context, id string, revision int, in FindingInput, by Actor) (*EditFinding, error) {
	f := content.Finding{ID: id, Title: strings.TrimSpace(in.Title), Tags: in.Tags}
	if issues := content.CheckFinding(f); len(issues) > 0 {
		return nil, invalid(issues...)
	}
	var updated *EditFinding
	err := s.inTx(ctx, func(tx *sql.Tx) error {
		if err := lockRevision(ctx, tx, "gordon_findings", id, revision); err != nil {
			return err
		}
		before, err := getFinding(ctx, tx, id)
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `update gordon_findings set title = $2 where id = $1`, id, f.Title); err != nil {
			return err
		}
		if err := writeFindingTags(ctx, tx, id, f.Tags); err != nil {
			return err
		}
		if err := touch(ctx, tx, "gordon_findings", id, by); err != nil {
			return err
		}
		if updated, err = getFinding(ctx, tx, id); err != nil {
			return err
		}
		return audit(ctx, tx, by, "update", "finding", id, before.Finding, updated.Finding)
	})
	return updated, err
}

func (s *Store) ArchiveFinding(ctx context.Context, id string, archived bool, by Actor) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if err := setArchived(ctx, tx, "gordon_findings", id, archived, by); err != nil {
			return err
		}
		return audit(ctx, tx, by, archiveAction(archived), "finding", id, nil, nil)
	})
}

func (s *Store) ReorderFindings(ctx context.Context, domainID string, ids []string, by Actor) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if err := reorder(ctx, tx, "gordon_findings", "domain_id = $1", []any{domainID}, ids); err != nil {
			return err
		}
		return audit(ctx, tx, by, "reorder", "finding", domainID, nil, ids)
	})
}

// ------------------------------------------------------------------ tags

// Tag is one entry of the tag list, with where it is used.
type Tag struct {
	Name     string   `json:"name"`
	Label    string   `json:"label"`
	Plans    []string `json:"plans"`    // care plan ids (active)
	Findings []string `json:"findings"` // finding ids (active)
}

func (s *Store) ListTags(ctx context.Context) ([]Tag, error) {
	rows, err := s.DB.QueryContext(ctx, `select t.name, t.label,
		coalesce((select array_to_json(array_agg(p.id order by p.id)) from care_plan_tags pt
		          join care_plans p on p.id = pt.plan_id and not p.archived where pt.tag = t.name), '[]'),
		coalesce((select array_to_json(array_agg(f.id order by f.id)) from gordon_finding_tags ft
		          join gordon_findings f on f.id = ft.finding_id and not f.archived where ft.tag = t.name), '[]')
		from tags t order by t.name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Tag{}
	for rows.Next() {
		var t Tag
		var plans, findings []byte
		if err := rows.Scan(&t.Name, &t.Label, &plans, &findings); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(plans, &t.Plans); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(findings, &t.Findings); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// CreateTag adds a tag. Tags one letter away from an existing one are
// refused (almost always a typo).
func (s *Store) CreateTag(ctx context.Context, name, label string, by Actor) error {
	name, label = strings.TrimSpace(name), strings.TrimSpace(label)
	if !content.TagFormat.MatchString(name) {
		return invalid("tag must be lowercase snake_case, e.g. chest_pain")
	}
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if err := checkTagTypo(ctx, tx, name, ""); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `insert into tags (name, label) values ($1, $2)`, name, label); err != nil {
			if isUniqueViolation(err) {
				return ErrIDTaken
			}
			return err
		}
		return audit(ctx, tx, by, "create", "tag", name, nil, map[string]string{"label": label})
	})
}

func checkTagTypo(ctx context.Context, q querier, name, except string) error {
	rows, err := q.QueryContext(ctx, `select name from tags where name <> $1`, except)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var other string
		if err := rows.Scan(&other); err != nil {
			return err
		}
		if other != name && len(name) > 4 && content.EditDistance(name, other) <= 1 {
			return invalid(fmt.Sprintf("%q looks like a typo of the existing tag %q", name, other))
		}
	}
	return rows.Err()
}

// UpdateTag changes a tag's label and/or renames it everywhere it is used.
func (s *Store) UpdateTag(ctx context.Context, name, newName, label string, by Actor) error {
	newName, label = strings.TrimSpace(newName), strings.TrimSpace(label)
	if newName == "" {
		newName = name
	}
	if !content.TagFormat.MatchString(newName) {
		return invalid("tag must be lowercase snake_case, e.g. chest_pain")
	}
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if newName != name {
			if err := checkTagTypo(ctx, tx, newName, name); err != nil {
				return err
			}
		}
		res, err := tx.ExecContext(ctx, `update tags set name = $2, label = $3 where name = $1`, name, newName, label)
		if isUniqueViolation(err) {
			return ErrIDTaken
		}
		if err != nil {
			return err
		}
		if n, _ := res.RowsAffected(); n == 0 {
			return ErrNotFound
		}
		return audit(ctx, tx, by, "update", "tag", name, map[string]string{"name": name},
			map[string]string{"name": newName, "label": label})
	})
}

// DeleteTag removes an unused tag.
func (s *Store) DeleteTag(ctx context.Context, name string, by Actor) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		var used bool
		if err := tx.QueryRowContext(ctx, `select exists(select 1 from care_plan_tags where tag = $1)
			or exists(select 1 from gordon_finding_tags where tag = $1)`, name).Scan(&used); err != nil {
			return err
		}
		if used {
			return ErrTagInUse
		}
		res, err := tx.ExecContext(ctx, `delete from tags where name = $1`, name)
		if err != nil {
			return err
		}
		if n, _ := res.RowsAffected(); n == 0 {
			return ErrNotFound
		}
		return audit(ctx, tx, by, "delete", "tag", name, nil, nil)
	})
}
