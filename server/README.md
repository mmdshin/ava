# AvA server

Go + PostgreSQL server for **AvA – nursing assistant**: it stores the
educational content, publishes it to the app, and keeps each user's own
data (favorites, notes, quiz progress, mistakes) behind a login.

Only the Go standard library and one PostgreSQL driver (`lib/pq`).

## What it does

- **Content** (care plans, Gordon assessment, quizzes) is stored in
  normalized tables, guarded by foreign keys and checks. Publishing
  validates everything (same rules as the app) and stores an immutable,
  numbered snapshot. The app downloads it once, caches it, and only
  fetches it again when a new version is published.
- **Accounts**: email + password (PBKDF2-SHA256, 600k iterations),
  opaque session tokens (only their SHA-256 is stored), login rate
  limiting, password change (logs out other devices), account deletion
  (deletes all data). Roles: `nurse`, `editor`, `reviewer`, `admin`.
- **User data**: favorites, notes, recently viewed plans, quiz attempts
  with per-question results (→ best/last score and "mistakes").

> **Content is private.** This repository contains only made-up sample
> content (`testdata/sample_bundle.json`) for tests and development.
> Keep the real content in a separate, private place and import it on
> the server.

## Layout

```
cmd/ava-server/            CLI: migrate, import, validate, publish, versions,
                           create-user, set-role, serve
internal/content/          content model (= the app's JSON) and validation rules
internal/contentfile/      reads content JSON files
internal/store/            PostgreSQL: migrations, content, users, sessions, user data
internal/store/migrations/ schema (embedded in the binary)
internal/auth/             password hashing, tokens, rate limiting
internal/api/              HTTP API
testdata/sample_bundle.json  made-up sample content
```

## Run locally

With Docker, from the **repository root** (see the root README):

```sh
cp .env.example .env
docker compose up -d db api                          # PostgreSQL + API on :8080
docker compose run --rm seed                         # import + publish the sample content
docker compose run --rm -e AVA_PASSWORD='choose-a-password' api \
  create-user --email you@example.com --role admin --name "Your name"
curl http://localhost:8080/v1/content/manifest
```

Without Docker (Go 1.24+, PostgreSQL 14+), from this folder:

```sh
createdb ava
export DATABASE_URL="postgres://localhost:5432/ava?sslmode=disable"
make sample            # import + publish the sample content
go run ./cmd/ava-server serve
```

Then run the app against it (`flutter run`; it uses
`http://localhost:8080` by default, see [`../app/README.md`](../app/README.md)).

### Tests

```sh
go vet ./... && go test ./...                       # unit tests
# Database tests need a throwaway database (it is wiped!):
AVA_TEST_DATABASE_URL="postgres://localhost:5432/ava_test?sslmode=disable" go test -p 1 ./...
```

### Your real content

```sh
ava-server import --dir /path/to/private/content   # care_plans.json, quizzes.json, gordon_domains.json (+ categories.json, optional)
ava-server validate                                # errors block publishing; warnings don't
ava-server publish --notes "first version" --by admin
```

`import` refuses to overwrite existing content unless you add
`--replace`. Published versions are never changed or deleted.

## Commands

| command | |
|---|---|
| `migrate` | create/upgrade tables (also done by `import`, `serve`, `create-user`) |
| `import --file F` / `--dir D` `[--replace]` | load content (a bundle file, or the three JSON files) |
| `validate` | check the current draft |
| `publish --notes "..." [--by NAME] [--ignore-freeze]` | publish the draft as the next version (no-op when unchanged) |
| `versions` | list published versions |
| `create-user --email E [--role R] [--name N]` | password from `AVA_PASSWORD` or stdin |
| `set-role --email E --role R` | change a role |
| `serve` | run the API |

Environment: `DATABASE_URL` (required), `ADDR` (default `:8080`),
`CORS_ORIGINS` (comma-separated web-app origins; default `*`),
`ALLOW_SIGNUP` (`false` = only admins create accounts).

### Admin panel

