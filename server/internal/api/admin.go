package api

import (
	"context"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/mmdshin/ava/server/internal/auth"
	"github.com/mmdshin/ava/server/internal/store"
)

func (s *Server) adminRoutes(mux *http.ServeMux) {
	editor := func(h http.HandlerFunc) http.HandlerFunc { return s.requireRole(store.RoleEditor, h) }
	reviewer := func(h http.HandlerFunc) http.HandlerFunc { return s.requireRole(store.RoleReviewer, h) }
	admin := func(h http.HandlerFunc) http.HandlerFunc { return s.requireRole(store.RoleAdmin, h) }

	// disease categories
	mux.HandleFunc("GET /v1/admin/categories", editor(s.listCategories))
	mux.HandleFunc("POST /v1/admin/categories", editor(s.createCategory))
	mux.HandleFunc("PUT /v1/admin/categories/order", editor(s.reorderCategories))
	mux.HandleFunc("PUT /v1/admin/categories/{id}", editor(s.updateCategory))
	mux.HandleFunc("POST /v1/admin/categories/{id}/archive", editor(s.archive(s.Store.ArchiveCategory, true)))
	mux.HandleFunc("POST /v1/admin/categories/{id}/restore", editor(s.archive(s.Store.ArchiveCategory, false)))

	// care plans
	mux.HandleFunc("GET /v1/admin/care-plans", editor(s.listCarePlans))
	mux.HandleFunc("POST /v1/admin/care-plans", editor(s.createCarePlan))
	mux.HandleFunc("PUT /v1/admin/care-plans/order", editor(s.reorderCarePlans))
	mux.HandleFunc("GET /v1/admin/care-plans/{id}", editor(s.getCarePlan))
	mux.HandleFunc("PUT /v1/admin/care-plans/{id}", editor(s.updateCarePlan))
	mux.HandleFunc("POST /v1/admin/care-plans/{id}/archive", editor(s.archive(s.Store.ArchiveCarePlan, true)))
	mux.HandleFunc("POST /v1/admin/care-plans/{id}/restore", editor(s.archive(s.Store.ArchiveCarePlan, false)))

	// quizzes and questions
	mux.HandleFunc("GET /v1/admin/quizzes", editor(s.listQuizzes))
	mux.HandleFunc("POST /v1/admin/quizzes", editor(s.createQuiz))
	mux.HandleFunc("PUT /v1/admin/quizzes/order", editor(s.reorderQuizzes))
	mux.HandleFunc("GET /v1/admin/quizzes/{id}", editor(s.getQuiz))
	mux.HandleFunc("PUT /v1/admin/quizzes/{id}", editor(s.updateQuiz))
	mux.HandleFunc("POST /v1/admin/quizzes/{id}/archive", editor(s.archive(s.Store.ArchiveQuiz, true)))
	mux.HandleFunc("POST /v1/admin/quizzes/{id}/restore", editor(s.archive(s.Store.ArchiveQuiz, false)))
	mux.HandleFunc("POST /v1/admin/quizzes/{id}/questions", editor(s.createQuestion))
	mux.HandleFunc("PUT /v1/admin/quizzes/{id}/questions/order", editor(s.reorderQuestions))
	mux.HandleFunc("GET /v1/admin/questions/{id}", editor(s.getQuestion))
	mux.HandleFunc("PUT /v1/admin/questions/{id}", editor(s.updateQuestion))
	mux.HandleFunc("POST /v1/admin/questions/{id}/archive", editor(s.archive(s.Store.ArchiveQuestion, true)))
	mux.HandleFunc("POST /v1/admin/questions/{id}/restore", editor(s.archive(s.Store.ArchiveQuestion, false)))

	// Gordon assessment
	mux.HandleFunc("GET /v1/admin/domains", editor(s.listDomains))
	mux.HandleFunc("POST /v1/admin/domains", editor(s.createDomain))
	mux.HandleFunc("PUT /v1/admin/domains/order", editor(s.reorderDomains))
	mux.HandleFunc("PUT /v1/admin/domains/{id}", editor(s.updateDomain))
	mux.HandleFunc("POST /v1/admin/domains/{id}/archive", editor(s.archive(s.Store.ArchiveDomain, true)))
	mux.HandleFunc("POST /v1/admin/domains/{id}/restore", editor(s.archive(s.Store.ArchiveDomain, false)))
	mux.HandleFunc("POST /v1/admin/domains/{id}/findings", editor(s.createFinding))
	mux.HandleFunc("PUT /v1/admin/domains/{id}/findings/order", editor(s.reorderFindings))
	mux.HandleFunc("GET /v1/admin/findings/{id}", editor(s.getFinding))
	mux.HandleFunc("PUT /v1/admin/findings/{id}", editor(s.updateFinding))
	mux.HandleFunc("POST /v1/admin/findings/{id}/archive", editor(s.archive(s.Store.ArchiveFinding, true)))
	mux.HandleFunc("POST /v1/admin/findings/{id}/restore", editor(s.archive(s.Store.ArchiveFinding, false)))

	// tags
	mux.HandleFunc("GET /v1/admin/tags", editor(s.listTags))
	mux.HandleFunc("POST /v1/admin/tags", editor(s.createTag))
	mux.HandleFunc("PUT /v1/admin/tags/{name}", editor(s.updateTag))
	mux.HandleFunc("DELETE /v1/admin/tags/{name}", editor(s.deleteTag))

	// draft, publishing, history
	mux.HandleFunc("GET /v1/admin/draft/issues", editor(s.draftIssues))
	mux.HandleFunc("GET /v1/admin/draft/changes", editor(s.draftChanges))
	mux.HandleFunc("GET /v1/admin/versions", editor(s.listVersions))
	mux.HandleFunc("GET /v1/admin/audit", editor(s.auditLog))
	mux.HandleFunc("GET /v1/admin/settings/freeze", editor(s.getFreeze))
	mux.HandleFunc("POST /v1/admin/publish", reviewer(s.publish))
	mux.HandleFunc("PUT /v1/admin/settings/freeze", admin(s.setFreeze))

	// users
	mux.HandleFunc("GET /v1/admin/users", admin(s.listUsers))
	mux.HandleFunc("POST /v1/admin/users", admin(s.createUserAdmin))
	mux.HandleFunc("PUT /v1/admin/users/{email}/role", admin(s.setRole))
}

