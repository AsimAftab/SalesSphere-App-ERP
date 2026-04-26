# SalesSphere ERP — Mobile App

Field-operations companion to the SalesSphere ERP SaaS for Nepal. Sibling of `../SalesSphereERP-Frontend/` and `../SalesSphereERP-Backend/`. Built **Android-first** — iOS comes later. **No accounting** — that's web-only.

The full product plan lives at `C:\Users\asima\.claude\plans\hey-you-know-about-wondrous-lighthouse.md` (server / web design) and the mobile-specific scaffold plan at `C:\Users\asima\.claude\plans\hey-we-are-starting-cheerful-garden.md`.

---

## Stack (locked)

- Flutter 3.41+ / Dart 3.11+, **Android only** (`flutter create --platforms=android`)
- `dio` 5 + 5-stage interceptor chain (Connectivity → Auth → PrettyDioLogger → AppLogger → ErrorMapper)
- `flutter_riverpod` 3 with `riverpod_generator`
- `go_router` 16 + `app_links` (deep link scheme: `salessphere://`)
- `freezed` + `json_serializable` for all models
- `drift` (SQLite) as the **single source of truth for reads**
- `flutter_secure_storage` for JWT access/refresh tokens — never `SharedPreferences`
- `local_auth` for biometric unlock on cold start
- `flex_color_scheme` + Poppins + `flutter_screenutil` (base 360×800)
- `sentry_flutter` (DSN from `Env.sentryDsn`; empty = disabled)
- `very_good_analysis` + `custom_lint` (`riverpod_lint`)

Three flavors: `dev`, `staging`, `prod`. Configure via `--dart-define-from-file=env/<flavor>.json` — never `flutter_dotenv`.

---

## Architecture rules

### Hybrid API client (anti-corruption layer)

- **Generated wire DTOs only.** From `tool/openapi.json` via `swagger_parser`. Output: `lib/core/api/generated/dto/`. Committed. Never edited.
- **Hand-written client.** `core/api/dio_client.dart`, interceptors, `endpoints.dart`.
- **Hand-written `<feature>_api.dart` per feature** — typed by generated DTOs.
- **Hand-written domain models** in `features/<x>/domain/` — UI consumes these, not wire DTOs.
- **Repository is the translation boundary** — DTO ↔ domain mapping + drift persistence + outbox enqueue.
- **Never use a generated client / service class.** `tool/gen_dto.sh` strips them automatically. Don't suggest `openapi-generator-cli` for clients, `retrofit`, `chopper`, etc.

### Offline-first

- **All field-ops features must work offline.** Not just location pings.
- **Reads:** UI watches drift `Stream` queries → repository → drift. The network layer never returns directly to the UI.
- **Writes:** repository optimistically updates drift + appends a `mutation_outbox` row → `SyncService` drains FIFO when online → handler reconciles server response back into drift.
- **Conflict policy:** last-write-wins by default. Accounting-touching writes set `ConflictPolicy.serverAuthoritative` and flag rejected rows in a "needs review" tray.

### Auth

- **Tokens in secure storage** (`EncryptedSharedPreferences` on Android via `flutter_secure_storage`).
- **Cold start:** if refresh token exists and biometrics are available, prompt unlock → call `/auth/me` → restore session. Else fall back to login.
- **Auth refresh** is handled by `AuthInterceptor` with concurrent-request coalescing via a `Completer`. Three consecutive failures → force logout via `tokenRefreshFailureSinkProvider`.

### Routing

- **`go_router` only.** No imperative `Navigator.push` / `pop` calls. Always `context.go`, `context.goNamed`, `context.pop`.
- **`refreshListenable`** wired to `RouterRefreshNotifier` which listens to `authStateProvider`.
- **Auth zone:** `/`, `/login`, `/biometric`. Authenticated users are bounced to `/home`. Unauthenticated users are bounced to `/login`. Unknown auth → splash.

### State + DI

- **Riverpod 3 only.** Prefer `Notifier` / `AsyncNotifier` with `@riverpod` codegen. No `flutter_hooks` / `hooks_riverpod`. No `get_it`. No `provider`.
- **Cross-feature plumbing** lives in `lib/core/providers/`.

### Logging

- **`AppLogger` only.** Never `print()`. `pretty_dio_logger` only runs in debug.

