package content

import (
	"fmt"
	"regexp"
	"slices"
	"sort"
	"strings"
)

// Issues found by Validate. Errors block publishing; warnings are shown
// to editors (e.g. findings no care plan uses yet) but don't block.
type Issues struct {
	Errors   []string `json:"errors"`
	Warnings []string `json:"warnings"`
}

func (i *Issues) errorf(format string, a ...any) {
	i.Errors = append(i.Errors, fmt.Sprintf(format, a...))
}

func (i *Issues) warnf(format string, a ...any) {
	i.Warnings = append(i.Warnings, fmt.Sprintf(format, a...))
}

// OK reports whether the bundle can be published.
func (i Issues) OK() bool { return len(i.Errors) == 0 }

var (
	tagFormat    = regexp.MustCompile(`^[a-z]+(_[a-z]+)*$`)
	domainFormat = regexp.MustCompile(`^[a-z]+(_[a-z]+)*$`)
	findingID    = regexp.MustCompile(`^[a-z0-9]+(_[a-z0-9]+)*$`)
)

// Validate checks a whole bundle.
func Validate(b *Bundle) Issues {
	var is Issues
	categories := validateCategories(b, &is)
	selectable := validateGordon(b, &is)
	validateCarePlans(b, categories, selectable, &is)
	validateQuizzes(b, categories, &is)
	validateTags(b, &is)
	return is
}

func blank(s string) bool { return strings.TrimSpace(s) == "" }

func duplicates(values []string) []string {
	seen := map[string]bool{}
	var dupes []string
	for _, v := range values {
		v = strings.TrimSpace(v)
		if seen[v] && !slices.Contains(dupes, v) {
			dupes = append(dupes, v)
		}
		seen[v] = true
	}
	return dupes
}

// validateCategories returns the set of category ids.
func validateCategories(b *Bundle, is *Issues) map[string]bool {
	ids := map[string]bool{}
	var titles []string
	for _, c := range b.Categories {
		where := fmt.Sprintf("category %q", c.ID)
		if !CategoryIDFormat.MatchString(c.ID) {
			is.errorf("%s: id must be lowercase letters or digits", where)
		}
		if ids[c.ID] {
			is.errorf("%s: duplicate id", where)
		}
		ids[c.ID] = true
		titles = append(titles, c.Title)
		for _, problem := range CheckCategory(Category{Title: c.Title, Abbr: c.Abbr, Color: c.Color, Icon: c.Icon}) {
			is.errorf("%s: %s", where, problem)
		}
	}
	for _, t := range duplicates(titles) {
		is.errorf("category title %q is used twice", t)
	}
	if !ids[GeneralCategory] {
		is.errorf("the %q category is missing (it holds the plans shared by every disease)", GeneralCategory)
	}
	return ids
}

// validateGordon returns the set of tags a finding can select.
func validateGordon(b *Bundle, is *Issues) map[string]bool {
	if len(b.GordonDomains) == 0 {
		is.errorf("no Gordon domains")
	}
	selectable := map[string]bool{}
	domainIDs := map[string]bool{}
	findingIDs := map[string]bool{}
	var titles []string
	for _, d := range b.GordonDomains {
		if !domainFormat.MatchString(d.ID) {
			is.errorf("domain %q: id must be lowercase snake_case", d.ID)
		}
		if domainIDs[d.ID] {
			is.errorf("domain %q: duplicate id", d.ID)
		}
		domainIDs[d.ID] = true
		if blank(d.Title) {
			is.errorf("domain %q: empty title", d.ID)
		}
		for _, f := range d.Items {
			if !findingID.MatchString(f.ID) {
				is.errorf("finding %q: id must be lowercase snake_case", f.ID)
			}
			if findingIDs[f.ID] {
				is.errorf("finding %q: duplicate id", f.ID)
			}
			findingIDs[f.ID] = true
			if blank(f.Title) {
				is.errorf("finding %q: empty title", f.ID)
			}
			titles = append(titles, f.Title)
			if len(f.Tags) == 0 {
				is.errorf("finding %q: no tags", f.ID)
			}
			if d := duplicates(f.Tags); len(d) > 0 {
				is.errorf("finding %q: repeated tags %v", f.ID, d)
			}
			for _, t := range f.Tags {
				selectable[t] = true
			}
		}
	}
	for _, t := range duplicates(titles) {
		is.errorf("finding title %q is used twice", t)
	}
	return selectable
}

