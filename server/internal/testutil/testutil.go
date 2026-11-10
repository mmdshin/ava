package testutil

import (
	"context"
	"os"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/mmdshin/ava/server/internal/store"
)

// Store connects to AVA_TEST_DATABASE_URL, wipes it and migrates it.
// Tests are skipped when the variable isn't set.
//
// WARNING: everything in that database is deleted.
func Store(t *testing.T) *store.Store {
	t.Helper()
	url := os.Getenv("AVA_TEST_DATABASE_URL")
	if url == "" {
		t.Skip("set AVA_TEST_DATABASE_URL to run database tests")
	}
	ctx := context.Background()
	s, err := store.Open(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { s.Close() })
	if _, err := s.DB.ExecContext(ctx, `drop schema public cascade; create schema public;`); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Migrate(ctx); err != nil {
		t.Fatal(err)
	}
	return s
}

// SampleBundle is the small, made-up content used by tests and for
// local development (testdata/sample_bundle.json).
func SampleBundle() string {
	_, file, _, _ := runtime.Caller(0)
	return filepath.Join(filepath.Dir(file), "..", "..", "testdata", "sample_bundle.json")
}
