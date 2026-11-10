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

// EditQuiz is a quiz with all its questions (archived included).
type EditQuiz struct {
	ID        string         `json:"id"`
	Title     string         `json:"title"`
	Kind      string         `json:"kind,omitempty"`
	Questions []EditQuestion `json:"questions"`
	Meta
}

// QuizSummary is a row in the editors' list.
type QuizSummary struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Kind      string `json:"kind,omitempty"`
	Questions int    `json:"questions"`
	Meta
}

// EditQuestion is one question as editors see it.
type EditQuestion struct {
	content.Question
	QuizID string `json:"quizId"`
	Meta
}

// QuizInput creates or updates a quiz's own fields.
type QuizInput struct {
	Title string `json:"title"`
	Kind  string `json:"kind"` // "" for mixed quizzes
}

// QuestionInput creates or updates a question.
type QuestionInput struct {
	Text         string   `json:"text"`
	Options      []string `json:"options"`
	CorrectIndex int      `json:"correctIndex"`
	Explanation  string   `json:"explanation"`
	Hint         string   `json:"hint"`
}

func (in QuestionInput) question(id string) content.Question {
	opts := make([]string, len(in.Options))
	for i, o := range in.Options {
		opts[i] = strings.TrimSpace(o)
	}
	return content.Question{
		ID: id, Text: strings.TrimSpace(in.Text), Options: opts, CorrectIndex: in.CorrectIndex,
		Explanation: strings.TrimSpace(in.Explanation), Hint: strings.TrimSpace(in.Hint),
	}
}