func validateCarePlans(b *Bundle, categories, selectable map[string]bool, is *Issues) {
	ids := map[string]bool{}
	titles := map[string][]string{}
	planTags := map[string]bool{}
	perKind := map[string]int{}

	for _, p := range b.CarePlans {
		where := fmt.Sprintf("care plan %q", p.ID)
		if !categories[p.Kind] {
			is.errorf("%s: unknown category %q", where, p.Kind)
		}
		if ok, _ := regexp.MatchString(`^`+regexp.QuoteMeta(p.Kind)+`-\d{2,}$`, p.ID); !ok {
			is.errorf("%s: id must look like %s-01", where, p.Kind)
		}
		if ids[p.ID] {
			is.errorf("%s: duplicate id", where)
		}
		ids[p.ID] = true
		perKind[p.Kind]++
		if blank(p.Title) {
			is.errorf("%s: empty title", where)
		}
		titles[p.Kind] = append(titles[p.Kind], p.Title)
		if len(p.Tags) == 0 {
			is.errorf("%s: no tags", where)
		}
		if d := duplicates(p.Tags); len(d) > 0 {
			is.errorf("%s: repeated tags %v", where, d)
		}
		for _, t := range p.Tags {
			planTags[t] = true
			if !selectable[t] {
				is.errorf("%s: tag %q can't be selected in the assessment", where, t)
			}
		}
		if len(p.Sections) == 0 {
			is.errorf("%s: no sections", where)
		}
		has := map[string]bool{}
		for i, s := range p.Sections {
			if !slices.Contains(SectionTypes, s.Type) {
				is.errorf("%s: section %d has unknown type %q", where, i+1, s.Type)
			}
			has[s.Type] = true
			if len(s.Items) == 0 {
				is.errorf("%s: section %d (%s) is empty", where, i+1, s.Type)
			}
			for _, item := range s.Items {
				if blank(item) {
					is.errorf("%s: section %d (%s) has a blank item", where, i+1, s.Type)
				}
			}
			if d := duplicates(s.Items); len(d) > 0 {
				is.errorf("%s: section %d (%s) repeats %q", where, i+1, s.Type, d[0])
			}
		}
		for _, required := range []string{"interventions", "outcomes"} {
			if !has[required] {
				is.errorf("%s: missing a %s section", where, required)
			}
		}
	}
	for kind, ts := range titles {
		for _, t := range duplicates(ts) {
			is.errorf("care plan title %q is used twice in %s", t, kind)
		}
	}
	for _, c := range b.Categories {
		if perKind[c.ID] == 0 {
			is.errorf("no care plans for %s (add one, or archive the category)", c.ID)
		}
	}

	// Findings no plan uses: ticking them changes nothing (warning).
	for _, d := range b.GordonDomains {
		for _, f := range d.Items {
			used := slices.ContainsFunc(f.Tags, func(t string) bool { return planTags[t] })
			if !used {
				is.warnf("finding %q (%s) doesn't lead to any care plan", f.ID, f.Title)
			}
		}
	}
}

func validateQuizzes(b *Bundle, categories map[string]bool, is *Issues) {
	if len(b.Quizzes) == 0 {
		is.errorf("no quizzes")
	}
	ids := map[string]bool{}
	texts := map[string]string{}
	for _, q := range b.Quizzes {
		where := fmt.Sprintf("quiz %q", q.ID)
		if ids[q.ID] {
			is.errorf("%s: duplicate id", where)
		}
		ids[q.ID] = true
		if blank(q.Title) {
			is.errorf("%s: empty title", where)
		}
		if q.Kind != "" && !categories[q.Kind] {
			is.errorf("%s: unknown category %q", where, q.Kind)
		}
		if len(q.Questions) == 0 {
			is.errorf("%s: no questions", where)
		}
		for _, qu := range q.Questions {
			at := fmt.Sprintf("question %q", qu.ID)
			if ids[qu.ID] {
				is.errorf("%s: duplicate id", at)
			}
			ids[qu.ID] = true
			text := strings.TrimSpace(qu.Text)
			if text == "" {
				is.errorf("%s: empty text", at)
			} else if other, seen := texts[text]; seen {
				is.errorf("%s: same text as %q", at, other)
			}
			texts[text] = qu.ID
			if len(qu.Options) < 2 {
				is.errorf("%s: needs at least 2 options", at)
			}
			for _, o := range qu.Options {
				if blank(o) {
					is.errorf("%s: blank option", at)
				}
			}
			if d := duplicates(qu.Options); len(d) > 0 {
				is.errorf("%s: repeated option %q", at, d[0])
			}
			if qu.CorrectIndex < 0 || qu.CorrectIndex >= len(qu.Options) {
				is.errorf("%s: correct answer %d is not one of the options", at, qu.CorrectIndex)
			}
		}
	}
}

func validateTags(b *Bundle, is *Issues) {
	set := map[string]bool{}
	for _, p := range b.CarePlans {
		for _, t := range p.Tags {
			set[t] = true
		}
	}
	for _, d := range b.GordonDomains {
		for _, f := range d.Items {
			for _, t := range f.Tags {
				set[t] = true
			}
		}
	}
	tags := make([]string, 0, len(set))
	for t := range set {
		tags = append(tags, t)
		if !tagFormat.MatchString(t) {
			is.errorf("tag %q must be lowercase snake_case", t)
		}
	}
	sort.Strings(tags)
	// Two tags one letter apart are almost always a typo.
	for i := range tags {
		for j := i + 1; j < len(tags); j++ {
			if len(tags[i]) > 4 && EditDistance(tags[i], tags[j]) <= 1 {
				is.errorf("tags %q and %q look like a typo of each other", tags[i], tags[j])
			}
		}
	}
}

// EditDistance is the Levenshtein distance (capped: returns 2 when the
// lengths differ by more than one, which is all callers care about).
func EditDistance(a, b string) int {
	ra, rb := []rune(a), []rune(b)
	if d := len(ra) - len(rb); d > 1 || d < -1 {
		return 2
	}
	prev := make([]int, len(rb)+1)
	for j := range prev {
		prev[j] = j
	}
	for i := 1; i <= len(ra); i++ {
		cur := make([]int, len(rb)+1)
		cur[0] = i
		for j := 1; j <= len(rb); j++ {
			cost := 1
			if ra[i-1] == rb[j-1] {
				cost = 0
			}
			cur[j] = min(prev[j]+1, cur[j-1]+1, prev[j-1]+cost)
		}
		prev = cur
	}
	return prev[len(rb)]
}