The admin panel is part of the Flutter app (`../app/lib/main_admin.dart`).
Add its address to `CORS_ORIGINS` too, e.g.
`CORS_ORIGINS=http://localhost:8000,http://localhost:8001`.

### "CORS error" in the browser

The web app's address must be in `CORS_ORIGINS`, exactly as the browser
shows it: scheme, host and port (`http://localhost:8000` and
`http://127.0.0.1:8000` are different). The server logs a warning
naming any blocked address. After changing `.env`, restart the API
(`docker compose up -d api` from the repository root, or stop and start `serve`).

## API

Errors are JSON: `{"error": "message", "code": "machine_code"}`.
Authenticated endpoints need `Authorization: Bearer <token>`.

**Content (public)**

| | |
|---|---|
| `GET /healthz` | `ok` when the database is reachable |
| `GET /v1/content/manifest` | `{version, schemaVersion, publishedAt, sha256, size}` |
| `GET /v1/content/bundle[?version=N]` | the content JSON; gzip, `ETag`/304; pinned versions are cached as immutable |

**Accounts**

| | |
|---|---|
| `POST /v1/auth/register` | `{email, password, displayName}` → `{token, user}` (201) |
| `POST /v1/auth/login` | `{email, password}` → `{token, user}`; 10 tries / 15 min |
| `POST /v1/auth/logout` | ends this session |
| `GET /v1/me` | the user |
| `POST /v1/me/password` | `{currentPassword, newPassword}` → new `{token, user}`; other sessions end |
| `DELETE /v1/me` | `{password}`; deletes the account and all its data |
| `PUT /v1/admin/users/{email}/role` | `{role}` (admin only) |

**User data**

| | |
|---|---|
| `GET /v1/me/data` | `{favorites, notes, recent, progress, mistakes}` |
| `PUT` / `DELETE /v1/me/favorites/{planId}` | add / remove a favorite |
| `PUT /v1/me/notes/{planId}` | `{text}` (empty deletes); `DELETE` removes |
| `POST /v1/me/recent/{planId}` · `DELETE /v1/me/recent` | mark viewed · clear (last 10 kept) |
| `POST /v1/me/quiz-attempts` | `{quizId, mode, answers: {questionId: correct}}` → updated data |

User data refers to content by id and has no foreign keys to content,
so archiving or editing content never deletes anyone's data.

## Editing API

For the admin panel. Roles: **editor** edits the draft; **reviewer**
also publishes; **admin** also manages the publishing freeze and users.

Edits change the **draft** (the content tables); the app sees nothing
until a reviewer publishes. Every change is written to the audit log
(who, when, before/after).

**Optimistic locking:** every editable item has a `revision`. Updates
must send the revision they started from; if someone else saved in
between, the answer is `409 {"code":"conflict","revision":N}` — reload
and redo the change.

