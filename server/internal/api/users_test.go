package api_test

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/mmdshin/ava/server/internal/api"
	"github.com/mmdshin/ava/server/internal/auth"
	"github.com/mmdshin/ava/server/internal/store"
	"github.com/mmdshin/ava/server/internal/testutil"
)

type client struct {
	t     *testing.T
	base  string
	token string
}

// do sends a JSON request and decodes a JSON response into out.
func (c *client) do(method, path string, body any, out any) int {
	c.t.Helper()
	var r io.Reader
	if body != nil {
		raw, _ := json.Marshal(body)
		r = bytes.NewReader(raw)
	}
	req, _ := http.NewRequest(method, c.base+path, r)
	req.Header.Set("Content-Type", "application/json")
	if c.token != "" {
		req.Header.Set("Authorization", "Bearer "+c.token)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		c.t.Fatal(err)
	}
	defer res.Body.Close()
	if out != nil {
		json.NewDecoder(res.Body).Decode(out)
	}
	return res.StatusCode
}

func newServer(t *testing.T, signup bool) (*store.Store, *httptest.Server) {
	s := testutil.Store(t)
	srv := httptest.NewServer((&api.Server{
		Store:          s,
		Log:            slog.New(slog.NewTextHandler(io.Discard, nil)),
		AllowedOrigins: []string{"*"},
		AllowSignup:    signup,
	}).Handler())
	t.Cleanup(srv.Close)
	return s, srv
}

type sessionResp struct {
	Token string     `json:"token"`
	User  store.User `json:"user"`
	Code  string     `json:"code"`
}

func TestAccounts(t *testing.T) {
	_, srv := newServer(t, true)
	c := &client{t: t, base: srv.URL}

	var reg sessionResp
	if code := c.do("POST", "/v1/auth/register", map[string]string{
		"email": "Nurse@Example.ir", "password": "secret-pass-1", "displayName": "پرستار",
	}, &reg); code != 201 || reg.Token == "" {
		t.Fatalf("register: %d %+v", code, reg)
	}
	if reg.User.Email != "nurse@example.ir" || reg.User.Role != "nurse" {
		t.Fatalf("user = %+v", reg.User)
	}

	// Validation and duplicates.
	for _, tc := range []struct {
		body map[string]string
		code string
	}{
		{map[string]string{"email": "nurse@example.ir", "password": "another-pass"}, "email_taken"},
		{map[string]string{"email": "not-an-email", "password": "another-pass"}, "invalid_email"},
		{map[string]string{"email": "b@example.ir", "password": "short"}, "weak_password"},
	} {
		var out sessionResp
		c.do("POST", "/v1/auth/register", tc.body, &out)
		if out.Code != tc.code {
			t.Errorf("register %v: code %q, want %q", tc.body, out.Code, tc.code)
		}
	}

	// Login: wrong password, then right (email is case-insensitive).
	var bad sessionResp
	if code := c.do("POST", "/v1/auth/login", map[string]string{"email": "nurse@example.ir", "password": "nope-nope"}, &bad); code != 401 || bad.Code != "wrong_credentials" {
		t.Fatalf("wrong password: %d %q", code, bad.Code)
	}
	var unknown sessionResp
	c.do("POST", "/v1/auth/login", map[string]string{"email": "ghost@example.ir", "password": "whatever-1"}, &unknown)
	if unknown.Code != "wrong_credentials" {
		t.Fatal("unknown email must look like a wrong password")
	}
	var login sessionResp
	if code := c.do("POST", "/v1/auth/login", map[string]string{"email": "NURSE@example.ir", "password": "secret-pass-1"}, &login); code != 200 {
		t.Fatalf("login: %d", code)
	}

	// /me needs a token.
	if code := c.do("GET", "/v1/me", nil, nil); code != 401 {
		t.Fatalf("/me without token: %d", code)
	}
	c.token = login.Token
	var me store.User
	if code := c.do("GET", "/v1/me", nil, &me); code != 200 || me.DisplayName != "پرستار" {
		t.Fatalf("/me: %d %+v", code, me)
	}

	// Changing the password ends every session and returns a new token.
	var changed sessionResp
	if code := c.do("POST", "/v1/me/password", map[string]string{
		"currentPassword": "secret-pass-1", "newPassword": "secret-pass-2",
	}, &changed); code != 200 || changed.Token == "" {
		t.Fatalf("change password: %d", code)
	}
	if code := c.do("GET", "/v1/me", nil, nil); code != 401 {
		t.Fatal("old session still valid after password change")
	}
	c.token = changed.Token

	// Logout ends the session.
	if code := c.do("POST", "/v1/auth/logout", nil, nil); code != 204 {
		t.Fatalf("logout: %d", code)
	}
	if code := c.do("GET", "/v1/me", nil, nil); code != 401 {
		t.Fatal("session still valid after logout")
	}

	// Delete the account (needs the password).
	c.do("POST", "/v1/auth/login", map[string]string{"email": "nurse@example.ir", "password": "secret-pass-2"}, &login)
	c.token = login.Token
	if code := c.do("DELETE", "/v1/me", map[string]string{"password": "wrong-one"}, nil); code != 401 {
		t.Fatalf("delete with wrong password: %d", code)
	}
	if code := c.do("DELETE", "/v1/me", map[string]string{"password": "secret-pass-2"}, nil); code != 204 {
		t.Fatalf("delete: %d", code)
	}
	if code := c.do("POST", "/v1/auth/login", map[string]string{"email": "nurse@example.ir", "password": "secret-pass-2"}, nil); code != 401 {
		t.Fatal("deleted account can still log in")
	}
}