func actor(r *http.Request) store.Actor { return store.ActorOf(currentUser(r)) }

// editError turns store errors into HTTP answers.
func (s *Server) editError(w http.ResponseWriter, r *http.Request, err error) {
	var inv *store.InvalidError
	var conflict *store.ConflictError
	var verr *store.ValidationError
	switch {
	case errors.As(err, &inv):
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"code": "invalid", "error": "please fix: " + strings.Join(inv.Issues, "; "), "issues": inv.Issues,
		})
	case errors.As(err, &conflict):
		writeJSON(w, http.StatusConflict, map[string]any{
			"code": "conflict", "error": conflict.Error(), "revision": conflict.Current,
		})
	case errors.As(err, &verr):
		writeJSON(w, http.StatusUnprocessableEntity, map[string]any{
			"code": "content_invalid", "error": "the content has errors; fix them before publishing",
			"issues": verr.Issues,
		})
	case errors.Is(err, store.ErrNotFound):
		writeError(w, http.StatusNotFound, "not_found", "not found")
	case errors.Is(err, store.ErrIDTaken):
		writeError(w, http.StatusConflict, "id_taken", err.Error())
	case errors.Is(err, store.ErrCategoryInUse):
		writeError(w, http.StatusConflict, "category_in_use",
			"only categories without active care plans or quizzes can be removed, and never \"general\"")
	case errors.Is(err, store.ErrTagInUse):
		writeError(w, http.StatusConflict, "tag_in_use", "the tag is still used by care plans or findings")
	case errors.Is(err, store.ErrFrozen):
		writeError(w, http.StatusLocked, "frozen", "publishing is frozen")
	case errors.Is(err, store.ErrNothingChanged):
		writeError(w, http.StatusConflict, "nothing_changed", err.Error())
	case errors.Is(err, store.ErrUnknownRole):
		writeError(w, http.StatusBadRequest, "unknown_role", "role must be nurse, editor, reviewer or admin")
	case errors.Is(err, store.ErrEmailTaken):
		writeError(w, http.StatusConflict, "email_taken", err.Error())
	default:
		s.fail(w, r, err)
	}
}

