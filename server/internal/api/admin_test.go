package api_test

import (
	"context"
	"fmt"
	"strings"
	"testing"

	"github.com/mmdshin/ava/server/internal/auth"
	"github.com/mmdshin/ava/server/internal/contentfile"
	"github.com/mmdshin/ava/server/internal/store"
	"github.com/mmdshin/ava/server/internal/testutil"
)

type errResp struct {
	Code     string   `json:"code"`
	Error    string   `json:"error"`
	Issues   []string `json:"issues"`
	Revision int      `json:"revision"`
}

// adminSetup: sample content published as v1, and one user per role.
func adminSetup(t *testing.T) (*store.Store, map[string]*client) {
	s, srv := newServer(t, true)
	ctx := context.Background()
	b, _ := contentfile.ReadBundle(testutil.SampleBundle())
	if err := s.Import(ctx, b, false); err != nil {
		t.Fatal(err)
	}
	if _, _, err := s.Publish(ctx, store.PublishRequest{Notes: "v1"}); err != nil {
		t.Fatal(err)
	}
	clients := map[string]*client{}
	for _, role := range []string{"nurse", "editor", "reviewer", "admin"} {
		email := role + "@example.ir"
		hash, _ := auth.HashPassword("password-" + role)
		if _, err := s.CreateUser(ctx, email, role, hash, role); err != nil {
			t.Fatal(err)
		}
		c := &client{t: t, base: srv.URL}
		var sess sessionResp
		c.do("POST", "/v1/auth/login", map[string]string{"email": email, "password": "password-" + role}, &sess)
		c.token = sess.Token
		clients[role] = c
	}
	return s, clients
}

func TestAdminRoles(t *testing.T) {
	_, c := adminSetup(t)
	for path, want := range map[string]map[string]int{
		"/v1/admin/care-plans": {"nurse": 403, "editor": 200, "reviewer": 200, "admin": 200},
		"/v1/admin/users":      {"nurse": 403, "editor": 403, "reviewer": 403, "admin": 200},
	} {
		for role, code := range want {
			if got := c[role].do("GET", path, nil, nil); got != code {
				t.Errorf("%s GET %s: %d, want %d", role, path, got, code)
			}
		}
	}
	if got := c["editor"].do("POST", "/v1/admin/publish", map[string]string{"notes": "x"}, nil); got != 403 {
		t.Errorf("editor publishing: %d, want 403", got)
	}
	if got := c["reviewer"].do("PUT", "/v1/admin/settings/freeze", map[string]any{"frozen": true, "reason": "x"}, nil); got != 403 {
		t.Errorf("reviewer freezing: %d, want 403", got)
	}
}

