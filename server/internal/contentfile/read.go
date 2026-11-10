package contentfile

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/mmdshin/ava/server/internal/content"
)

// Read loads the content files from dir into one bundle. categories.json
// is optional; without it the five original diseases are used.
func Read(dir string) (*content.Bundle, error) {
	b := &content.Bundle{SchemaVersion: content.SchemaVersion}
	raw, err := os.ReadFile(filepath.Join(dir, "categories.json"))
	switch {
	case errors.Is(err, fs.ErrNotExist):
		b.Categories = content.DefaultCategories()
	case err != nil:
		return nil, err
	default:
		if err := json.Unmarshal(raw, &b.Categories); err != nil {
			return nil, fmt.Errorf("categories.json: %w", err)
		}
	}
	for name, target := range map[string]any{
		"care_plans.json":     &b.CarePlans,
		"quizzes.json":        &b.Quizzes,
		"gordon_domains.json": &b.GordonDomains,
	} {
		raw, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			return nil, err
		}
		if err := json.Unmarshal(raw, target); err != nil {
			return nil, fmt.Errorf("%s: %w", name, err)
		}
	}
	return b, nil
}

// ReadBundle loads a single bundle file ({"carePlans", "quizzes",
// "gordonDomains", …}), e.g. the sample content or a downloaded bundle.
func ReadBundle(path string) (*content.Bundle, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var b content.Bundle
	if err := json.Unmarshal(raw, &b); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	b.SchemaVersion, b.Version, b.PublishedAt = content.SchemaVersion, 0, ""
	if len(b.Categories) == 0 {
		b.Categories = content.DefaultCategories()
	}
	return &b, nil
}
