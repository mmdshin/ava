package store_test

import (
	"context"
	"encoding/json"
	"errors"
	"reflect"
	"testing"

	"github.com/mmdshin/ava/server/internal/content"
	"github.com/mmdshin/ava/server/internal/contentfile"
	"github.com/mmdshin/ava/server/internal/store"
	"github.com/mmdshin/ava/server/internal/testutil"
)

func importSample(t *testing.T, s *store.Store) *content.Bundle {
	t.Helper()
	b, err := contentfile.ReadBundle(testutil.SampleBundle())
	if err != nil {
		t.Fatal(err)
	}
	if err := s.Import(context.Background(), b, false); err != nil {
		t.Fatal(err)
	}
	return b
}

func TestImportRoundTrip(t *testing.T) {
	s := testutil.Store(t)
	ctx := context.Background()
	original := importSample(t, s)

	draft, err := s.Draft(ctx)
	if err != nil {
		t.Fatal(err)
	}
	for name, pair := range map[string][2]any{
		"care plans": {original.CarePlans, draft.CarePlans},
		"quizzes":    {original.Quizzes, draft.Quizzes},
		"domains":    {original.GordonDomains, draft.GordonDomains},
	} {
		a, _ := json.Marshal(pair[0])
		b, _ := json.Marshal(pair[1])
		if string(a) != string(b) {
			t.Errorf("%s changed after import → draft", name)
		}
	}

	if err := s.Import(ctx, original, false); !errors.Is(err, store.ErrNotEmpty) {
		t.Fatalf("second import without replace: got %v, want ErrNotEmpty", err)
	}
	if err := s.Import(ctx, original, true); err != nil {
		t.Fatalf("import with replace: %v", err)
	}
}

func TestPublishVersions(t *testing.T) {
	s := testutil.Store(t)
	ctx := context.Background()
	importSample(t, s)

	if _, err := s.Latest(ctx); !errors.Is(err, store.ErrNoVersion) {
		t.Fatalf("before publishing: got %v, want ErrNoVersion", err)
	}

	v1, issues, err := s.Publish(ctx, store.PublishRequest{Notes: "first", By: store.Actor{Email: "test"}})
	if err != nil {
		t.Fatal(err)
	}
	if v1.Version != 1 || len(issues.Warnings) != 0 {
		t.Fatalf("got version %d with %d warnings, want 1 and 0", v1.Version, len(issues.Warnings))
	}

	// Same content again → nothing to publish.
	if _, _, err := s.Publish(ctx, store.PublishRequest{Notes: "again", By: store.Actor{Email: "test"}}); !errors.Is(err, store.ErrNothingChanged) {
		t.Fatalf("republish: got %v, want ErrNothingChanged", err)
	}

	// An edit → version 2; version 1 stays as it was.
	if _, err := s.DB.ExecContext(ctx, `update care_plans set title = 'درد حاد (ویرایش)' where id = 'acs-01'`); err != nil {
		t.Fatal(err)
	}
	v2, _, err := s.Publish(ctx, store.PublishRequest{Notes: "edit", By: store.Actor{Email: "test"}})
	if err != nil || v2.Version != 2 {
		t.Fatalf("publish edit: %v, %+v", err, v2)
	}
	old, err := s.GetVersion(ctx, 1)
	if err != nil || reflect.DeepEqual(old.Bundle, v2.Bundle) {
		t.Fatalf("version 1 should be unchanged: %v", err)
	}
	latest, _ := s.Latest(ctx)
	if latest.Version != 2 {
		t.Fatalf("latest = %d, want 2", latest.Version)
	}

	// Archived plans disappear from the next version.
	if _, err := s.DB.ExecContext(ctx, `update care_plans set archived = true where id = 'acs-02'`); err != nil {
		t.Fatal(err)
	}
	draft, _ := s.Draft(ctx)
	for _, p := range draft.CarePlans {
		if p.ID == "acs-02" {
			t.Fatal("archived plan still in the draft")
		}
	}
}

func TestPublishRejectsInvalidContent(t *testing.T) {
	s := testutil.Store(t)
	ctx := context.Background()
	importSample(t, s)

	// A correct answer that isn't one of the options.
	if _, err := s.DB.ExecContext(ctx, `update quiz_questions set correct_index = 9 where id = 'sample-mixed-q01'`); err != nil {
		t.Fatal(err)
	}
	_, _, err := s.Publish(ctx, store.PublishRequest{Notes: "broken", By: store.Actor{Email: "test"}})
	var verr *store.ValidationError
	if !errors.As(err, &verr) {
		t.Fatalf("got %v, want a ValidationError", err)
	}
	if _, err := s.Latest(ctx); !errors.Is(err, store.ErrNoVersion) {
		t.Fatal("invalid content was published")
	}
}

func TestDatabaseChecks(t *testing.T) {
	s := testutil.Store(t)
	ctx := context.Background()
	importSample(t, s)

	for name, stmt := range map[string]string{
		"bad tag":         `insert into tags (name) values ('Bad Tag')`,
		"plan id vs kind": `insert into care_plans (id, kind, title, position) values ('mi-99', 'acs', 'x', 99)`,
		"unknown tag":     `insert into care_plan_tags (plan_id, tag, position) values ('acs-01', 'no_such_tag', 9)`,
		"blank item":      `insert into care_plan_section_items (section_id, position, text) select id, 999, '  ' from care_plan_sections limit 1`,
	} {
		if _, err := s.DB.ExecContext(ctx, stmt); err == nil {
			t.Errorf("%s: the database accepted it", name)
		}
	}
}