func TestEditCarePlanAndPublish(t *testing.T) {
	_, c := adminSetup(t)
	ed, rev := c["editor"], c["reviewer"]

	plan := map[string]any{
		"kind": "acs", "title": "  خستگی (نمونه جدید)  ", "tags": []string{"fatigue"},
		"sections": []map[string]any{
			{"type": "interventions", "items": []string{"استراحت کافی", " پایش علائم "}},
			{"type": "outcomes", "items": []string{"کاهش خستگی"}},
		},
	}
	var created store.EditCarePlan
	if code := ed.do("POST", "/v1/admin/care-plans", plan, &created); code != 201 {
		t.Fatalf("create: %d", code)
	}
	if created.ID != "acs-03" || created.Revision != 1 || created.Title != "خستگی (نمونه جدید)" {
		t.Fatalf("created = %+v", created)
	}
	if created.Sections[0].Items[1] != "پایش علائم" {
		t.Errorf("items not trimmed: %q", created.Sections[0].Items[1])
	}

	// Update with the right revision.
	plan["revision"] = 1
	plan["title"] = "خستگی (ویرایش)"
	delete(plan, "kind")
	var updated store.EditCarePlan
	if code := ed.do("PUT", "/v1/admin/care-plans/acs-03", plan, &updated); code != 200 || updated.Revision != 2 {
		t.Fatalf("update: %d %+v", code, updated.Meta)
	}
	if updated.UpdatedBy != "editor@example.ir" {
		t.Errorf("updatedBy = %q", updated.UpdatedBy)
	}

	// A stale revision is a conflict, with the current revision.
	var e errResp
	if code := ed.do("PUT", "/v1/admin/care-plans/acs-03", plan, &e); code != 409 || e.Code != "conflict" || e.Revision != 2 {
		t.Fatalf("stale update: %d %+v", code, e)
	}

	// Content rules and unknown tags.
	plan["revision"] = 2
	plan["sections"] = []map[string]any{{"type": "interventions", "items": []string{"x"}}}
	e = errResp{}
	if code := ed.do("PUT", "/v1/admin/care-plans/acs-03", plan, &e); code != 400 || !strings.Contains(strings.Join(e.Issues, " "), "outcomes") {
		t.Fatalf("missing outcomes: %d %+v", code, e)
	}
	plan["sections"] = []map[string]any{
		{"type": "interventions", "items": []string{"x"}}, {"type": "outcomes", "items": []string{"y"}},
	}
	plan["tags"] = []string{"no_such_tag"}
	e = errResp{}
	if code := ed.do("PUT", "/v1/admin/care-plans/acs-03", plan, &e); code != 400 || !strings.Contains(e.Error, "unknown tag") {
		t.Fatalf("unknown tag: %d %+v", code, e)
	}

	// Draft changes, publish, then nothing changed.
	var changes []store.Change
	ed.do("GET", "/v1/admin/draft/changes", nil, &changes)
	if len(changes) != 1 || changes[0].ID != "acs-03" || changes[0].Kind != "added" {
		t.Fatalf("changes = %+v", changes)
	}
	if code := rev.do("POST", "/v1/admin/publish", map[string]string{"notes": ""}, nil); code != 400 {
		t.Fatalf("publish without notes: %d", code)
	}
	var pub struct {
		Version store.Version `json:"version"`
	}
	if code := rev.do("POST", "/v1/admin/publish", map[string]string{"notes": "new plan"}, &pub); code != 201 || pub.Version.Version != 2 {
		t.Fatalf("publish: %d %+v", code, pub)
	}
	var m struct {
		Version int `json:"version"`
	}
	ed.do("GET", "/v1/content/manifest", nil, &m)
	if m.Version != 2 {
		t.Fatalf("manifest still at %d after publishing", m.Version)
	}
	ed.do("GET", "/v1/admin/draft/changes", nil, &changes)
	if len(changes) != 0 {
		t.Fatalf("changes after publish = %+v", changes)
	}
	e = errResp{}
	if code := rev.do("POST", "/v1/admin/publish", map[string]string{"notes": "again"}, &e); code != 409 || e.Code != "nothing_changed" {
		t.Fatalf("publish unchanged: %d %+v", code, e)
	}

	// Archive → "removed"; restore → no change.
	if code := ed.do("POST", "/v1/admin/care-plans/acs-03/archive", nil, nil); code != 204 {
		t.Fatalf("archive: %d", code)
	}
	ed.do("GET", "/v1/admin/draft/changes", nil, &changes)
	if len(changes) != 1 || changes[0].Kind != "removed" {
		t.Fatalf("after archive: %+v", changes)
	}
	ed.do("POST", "/v1/admin/care-plans/acs-03/restore", nil, nil)
	ed.do("GET", "/v1/admin/draft/changes", nil, &changes)
	if len(changes) != 0 {
		t.Fatalf("after restore: %+v", changes)
	}

	// Content-wide rules block publishing: no general plans left.
	ed.do("POST", "/v1/admin/care-plans/general-01/archive", nil, nil)
	ed.do("POST", "/v1/admin/care-plans/general-02/archive", nil, nil)
	e = errResp{}
	if code := rev.do("POST", "/v1/admin/publish", map[string]string{"notes": "broken"}, &e); code != 422 || e.Code != "content_invalid" {
		t.Fatalf("publishing invalid content: %d %+v", code, e)
	}
	var issues struct {
		Errors []string `json:"errors"`
	}
	ed.do("GET", "/v1/admin/draft/issues", nil, &issues)
	if !strings.Contains(strings.Join(issues.Errors, " "), "no care plans for general") {
		t.Fatalf("issues = %+v", issues)
	}

	// The log knows who did what.
	var log []store.AuditEntry
	ed.do("GET", "/v1/admin/audit?entity=care_plan&entityId=acs-03", nil, &log)
	var actions []string
	for _, l := range log {
		actions = append(actions, l.Action+":"+l.User)
	}
	want := "restore:editor@example.ir archive:editor@example.ir update:editor@example.ir create:editor@example.ir"
	if strings.Join(actions, " ") != want {
		t.Fatalf("audit = %v", actions)
	}
}

