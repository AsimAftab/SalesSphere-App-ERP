# SalesSphere ERP — Mobile App

Field-operations companion to the SalesSphere ERP SaaS for the Nepal market. Sibling repos: `SalesSphereERP-Frontend` (web) and `SalesSphereERP-Backend` (Express 5 / Bun / Postgres / Prisma).

This app is **Android-first**; iOS scaffolding is intentionally absent and will be added when iOS comes online.

---

## Stack

| Concern | Choice |
|---|---|
| Framework | Flutter 3.41+ (Dart 3.11+) |
| HTTP | `dio` 5 with a 5-stage interceptor chain |
| State | `flutter_riverpod` 3 (with `riverpod_generator`) |
| Routing | `go_router` 16 + `app_links` for deep links |
| Models | `freezed` + `json_serializable` |
| Local DB | `drift` (SQLite) — single source of truth for reads |
| Offline | mutation outbox + `SyncService` + `SyncScheduler` |
| Secure storage | `flutter_secure_storage` (EncryptedSharedPreferences on Android) |
| Auth UX | `local_auth` (Android BiometricPrompt) for cold-start unlock |
| Realtime | `socket_io_client` |
| Maps | `google_maps_flutter` + `geolocator` + `geocoding` |
| Background | `flutter_background_service` + `flutter_local_notifications` |
| Theming | `flex_color_scheme` (Material 3) + Poppins + `flutter_screenutil` |
| Observability | `sentry_flutter` + `logger` (`AppLogger`) + Riverpod `ProviderObserver` |
| i18n | `flutter_localizations` + ARB files (English default, Nepali stubbed) |
| Lint | `very_good_analysis` + `custom_lint` (`riverpod_lint`) |
| Tests | `flutter_test` + `mocktail` + `http_mock_adapter` |

---

## Project layout

```
lib/
├─ main.dart                  ← shared bootstrap (Sentry, ProviderScope)
├─ main_dev.dart / staging / prod  ← flavor entrypoints
├─ app.dart                   ← MaterialApp.router, theme, l10n
├─ core/
│  ├─ api/
│  │  ├─ dio_client.dart           ← handwritten Dio + Riverpod provider
│  │  ├─ endpoints.dart            ← all API URL paths centralised
│  │  ├─ interceptors/             ← connectivity, auth, logging, error
│  │  └─ generated/dto/            ← swagger_parser output (commit, never edit)
│  ├─ auth/                        ← token_storage, biometric_service, auth_state
│  ├─ config/                      ← Env (--dart-define-from-file) + flavors
│  ├─ db/                          ← drift database, tables, daos
│  ├─ exceptions/                  ← ApiException hierarchy
│  ├─ providers/                   ← cross-cutting Riverpod (observer, etc.)
│  ├─ router/                      ← go_router config + ShellRoute scaffold
│  ├─ sync/                        ← outbox + SyncService + SyncScheduler
│  ├─ theme/                       ← flex_color_scheme + Poppins
│  └─ utils/                       ← AppLogger
└─ features/<feature>/
   ├─ data/
   │  ├─ <feature>_api.dart        ← handwritten Dio calls
   │  ├─ dto/                      ← handwritten request DTOs
   │  └─ <feature>_repository.dart ← DTO ↔ domain mapping + drift writes
   ├─ domain/                      ← UI-facing freezed models
   └─ presentation/
      ├─ controllers/              ← Riverpod AsyncNotifiers
      └─ pages/
```

---

## Quick start

### Prerequisites

- Flutter 3.41.x (stable)
- Android Studio with an Android 24+ emulator OR a physical Android device
- Backend running locally (see `../SalesSphereERP-Backend/`) — `http://10.0.2.2:3000` from the emulator
- `env/dev.json` populated (copy `env/dev.json.example`)

### Run dev flavor

```bash
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json
```

### Run staging / prod

```bash
flutter run --flavor staging -t lib/main_staging.dart --dart-define-from-file=env/staging.json
flutter run --flavor prod    -t lib/main_prod.dart    --dart-define-from-file=env/prod.json
```

### Build APK

```bash
flutter build apk --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json
```

---

## Codegen

Three generators run via `build_runner`: `freezed`, `json_serializable`, `riverpod_generator`, `drift_dev`.

```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs   # incremental
```

### Wire DTOs from OpenAPI (hybrid pattern)