| | |
|---|---|
| `GET` / `POST /v1/admin/categories` | disease categories with how many plans/quizzes use them / `{id, title, abbr, color, icon}` |
| `PUT /v1/admin/categories/{id}` · `PUT /v1/admin/categories/order` | `{revision, title, abbr, color, icon}` · `{ids}` (the id never changes) |
| `POST /v1/admin/categories/{id}/archive` · `/restore` | only when no active plan or quiz uses it; never `general` |
| `GET /v1/admin/care-plans` | all plans (archived too), with tags and revision |
| `POST /v1/admin/care-plans` | `{kind, title, tags, sections}` → new plan, next id of its kind (e.g. `acs-05`) |
| `GET` / `PUT /v1/admin/care-plans/{id}` | one plan / replace `{revision, title, tags, sections}` |
| `POST /v1/admin/care-plans/{id}/archive` · `/restore` | hide from / bring back to the next version |
| `PUT /v1/admin/care-plans/order` | `{kind, ids}` |
| `GET` / `POST /v1/admin/quizzes` | list / create `{title, kind}` (id `quiz-N`) |
| `GET` / `PUT /v1/admin/quizzes/{id}` | quiz with all questions / `{revision, title, kind}` |
| `POST /v1/admin/quizzes/{id}/questions` | `{text, options, correctIndex, explanation, hint}` (id `<quiz>-qNN`) |
| `PUT /v1/admin/quizzes/{id}/questions/order` · `PUT /v1/admin/quizzes/order` | `{ids}` |
| `GET` / `PUT /v1/admin/questions/{id}` | one question / `{revision, text, options, correctIndex, explanation, hint}` |
| `GET` / `POST /v1/admin/domains` | domains with findings (and the plans each finding leads to) / `{id, title}` |
| `PUT /v1/admin/domains/{id}` · `PUT /v1/admin/domains/order` | `{revision, title}` · `{ids}` |
| `POST /v1/admin/domains/{id}/findings` | `{id?, title, tags}` (id generated when empty) |
| `GET` / `PUT /v1/admin/findings/{id}` | `{revision, title, tags}` |
| `…/{id}/archive` · `…/{id}/restore` | also for quizzes, questions, domains, findings |
| `GET` / `POST /v1/admin/tags` | tags with where they're used / `{name, label}` (near-duplicates refused) |
| `PUT` / `DELETE /v1/admin/tags/{name}` | `{name?, label}` (renaming updates every use) / delete if unused |
| `GET /v1/admin/draft/issues` | `{errors, warnings}` with the publishing rules |
| `GET /v1/admin/draft/changes` | what's added / changed / removed since the published version |
| `POST /v1/admin/publish` | **reviewer** · `{notes}` → new version (or 422 with the errors, 423 when frozen) |
| `GET /v1/admin/versions` · `GET /v1/admin/audit?entity=&entityId=&before=&limit=` | history |
| `GET` / `PUT /v1/admin/settings/freeze` | read / **admin** `{frozen, reason}` |
| `GET` / `POST /v1/admin/users` · `PUT /v1/admin/users/{email}/role` | **admin** · list / create `{email, displayName, role, password}` / `{role}` |

Errors: `400 invalid` (with `issues`), `404 not_found`, `409 conflict`
/ `id_taken` / `tag_in_use` / `category_in_use` / `nothing_changed`, `422 content_invalid`,
`423 frozen`.

New ids are generated by the server and never reused; deleting means
archiving.

### Clinical trial freeze

`PUT /v1/admin/settings/freeze {"frozen": true, "reason": "کارآزمایی بالینی"}`
blocks publishing (editing drafts still works) until an admin unfreezes
it. The command line refuses too, unless `publish --ignore-freeze`.

## Rules that keep content safe

- **Disease categories are content** (table `categories`): name, short
  code, card color and icon are editable; the id is part of care plan
  ids, so it can't change. `general` always exists: its plans are shown
  for every disease in the diagnosis finder. Icons come from a fixed list
  (`content.CategoryIcons`, same as the app's `kind_style.dart`).
- **Ids never change** (`acs-01`, `quiz-1-q01`, `hp_smoking`); user data
  refers to them. Don't delete published rows; set `archived = true`.
- **Validation is shared**: `internal/content/validate.go` and the app's
  `lib/data/content_validation.dart` implement the same rules.
- **`schemaVersion`** is the JSON shape. Bump it (here and in the app's
  `ContentRepository.supportedSchemaVersion`) only for changes old apps
  can't read.
- **During the clinical trial**, freeze publishing (see below); every
  version and every edit keeps its author and notes in the audit log.

## Tests

```sh
go test ./...                     # unit tests; database tests are skipped
AVA_TEST_DATABASE_URL="postgres://localhost:5432/ava_test?sslmode=disable" go test -p 1 ./...
```

Database tests **wipe** the database they're given.

## Deploying

- Docker Hub / Google registries may block some region servers: use a
  registry mirror for `golang`, `alpine`, `postgres`. If
  `go mod download` fails: `--build-arg GOPROXY=https://goproxy.io,direct`.
- Serve the API over **HTTPS only** (tokens travel in headers), set
  `CORS_ORIGINS` to the web app's address, and back up PostgreSQL daily
  (`pg_dump`).
- First admin: `ava-server create-user --email ... --role admin`.