func TestSignupClosedAndRoles(t *testing.T) {
	s, srv := newServer(t, false)
	c := &client{t: t, base: srv.URL}
	var out sessionResp
	if c.do("POST", "/v1/auth/register", map[string]string{"email": "a@example.ir", "password": "long-enough"}, &out); out.Code != "signup_closed" {
		t.Fatalf("signup should be closed, got %q", out.Code)
	}

	ctx := context.Background()
	hash, _ := auth.HashPassword("admin-pass-1")
	s.CreateUser(ctx, "admin@example.ir", "", hash, store.RoleAdmin)
	hash, _ = auth.HashPassword("nurse-pass-1")
	s.CreateUser(ctx, "nurse@example.ir", "", hash, store.RoleNurse)

	c.do("POST", "/v1/auth/login", map[string]string{"email": "nurse@example.ir", "password": "nurse-pass-1"}, &out)
	c.token = out.Token
	if code := c.do("PUT", "/v1/admin/users/nurse@example.ir/role", map[string]string{"role": "admin"}, nil); code != 403 {
		t.Fatalf("nurse promoting herself: %d, want 403", code)
	}

	c.do("POST", "/v1/auth/login", map[string]string{"email": "admin@example.ir", "password": "admin-pass-1"}, &out)
	c.token = out.Token
	if code := c.do("PUT", "/v1/admin/users/nurse@example.ir/role", map[string]string{"role": "editor"}, nil); code != 204 {
		t.Fatalf("admin setting role: %d", code)
	}
	u, _ := s.UserByEmail(ctx, "nurse@example.ir")
	if u.Role != "editor" {
		t.Fatalf("role = %s", u.Role)
	}
	if code := c.do("PUT", "/v1/admin/users/nurse@example.ir/role", map[string]string{"role": "king"}, nil); code != 400 {
		t.Fatalf("unknown role: %d", code)
	}
}