Wire DTOs are generated from the backend's `/openapi.json` using `swagger_parser`. **DTOs only** — the SalesSphere mobile app uses a hand-written client + repository layer, so the generated `clients/*` and `rest_client.dart` are stripped automatically by the script.

```bash
# Use the committed snapshot at tool/openapi.json
./tool/gen_dto.sh

# Or pull a fresh snapshot from a running backend
API=http://localhost:3000 ./tool/gen_dto.sh --pull
```

Output lands under `lib/core/api/generated/dto/`. Commit the result so PR diffs surface contract changes.

### Localisation

```bash
flutter gen-l10n
```

ARB files live in `lib/l10n/`. Add new keys to `app_en.arb` first; `app_ne.arb` carries the Nepali translations.

---

## Architecture rules

### Hybrid API client (anti-corruption layer)

- **Generated DTOs only.** Wire DTOs come from the backend's OpenAPI spec via `swagger_parser`. Never hand-edit `lib/core/api/generated/dto/`.
- **Hand-written client.** `core/api/dio_client.dart`, interceptors, and `endpoints.dart` are owned and read by humans.
- **Hand-written API per feature.** Each feature has a `<feature>_api.dart` with raw Dio calls typed by the generated DTOs.
- **Hand-written domain models.** UI consumes `freezed` domain models (in `features/<x>/domain/`), never wire DTOs. The repository is the explicit translation boundary.

### Offline-first

- **drift is the source of truth for reads.** UI watches drift `Stream` queries; the network layer never returns directly to the UI.
- **All writes go through the outbox.** Repositories optimistically update drift, append a row to `mutation_outbox`, and let `SyncService` drain it FIFO when online.
- **Conflict policy.** Default last-write-wins. Accounting-touching writes (collections, expense claims) opt into `serverAuthoritative` — backend has final say, mobile shows a "needs review" tray on rejection.

### Auth

- **Tokens live in secure storage.** Access + refresh tokens are stored via `flutter_secure_storage` (EncryptedSharedPreferences). Never `SharedPreferences`.
- **Biometric unlock.** On cold start, if a refresh token exists and the device has biometrics enrolled, prompt before restoring the session.
- **Refresh interceptor coalesces.** Concurrent 401s wait on a single refresh request via a `Completer`. After 3 consecutive failures the app force-logs-out.

### Routing

- **`go_router` only.** Never call `Navigator.push` / `pop` directly. `context.go` / `context.goNamed` / `context.pop` only.
- **Auth state drives redirects.** `RouterRefreshNotifier` listens to `authStateProvider` and re-evaluates `redirect`.
- **Deep link scheme.** `salessphere://<path>` — registered in `AndroidManifest.xml`.

### State management

- **Riverpod 3 with codegen.** Prefer `@riverpod` annotation + `Notifier` / `AsyncNotifier`. No `flutter_hooks`, no `get_it`, no `provider`.
- **DI lives in providers.** No service locator. Each feature exposes its providers in `<feature>_providers.dart` (where applicable).

### Logging + observability

- **`AppLogger`, not `print`.** All logging routes through `appLoggerProvider`.
- **Sentry is opt-in via `Env.sentryDsn`.** Empty DSN disables Sentry (useful for dev). Tracesample 100% in debug, 20% in prod.

---

## Testing

```bash
flutter test
```

Layered patterns:

- **DAO tests** (`test/db/`): in-memory drift via `NativeDatabase.memory()` + `AppDatabase.test(...)`.
- **Notifier tests** (`test/auth/`): `ProviderContainer` + `overrideWith` to swap in stubs.
- **Widget tests** (`test/widget/`): `ProviderScope.overrides` for the controller, `MaterialApp(home: ...)` for the page under test.
- **Repository / API tests** (future): `mocktail` + `http_mock_adapter` against a real Dio.

---

## Useful commands

```bash
flutter analyze
flutter test
flutter format lib/ test/
flutter pub get
flutter pub upgrade --major-versions

dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs

flutter gen-l10n
./tool/gen_dto.sh
```

---

## Sibling repos

- `../SalesSphereERP-Frontend/` — React + Vite web (orval + TanStack Query + shadcn)
- `../SalesSphereERP-Backend/` — Express 5 / Bun / Postgres / Prisma + SphereLedger SDK
- `../SalesSphereERP-Deployment/` — infra
