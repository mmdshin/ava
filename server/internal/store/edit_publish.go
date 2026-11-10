package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"reflect"
	"strings"
	"time"

	"github.com/mmdshin/ava/server/internal/content"
)

// ------------------------------------------------------------ changes

// Change is one difference between the draft and the published version.
type Change struct {
	Entity string `json:"entity"` // category, care_plan, quiz, question, domain, finding
	ID     string `json:"id"`
	Title  string `json:"title"`
	Kind   string `json:"kind"` // added, changed, removed
}

// DraftChanges compares the current draft with the latest published
// version (everything is "added" when nothing is published yet).
func (s *Store) DraftChanges(ctx context.Context) ([]Change, error) {
	draft, err := s.Draft(ctx)
	if err != nil {
		return nil, err
	}
	published := &content.Bundle{}
	latest, err := s.Latest(ctx)
	switch {
	case errors.Is(err, ErrNoVersion):
	case err != nil:
		return nil, err
	default:
		if err := json.Unmarshal(latest.Bundle, published); err != nil {
			return nil, err
		}
	}

	changes := []Change{}
	type item struct {
		title string
		value any
	}
	diff := func(entity string, before, after map[string]item, order []string) {
		for _, id := range order {
			a := after[id]
			b, existed := before[id]
			switch {
			case !existed:
				changes = append(changes, Change{entity, id, a.title, "added"})
			case !reflect.DeepEqual(normalize(b.value), normalize(a.value)):
				changes = append(changes, Change{entity, id, a.title, "changed"})
			}
		}
		var removed []string
		for id := range before {
			if _, ok := after[id]; !ok {
				removed = append(removed, id)
			}
		}
		sortStrings(removed)
		for _, id := range removed {
			changes = append(changes, Change{entity, id, before[id].title, "removed"})
		}
	}

	categories := func(b *content.Bundle) (map[string]item, []string) {
		m, order := map[string]item{}, []string{}
		for _, c := range b.Categories {
			m[c.ID] = item{c.Title, c}
			order = append(order, c.ID)
		}
		return m, order
	}
	plans := func(b *content.Bundle) (map[string]item, []string) {
		m, order := map[string]item{}, []string{}
		for _, p := range b.CarePlans {
			m[p.ID] = item{p.Title, p}
			order = append(order, p.ID)
		}
		return m, order
	}
	quizzes := func(b *content.Bundle) (map[string]item, []string) {
		m, order := map[string]item{}, []string{}
		for _, q := range b.Quizzes {
			q.Questions = nil // questions are compared one by one
			m[q.ID] = item{q.Title, q}
			order = append(order, q.ID)
		}
		return m, order
	}
	questions := func(b *content.Bundle) (map[string]item, []string) {
		m, order := map[string]item{}, []string{}
		for _, q := range b.Quizzes {
			for _, qu := range q.Questions {
				m[qu.ID] = item{qu.Text, qu}
				order = append(order, qu.ID)
			}
		}
		return m, order
	}
	domains := func(b *content.Bundle) (map[string]item, []string) {
		m, order := map[string]item{}, []string{}
		for _, d := range b.GordonDomains {
			d.Items = nil
			m[d.ID] = item{d.Title, d}
			order = append(order, d.ID)
		}
		return m, order
	}
	findings := func(b *content.Bundle) (map[string]item, []string) {
		m, order := map[string]item{}, []string{}
		for _, d := range b.GordonDomains {
			for _, f := range d.Items {
				m[f.ID] = item{f.Title, f}
				order = append(order, f.ID)
			}
		}
		return m, order
	}
	for _, x := range []struct {
		entity string
		get    func(*content.Bundle) (map[string]item, []string)
	}{{"category", categories}, {"care_plan", plans}, {"quiz", quizzes}, {"question", questions}, {"domain", domains}, {"finding", findings}} {
		before, _ := x.get(published)
		after, order := x.get(draft)
		diff(x.entity, before, after, order)
	}
	return changes, nil
}

// normalize makes values from JSON and from the database comparable
// (nil vs empty slices).
func normalize(v any) any {
	raw, _ := json.Marshal(v)
	var out any
	json.Unmarshal(raw, &out)
	return out
}

func sortStrings(s []string) {
	for i := 1; i < len(s); i++ {
		for j := i; j > 0 && s[j] < s[j-1]; j-- {
			s[j], s[j-1] = s[j-1], s[j]
		}
	}
}

// ValidateDraft checks the current draft with the publishing rules.
func (s *Store) ValidateDraft(ctx context.Context) (content.Issues, error) {
	draft, err := s.Draft(ctx)
	if err != nil {
		return content.Issues{}, err
	}
	is := content.Validate(draft)
	if is.Errors == nil {
		is.Errors = []string{}
	}
	if is.Warnings == nil {
		is.Warnings = []string{}
	}
	return is, nil
}