func TestEditQuizzesFindingsTags(t *testing.T) {
	_, c := adminSetup(t)
	ed := c["editor"]

	var q store.EditQuestion
	if code := ed.do("POST", "/v1/admin/quizzes/sample-mi/questions", map[string]any{
		"text": "سؤال تازه؟", "options": []string{"الف", "ب", "ج"}, "correctIndex": 2, "explanation": "چون…",
	}, &q); code != 201 || q.ID != "sample-mi-q03" {
		t.Fatalf("create question: %d %+v", code, q)
	}
	var e errResp
	if code := ed.do("PUT", "/v1/admin/questions/sample-mi-q03", map[string]any{
		"revision": 1, "text": "x", "options": []string{"الف", "ب"}, "correctIndex": 5,
	}, &e); code != 400 {
		t.Fatalf("bad answer key: %d %+v", code, e)
	}
	if code := ed.do("PUT", "/v1/admin/quizzes/sample-mi/questions/order", map[string]any{
		"ids": []string{"sample-mi-q03"},
	}, nil); code != 204 {
		t.Fatalf("reorder: %d", code)
	}
	var quiz store.EditQuiz
	ed.do("GET", "/v1/admin/quizzes/sample-mi", nil, &quiz)
	if len(quiz.Questions) != 3 || quiz.Questions[0].ID != "sample-mi-q03" {
		t.Fatalf("quiz order = %+v", quiz.Questions)
	}
	var newQuiz store.EditQuiz
	if code := ed.do("POST", "/v1/admin/quizzes", map[string]any{"title": "آزمون جدید", "kind": "chf"}, &newQuiz); code != 201 || newQuiz.ID != "quiz-1" {
		t.Fatalf("create quiz: %d %+v", code, newQuiz)
	}

	// Tags: typo guard, rename everywhere, delete only when unused.
	e = errResp{}
	if code := ed.do("POST", "/v1/admin/tags", map[string]string{"name": "anxiet"}, &e); code != 400 || !strings.Contains(e.Error, "typo") {
		t.Fatalf("typo tag: %d %+v", code, e)
	}
	if code := ed.do("POST", "/v1/admin/tags", map[string]string{"name": "nausea", "label": "تهوع"}, nil); code != 201 {
		t.Fatalf("create tag: %d", code)
	}
	if code := ed.do("PUT", "/v1/admin/tags/fear", map[string]string{"name": "fear_of_death", "label": "ترس"}, nil); code != 204 {
		t.Fatalf("rename tag: %d", code)
	}
	var plan store.EditCarePlan
	ed.do("GET", "/v1/admin/care-plans/acs-02", nil, &plan)
	if fmt.Sprint(plan.Tags) != "[anxiety fear_of_death]" {
		t.Fatalf("rename didn't follow: %v", plan.Tags)
	}
	if code := ed.do("DELETE", "/v1/admin/tags/anxiety", nil, nil); code != 409 {
		t.Fatalf("deleting a used tag: %d", code)
	}
	if code := ed.do("DELETE", "/v1/admin/tags/nausea", nil, nil); code != 204 {
		t.Fatalf("deleting an unused tag: %d", code)
	}

	// Findings: generated id, which plans they lead to, duplicates.
	ed.do("POST", "/v1/admin/tags", map[string]string{"name": "nausea"}, nil)
	var f store.EditFinding
	if code := ed.do("POST", "/v1/admin/domains/comfort/findings", map[string]any{
		"title": "تهوع", "tags": []string{"nausea"},
	}, &f); code != 201 || f.ID != "comfort_1" || len(f.Plans) != 0 {
		t.Fatalf("create finding: %d %+v", code, f)
	}
	var issues struct {
		Warnings []string `json:"warnings"`
	}
	ed.do("GET", "/v1/admin/draft/issues", nil, &issues)
	if len(issues.Warnings) != 1 || !strings.Contains(issues.Warnings[0], "comfort_1") {
		t.Fatalf("warnings = %v", issues.Warnings)
	}
	if code := ed.do("POST", "/v1/admin/domains/comfort/findings", map[string]any{
		"id": "comfort_1", "title": "دوباره", "tags": []string{"pain"},
	}, &e); code != 409 {
		t.Fatalf("duplicate finding id: %d", code)
	}
	ed.do("PUT", "/v1/admin/findings/comfort_1", map[string]any{"revision": 1, "title": "تهوع", "tags": []string{"nausea", "chest_pain"}}, &f)
	if len(f.Plans) != 2 {
		t.Fatalf("finding now leads to %v", f.Plans)
	}
}

