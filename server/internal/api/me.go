package api

import (
	"errors"
	"net/http"
	"regexp"

	"github.com/mmdshin/ava/server/internal/store"
)

// Content ids look like "acs-01", "quiz-1-q01", "hp_smoking".
var contentID = regexp.MustCompile(`^[a-z0-9][a-z0-9_-]{0,63}$`)

func planID(w http.ResponseWriter, r *http.Request) (string, bool) {
	id := r.PathValue("planId")
	if !contentID.MatchString(id) {
		writeError(w, http.StatusBadRequest, "bad_id", "invalid care plan id")
		return "", false
	}
	return id, true
}

func (s *Server) userData(w http.ResponseWriter, r *http.Request) {
	d, err := s.Store.LoadUserData(r.Context(), currentUser(r).ID)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusOK, d)
}

func (s *Server) setFavorite(on bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, ok := planID(w, r)
		if !ok {
			return
		}
		if err := s.Store.SetFavorite(r.Context(), currentUser(r).ID, id, on); err != nil {
			s.fail(w, r, err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}
}

func (s *Server) setNote(w http.ResponseWriter, r *http.Request) {
	id, ok := planID(w, r)
	if !ok {
		return
	}
	var in struct {
		Text string `json:"text"`
	}
	if !decode(w, r, &in) {
		return
	}
	s.saveNote(w, r, id, in.Text)
}

func (s *Server) deleteNote(w http.ResponseWriter, r *http.Request) {
	if id, ok := planID(w, r); ok {
		s.saveNote(w, r, id, "")
	}
}

func (s *Server) saveNote(w http.ResponseWriter, r *http.Request, id, text string) {
	err := s.Store.SetNote(r.Context(), currentUser(r).ID, id, text)
	if errors.Is(err, store.ErrNoteTooLong) {
		writeError(w, http.StatusBadRequest, "note_too_long", "notes are limited to 5000 characters")
		return
	}
	if err != nil {
		s.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) recordView(w http.ResponseWriter, r *http.Request) {
	id, ok := planID(w, r)
	if !ok {
		return
	}
	if err := s.Store.RecordView(r.Context(), currentUser(r).ID, id); err != nil {
		s.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) clearRecent(w http.ResponseWriter, r *http.Request) {
	if err := s.Store.ClearRecent(r.Context(), currentUser(r).ID); err != nil {
		s.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) recordAttempt(w http.ResponseWriter, r *http.Request) {
	var a store.Attempt
	if !decode(w, r, &a) {
		return
	}
	valid := contentID.MatchString(a.QuizID)
	for q := range a.Answers {
		valid = valid && contentID.MatchString(q)
	}
	if !valid {
		writeError(w, http.StatusBadRequest, "bad_attempt", "invalid quiz or question id")
		return
	}
	u := currentUser(r)
	err := s.Store.RecordAttempt(r.Context(), u.ID, a)
	if errors.Is(err, store.ErrBadAttempt) {
		writeError(w, http.StatusBadRequest, "bad_attempt", err.Error())
		return
	}
	if err != nil {
		s.fail(w, r, err)
		return
	}
	d, err := s.Store.LoadUserData(r.Context(), u.ID)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, d)
}
