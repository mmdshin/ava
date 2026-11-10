package store

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"time"

	"github.com/lib/pq"
)

// Roles, from least to most rights.
const (
	RoleNurse    = "nurse"
	RoleEditor   = "editor"
	RoleReviewer = "reviewer"
	RoleAdmin    = "admin"
)

var roleRank = map[string]int{RoleNurse: 0, RoleEditor: 1, RoleReviewer: 2, RoleAdmin: 3}

// User is an account.
type User struct {
	ID          int64      `json:"id"`
	Email       string     `json:"email"`
	DisplayName string     `json:"displayName"`
	Role        string     `json:"role"`
	CreatedAt   time.Time  `json:"createdAt"`
	LastLoginAt *time.Time `json:"lastLoginAt,omitempty"`

	passwordHash string
}

// PasswordHash is only used by the login code.
func (u *User) PasswordHash() string { return u.passwordHash }

// Can reports whether the user has at least the given role.
func (u *User) Can(role string) bool { return roleRank[u.Role] >= roleRank[role] }

var (
	ErrEmailTaken  = errors.New("an account with this email already exists")
	ErrNotFound    = errors.New("not found")
	ErrUnknownRole = errors.New("unknown role")
)

// NormalizeEmail trims and lowercases an email address.
func NormalizeEmail(email string) string { return strings.ToLower(strings.TrimSpace(email)) }

// CreateUser adds an account (the password must already be hashed).
func (s *Store) CreateUser(ctx context.Context, email, displayName, passwordHash, role string) (*User, error) {
	if _, ok := roleRank[role]; !ok {
		return nil, ErrUnknownRole
	}
	u := &User{Email: NormalizeEmail(email), DisplayName: strings.TrimSpace(displayName), Role: role}
	err := s.DB.QueryRowContext(ctx, `insert into users (email, display_name, password_hash, role)
		values ($1, $2, $3, $4) returning id, created_at`,
		u.Email, u.DisplayName, passwordHash, role).Scan(&u.ID, &u.CreatedAt)
	var pqErr *pq.Error
	if errors.As(err, &pqErr) && pqErr.Code == "23505" {
		return nil, ErrEmailTaken
	}
	if err != nil {
		return nil, err
	}
	return u, nil
}

const userColumns = `id, email, display_name, role, created_at, last_login_at, password_hash`

func scanUser(row interface{ Scan(...any) error }) (*User, error) {
	var u User
	err := row.Scan(&u.ID, &u.Email, &u.DisplayName, &u.Role, &u.CreatedAt, &u.LastLoginAt, &u.passwordHash)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (s *Store) UserByEmail(ctx context.Context, email string) (*User, error) {
	return scanUser(s.DB.QueryRowContext(ctx,
		`select `+userColumns+` from users where lower(email) = $1`, NormalizeEmail(email)))
}

func (s *Store) UserByID(ctx context.Context, id int64) (*User, error) {
	return scanUser(s.DB.QueryRowContext(ctx, `select `+userColumns+` from users where id = $1`, id))
}

// SetRole changes a user's role (admin only, enforced by the API).
func (s *Store) SetRole(ctx context.Context, email, role string) error {
	if _, ok := roleRank[role]; !ok {
		return ErrUnknownRole
	}
	res, err := s.DB.ExecContext(ctx, `update users set role = $2 where lower(email) = $1`, NormalizeEmail(email), role)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotFound
	}
	return nil
}

// SetPassword replaces the password hash and ends all sessions.
func (s *Store) SetPassword(ctx context.Context, userID int64, passwordHash string) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `update users set password_hash = $2 where id = $1`, userID, passwordHash); err != nil {
			return err
		}
		_, err := tx.ExecContext(ctx, `delete from sessions where user_id = $1`, userID)
		return err
	})
}

// DeleteUser removes an account and all its data.
func (s *Store) DeleteUser(ctx context.Context, userID int64) error {
	_, err := s.DB.ExecContext(ctx, `delete from users where id = $1`, userID)
	return err
}

// ------------------------------------------------------------ sessions

// SessionTTL: a session lasts this long after its last use.
const SessionTTL = 90 * 24 * time.Hour

// CreateSession stores a session for the token hash.
func (s *Store) CreateSession(ctx context.Context, userID int64, tokenHash []byte, userAgent string) error {
	if len(userAgent) > 300 {
		userAgent = userAgent[:300]
	}
	_, err := s.DB.ExecContext(ctx, `insert into sessions (token_hash, user_id, expires_at, user_agent)
		values ($1, $2, $3, $4)`, tokenHash, userID, time.Now().Add(SessionTTL), userAgent)
	if err != nil {
		return err
	}
	_, err = s.DB.ExecContext(ctx, `update users set last_login_at = now() where id = $1`, userID)
	return err
}

// UserBySession returns the user of a valid session and extends it
// (at most once a minute, to keep writes low).
func (s *Store) UserBySession(ctx context.Context, tokenHash []byte) (*User, error) {
	u, err := scanUser(s.DB.QueryRowContext(ctx, `select u.id, u.email, u.display_name, u.role,
			u.created_at, u.last_login_at, u.password_hash
		from sessions se join users u on u.id = se.user_id
		where se.token_hash = $1 and se.expires_at > now()`, tokenHash))
	if err != nil {
		return nil, err
	}
	_, err = s.DB.ExecContext(ctx, `update sessions set last_used_at = now(),
			expires_at = now() + make_interval(secs => $2)
		where token_hash = $1 and last_used_at < now() - interval '1 minute'`,
		tokenHash, SessionTTL.Seconds())
	return u, err
}

func (s *Store) DeleteSession(ctx context.Context, tokenHash []byte) error {
	_, err := s.DB.ExecContext(ctx, `delete from sessions where token_hash = $1`, tokenHash)
	return err
}

// DeleteExpiredSessions cleans up; run periodically.
func (s *Store) DeleteExpiredSessions(ctx context.Context) (int64, error) {
	res, err := s.DB.ExecContext(ctx, `delete from sessions where expires_at <= now()`)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}
