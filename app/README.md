# AvA app (Flutter)

The nurses' app and the admin panel. Persian (right-to-left) text with a
left-to-right navigation flow. Runs on the web (installable, works
offline), Android and iOS.

Two entry points in one Flutter project:

| | entry point | for |
|---|---|---|
| **App** | `lib/main.dart` | nurses and nursing students |
| **Admin panel** | `lib/main_admin.dart` | editors, reviewers and admins (web) |

The app never includes the admin panel's code (`lib/admin/`).

## How it works

- **Content** (disease categories, care plans, the Gordon assessment,
  quizzes) comes from the [AvA server](../server). It is downloaded on
  the first start and kept on the device, so the app opens instantly and
  works offline; newer published versions are fetched in the background.
- **Accounts:** favorites, notes, recently viewed plans, quiz progress
  and mistakes are stored on the server and follow the user across
  devices. The device keeps only the session token and display settings
  (theme, quiz mode).
- **No real content is in this repository.** Tests use made-up sample
  content: `test/fixtures/sample_bundle.json`.

## Run

Start the server first (from the repository root: `docker compose up -d
db api`, then `docker compose run --rm seed` once for the sample content).

```sh
flutter pub get

# App (the server's default address is http://localhost:8080)
flutter run -d chrome --web-port 8000

# Admin panel
flutter run -d chrome -t lib/main_admin.dart --web-port 8001

# Android emulator: the emulator reaches your computer at 10.0.2.2
flutter run -d emulator-5554 --dart-define=AVA_API_URL=http://10.0.2.2:8080
```

The web addresses (`http://localhost:8000`, `http://localhost:8001`)
must be in the server's `CORS_ORIGINS` (they are by default).

To use the admin panel, your account needs a role:

```sh
docker compose run --rm api set-role --email you@example.com --role admin
```

## Build

`AVA_API_URL` is the server address, built into the app.

```sh
# Web: each into its own folder, host them separately
flutter build web --release -o build/web_app \
  --dart-define=AVA_API_URL=https://api.example.com
flutter build web --release -t lib/main_admin.dart -o build/web_admin \
  --dart-define=AVA_API_URL=https://api.example.com

# Android
flutter build appbundle --release --dart-define=AVA_API_URL=https://api.example.com
```

Or use the [`Dockerfile`](Dockerfile): it builds both web versions and
serves them with nginx (app on `:8000`, admin panel on `:8001`).

Serve the web files with `Cache-Control: no-cache` (see
[`docker/nginx.conf`](docker/nginx.conf)): their names don't change
between builds, so browsers must check for newer copies.

## Admin panel

- **Summary:** what to do next, unpublished changes, errors and warnings, recent activity.
- **Disease categories:** name, short code, card color and icon; add, reorder and remove. "General" always exists, and its plans are suggested for every disease.
- **Care plans:** filter by disease, search, reorder by dragging. The editor has a live preview, Ctrl+S to save, a warning before leaving with unsaved changes, and a "one item per line" text mode for pasting lists.
- **Quizzes:** questions with options, the correct answer, explanation and hint. "Save and next" for fast entry; copy an existing question.
- **Gordon assessment:** patterns and findings. Each finding shows which care plans it leads to; findings that lead nowhere are flagged.
- **Tags:** what each tag means and where it is used; renaming updates everywhere.
- **Publishing:** review the changes, check the content, publish with notes (reviewers and admins only). Version history.
- **History:** every change, who made it and when, with a field-by-field before/after.
- **Users and settings (admins):** accounts and roles; freezing publishing (e.g. during a clinical trial).

## Structure

```
lib/main.dart, lib/main_admin.dart   entry points
lib/app/            app root, router (sign-in gate), tab shell, first-run download
lib/core/           theme, design system, colors/contrast, config, providers
lib/data/           API client, content repository / validation / updater
lib/features/
  account/          session, user data, sign-in and account screens
  care_plans/       categories, plan lists and details, favorites, notes
  gordon_assessment/  diagnosis finder
  quiz/             quiz list, practice and exam modes, result, review
  home/, about/
lib/admin/          admin panel (screens, widgets, API client)
web/                PWA manifest and offline service worker (never caches the API)
test/               widget and logic tests with an in-memory fake server
```

## Tests

```sh
flutter analyze
flutter test
```

Tests never use the network: `test/fake_api.dart` is an in-memory
version of the server's API, and content comes from the sample fixture.

## Notes

- Navigation flows left to right (back on the left), text is right to
  left; see `lib/common/widgets/flow.dart`.
- Numbers are shown with English digits.
- The content rules in `lib/data/content_validation.dart` match the
  server's (`server/internal/content/validate.go`); change both together.
- Category icons are a fixed list in `lib/core/kind_style.dart`, mirrored
  by the server's `content.CategoryIcons`.
