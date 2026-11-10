package api

import (
	"context"
	"errors"
	"net"
	"net/http"
	"net/mail"
	"strings"
	"unicode/utf8"

	"github.com/mmdshin/ava/server/internal/auth"
	"github.com/mmdshin/ava/server/internal/store"
)

type ctxKey int

const userKey ctxKey = 0

func currentUser(r *http.Request) *store.User {
	u, _ := r.Context().Value(userKey).(*store.User)
	return u
}

func bearerToken(r *http.Request) string {
	h := r.Header.Get("Authorization")
	if t, ok := strings.CutPrefix(h, "Bearer "); ok {
		return strings.TrimSpace(t)
	}
	return ""
}

// requireUser rejects requests without a valid session.
func (s *Server) requireUser(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := bearerToken(r)
		if token == "" {
			writeError(w, http.StatusUnauthorized, "unauthorized", "login required")
			return
		}
		u, err := s.Store.UserBySession(r.Context(), auth.HashToken(token))
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusUnauthorized, "unauthorized", "session expired, please log in again")
			return
		}
		if err != nil {
			s.fail(w, r, err)
			return
		}
		next(w, r.WithContext(context.WithValue(r.Context(), userKey, u)))
	}
}

// requireRole also checks the user's role.
func (s *Server) requireRole(role string, next http.HandlerFunc) http.HandlerFunc {
	return s.requireUser(func(w http.ResponseWriter, r *http.Request) {
		if !currentUser(r).Can(role) {
			writeError(w, http.StatusForbidden, "forbidden", "you don't have access to this")
			return
		}
		next(w, r)
	})
}

type session struct {
	Token string      `json:"token"`
	User  *store.User `json:"user"`
}

func (s *Server) startSession(w http.ResponseWriter, r *http.Request, status int, u *store.User) {
	token, hash, err := auth.NewToken()
	if err == nil {
		err = s.Store.CreateSession(r.Context(), u.ID, hash, r.UserAgent())
	}
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, status, session{Token: token, User: u})
}

func clientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func validEmail(email string) bool {
	a, err := mail.ParseAddress(email)
	return err == nil && a.Address == email && len(email) <= 254
}

func (s *Server) register(w http.ResponseWriter, r *http.Request) {
	if !s.AllowSignup {
		writeError(w, http.StatusForbidden, "signup_closed", "signing up is closed; ask an administrator")
		return
	}
	var in struct {
		Email       string `json:"email"`
		Password    string `json:"password"`
		DisplayName string `json:"displayName"`
	}
	if !decode(w, r, &in) {
		return
	}
	email := store.NormalizeEmail(in.Email)
	if !validEmail(email) {
		writeError(w, http.StatusBadRequest, "invalid_email", "invalid email address")
		return
	}
	if err := auth.CheckPasswordPolicy(in.Password); err != nil {
		writeError(w, http.StatusBadRequest, "weak_password", err.Error())
		return
	}
	if utf8.RuneCountInString(in.DisplayName) > 100 {
		writeError(w, http.StatusBadRequest, "invalid_name", "name is too long")
		return
	}
	if !s.signupLimiter.Allow(clientIP(r)) {
		writeError(w, http.StatusTooManyRequests, "too_many_attempts", "too many sign-ups, try again later")
		return
	}
	hash, err := auth.HashPassword(in.Password)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	u, err := s.Store.CreateUser(r.Context(), email, in.DisplayName, hash, store.RoleNurse)
	if errors.Is(err, store.ErrEmailTaken) {
		writeError(w, http.StatusConflict, "email_taken", err.Error())
		return
	}
	if err != nil {
		s.fail(w, r, err)
		return
	}
	s.startSession(w, r, http.StatusCreated, u)
}

func (s *Server) login(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if !decode(w, r, &in) {
		return
	}
	email := store.NormalizeEmail(in.Email)
	if !s.loginLimiter.Allow("email:"+email) || !s.loginLimiter.Allow("ip:"+clientIP(r)) {
		writeError(w, http.StatusTooManyRequests, "too_many_attempts", "too many attempts, try again in 15 minutes")
		return
	}
	u, err := s.Store.UserByEmail(r.Context(), email)
	if err != nil && !errors.Is(err, store.ErrNotFound) {
		s.fail(w, r, err)
		return
	}
	if u == nil {
		auth.SpendTime(in.Password)
	}
	if u == nil || !auth.VerifyPassword(in.Password, u.PasswordHash()) {
		writeError(w, http.StatusUnauthorized, "wrong_credentials", "wrong email or password")
		return
	}
	s.loginLimiter.Reset("email:" + email)
	s.startSession(w, r, http.StatusOK, u)
}

func (s *Server) logout(w http.ResponseWriter, r *http.Request) {
	if err := s.Store.DeleteSession(r.Context(), auth.HashToken(bearerToken(r))); err != nil {
		s.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) me(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, currentUser(r))
}

func (s *Server) changePassword(w http.ResponseWriter, r *http.Request) {
	var in struct {
		CurrentPassword string `json:"currentPassword"`
		NewPassword     string `json:"newPassword"`
	}
	if !decode(w, r, &in) {
		return
	}
	u := currentUser(r)
	if !s.loginLimiter.Allow("email:" + u.Email) {
		writeError(w, http.StatusTooManyRequests, "too_many_attempts", "too many attempts, try again later")
		return
	}
	if !auth.VerifyPassword(in.CurrentPassword, u.PasswordHash()) {
		writeError(w, http.StatusUnauthorized, "wrong_credentials", "current password is wrong")
		return
	}
	if err := auth.CheckPasswordPolicy(in.NewPassword); err != nil {
		writeError(w, http.StatusBadRequest, "weak_password", err.Error())
		return
	}
	hash, err := auth.HashPassword(in.NewPassword)
	if err == nil {
		err = s.Store.SetPassword(r.Context(), u.ID, hash)
	}
	if err != nil {
		s.fail(w, r, err)
		return
	}
	s.startSession(w, r, http.StatusOK, u)
}

func (s *Server) deleteAccount(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Password string `json:"password"`
	}
	if !decode(w, r, &in) {
		return
	}
	u := currentUser(r)
	if !auth.VerifyPassword(in.Password, u.PasswordHash()) {
		writeError(w, http.StatusUnauthorized, "wrong_credentials", "password is wrong")
		return
	}
	if err := s.Store.DeleteUser(r.Context(), u.ID); err != nil {
		s.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) setRole(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Role string `json:"role"`
	}
	if !decode(w, r, &in) {
		return
	}
	err := s.Store.SetRoleAs(r.Context(), r.PathValue("email"), in.Role, actor(r))
	switch {
	case errors.Is(err, store.ErrUnknownRole):
		writeError(w, http.StatusBadRequest, "unknown_role", "role must be nurse, editor, reviewer or admin")
	case errors.Is(err, store.ErrNotFound):
		writeError(w, http.StatusNotFound, "not_found", "no such user")
	case err != nil:
		s.fail(w, r, err)
	default:
		w.WriteHeader(http.StatusNoContent)
	}
}
