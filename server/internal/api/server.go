package api

import (
	"compress/gzip"
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/mmdshin/ava/server/internal/auth"
	"github.com/mmdshin/ava/server/internal/store"
)

// Server holds the HTTP handlers.
type Server struct {
	Store *store.Store
	Log   *slog.Logger
	// Origins allowed to call the API from a browser (the Flutter web
	// app). "*" allows any.
	AllowedOrigins []string
	// How long the latest version is cached in memory.
	CacheTTL time.Duration

	// Whether anyone can create an account (else admins create them).
	AllowSignup bool

	warnedOrigins sync.Map

	loginLimiter  *auth.Limiter
	signupLimiter *auth.Limiter

	mu        sync.Mutex
	cached    *store.Version
	cachedAt  time.Time
	gzipped   []byte
	gzippedOf int
}

// Handler returns the routes with logging, CORS and panic recovery.
func (s *Server) Handler() http.Handler {
	if s.loginLimiter == nil {
		// Per email and per IP: slow down password guessing.
		s.loginLimiter = auth.NewLimiter(10, 15*time.Minute)
		s.signupLimiter = auth.NewLimiter(5, time.Hour)
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.health)
	mux.HandleFunc("GET /v1/content/manifest", s.manifest)
	mux.HandleFunc("GET /v1/content/bundle", s.bundle)

	mux.HandleFunc("POST /v1/auth/register", s.register)
	mux.HandleFunc("POST /v1/auth/login", s.login)
	mux.HandleFunc("POST /v1/auth/logout", s.requireUser(s.logout))

	mux.HandleFunc("GET /v1/me", s.requireUser(s.me))
	mux.HandleFunc("DELETE /v1/me", s.requireUser(s.deleteAccount))
	mux.HandleFunc("POST /v1/me/password", s.requireUser(s.changePassword))
	mux.HandleFunc("GET /v1/me/data", s.requireUser(s.userData))
	mux.HandleFunc("PUT /v1/me/favorites/{planId}", s.requireUser(s.setFavorite(true)))
	mux.HandleFunc("DELETE /v1/me/favorites/{planId}", s.requireUser(s.setFavorite(false)))
	mux.HandleFunc("PUT /v1/me/notes/{planId}", s.requireUser(s.setNote))
	mux.HandleFunc("DELETE /v1/me/notes/{planId}", s.requireUser(s.deleteNote))
	mux.HandleFunc("POST /v1/me/recent/{planId}", s.requireUser(s.recordView))
	mux.HandleFunc("DELETE /v1/me/recent", s.requireUser(s.clearRecent))
	mux.HandleFunc("POST /v1/me/quiz-attempts", s.requireUser(s.recordAttempt))

	s.adminRoutes(mux)
	return s.recoverer(s.logger(s.cors(s.limitBody(mux))))
}

func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if err := s.Store.DB.PingContext(ctx); err != nil {
		http.Error(w, "database unavailable", http.StatusServiceUnavailable)
		return
	}
	w.Write([]byte("ok"))
}

// latest returns the newest version, cached for CacheTTL.
func (s *Server) latest(ctx context.Context) (*store.Version, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.cached != nil && time.Since(s.cachedAt) < s.CacheTTL {
		return s.cached, nil
	}
	v, err := s.Store.Latest(ctx)
	if err != nil {
		return nil, err
	}
	s.cached, s.cachedAt = v, time.Now()
	return v, nil
}

type manifest struct {
	Version       int       `json:"version"`
	SchemaVersion int       `json:"schemaVersion"`
	PublishedAt   time.Time `json:"publishedAt"`
	SHA256        string    `json:"sha256"`
	Size          int       `json:"size"`
}

func (s *Server) manifest(w http.ResponseWriter, r *http.Request) {
	v, err := s.latest(r.Context())
	if err != nil {
		s.fail(w, r, err)
		return
	}
	w.Header().Set("Cache-Control", "no-cache")
	writeJSON(w, http.StatusOK, manifest{
		Version:       v.Version,
		SchemaVersion: v.SchemaVersion,
		PublishedAt:   v.PublishedAt.UTC(),
		SHA256:        v.SHA256,
		Size:          len(v.Bundle),
	})
}