func TestPublishingFreeze(t *testing.T) {
	_, c := adminSetup(t)
	c["editor"].do("POST", "/v1/admin/tags", map[string]string{"name": "nausea"}, nil)
	c["editor"].do("POST", "/v1/admin/domains/comfort/findings", map[string]any{"title": "تهوع", "tags": []string{"nausea", "pain"}}, nil)

	if code := c["admin"].do("PUT", "/v1/admin/settings/freeze", map[string]any{"frozen": true}, nil); code != 400 {
		t.Fatalf("freeze without a reason: %d", code)
	}
	if code := c["admin"].do("PUT", "/v1/admin/settings/freeze", map[string]any{"frozen": true, "reason": "کارآزمایی بالینی"}, nil); code != 200 {
		t.Fatalf("freeze: %d", code)
	}
	var f store.FreezeState
	c["editor"].do("GET", "/v1/admin/settings/freeze", nil, &f)
	if !f.Frozen || f.UpdatedBy != "admin@example.ir" {
		t.Fatalf("freeze state = %+v", f)
	}
	var e errResp
	if code := c["reviewer"].do("POST", "/v1/admin/publish", map[string]string{"notes": "x"}, &e); code != 423 || e.Code != "frozen" {
		t.Fatalf("publish while frozen: %d %+v", code, e)
	}
	c["admin"].do("PUT", "/v1/admin/settings/freeze", map[string]any{"frozen": false}, nil)
	if code := c["reviewer"].do("POST", "/v1/admin/publish", map[string]string{"notes": "x"}, nil); code != 201 {
		t.Fatalf("publish after unfreezing: %d", code)
	}
}

func TestAdminUsers(t *testing.T) {
	_, c := adminSetup(t)
	var u store.User
	if code := c["admin"].do("POST", "/v1/admin/users", map[string]string{
		"email": "new@example.ir", "displayName": "جدید", "role": "editor", "password": "long-enough-1",
	}, &u); code != 201 || u.Role != "editor" {
		t.Fatalf("create user: %d %+v", code, u)
	}
	c["admin"].do("PUT", "/v1/admin/users/new@example.ir/role", map[string]string{"role": "reviewer"}, nil)
	var users []store.User
	c["admin"].do("GET", "/v1/admin/users", nil, &users)
	var found bool
	for _, x := range users {
		found = found || (x.Email == "new@example.ir" && x.Role == "reviewer")
	}
	if !found || len(users) != 5 {
		t.Fatalf("users = %+v", users)
	}
	var log []store.AuditEntry
	c["admin"].do("GET", "/v1/admin/audit?entity=user", nil, &log)
	if len(log) != 1 || log[0].Action != "set_role" {
		t.Fatalf("role change not logged: %+v", log)
	}
}