func (s *Store) ListQuizzes(ctx context.Context) ([]QuizSummary, error) {
	rows, err := s.DB.QueryContext(ctx, `select q.id, q.title, coalesce(q.kind, ''),
		(select count(*) from quiz_questions qu where qu.quiz_id = q.id and not qu.archived),
		`+metaCols("q")+` from quizzes q order by q.position, q.id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []QuizSummary{}
	for rows.Next() {
		var q QuizSummary
		if err := rows.Scan(&q.ID, &q.Title, &q.Kind, &q.Questions, &q.Revision, &q.Archived, &q.UpdatedAt, &q.UpdatedBy); err != nil {
			return nil, err
		}
		out = append(out, q)
	}
	return out, rows.Err()
}

func (s *Store) GetQuiz(ctx context.Context, id string) (*EditQuiz, error) {
	return getQuiz(ctx, s.DB, id)
}

func getQuiz(ctx context.Context, q querier, id string) (*EditQuiz, error) {
	var z EditQuiz
	err := q.QueryRowContext(ctx, `select q.id, q.title, coalesce(q.kind, ''), `+metaCols("q")+`
		from quizzes q where q.id = $1`, id).Scan(&z.ID, &z.Title, &z.Kind, &z.Revision, &z.Archived, &z.UpdatedAt, &z.UpdatedBy)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	rows, err := q.QueryContext(ctx, `select qu.id from quiz_questions qu where qu.quiz_id = $1 order by qu.position, qu.id`, id)
	if err != nil {
		return nil, err
	}
	var ids []string
	for rows.Next() {
		var qid string
		if err := rows.Scan(&qid); err != nil {
			rows.Close()
			return nil, err
		}
		ids = append(ids, qid)
	}
	rows.Close()
	z.Questions = []EditQuestion{}
	for _, qid := range ids {
		qu, err := getQuestion(ctx, q, qid)
		if err != nil {
			return nil, err
		}
		z.Questions = append(z.Questions, *qu)
	}
	return &z, nil
}

func (s *Store) GetQuestion(ctx context.Context, id string) (*EditQuestion, error) {
	return getQuestion(ctx, s.DB, id)
}

func getQuestion(ctx context.Context, q querier, id string) (*EditQuestion, error) {
	var e EditQuestion
	var opts []byte
	var explanation, hint sql.NullString
	err := q.QueryRowContext(ctx, `select qu.id, qu.quiz_id, qu.text, qu.correct_index, qu.explanation, qu.hint,
		coalesce((select array_to_json(array_agg(o.text order by o.position)) from quiz_question_options o where o.question_id = qu.id), '[]'),
		`+metaCols("qu")+` from quiz_questions qu where qu.id = $1`, id,
	).Scan(&e.ID, &e.QuizID, &e.Text, &e.CorrectIndex, &explanation, &hint, &opts, &e.Revision, &e.Archived, &e.UpdatedAt, &e.UpdatedBy)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	e.Explanation, e.Hint = explanation.String, hint.String
	return &e, json.Unmarshal(opts, &e.Options)
}

// CreateQuiz adds a quiz with the next free id (quiz-7, …).
func (s *Store) CreateQuiz(ctx context.Context, in QuizInput, by Actor) (*EditQuiz, error) {
	in.Title = strings.TrimSpace(in.Title)
	if issues := content.CheckQuiz(content.Quiz{Title: in.Title, Kind: in.Kind}); len(issues) > 0 {
		return nil, invalid(issues...)
	}
	var created *EditQuiz
	err := s.inTx(ctx, func(tx *sql.Tx) error {
		if in.Kind != "" {
			if err := requireCategory(ctx, tx, in.Kind); err != nil {
				return err
			}
		}
		if _, err := tx.ExecContext(ctx, `select pg_advisory_xact_lock(hashtext('quiz_id'))`); err != nil {
			return err
		}
		var n int
		if err := tx.QueryRowContext(ctx, `select coalesce(max(substring(id from '^quiz-(\d+)$')::int), 0) + 1 from quizzes`).Scan(&n); err != nil {
			return err
		}
		id := fmt.Sprintf("quiz-%d", n)
		pos, err := nextPosition(ctx, tx, "quizzes", "true")
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `insert into quizzes (id, title, kind, position, updated_by) values ($1, $2, $3, $4, $5)`,
			id, in.Title, nullable(in.Kind), pos, by.userID()); err != nil {
			return err
		}
		if created, err = getQuiz(ctx, tx, id); err != nil {
			return err
		}
		return audit(ctx, tx, by, "create", "quiz", id, nil, in)
	})
	return created, err
}

func (s *Store) UpdateQuiz(ctx context.Context, id string, revision int, in QuizInput, by Actor) (*EditQuiz, error) {
	in.Title = strings.TrimSpace(in.Title)
	if issues := content.CheckQuiz(content.Quiz{Title: in.Title, Kind: in.Kind}); len(issues) > 0 {
		return nil, invalid(issues...)
	}
	var updated *EditQuiz
	err := s.inTx(ctx, func(tx *sql.Tx) error {
		if err := lockRevision(ctx, tx, "quizzes", id, revision); err != nil {
			return err
		}
		if in.Kind != "" {
			if err := requireCategory(ctx, tx, in.Kind); err != nil {
				return err
			}
		}
		before, err := getQuiz(ctx, tx, id)
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `update quizzes set title = $2, kind = $3 where id = $1`, id, in.Title, nullable(in.Kind)); err != nil {
			return err
		}
		if err := touch(ctx, tx, "quizzes", id, by); err != nil {
			return err
		}
		if updated, err = getQuiz(ctx, tx, id); err != nil {
			return err
		}
		return audit(ctx, tx, by, "update", "quiz", id,
			QuizInput{Title: before.Title, Kind: before.Kind}, in)
	})
	return updated, err
}

func (s *Store) ArchiveQuiz(ctx context.Context, id string, archived bool, by Actor) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if err := setArchived(ctx, tx, "quizzes", id, archived, by); err != nil {
			return err
		}
		return audit(ctx, tx, by, archiveAction(archived), "quiz", id, nil, nil)
	})
}

func (s *Store) ReorderQuizzes(ctx context.Context, ids []string, by Actor) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if err := reorder(ctx, tx, "quizzes", "true", nil, ids); err != nil {
			return err
		}
		return audit(ctx, tx, by, "reorder", "quiz", "", nil, ids)
	})
}

func writeOptions(ctx context.Context, tx *sql.Tx, id string, options []string) error {
	if _, err := tx.ExecContext(ctx, `delete from quiz_question_options where question_id = $1`, id); err != nil {
		return err
	}
	for i, o := range options {
		if _, err := tx.ExecContext(ctx, `insert into quiz_question_options (question_id, position, text) values ($1, $2, $3)`, id, i, o); err != nil {
			return err
		}
	}
	return nil
}

// CreateQuestion adds a question at the end of a quiz, with the next
// free id (quiz-1-q13, …).
func (s *Store) CreateQuestion(ctx context.Context, quizID string, in QuestionInput, by Actor) (*EditQuestion, error) {
	q := in.question("")
	if issues := content.CheckQuestion(q); len(issues) > 0 {
		return nil, invalid(issues...)
	}
	var created *EditQuestion
	err := s.inTx(ctx, func(tx *sql.Tx) error {
		if _, err := getQuiz(ctx, tx, quizID); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `select pg_advisory_xact_lock(hashtext('question_id:' || $1))`, quizID); err != nil {
			return err
		}
		var n int
		if err := tx.QueryRowContext(ctx, `select coalesce(max(substring(id from '-q(\d+)$')::int), 0) + 1
			from quiz_questions where quiz_id = $1`, quizID).Scan(&n); err != nil {
			return err
		}
		q.ID = fmt.Sprintf("%s-q%02d", quizID, n)
		pos, err := nextPosition(ctx, tx, "quiz_questions", "quiz_id = $1", quizID)
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `insert into quiz_questions (id, quiz_id, position, text, correct_index, explanation, hint, updated_by)
			values ($1, $2, $3, $4, $5, $6, $7, $8)`, q.ID, quizID, pos, q.Text, q.CorrectIndex,
			nullable(q.Explanation), nullable(q.Hint), by.userID()); err != nil {
			return err
		}
		if err := writeOptions(ctx, tx, q.ID, q.Options); err != nil {
			return err
		}
		if created, err = getQuestion(ctx, tx, q.ID); err != nil {
			return err
		}
		return audit(ctx, tx, by, "create", "question", q.ID, nil, created.Question)
	})
	return created, err
}

func (s *Store) UpdateQuestion(ctx context.Context, id string, revision int, in QuestionInput, by Actor) (*EditQuestion, error) {
	q := in.question(id)
	if issues := content.CheckQuestion(q); len(issues) > 0 {
		return nil, invalid(issues...)
	}
	var updated *EditQuestion
	err := s.inTx(ctx, func(tx *sql.Tx) error {
		if err := lockRevision(ctx, tx, "quiz_questions", id, revision); err != nil {
			return err
		}
		before, err := getQuestion(ctx, tx, id)
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `update quiz_questions set text = $2, correct_index = $3, explanation = $4, hint = $5 where id = $1`,
			id, q.Text, q.CorrectIndex, nullable(q.Explanation), nullable(q.Hint)); err != nil {
			return err
		}
		if err := writeOptions(ctx, tx, id, q.Options); err != nil {
			return err
		}
		if err := touch(ctx, tx, "quiz_questions", id, by); err != nil {
			return err
		}
		if updated, err = getQuestion(ctx, tx, id); err != nil {
			return err
		}
		return audit(ctx, tx, by, "update", "question", id, before.Question, updated.Question)
	})
	return updated, err
}

func (s *Store) ArchiveQuestion(ctx context.Context, id string, archived bool, by Actor) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if err := setArchived(ctx, tx, "quiz_questions", id, archived, by); err != nil {
			return err
		}
		return audit(ctx, tx, by, archiveAction(archived), "question", id, nil, nil)
	})
}

func (s *Store) ReorderQuestions(ctx context.Context, quizID string, ids []string, by Actor) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if _, err := getQuiz(ctx, tx, quizID); err != nil {
			return err
		}
		if err := reorder(ctx, tx, "quiz_questions", "quiz_id = $1", []any{quizID}, ids); err != nil {
			return err
		}
		return audit(ctx, tx, by, "reorder", "question", quizID, nil, ids)
	})
}
