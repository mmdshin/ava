package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/lib/pq"
)

// Actor is who makes a change (for updated_by and the audit log).
type Actor struct {
	ID    int64
	Email string
}

// ActorOf turns a user into an Actor (nil → the command line).
func ActorOf(u *User) Actor {
	if u == nil {
		return Actor{Email: "cli"}
	}
	return Actor{ID: u.ID, Email: u.Email}
}

func (a Actor) userID() any {
	if a.ID == 0 {
		return nil
	}
	return a.ID
}

// Meta is the editing information of a content row.
type Meta struct {
	Revision  int       `json:"revision"`
	Archived  bool      `json:"archived"`
	UpdatedAt time.Time `json:"updatedAt"`
	UpdatedBy string    `json:"updatedBy"`
}

// ---------------------------------------------------------------- errors

// InvalidError: the input breaks content rules; Issues says how.
type InvalidError struct{ Issues []string }

func (e *InvalidError) Error() string { return "invalid: " + strings.Join(e.Issues, "; ") }

func invalid(issues ...string) error { return &InvalidError{Issues: issues} }

// ConflictError: someone else changed the entity since it was loaded.
type ConflictError struct{ Current int }

func (e *ConflictError) Error() string {
	return fmt.Sprintf("changed by someone else (now at revision %d); reload and try again", e.Current)
}

var (
	ErrIDTaken  = errors.New("this id is already used")
	ErrTagInUse = errors.New("the tag is still used")
	ErrFrozen   = errors.New("publishing is frozen")
)

// ---------------------------------------------------------------- helpers

type querier interface {
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

// lockRevision locks one row and checks the caller's revision.
// table is a trusted constant.
func lockRevision(ctx context.Context, tx *sql.Tx, table, id string, want int) error {
	var current int
	err := tx.QueryRowContext(ctx, `select revision from `+table+` where id = $1 for update`, id).Scan(&current)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if want != current {
		return &ConflictError{Current: current}
	}
	return nil
}

// touch bumps a row's revision and records who changed it.
func touch(ctx context.Context, tx *sql.Tx, table, id string, by Actor) error {
	_, err := tx.ExecContext(ctx, `update `+table+` set revision = revision + 1,
		updated_at = now(), updated_by = $2 where id = $1`, id, by.userID())
	return err
}

// audit records a change. before/after are marshalled to JSON (nil → NULL).
func audit(ctx context.Context, q querier, by Actor, action, entity, id string, before, after any) error {
	j := func(v any) (any, error) {
		if v == nil {
			return nil, nil
		}
		raw, err := json.Marshal(v)
		if err != nil {
			return nil, err
		}
		return string(raw), nil
	}
	b, err := j(before)
	if err != nil {
		return err
	}
	a, err := j(after)
	if err != nil {
		return err
	}
	_, err = q.ExecContext(ctx, `insert into audit_log (user_id, user_email, action, entity, entity_id, before, after)
		values ($1, $2, $3, $4, $5, $6, $7)`, by.userID(), by.Email, action, entity, id, b, a)
	return err
}

// requireTags checks that every tag exists in the tag list.
func requireTags(ctx context.Context, q querier, tags []string) error {
	if len(tags) == 0 {
		return nil
	}
	rows, err := q.QueryContext(ctx, `select name from tags where name = any($1)`, pq.Array(tags))
	if err != nil {
		return err
	}
	defer rows.Close()
	known := map[string]bool{}
	for rows.Next() {
		var n string
		if err := rows.Scan(&n); err != nil {
			return err
		}
		known[n] = true
	}
	var missing []string
	for _, t := range tags {
		if !known[t] {
			missing = append(missing, fmt.Sprintf("unknown tag %q (add it to the tag list first)", t))
		}
	}
	if len(missing) > 0 {
		return invalid(missing...)
	}
	return rows.Err()
}

func isUniqueViolation(err error) bool {
	var pqErr *pq.Error
	return errors.As(err, &pqErr) && pqErr.Code == "23505"
}

// nextPosition is one past the largest position in table where cond holds.
func nextPosition(ctx context.Context, q querier, table, cond string, args ...any) (int, error) {
	var n int
	err := q.QueryRowContext(ctx, `select coalesce(max(position), -1) + 1 from `+table+` where `+cond, args...).Scan(&n)
	return n, err
}

// reorder sets positions: ids in the given order first, then the rest
// of the scope in their previous order. Every id must be in the scope.
func reorder(ctx context.Context, tx *sql.Tx, table, scopeCond string, scopeArgs []any, ids []string) error {
	rows, err := tx.QueryContext(ctx, `select id from `+table+` where `+scopeCond+` order by position, id for update`, scopeArgs...)
	if err != nil {
		return err
	}
	var existing []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return err
		}
		existing = append(existing, id)
	}
	rows.Close()
	inScope := map[string]bool{}
	for _, id := range existing {
		inScope[id] = true
	}
	seen := map[string]bool{}
	for _, id := range ids {
		if !inScope[id] {
			return invalid(fmt.Sprintf("%q is not in this list", id))
		}
		if seen[id] {
			return invalid(fmt.Sprintf("%q is listed twice", id))
		}
		seen[id] = true
	}
	order := append([]string{}, ids...)
	for _, id := range existing {
		if !seen[id] {
			order = append(order, id)
		}
	}
	for i, id := range order {
		if _, err := tx.ExecContext(ctx, `update `+table+` set position = $2 where id = $1`, id, i); err != nil {
			return err
		}
	}
	return nil
}

// setArchived archives or restores a row (table is a trusted constant).
func setArchived(ctx context.Context, tx *sql.Tx, table, id string, archived bool, by Actor) error {
	res, err := tx.ExecContext(ctx, `update `+table+` set archived = $2, revision = revision + 1,
		updated_at = now(), updated_by = $3 where id = $1`, id, archived, by.userID())
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotFound
	}
	return nil
}

// metaCols selects a row's Meta (alias is the table alias in the query).
func metaCols(alias string) string {
	return alias + `.revision, ` + alias + `.archived, ` + alias + `.updated_at,
		coalesce((select email from users where id = ` + alias + `.updated_by), '')`
}