// reply writes v (or the error).
func (s *Server) reply(w http.ResponseWriter, r *http.Request, status int, v any, err error) {
	if err != nil {
		s.editError(w, r, err)
		return
	}
	if v == nil {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	writeJSON(w, status, v)
}

type archiveFunc func(ctx context.Context, id string, archived bool, by store.Actor) error

// archive hides an item from the next published version, or restores it.
func (s *Server) archive(fn archiveFunc, archived bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		s.reply(w, r, 0, nil, fn(r.Context(), r.PathValue("id"), archived, actor(r)))
	}
}

type orderInput struct {
	Kind string   `json:"kind,omitempty"` // care plans: which disease
	IDs  []string `json:"ids"`
}

// ------------------------------------------------------------ categories

func (s *Server) listCategories(w http.ResponseWriter, r *http.Request) {
	v, err := s.Store.ListCategories(r.Context())
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) createCategory(w http.ResponseWriter, r *http.Request) {
	var in store.CategoryInput
	if !decode(w, r, &in) {
		return
	}
	v, err := s.Store.CreateCategory(r.Context(), in, actor(r))
	s.reply(w, r, http.StatusCreated, v, err)
}

func (s *Server) updateCategory(w http.ResponseWriter, r *http.Request) {
	var in struct {
		store.CategoryInput
		Revision int `json:"revision"`
	}
	if !decode(w, r, &in) {
		return
	}
	v, err := s.Store.UpdateCategory(r.Context(), r.PathValue("id"), in.Revision, in.CategoryInput, actor(r))
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) reorderCategories(w http.ResponseWriter, r *http.Request) {
	var in orderInput
	if !decode(w, r, &in) {
		return
	}
	s.reply(w, r, 0, nil, s.Store.ReorderCategories(r.Context(), in.IDs, actor(r)))
}

// ------------------------------------------------------------ care plans

func (s *Server) listCarePlans(w http.ResponseWriter, r *http.Request) {
	v, err := s.Store.ListCarePlans(r.Context())
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) getCarePlan(w http.ResponseWriter, r *http.Request) {
	v, err := s.Store.GetCarePlan(r.Context(), r.PathValue("id"))
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) createCarePlan(w http.ResponseWriter, r *http.Request) {
	var in store.CarePlanInput
	if !decode(w, r, &in) {
		return
	}
	v, err := s.Store.CreateCarePlan(r.Context(), in, actor(r))
	s.reply(w, r, http.StatusCreated, v, err)
}

func (s *Server) updateCarePlan(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Revision int `json:"revision"`
		store.CarePlanInput
	}
	if !decode(w, r, &in) {
		return
	}
	v, err := s.Store.UpdateCarePlan(r.Context(), r.PathValue("id"), in.Revision, in.CarePlanInput, actor(r))
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) reorderCarePlans(w http.ResponseWriter, r *http.Request) {
	var in orderInput
	if !decode(w, r, &in) {
		return
	}
	s.reply(w, r, 0, nil, s.Store.ReorderCarePlans(r.Context(), in.Kind, in.IDs, actor(r)))
}

// ------------------------------------------------------------ quizzes

func (s *Server) listQuizzes(w http.ResponseWriter, r *http.Request) {
	v, err := s.Store.ListQuizzes(r.Context())
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) getQuiz(w http.ResponseWriter, r *http.Request) {
	v, err := s.Store.GetQuiz(r.Context(), r.PathValue("id"))
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) createQuiz(w http.ResponseWriter, r *http.Request) {
	var in store.QuizInput
	if !decode(w, r, &in) {
		return
	}
	v, err := s.Store.CreateQuiz(r.Context(), in, actor(r))
	s.reply(w, r, http.StatusCreated, v, err)
}

