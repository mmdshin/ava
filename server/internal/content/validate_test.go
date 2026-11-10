package content

import (
	"strings"
	"testing"
)

// valid returns a small bundle that passes every rule.
func valid() *Bundle {
	plan := func(id, kind string) CarePlan {
		return CarePlan{
			ID: id, Kind: kind, Title: "عنوان " + id, Tags: []string{"pain"},
			Sections: []Section{
				{Type: "interventions", Items: []string{"اقدام"}},
				{Type: "outcomes", Items: []string{"پیامد"}},
			},
		}
	}
	return &Bundle{
		SchemaVersion: SchemaVersion,
		Categories:    DefaultCategories(),
		CarePlans: []CarePlan{
			plan("acs-01", "acs"), plan("chf-01", "chf"), plan("dvt-01", "dvt"),
			plan("mi-01", "mi"), plan("general-01", "general"),
		},
		Quizzes: []Quiz{{
			ID: "quiz-1", Title: "آزمون", Kind: "mi",
			Questions: []Question{{ID: "q1", Text: "سؤال؟", Options: []string{"الف", "ب"}, CorrectIndex: 1}},
		}},
		GordonDomains: []Domain{{
			ID: "comfort", Title: "آسایش", Order: 1,
			Items: []Finding{{ID: "comfort_pain", Title: "درد", Tags: []string{"pain"}}},
		}},
	}
}

func TestValidBundle(t *testing.T) {
	if is := Validate(valid()); !is.OK() || len(is.Warnings) > 0 {
		t.Fatalf("expected no issues, got %+v", is)
	}
}

func TestValidationErrors(t *testing.T) {
	cases := []struct {
		name   string
		break_ func(b *Bundle)
		want   string
	}{
		{"tag case", func(b *Bundle) {
			b.CarePlans[0].Tags = []string{"Pain"}
			b.GordonDomains[0].Items[0].Tags = []string{"Pain"}
		}, "lowercase"},
		{"tag typo", func(b *Bundle) {
			b.GordonDomains[0].Items = append(b.GordonDomains[0].Items,
				Finding{ID: "x_1", Title: "بی قراری", Tags: []string{"restlessness"}},
				Finding{ID: "x_2", Title: "بی قراری ۲", Tags: []string{"restlessnes"}})
		}, "typo"},
		{"unselectable plan tag", func(b *Bundle) { b.CarePlans[0].Tags = []string{"fever"} }, "can't be selected"},
		{"plan id format", func(b *Bundle) { b.CarePlans[0].ID = "acs-1" }, "id must look like"},
		{"duplicate plan id", func(b *Bundle) { b.CarePlans[1].ID = "acs-01"; b.CarePlans[1].Kind = "acs" }, "duplicate id"},
		{"missing outcomes", func(b *Bundle) { b.CarePlans[0].Sections = b.CarePlans[0].Sections[:1] }, "missing a outcomes"},
		{"blank item", func(b *Bundle) { b.CarePlans[0].Sections[0].Items = []string{" "} }, "blank item"},
		{"repeated item", func(b *Bundle) { b.CarePlans[0].Sections[0].Items = []string{"a", "a"} }, "repeats"},
		{"kind without plans", func(b *Bundle) { b.CarePlans = b.CarePlans[1:] }, "no care plans for acs"},
		{"unknown category", func(b *Bundle) { b.CarePlans[0].Kind = "copd"; b.CarePlans[0].ID = "copd-01" }, "unknown category"},
		{"no general category", func(b *Bundle) {
			b.Categories = b.Categories[:4]
			b.CarePlans = b.CarePlans[:4]
		}, `"general" category is missing`},
		{"bad color", func(b *Bundle) { b.Categories[0].Color = "teal" }, "color must look like"},
		{"unknown icon", func(b *Bundle) { b.Categories[0].Icon = "rocket" }, "unknown icon"},
		{"duplicate category", func(b *Bundle) { b.Categories = append(b.Categories, b.Categories[0]) }, "duplicate id"},
		{"empty new category", func(b *Bundle) {
			b.Categories = append(b.Categories, Category{ID: "copd", Title: "COPD", Color: "#123456", Icon: "air"})
		}, "no care plans for copd"},
		{"quiz category", func(b *Bundle) { b.Quizzes[0].Kind = "copd" }, "unknown category"},
		{"correct index", func(b *Bundle) { b.Quizzes[0].Questions[0].CorrectIndex = 5 }, "not one of the options"},
		{"one option", func(b *Bundle) {
			b.Quizzes[0].Questions[0].Options = []string{"الف"}
			b.Quizzes[0].Questions[0].CorrectIndex = 0
		}, "at least 2"},
		{"repeated option", func(b *Bundle) { b.Quizzes[0].Questions[0].Options = []string{"الف", "الف"} }, "repeated option"},
		{"finding without tags", func(b *Bundle) { b.GordonDomains[0].Items[0].Tags = nil }, "no tags"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			b := valid()
			c.break_(b)
			is := Validate(b)
			if is.OK() {
				t.Fatalf("expected an error containing %q", c.want)
			}
			if !strings.Contains(strings.Join(is.Errors, "\n"), c.want) {
				t.Fatalf("errors %q don't mention %q", is.Errors, c.want)
			}
		})
	}
}

func TestFindingWithoutPlanIsWarning(t *testing.T) {
	b := valid()
	b.GordonDomains[0].Items = append(b.GordonDomains[0].Items,
		Finding{ID: "comfort_nausea", Title: "تهوع", Tags: []string{"nausea"}})
	is := Validate(b)
	if !is.OK() || len(is.Warnings) != 1 || !strings.Contains(is.Warnings[0], "comfort_nausea") {
		t.Fatalf("expected one warning about comfort_nausea, got %+v", is)
	}
}

func TestEditDistance(t *testing.T) {
	for _, c := range []struct {
		a, b string
		want int
	}{{"pain", "pain", 0}, {"restlessness", "restlessnes", 1}, {"fear", "feat", 1}, {"pain", "edema", 2}} {
		// Only "0", "1" or "more than 1" matters to callers.
		if got := EditDistance(c.a, c.b); min(got, 2) != c.want {
			t.Errorf("EditDistance(%q, %q) = %d, want %d", c.a, c.b, got, c.want)
		}
	}
}