func TestUserData(t *testing.T) {
	s, srv := newServer(t, true)
	c := &client{t: t, base: srv.URL}
	var reg sessionResp
	c.do("POST", "/v1/auth/register", map[string]string{"email": "n@example.ir", "password": "secret-pass-1"}, &reg)
	c.token = reg.Token

	type data = store.UserData
	var d data
	if code := c.do("GET", "/v1/me/data", nil, &d); code != 200 || len(d.Favorites) != 0 || d.Notes == nil {
		t.Fatalf("empty data: %d %+v", code, d)
	}

	c.do("PUT", "/v1/me/favorites/acs-01", nil, nil)
	c.do("PUT", "/v1/me/favorites/acs-01", nil, nil) // idempotent
	c.do("PUT", "/v1/me/favorites/mi-01", nil, nil)
	c.do("DELETE", "/v1/me/favorites/mi-01", nil, nil)
	if code := c.do("PUT", "/v1/me/favorites/BAD ID", nil, nil); code != 400 && code != 404 {
		t.Fatalf("bad id accepted: %d", code)
	}

	c.do("PUT", "/v1/me/notes/acs-01", map[string]string{"text": "  یادداشت  "}, nil)
	c.do("PUT", "/v1/me/notes/chf-01", map[string]string{"text": "x"}, nil)
	c.do("PUT", "/v1/me/notes/chf-01", map[string]string{"text": "   "}, nil) // empty → deleted

	for _, id := range []string{"acs-01", "chf-01", "acs-01"} {
		c.do("POST", "/v1/me/recent/"+id, nil, nil)
	}

	// Quiz attempts: progress and mistakes.
	c.do("POST", "/v1/me/quiz-attempts", map[string]any{
		"quizId": "sample-mi", "mode": "practice",
		"answers": map[string]bool{"sample-mi-q01": false, "sample-mi-q02": true},
	}, nil)
	var after data
	if code := c.do("POST", "/v1/me/quiz-attempts", map[string]any{
		"quizId": "sample-mi", "mode": "exam",
		"answers": map[string]bool{"sample-mi-q01": true, "sample-mi-q02": false},
	}, &after); code != 201 {
		t.Fatalf("attempt: %d", code)
	}
	// Practising mistakes doesn't change the quiz's own score.
	c.do("POST", "/v1/me/quiz-attempts", map[string]any{
		"quizId": "mistakes", "mode": "practice",
		"answers": map[string]bool{"sample-mi-q02": true},
	}, nil)
	if code := c.do("POST", "/v1/me/quiz-attempts", map[string]any{"quizId": "sample-mi", "mode": "exam", "answers": map[string]bool{}}, nil); code != 400 {
		t.Fatalf("empty attempt: %d", code)
	}

	d = data{}
	c.do("GET", "/v1/me/data", nil, &d)
	if len(d.Favorites) != 1 || d.Favorites[0] != "acs-01" {
		t.Errorf("favorites = %v", d.Favorites)
	}
	if len(d.Notes) != 1 || d.Notes["acs-01"] != "یادداشت" {
		t.Errorf("notes = %v", d.Notes)
	}
	if len(d.Recent) != 2 || d.Recent[0] != "acs-01" {
		t.Errorf("recent = %v (newest first)", d.Recent)
	}
	p := d.Progress["sample-mi"]
	if p.Best != 1 || p.Last != 1 || p.Total != 2 || p.Attempts != 2 {
		t.Errorf("progress = %+v", p)
	}
	if _, ok := d.Progress["mistakes"]; ok {
		t.Error("mistakes practice must not have a score")
	}
	if len(d.Mistakes) != 0 {
		t.Errorf("mistakes = %v, want none (both answered right most recently)", d.Mistakes)
	}
	if len(after.Mistakes) != 1 || after.Mistakes[0] != "sample-mi-q02" {
		t.Errorf("mistakes after 2nd attempt = %v", after.Mistakes)
	}

	// Another user sees none of it.
	var other sessionResp
	c.token = ""
	c.do("POST", "/v1/auth/register", map[string]string{"email": "m@example.ir", "password": "secret-pass-1"}, &other)
	c.token = other.Token
	var fresh data // (decoding into d would merge into its maps)
	c.do("GET", "/v1/me/data", nil, &fresh)
	if len(fresh.Favorites)+len(fresh.Notes)+len(fresh.Recent)+len(fresh.Progress)+len(fresh.Mistakes) != 0 {
		t.Errorf("data leaked between users: %+v", fresh)
	}

	// Deleting the account deletes its data.
	u, _ := s.UserByEmail(context.Background(), "n@example.ir")
	s.DeleteUser(context.Background(), u.ID)
	var n int
	s.DB.QueryRow(`select count(*) from user_favorites`).Scan(&n)
	if n != 0 {
		t.Error("favorites left after deleting the account")
	}
}
