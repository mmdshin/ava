package content

import (
	"fmt"
	"regexp"
	"slices"
	"strings"
)

// Rules for a single entity on its own, used when an editor saves one
var (
	planIDFormat     = regexp.MustCompile(`^[a-z][a-z0-9]*-\d{2,}$`)
	CategoryIDFormat = regexp.MustCompile(`^[a-z][a-z0-9]{1,19}$`)
	colorFormat      = regexp.MustCompile(`^#[0-9A-Fa-f]{6}$`)
	TagFormat        = tagFormat
	DomainIDFormat   = domainFormat
	FindingIDFormat  = findingID
	QuizIDFormat     = regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`)
	QuestionIDFormat = regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`)
)

// MaxTextLength limits titles, items, questions, options, explanations.
const MaxTextLength = 4000

func tooLong(s string) bool { return len([]rune(s)) > MaxTextLength }

// CheckCarePlan checks one care plan's own fields.
func CheckCarePlan(p CarePlan) []string {
	var out []string
	add := func(format string, a ...any) { out = append(out, fmt.Sprintf(format, a...)) }

	// Whether the category exists is checked against the database.
	if blank(p.Kind) {
		add("choose a disease category")
	}
	if p.ID != "" && (!planIDFormat.MatchString(p.ID) || !strings.HasPrefix(p.ID, p.Kind+"-")) {
		add("id must look like %s-01", p.Kind)
	}
	if blank(p.Title) {
		add("title is empty")
	} else if tooLong(p.Title) {
		add("title is too long")
	}
	if len(p.Tags) == 0 {
		add("needs at least one tag")
	}
	if d := duplicates(p.Tags); len(d) > 0 {
		add("repeated tags %v", d)
	}
	for _, t := range p.Tags {
		if !tagFormat.MatchString(t) {
			add("tag %q must be lowercase snake_case", t)
		}
	}
	if len(p.Sections) == 0 {
		add("needs at least one section")
	}
	has := map[string]bool{}
	for i, s := range p.Sections {
		if !slices.Contains(SectionTypes, s.Type) {
			add("section %d has unknown type %q", i+1, s.Type)
		}
		has[s.Type] = true
		if len(s.Items) == 0 {
			add("section %d (%s) is empty", i+1, s.Type)
		}
		for _, item := range s.Items {
			if blank(item) {
				add("section %d (%s) has a blank item", i+1, s.Type)
				break
			}
			if tooLong(item) {
				add("section %d (%s) has an item that is too long", i+1, s.Type)
				break
			}
		}
		if d := duplicates(s.Items); len(d) > 0 {
			add("section %d (%s) repeats %q", i+1, s.Type, d[0])
		}
	}
	for _, required := range []string{"interventions", "outcomes"} {
		if !has[required] {
			add("missing a %s section", required)
		}
	}
	return out
}

// CheckQuiz checks a quiz's own fields (not its questions).
func CheckQuiz(q Quiz) []string {
	var out []string
	if blank(q.Title) {
		out = append(out, "title is empty")
	} else if tooLong(q.Title) {
		out = append(out, "title is too long")
	}
	return out
}

// CheckCategory checks a disease category's own fields.
func CheckCategory(c Category) []string {
	var out []string
	add := func(format string, a ...any) { out = append(out, fmt.Sprintf(format, a...)) }
	if c.ID != "" && !CategoryIDFormat.MatchString(c.ID) {
		add("id must be 2–20 lowercase English letters or digits, starting with a letter (e.g. copd)")
	}
	if blank(c.Title) {
		add("title is empty")
	} else if len([]rune(c.Title)) > 80 {
		add("title is too long (80 characters at most)")
	}
	if len([]rune(c.Abbr)) > 12 {
		add("short code is too long (12 characters at most)")
	}
	if !colorFormat.MatchString(c.Color) {
		add("color must look like #17A398")
	}
	if !slices.Contains(CategoryIcons, c.Icon) {
		add("unknown icon %q", c.Icon)
	}
	return out
}

// CheckQuestion checks one quiz question.
func CheckQuestion(q Question) []string {
	var out []string
	add := func(format string, a ...any) { out = append(out, fmt.Sprintf(format, a...)) }
	if blank(q.Text) {
		add("question text is empty")
	} else if tooLong(q.Text) {
		add("question text is too long")
	}
	if len(q.Options) < 2 {
		add("needs at least 2 options")
	}
	if len(q.Options) > 6 {
		add("at most 6 options")
	}
	for _, o := range q.Options {
		if blank(o) {
			add("blank option")
			break
		}
		if tooLong(o) {
			add("an option is too long")
			break
		}
	}
	if d := duplicates(q.Options); len(d) > 0 {
		add("repeated option %q", d[0])
	}
	if q.CorrectIndex < 0 || q.CorrectIndex >= len(q.Options) {
		add("correct answer %d is not one of the options", q.CorrectIndex)
	}
	if tooLong(q.Explanation) || tooLong(q.Hint) {
		add("explanation or hint is too long")
	}
	return out
}

// CheckFinding checks one Gordon assessment finding.
func CheckFinding(f Finding) []string {
	var out []string
	add := func(format string, a ...any) { out = append(out, fmt.Sprintf(format, a...)) }
	if f.ID != "" && !findingID.MatchString(f.ID) {
		add("id must be lowercase snake_case (e.g. hp_smoking)")
	}
	if blank(f.Title) {
		add("title is empty")
	} else if tooLong(f.Title) {
		add("title is too long")
	}
	if len(f.Tags) == 0 {
		add("needs at least one tag")
	}
	if d := duplicates(f.Tags); len(d) > 0 {
		add("repeated tags %v", d)
	}
	for _, t := range f.Tags {
		if !tagFormat.MatchString(t) {
			add("tag %q must be lowercase snake_case", t)
		}
	}
	return out
}

// CheckDomain checks a Gordon domain's own fields.
func CheckDomain(d Domain) []string {
	var out []string
	if d.ID != "" && !domainFormat.MatchString(d.ID) {
		out = append(out, "id must be lowercase snake_case (e.g. health_promotion)")
	}
	if blank(d.Title) {
		out = append(out, "title is empty")
	} else if tooLong(d.Title) {
		out = append(out, "title is too long")
	}
	return out
}