### Localisation

- **English-default**, Nepali stubbed. Add new keys to `lib/l10n/app_en.arb` first, mirror in `app_ne.arb`. Run `flutter gen-l10n`.

---

## Folder layout (feature-first)

```
lib/
├─ main{,_dev,_staging,_prod}.dart    # bootstrap + flavor entries
├─ app.dart                            # MaterialApp.router
├─ core/
│  ├─ api/                             # dio_client, endpoints, interceptors, generated/dto/
│  ├─ auth/                            # token_storage, biometric_service, auth_state
│  ├─ config/                          # Env (--dart-define), Flavor
│  ├─ db/                              # AppDatabase, tables/, daos/
│  ├─ exceptions/                      # ApiException hierarchy
│  ├─ providers/                       # ProviderObserver
│  ├─ router/                          # GoRouter config + ShellScaffold
│  ├─ sync/                            # SyncService, SyncScheduler, MutationHandler
│  ├─ theme/                           # AppTheme (flex_color_scheme + Poppins)
│  └─ utils/                           # AppLogger
└─ features/<feature>/
   ├─ data/                            # <feature>_api.dart, dto/, <feature>_repository.dart
   ├─ domain/                          # freezed UI models
   └─ presentation/                    # controllers/, pages/, widgets/
```

---

## Codegen

```bash
dart run build_runner build --delete-conflicting-outputs   # one-shot
dart run build_runner watch --delete-conflicting-outputs   # incremental
./tool/gen_dto.sh                                          # regenerate wire DTOs
flutter gen-l10n                                           # regenerate ARB → AppL10n
```

Generated files (under `lib/`) are **committed** so PR diffs surface contract changes:

- `**/*.freezed.dart`, `**/*.g.dart` (freezed + json_serializable)
- `lib/core/db/**/*.g.dart` (drift)
- `lib/core/api/generated/dto/**` (swagger_parser DTOs only — clients stripped)
- `lib/l10n/generated/**` (ARB → Dart)

---

## Testing

```bash
flutter test          # all
flutter analyze       # static
```

Three layered patterns established by the scaffold:

- `test/db/users_dao_test.dart` — drift in-memory (`NativeDatabase.memory()`)
- `test/auth/auth_state_test.dart` — Riverpod `ProviderContainer`
- `test/widget/login_page_test.dart` — `ProviderScope.overrides` + widget pump

When importing both `drift/drift.dart` and `flutter_test/flutter_test.dart` in tests, hide drift's `isNotNull` / `isNull` to avoid the matcher collision: `import 'package:drift/drift.dart' hide isNotNull, isNull;`.

---

## What NOT to do

- Don't store JWTs in `SharedPreferences`. Use `flutter_secure_storage`.
- Don't hand-write wire DTOs (after the auth-feature placeholders) — regenerate them.
- Don't use a generated API client. The `clients/*` and `rest_client.dart` from `swagger_parser` are stripped on purpose.
- Don't use `flutter_dotenv`. Use `--dart-define-from-file` with the per-flavor `env/*.json`.
- Don't fetch directly to the UI. UI reads from drift; repositories mediate.
- Don't ship a feature without an offline path.
- Don't add iOS-specific code. iOS comes later. (`flutter create --platforms=android` only.)
- Don't extend `flutter_lints`. We're on `very_good_analysis`.
- Don't pull in `firebase_messaging` until the backend has a device-token endpoint.
- Don't use `Navigator.push`. Always `go_router`.
- Don't add `get_it`, `flutter_hooks`, `provider`. Riverpod is the DI + state container.

---

## Reference repos / files

- v1 mobile (Flutter): `C:/Users/asima/Desktop/Projects/Web-Dev/SalesSphere/SalesSphere-App/` — port the interceptor chain pattern + tracking foreground-service shape.
- v1 web: `C:/Users/asima/Desktop/Projects/Web-Dev/SalesSphere/SalesSphere-Frontend/src/api/api.ts` — token-refresh queue logic.
- v2 backend: `C:/Users/asima/Desktop/Projects/Web-Dev/SalesSphere-ERP/SalesSphereERP-Backend/` — exposes `GET /openapi.json` (consumed by `tool/gen_dto.sh`).
