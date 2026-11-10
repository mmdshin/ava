package store

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"time"
)

// MistakesQuizID is the quiz id of the "review my mistakes" practice.
const MistakesQuizID = "mistakes"

// MaxRecentPlans kept per user.
const MaxRecentPlans = 10

// QuizScore is a user's record for one quiz.
type QuizScore struct {
	Best     int       `json:"best"`
	Last     int       `json:"last"`
	Total    int       `json:"total"`
	Attempts int       `json:"attempts"`
	LastAt   time.Time `json:"lastAt"`
}

// UserData is everything the app needs about one user, in one response.
type UserData struct {
	Favorites []string             `json:"favorites"`
	Notes     map[string]string    `json:"notes"`
	Recent    []string             `json:"recent"`
	Progress  map[string]QuizScore `json:"progress"`
	Mistakes  []string             `json:"mistakes"`
}

// LoadUserData collects a user's favorites, notes, recent plans, quiz
// progress and current mistakes.
func (s *Store) LoadUserData(ctx context.Context, userID int64) (*UserData, error) {
	d := &UserData{
		Favorites: []string{},
		Notes:     map[string]string{},
		Recent:    []string{},
		Progress:  map[string]QuizScore{},
		Mistakes:  []string{},
	}
	if err := s.strings(ctx, &d.Favorites,
		`select plan_id from user_favorites where user_id = $1 order by created_at, plan_id`, userID); err != nil {
		return nil, err
	}
	if err := s.strings(ctx, &d.Recent,
		`select plan_id from user_recent_plans where user_id = $1 order by viewed_at desc limit $2`,
		userID, MaxRecentPlans); err != nil {
		return nil, err
	}

	rows, err := s.DB.QueryContext(ctx, `select plan_id, text from user_notes where user_id = $1`, userID)
	if err != nil {
		return nil, err
	}
	for rows.Next() {
		var id, text string
		if err := rows.Scan(&id, &text); err != nil {
			rows.Close()
			return nil, err
		}
		d.Notes[id] = text
	}
	rows.Close()

	rows, err = s.DB.QueryContext(ctx, `
		select quiz_id, max(score), count(*),
		       (array_agg(score order by finished_at desc, id desc))[1],
		       (array_agg(total order by finished_at desc, id desc))[1],
		       max(finished_at)
		from quiz_attempts
		where user_id = $1 and quiz_id <> $2
		group by quiz_id`, userID, MistakesQuizID)
	if err != nil {
		return nil, err
	}
	for rows.Next() {
		var id string
		var sc QuizScore
		if err := rows.Scan(&id, &sc.Best, &sc.Attempts, &sc.Last, &sc.Total, &sc.LastAt); err != nil {
			rows.Close()
			return nil, err
		}
		d.Progress[id] = sc
	}
	rows.Close()

	// A question is a mistake when the latest answer to it was wrong.
	if err := s.strings(ctx, &d.Mistakes, `
		select question_id from (
			select distinct on (a.question_id) a.question_id, a.correct
			from quiz_attempt_answers a join quiz_attempts q on q.id = a.attempt_id
			where q.user_id = $1
			order by a.question_id, q.finished_at desc, q.id desc
		) latest where not correct order by question_id`, userID); err != nil {
		return nil, err
	}
	return d, nil
}

func (s *Store) strings(ctx context.Context, out *[]string, query string, args ...any) error {
	rows, err := s.DB.QueryContext(ctx, query, args...)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var v string
		if err := rows.Scan(&v); err != nil {
			return err
		}
		*out = append(*out, v)
	}
	return rows.Err()
}

func (s *Store) SetFavorite(ctx context.Context, userID int64, planID string, on bool) error {
	var err error
	if on {
		_, err = s.DB.ExecContext(ctx, `insert into user_favorites (user_id, plan_id) values ($1, $2)
			on conflict do nothing`, userID, planID)
	} else {
		_, err = s.DB.ExecContext(ctx, `delete from user_favorites where user_id = $1 and plan_id = $2`, userID, planID)
	}
	return err
}

// ErrNoteTooLong: notes are limited to MaxNoteLength characters.
var ErrNoteTooLong = errors.New("note is too long")

const MaxNoteLength = 5000

// SetNote saves a note; empty text deletes it.
func (s *Store) SetNote(ctx context.Context, userID int64, planID, text string) error {
	text = strings.TrimSpace(text)
	if len([]rune(text)) > MaxNoteLength {
		return ErrNoteTooLong
	}
	var err error
	if text == "" {
		_, err = s.DB.ExecContext(ctx, `delete from user_notes where user_id = $1 and plan_id = $2`, userID, planID)
	} else {
		_, err = s.DB.ExecContext(ctx, `insert into user_notes (user_id, plan_id, text) values ($1, $2, $3)
			on conflict (user_id, plan_id) do update set text = excluded.text, updated_at = now()`,
			userID, planID, text)
	}
	return err
}

// RecordView marks a plan as just viewed, keeping the newest few.
func (s *Store) RecordView(ctx context.Context, userID int64, planID string) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `insert into user_recent_plans (user_id, plan_id) values ($1, $2)
			on conflict (user_id, plan_id) do update set viewed_at = now()`, userID, planID); err != nil {
			return err
		}
		_, err := tx.ExecContext(ctx, `delete from user_recent_plans where user_id = $1 and plan_id not in (
			select plan_id from user_recent_plans where user_id = $1 order by viewed_at desc limit $2)`,
			userID, MaxRecentPlans)
		return err
	})
}

// ClearRecent forgets the recently viewed plans.
func (s *Store) ClearRecent(ctx context.Context, userID int64) error {
	_, err := s.DB.ExecContext(ctx, `delete from user_recent_plans where user_id = $1`, userID)
	return err
}

// Attempt is a finished quiz as reported by the app.
type Attempt struct {
	QuizID  string          `json:"quizId"`
	Mode    string          `json:"mode"`
	Answers map[string]bool `json:"answers"` // question id → answered correctly
}

// ErrBadAttempt: the attempt is empty or malformed.
var ErrBadAttempt = errors.New("invalid quiz attempt")

// RecordAttempt stores a finished quiz with its per-question results.
func (s *Store) RecordAttempt(ctx context.Context, userID int64, a Attempt) error {
	if strings.TrimSpace(a.QuizID) == "" || len(a.Answers) == 0 || len(a.Answers) > 500 ||
		(a.Mode != "practice" && a.Mode != "exam") {
		return ErrBadAttempt
	}
	score := 0
	for _, ok := range a.Answers {
		if ok {
			score++
		}
	}
	return s.inTx(ctx, func(tx *sql.Tx) error {
		var id int64
		if err := tx.QueryRowContext(ctx, `insert into quiz_attempts (user_id, quiz_id, mode, score, total)
			values ($1, $2, $3, $4, $5) returning id`,
			userID, a.QuizID, a.Mode, score, len(a.Answers)).Scan(&id); err != nil {
			return err
		}
		for q, ok := range a.Answers {
			if strings.TrimSpace(q) == "" {
				return ErrBadAttempt
			}
			if _, err := tx.ExecContext(ctx, `insert into quiz_attempt_answers (attempt_id, question_id, correct)
				values ($1, $2, $3)`, id, q, ok); err != nil {
				return err
			}
		}
		return nil
	})
}