// ------------------------------------------------------------ settings

// FreezeState: while frozen, nothing can be published (e.g. during the
// clinical trial), so the content participants see stays the same.
type FreezeState struct {
	Frozen    bool      `json:"frozen"`
	Reason    string    `json:"reason"`
	UpdatedAt time.Time `json:"updatedAt,omitzero"`
	UpdatedBy string    `json:"updatedBy,omitempty"`
}

const freezeKey = "publishing_freeze"

func (s *Store) Freeze(ctx context.Context) (FreezeState, error) {
	var raw []byte
	var f FreezeState
	err := s.DB.QueryRowContext(ctx, `select value, updated_at, coalesce((select email from users where id = updated_by), '')
		from settings where key = $1`, freezeKey).Scan(&raw, &f.UpdatedAt, &f.UpdatedBy)
	if errors.Is(err, sql.ErrNoRows) {
		return FreezeState{}, nil
	}
	if err != nil {
		return f, err
	}
	var v struct {
		Frozen bool   `json:"frozen"`
		Reason string `json:"reason"`
	}
	if err := json.Unmarshal(raw, &v); err != nil {
		return f, err
	}
	f.Frozen, f.Reason = v.Frozen, v.Reason
	return f, nil
}

func (s *Store) SetFreeze(ctx context.Context, frozen bool, reason string, by Actor) error {
	reason = strings.TrimSpace(reason)
	if frozen && reason == "" {
		return invalid("give a reason for freezing (e.g. the clinical trial)")
	}
	return s.inTx(ctx, func(tx *sql.Tx) error {
		value, _ := json.Marshal(map[string]any{"frozen": frozen, "reason": reason})
		if _, err := tx.ExecContext(ctx, `insert into settings (key, value, updated_by) values ($1, $2, $3)
			on conflict (key) do update set value = excluded.value, updated_at = now(), updated_by = excluded.updated_by`,
			freezeKey, string(value), by.userID()); err != nil {
			return err
		}
		action := "unfreeze"
		if frozen {
			action = "freeze"
		}
		return audit(ctx, tx, by, action, "settings", freezeKey, nil, map[string]any{"frozen": frozen, "reason": reason})
	})
}

// ------------------------------------------------------------ audit log

// AuditEntry is one recorded change.
type AuditEntry struct {
	ID       int64           `json:"id"`
	At       time.Time       `json:"at"`
	User     string          `json:"user"`
	Action   string          `json:"action"`
	Entity   string          `json:"entity"`
	EntityID string          `json:"entityId"`
	Before   json.RawMessage `json:"before,omitempty"`
	After    json.RawMessage `json:"after,omitempty"`
}

// AuditFilter narrows the log; BeforeID pages backwards.
type AuditFilter struct {
	Entity   string
	EntityID string
	BeforeID int64
	Limit    int
}

func (s *Store) Audit(ctx context.Context, f AuditFilter) ([]AuditEntry, error) {
	if f.Limit <= 0 || f.Limit > 200 {
		f.Limit = 50
	}
	rows, err := s.DB.QueryContext(ctx, `select id, at, user_email, action, entity, entity_id, before, after
		from audit_log
		where ($1 = '' or entity = $1) and ($2 = '' or entity_id = $2) and ($3 = 0 or id < $3)
		order by id desc limit $4`, f.Entity, f.EntityID, f.BeforeID, f.Limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []AuditEntry{}
	for rows.Next() {
		var e AuditEntry
		var before, after []byte
		if err := rows.Scan(&e.ID, &e.At, &e.User, &e.Action, &e.Entity, &e.EntityID, &before, &after); err != nil {
			return nil, err
		}
		e.Before, e.After = before, after
		out = append(out, e)
	}
	return out, rows.Err()
}

// ------------------------------------------------------------ users

func (s *Store) ListUsers(ctx context.Context) ([]User, error) {
	rows, err := s.DB.QueryContext(ctx, `select `+userColumns+` from users order by created_at`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []User{}
	for rows.Next() {
		u, err := scanUser(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *u)
	}
	return out, rows.Err()
}

// SetRoleAs changes a role and records who did it.
func (s *Store) SetRoleAs(ctx context.Context, email, role string, by Actor) error {
	before, err := s.UserByEmail(ctx, email)
	if err != nil {
		return err
	}
	if err := s.SetRole(ctx, email, role); err != nil {
		return err
	}
	return audit(ctx, s.DB, by, "set_role", "user", before.Email,
		map[string]string{"role": before.Role}, map[string]string{"role": role})
}