func (s *Server) bundle(w http.ResponseWriter, r *http.Request) {
	var v *store.Version
	var err error
	if q := r.URL.Query().Get("version"); q != "" {
		n, convErr := strconv.Atoi(q)
		if convErr != nil || n < 1 {
			writeError(w, http.StatusBadRequest, "bad_request", "version must be a positive number")
			return
		}
		v, err = s.Store.GetVersion(r.Context(), n)
	} else {
		v, err = s.latest(r.Context())
	}
	if err != nil {
		s.fail(w, r, err)
		return
	}

	etag := `"v` + strconv.Itoa(v.Version) + `-` + v.SHA256[:16] + `"`
	w.Header().Set("ETag", etag)
	w.Header().Set("Vary", "Accept-Encoding")
	// A specific version never changes; "latest" must be revalidated.
	if r.URL.Query().Has("version") {
		w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	} else {
		w.Header().Set("Cache-Control", "no-cache")
	}
	if match := r.Header.Get("If-None-Match"); match != "" && strings.Contains(match, etag) {
		w.WriteHeader(http.StatusNotModified)
		return
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	if strings.Contains(r.Header.Get("Accept-Encoding"), "gzip") {
		w.Header().Set("Content-Encoding", "gzip")
		w.Write(s.gzip(v))
		return
	}
	w.Write(v.Bundle)
}

// gzip compresses a version once and keeps the result.
func (s *Server) gzip(v *store.Version) []byte {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.gzipped != nil && s.gzippedOf == v.Version {
		return s.gzipped
	}
	var buf strings.Builder
	zw, _ := gzip.NewWriterLevel(&buf, gzip.BestCompression)
	zw.Write(v.Bundle)
	zw.Close()
	s.gzipped, s.gzippedOf = []byte(buf.String()), v.Version
	return s.gzipped
}

func (s *Server) fail(w http.ResponseWriter, r *http.Request, err error) {
	if errors.Is(err, store.ErrNoVersion) {
		writeError(w, http.StatusNotFound, "no_content", "no published content")
		return
	}
	s.Log.Error("request failed", "path", r.URL.Path, "err", err)
	writeError(w, http.StatusInternalServerError, "internal", "internal error")
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]string{"error": message, "code": code})
}

// decode reads a JSON body into v (unknown fields are rejected).
func decode(w http.ResponseWriter, r *http.Request, v any) bool {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(v); err != nil {
		writeError(w, http.StatusBadRequest, "bad_request", "invalid JSON: "+err.Error())
		return false
	}
	return true
}

// limitBody caps request bodies at 1 MB.
func (s *Server) limitBody(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

// ------------------------------------------------------------ middleware

func (s *Server) cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" && !s.originAllowed(origin) {
			s.warnOrigin(origin)
		}
		if origin != "" && s.originAllowed(origin) {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Add("Vary", "Origin")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "If-None-Match, Content-Type, Authorization")
			w.Header().Set("Access-Control-Expose-Headers", "ETag")
			w.Header().Set("Access-Control-Max-Age", "86400")
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// warnOrigin logs (once per origin) a browser call from an origin that
// isn't in CORS_ORIGINS, the usual cause of "CORS error" in the app.
func (s *Server) warnOrigin(origin string) {
	if _, seen := s.warnedOrigins.LoadOrStore(origin, true); !seen {
		s.Log.Warn("blocked a browser request from an origin not in CORS_ORIGINS",
			"origin", origin, "allowed", strings.Join(s.AllowedOrigins, ","))
	}
}

func (s *Server) originAllowed(origin string) bool {
	for _, o := range s.AllowedOrigins {
		if o == "*" || strings.EqualFold(o, origin) {
			return true
		}
	}
	return false
}

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (w *statusWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

func (s *Server) logger(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(sw, r)
		s.Log.Info("http", "method", r.Method, "path", r.URL.Path,
			"status", sw.status, "ms", time.Since(start).Milliseconds())
	})
}

func (s *Server) recoverer(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if p := recover(); p != nil {
				s.Log.Error("panic", "path", r.URL.Path, "panic", p)
				writeError(w, http.StatusInternalServerError, "internal", "internal error")
			}
		}()
		next.ServeHTTP(w, r)
	})
}
