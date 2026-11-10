package api_test

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/mmdshin/ava/server/internal/api"
	"github.com/mmdshin/ava/server/internal/content"
	"github.com/mmdshin/ava/server/internal/contentfile"
	"github.com/mmdshin/ava/server/internal/store"
	"github.com/mmdshin/ava/server/internal/testutil"
)

func TestContentEndpoints(t *testing.T) {
	s := testutil.Store(t)
	ctx := context.Background()
	srv := httptest.NewServer((&api.Server{
		Store:          s,
		Log:            slog.New(slog.NewTextHandler(io.Discard, nil)),
		AllowedOrigins: []string{"https://app.example"},
		CacheTTL:       0,
	}).Handler())
	defer srv.Close()

	get := func(path string, headers map[string]string) *http.Response {
		req, _ := http.NewRequest("GET", srv.URL+path, nil)
		for k, v := range headers {
			req.Header.Set(k, v)
		}
		// Raw transport: no automatic gzip handling.
		res, err := (&http.Transport{DisableCompression: true}).RoundTrip(req)
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { res.Body.Close() })
		return res
	}

	if res := get("/v1/content/manifest", nil); res.StatusCode != 404 {
		t.Fatalf("manifest before publishing: %d, want 404", res.StatusCode)
	}

	b, _ := contentfile.ReadBundle(testutil.SampleBundle())
	if err := s.Import(ctx, b, false); err != nil {
		t.Fatal(err)
	}
	if _, _, err := s.Publish(ctx, store.PublishRequest{Notes: "first", By: store.Actor{Email: "test"}}); err != nil {
		t.Fatal(err)
	}

	var m struct {
		Version       int       `json:"version"`
		SchemaVersion int       `json:"schemaVersion"`
		PublishedAt   time.Time `json:"publishedAt"`
		SHA256        string    `json:"sha256"`
	}
	res := get("/v1/content/manifest", nil)
	json.NewDecoder(res.Body).Decode(&m)
	if m.Version != 1 || m.SchemaVersion != content.SchemaVersion || len(m.SHA256) != 64 {
		t.Fatalf("manifest = %+v", m)
	}

	res = get("/v1/content/bundle", nil)
	etag := res.Header.Get("ETag")
	var bundle struct {
		Version   int               `json:"version"`
		CarePlans []json.RawMessage `json:"carePlans"`
	}
	json.NewDecoder(res.Body).Decode(&bundle)
	if res.StatusCode != 200 || etag == "" || bundle.Version != 1 || len(bundle.CarePlans) != len(b.CarePlans) {
		t.Fatalf("bundle: status %d etag %q version %d plans %d", res.StatusCode, etag, bundle.Version, len(bundle.CarePlans))
	}

	if res := get("/v1/content/bundle", map[string]string{"If-None-Match": etag}); res.StatusCode != 304 {
		t.Fatalf("conditional GET: %d, want 304", res.StatusCode)
	}

	res = get("/v1/content/bundle", map[string]string{"Accept-Encoding": "gzip"})
	if res.Header.Get("Content-Encoding") != "gzip" {
		t.Fatal("expected a gzip response")
	}
	zr, err := gzip.NewReader(res.Body)
	if err != nil {
		t.Fatal(err)
	}
	unzipped, _ := io.ReadAll(zr)
	if !bytes.HasPrefix(unzipped, []byte(`{"schemaVersion":`)) {
		t.Fatalf("gzip body starts with %q", unzipped[:20])
	}

	if res := get("/v1/content/bundle?version=1", nil); res.Header.Get("Cache-Control") != "public, max-age=31536000, immutable" {
		t.Fatalf("pinned version cache header: %q", res.Header.Get("Cache-Control"))
	}
	if res := get("/v1/content/bundle?version=0", nil); res.StatusCode != 400 {
		t.Fatalf("version=0: %d, want 400", res.StatusCode)
	}
	if res := get("/v1/content/bundle?version=5", nil); res.StatusCode != 404 {
		t.Fatalf("version=5: %d, want 404", res.StatusCode)
	}

	allowed := get("/v1/content/manifest", map[string]string{"Origin": "https://app.example"})
	if allowed.Header.Get("Access-Control-Allow-Origin") != "https://app.example" {
		t.Fatal("allowed origin not echoed")
	}
	other := get("/v1/content/manifest", map[string]string{"Origin": "https://evil.example"})
	if other.Header.Get("Access-Control-Allow-Origin") != "" {
		t.Fatal("unknown origin was allowed")
	}

	if res := get("/healthz", nil); res.StatusCode != 200 {
		t.Fatalf("healthz: %d", res.StatusCode)
	}
}