func (s *Server) updateQuiz(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Revision int `json:"revision"`
		store.QuizInput
	}
	if !decode(w, r, &in) {
		return
	}
	v, err := s.Store.UpdateQuiz(r.Context(), r.PathValue("id"), in.Revision, in.QuizInput, actor(r))
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) reorderQuizzes(w http.ResponseWriter, r *http.Request) {
	var in orderInput
	if !decode(w, r, &in) {
		return
	}
	s.reply(w, r, 0, nil, s.Store.ReorderQuizzes(r.Context(), in.IDs, actor(r)))
}

func (s *Server) createQuestion(w http.ResponseWriter, r *http.Request) {
	var in store.QuestionInput
	if !decode(w, r, &in) {
		return
	}
	v, err := s.Store.CreateQuestion(r.Context(), r.PathValue("id"), in, actor(r))
	s.reply(w, r, http.StatusCreated, v, err)
}

func (s *Server) reorderQuestions(w http.ResponseWriter, r *http.Request) {
	var in orderInput
	if !decode(w, r, &in) {
		return
	}
	s.reply(w, r, 0, nil, s.Store.ReorderQuestions(r.Context(), r.PathValue("id"), in.IDs, actor(r)))
}

func (s *Server) getQuestion(w http.ResponseWriter, r *http.Request) {
	v, err := s.Store.GetQuestion(r.Context(), r.PathValue("id"))
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) updateQuestion(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Revision int `json:"revision"`
		store.QuestionInput
	}
	if !decode(w, r, &in) {
		return
	}
	v, err := s.Store.UpdateQuestion(r.Context(), r.PathValue("id"), in.Revision, in.QuestionInput, actor(r))
	s.reply(w, r, http.StatusOK, v, err)
}

// ------------------------------------------------------------ Gordon

func (s *Server) listDomains(w http.ResponseWriter, r *http.Request) {
	v, err := s.Store.ListDomains(r.Context())
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) createDomain(w http.ResponseWriter, r *http.Request) {
	var in store.DomainInput
	if !decode(w, r, &in) {
		return
	}
	v, err := s.Store.CreateDomain(r.Context(), in, actor(r))
	s.reply(w, r, http.StatusCreated, v, err)
}

func (s *Server) updateDomain(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Revision int    `json:"revision"`
		Title    string `json:"title"`
	}
	if !decode(w, r, &in) {
		return
	}
	v, err := s.Store.UpdateDomain(r.Context(), r.PathValue("id"), in.Revision, store.DomainInput{Title: in.Title}, actor(r))
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) reorderDomains(w http.ResponseWriter, r *http.Request) {
	var in orderInput
	if !decode(w, r, &in) {
		return
	}
	s.reply(w, r, 0, nil, s.Store.ReorderDomains(r.Context(), in.IDs, actor(r)))
}

func (s *Server) createFinding(w http.ResponseWriter, r *http.Request) {
	var in store.FindingInput
	if !decode(w, r, &in) {
		return
	}
	v, err := s.Store.CreateFinding(r.Context(), r.PathValue("id"), in, actor(r))
	s.reply(w, r, http.StatusCreated, v, err)
}

func (s *Server) reorderFindings(w http.ResponseWriter, r *http.Request) {
	var in orderInput
	if !decode(w, r, &in) {
		return
	}
	s.reply(w, r, 0, nil, s.Store.ReorderFindings(r.Context(), r.PathValue("id"), in.IDs, actor(r)))
}

func (s *Server) getFinding(w http.ResponseWriter, r *http.Request) {
	v, err := s.Store.GetFinding(r.Context(), r.PathValue("id"))
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) updateFinding(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Revision int      `json:"revision"`
		Title    string   `json:"title"`
		Tags     []string `json:"tags"`
	}
	if !decode(w, r, &in) {
		return
	}
	v, err := s.Store.UpdateFinding(r.Context(), r.PathValue("id"), in.Revision,
		store.FindingInput{Title: in.Title, Tags: in.Tags}, actor(r))
	s.reply(w, r, http.StatusOK, v, err)
}

