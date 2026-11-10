package api_test

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/mmdshin/ava/server/internal/content"
	"github.com/mmdshin/ava/server/internal/store"
)

func TestCategories(t *testing.T) {
	s, c := adminSetup(t)
	ed, rev := c["editor"], c["reviewer"]

	var list []store.EditCategory
	if code := ed.do("GET", "/v1/admin/categories", nil, &list); code != 200 || len(list) != 5 {
		t.Fatalf("list: %d %+v", code, list)
	}
	if list[0].ID != "acs" || list[0].Plans != 2 || list[4].ID != "general" {
		t.Fatalf("list = %+v", list)
	}

	// Add one; the id must be new and the fields valid.
	copd := map[string]any{"id": "copd", "title": "بیماری انسدادی ریه", "abbr": "COPD", "color": "#0e7490", "icon": "air"}
	var created store.EditCategory
	if code := ed.do("POST", "/v1/admin/categories", copd, &created); code != 201 || created.Color != "#0E7490" {
		t.Fatalf("create: %d %+v", code, created)
	}
	var e errResp
	if code := ed.do("POST", "/v1/admin/categories", copd, &e); code != 409 || e.Code != "id_taken" {
		t.Fatalf("duplicate: %d %+v", code, e)
	}
	e = errResp{}
	bad := map[string]any{"id": "x-1", "title": "", "color": "teal", "icon": "rocket"}
	if code := ed.do("POST", "/v1/admin/categories", bad, &e); code != 400 || len(e.Issues) != 4 {
		t.Fatalf("invalid: %d %+v", code, e)
	}

	// An empty category blocks publishing until it has a plan.
	var issues content.Issues
	ed.do("GET", "/v1/admin/draft/issues", nil, &issues)
	if !strings.Contains(strings.Join(issues.Errors, " "), "no care plans for copd") {
		t.Fatalf("issues = %+v", issues)
	}
	plan := map[string]any{
		"kind": "copd", "title": "الگوی تنفسی ناکارآمد", "tags": []string{"dyspnea"},
		"sections": []map[string]any{
			{"type": "interventions", "items": []string{"پایش اشباع اکسیژن"}},
			{"type": "outcomes", "items": []string{"تنفس راحت"}},
		},
	}
	var p store.EditCarePlan
	if code := ed.do("POST", "/v1/admin/care-plans", plan, &p); code != 201 || p.ID != "copd-01" {
		t.Fatalf("plan in new category: %d %+v", code, p)
	}

	// Recolor (with the revision we started from).
	var acs store.EditCategory
	upd := map[string]any{"revision": 1, "title": "سندرم کرونری حاد", "abbr": "ACS", "color": "#FF0000", "icon": "favorite"}
	if code := ed.do("PUT", "/v1/admin/categories/acs", upd, &acs); code != 200 || acs.Color != "#FF0000" || acs.Revision != 2 {
		t.Fatalf("update: %d %+v", code, acs)
	}
	e = errResp{}
	if code := ed.do("PUT", "/v1/admin/categories/acs", upd, &e); code != 409 || e.Code != "conflict" {
		t.Fatalf("stale update: %d %+v", code, e)
	}

	// Only empty categories can be removed, and never "general".
	for _, id := range []string{"acs", "general", "copd"} {
		e = errResp{}
		if code := ed.do("POST", "/v1/admin/categories/"+id+"/archive", nil, &e); code != 409 || e.Code != "category_in_use" {
			t.Fatalf("archive %s: %d %+v", id, code, e)
		}
	}

	// Show COPD first and publish.
	if code := ed.do("PUT", "/v1/admin/categories/order", map[string]any{"ids": []string{"copd"}}, nil); code != 204 {
		t.Fatalf("reorder: %d", code)
	}
	var changes []store.Change
	ed.do("GET", "/v1/admin/draft/changes", nil, &changes)
	kinds := map[string]string{}
	for _, ch := range changes {
		kinds[ch.Entity+":"+ch.ID] = ch.Kind
	}
	if kinds["category:copd"] != "added" || kinds["category:acs"] != "changed" || kinds["care_plan:copd-01"] != "added" {
		t.Fatalf("changes = %+v", changes)
	}
	// The plan's tag can't be selected in the assessment yet; add a finding.
	ed.do("POST", "/v1/admin/domains/"+firstDomain(t, ed)+"/findings",
		map[string]any{"title": "تنگی نفس (آزمایشی)", "tags": []string{"dyspnea"}}, nil)
	if code := rev.do("POST", "/v1/admin/publish", map[string]string{"notes": "COPD"}, nil); code != 201 {
		var is content.Issues
		ed.do("GET", "/v1/admin/draft/issues", nil, &is)
		t.Fatalf("publish: %d %+v", code, is)
	}
	latest, err := s.Latest(t.Context())
	if err != nil {
		t.Fatal(err)
	}
	var b content.Bundle
	if err := json.Unmarshal(latest.Bundle, &b); err != nil {
		t.Fatal(err)
	}
	if len(b.Categories) != 6 || b.Categories[0].ID != "copd" || b.Categories[1].Color != "#FF0000" {
		t.Fatalf("published categories = %+v", b.Categories)
	}
	if b.CarePlans[0].ID != "copd-01" {
		t.Fatalf("plans should follow the category order, got %s first", b.CarePlans[0].ID)
	}

	// Empty it, then it can be archived; new plans can't use it then.
	ed.do("POST", "/v1/admin/care-plans/copd-01/archive", nil, nil)
	if code := ed.do("POST", "/v1/admin/categories/copd/archive", nil, nil); code != 204 {
		t.Fatalf("archive empty category: %d", code)
	}
	e = errResp{}
	if code := ed.do("POST", "/v1/admin/care-plans", plan, &e); code != 400 || !strings.Contains(strings.Join(e.Issues, " "), "unknown disease category") {
		t.Fatalf("plan in archived category: %d %+v", code, e)
	}
	ed.do("GET", "/v1/admin/draft/issues", nil, &issues)
	for _, msg := range issues.Errors {
		if strings.Contains(msg, "copd") {
			t.Fatalf("archived category still checked: %v", issues.Errors)
		}
	}
}

func firstDomain(t *testing.T, c *client) string {
	t.Helper()
	var ds []store.EditDomain
	c.do("GET", "/v1/admin/domains", nil, &ds)
	if len(ds) == 0 {
		t.Fatal("no domains")
	}
	return ds[0].ID
}