// ------------------------------------------------------------ tags

func (s *Server) listTags(w http.ResponseWriter, r *http.Request) {
	v, err := s.Store.ListTags(r.Context())
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) createTag(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Name  string `json:"name"`
		Label string `json:"label"`
	}
	if !decode(w, r, &in) {
		return
	}
	err := s.Store.CreateTag(r.Context(), in.Name, in.Label, actor(r))
	s.reply(w, r, http.StatusCreated, map[string]string{"name": strings.TrimSpace(in.Name)}, err)
}

func (s *Server) updateTag(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Name  string `json:"name"`
		Label string `json:"label"`
	}
	if !decode(w, r, &in) {
		return
	}
	s.reply(w, r, 0, nil, s.Store.UpdateTag(r.Context(), r.PathValue("name"), in.Name, in.Label, actor(r)))
}

func (s *Server) deleteTag(w http.ResponseWriter, r *http.Request) {
	s.reply(w, r, 0, nil, s.Store.DeleteTag(r.Context(), r.PathValue("name"), actor(r)))
}

// ------------------------------------------------------------ draft & publishing

func (s *Server) draftIssues(w http.ResponseWriter, r *http.Request) {
	v, err := s.Store.ValidateDraft(r.Context())
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) draftChanges(w http.ResponseWriter, r *http.Request) {
	v, err := s.Store.DraftChanges(r.Context())
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) listVersions(w http.ResponseWriter, r *http.Request) {
	v, err := s.Store.Versions(r.Context())
	if v == nil {
		v = []store.Version{}
	}
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) auditLog(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	before, _ := strconv.ParseInt(q.Get("before"), 10, 64)
	limit, _ := strconv.Atoi(q.Get("limit"))
	v, err := s.Store.Audit(r.Context(), store.AuditFilter{
		Entity: q.Get("entity"), EntityID: q.Get("entityId"), BeforeID: before, Limit: limit,
	})
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) publish(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Notes string `json:"notes"`
	}
	if !decode(w, r, &in) {
		return
	}
	if strings.TrimSpace(in.Notes) == "" {
		writeError(w, http.StatusBadRequest, "invalid", "describe what changed (notes)")
		return
	}
	v, issues, err := s.Store.Publish(r.Context(), store.PublishRequest{Notes: in.Notes, By: actor(r)})
	if err != nil {
		s.editError(w, r, err)
		return
	}
	// The app sees the new version right away.
	s.mu.Lock()
	s.cached = nil
	s.mu.Unlock()
	writeJSON(w, http.StatusCreated, map[string]any{"version": v, "warnings": issues.Warnings})
}

func (s *Server) getFreeze(w http.ResponseWriter, r *http.Request) {
	v, err := s.Store.Freeze(r.Context())
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) setFreeze(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Frozen bool   `json:"frozen"`
		Reason string `json:"reason"`
	}
	if !decode(w, r, &in) {
		return
	}
	if err := s.Store.SetFreeze(r.Context(), in.Frozen, in.Reason, actor(r)); err != nil {
		s.editError(w, r, err)
		return
	}
	v, err := s.Store.Freeze(r.Context())
	s.reply(w, r, http.StatusOK, v, err)
}

// ------------------------------------------------------------ users

func (s *Server) listUsers(w http.ResponseWriter, r *http.Request) {
	v, err := s.Store.ListUsers(r.Context())
	s.reply(w, r, http.StatusOK, v, err)
}

func (s *Server) createUserAdmin(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Email       string `json:"email"`
		DisplayName string `json:"displayName"`
		Role        string `json:"role"`
		Password    string `json:"password"`
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
	hash, err := auth.HashPassword(in.Password)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	u, err := s.Store.CreateUser(r.Context(), email, in.DisplayName, hash, in.Role)
	s.reply(w, r, http.StatusCreated, u, err)
}
