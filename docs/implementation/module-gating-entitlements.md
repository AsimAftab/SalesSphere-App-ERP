# Module gating + RBAC/PBAC — entitlements architecture

Status: **design approved, not yet implemented.** This doc is the contract for the
implementation pass. Written 2026-07-23 against backend `main` and app `main`
(drift schema v15, go_router 17).

The goal: when a module is not in the org's subscription plan — or the user's role
lacks its permissions — it does not appear in the app at all (no tile, no tab, no
deep-link entry). One registry, one gate primitive, offline-capable, and adding a
new module touches exactly three files.

---

## 1. Why (and why not like v1)

v1 SalesSphere gated modules manually and it sprawled:

- The module catalog was re-declared by hand in 4+ places (Flutter
  `module_config.dart` + bottom-nav index arithmetic; web `Sidebar.tsx`,
  `AppRoutes.tsx`, `PermissionGate.ROUTE_PRIORITY`, `SidebarMenu` special cases).
- Magic tab indices (`return 2; // invoice tab`) broke whenever modules toggled.
- Raw permission strings were scattered across 60+ files with typo-silent failure.
- Composite modules ("orderLists" = invoices + estimates) and role bypasses
  (`role === 'admin'`) were hand-coded `if` branches in multiple components.
- Web and mobile didn't even share a module vocabulary.

Every one of those has a structural counter in this design (§3).

## 2. How the backend gates (verified)

There is **no module table**. Gating is entirely permission-key based:

- Canonical catalog: `src/core/permissions.ts` (~230 keys, `<module>:<verb>`,
  kebab module names, `*` wildcard reserved for system roles OrgAdmin/BranchAdmin).
- Plans grant key sets: `SubscriptionPlan.enabledPermissions String[]`, tiers
  defined in `src/modules/subscriptions/plan-catalog.ts`:
  - **BASIC** = baseline (subscription/roles/employees/org-hierarchy/branches/companies)
    + CRM (customers/vendors/notes/collections) + SALES (invoices/estimates/payments)
  - **STANDARD** = BASIC + FIELD_OPS (sites/prospects/beat-plans/tour-plans/
    live-tracking/odometer/unplanned-visits/miscellaneous-work/targets)
    + PURCHASE + INVENTORY + HR (attendance/leaves/expense-claims)
  - **PREMIUM** = everything, incl. `collection-plus:*`, accounting, reports,
    `customers:credit-limit`
- Per request, `authGuard` (`src/middleware/authGuard.ts`) computes
  `req.auth.permissions = role.permissions ∩ plan.enabledPermissions` via
  `computeEffectivePermissions` (`src/core/effectivePermissions.ts`). A
  non-live subscription (EXPIRED/CANCELLED, grace period past) → **empty set**.
- Routes enforce with `requirePermission(key)` / `requireAnyPermission(...)`
  (`src/middleware/rbac.ts`).

So "module enabled in plan" ≡ "the plan's `enabledPermissions` contains that
module's keys". Dropping a key from the plan closes the API route, the web nav
entry, and (after this design) the mobile tile in one move.

The legacy `Feature` enum and `Subscription.customFeatures` columns are dead —
do not build against them.

## 3. Mobile architecture — two leaf primitives

Everything derives from two things; nothing else may hold gating state or lists.

### 3.1 `Entitlements` — the one gate value

`lib/core/entitlements/entitlements.dart`

```dart
enum EntitlementSource { none, cached, live }
// none   = no profile AND no drift snapshot (first launch pre-login)
// cached = built from drift snapshot (offline / pre-profile cold start)
// live   = built from a fresh /auth/me response

@immutable
class Entitlements {
  final Set<String> permissions;
  final bool wildcard;      // '*' present (interim fallback only, see §4)
  final String? planKey;    // BASIC | STANDARD | PREMIUM | null
  final String? planStatus; // TRIAL | ACTIVE | PAST_DUE | EXPIRED | CANCELLED
  final bool planMasked;    // true when built from effectivePermissions
  final EntitlementSource source;
  final DateTime? fetchedAt;

  bool can(String p) =>
      source == EntitlementSource.none || wildcard || permissions.contains(p);
  bool canAny(Iterable<String> ps) =>
      source == EntitlementSource.none || wildcard || ps.any(permissions.contains);
  bool moduleEnabled(AppModule m) => m.anyOf.isEmpty || canAny(m.anyOf);
}
```

**Fail policy (decided, do not re-litigate per screen):**

- Fail-**open** only while `source == none` — fresh install / first login before
  the profile lands. This preserves the current no-flicker contract of
  `hasPermissionProvider`.
- Once any snapshot exists (`cached`), **use it** — cold-start offline gating
  works and never flashes tiles.
- Loaded profile with `activeMembership == null` (platform/system-role users) →
  empty set, `source: live` → fail-**closed**; only ungated modules show.
- Expired subscription → backend sends an empty effective set → every
  plan-gated module closes naturally. No special-case branch anywhere.
- **No cache-age ceiling.** Field reps go offline for days; a stale-open
  snapshot beats locking a rep out of Parties in the field. The server's 403 is
  the hard gate; we self-heal on contact (§6).

### 3.2 `ModuleRegistry` — the one module catalog

`lib/core/entitlements/module_registry.dart`

```dart
enum ModuleId {
  home, catalog, order,                                  // shell tabs (ungated for now)
  parties, prospects, sites, unplannedVisits,            // field-ops grid
  collectionPlus, collection, notes, miscWork,
  attendance, leaves, odometer, expenseClaims,           // more grid
  tourPlans, targets, settings,
}

enum ModuleSurface { bottomTab, fieldOpsGrid, moreGrid, none }

@immutable
class AppModule {
  final ModuleId id;
  final String routePrefix;   // guards ALL subroutes, segment-aware (§7)
  final List<String> anyOf;   // Permissions.* constants; const [] = always on
  final ModuleSurface surface;
  final ModuleTileSpec? tile; // icon, l10n title key, subtitle, accent
  const AppModule({...});
}

/// THE single source of truth. Order within a surface = display order.
const kModules = <AppModule>[
  AppModule(
    id: ModuleId.collectionPlus,
    routePrefix: Routes.collectionPlus,
    anyOf: [Permissions.collectionPlusView, Permissions.collectionPlusViewOwn],
    surface: ModuleSurface.fieldOpsGrid,
    tile: ModuleTileSpec(...),
  ),
  // ... one entry per module
];
```

Structural rules:

- **Composite surfaces are computed, never listed.** The Field Ops tab is
  enabled ⇔ any module with `surface == fieldOpsGrid` is enabled. No union
  lists, no virtual modules.
- **Visibility gates on read keys only** — `anyOf` holds `<module>:view` /
  `<module>:view-own`, never `create`. A rep with only `view-own` sees the module.
- Permission constants come from `lib/core/auth/permissions.dart`, which mirrors
  the backend `src/core/permissions.ts` names **exactly**. During
  implementation, transcribe the remaining module keys (parties/customers,
  prospects, sites, notes, miscellaneous-work, attendance, leaves,
  expense-claims, tour-plans, targets, products/orders) from the backend
  catalog — do not guess.
- Raw permission strings in widgets are a **review-reject**.

**Add-a-module checklist (the scalability contract):**

1. Add its keys to `Permissions` (`lib/core/auth/permissions.dart`).
2. Add route constants + `GoRoute`s.
3. Add one `AppModule` entry to `kModules`.

Tile, tab, deep-link guard, bounce page, and 403 handling all follow. Anything
that requires a fourth touch point is an architecture regression — fix the
architecture, not the checklist.

## 4. Backend contract change (ships first, separate PR)

`GET /api/v1/auth/me` currently returns `activeMembership.role.permissions` —
the **raw** role list, not plan-masked. Field reps cannot call
`GET /subscription` (needs `subscription:view`), so mobile cannot learn the
effective set today. The server already computes it per request and throws it
away.

Change (backend `src/modules/auth`, serializer for `/auth/me`):

```jsonc
"activeMembership": {
  "role": { "permissions": ["*"] },                    // unchanged, raw
  "effectivePermissions": ["customers:view", "..."],   // NEW: role ∩ live plan
  "plan": { "key": "STANDARD", "name": "Standard", "status": "ACTIVE" } // NEW
}
```

- For wildcard roles, expand to the **concrete plan set** (not `["*"]`) — this
  is the whole point: an OrgAdmin on BASIC must lose STANDARD tiles, which is
  impossible to compute client-side.
- Non-live subscription → `effectivePermissions: []`, `plan.status` reflects it.

**Interim fallback (mobile must not block on the backend PR):** if
`effectivePermissions` is absent from the payload, build `Entitlements` from
`role.permissions` verbatim with `planMasked: false` — today's role-only
behavior. Nothing else in the app branches on which world it's in.

## 5. Data flow / provider graph

```
ProfileApi.me()  ─▶  profileControllerProvider            (exists, unchanged)
                          │ watch
                          ▼
        entitlementsControllerProvider  (AsyncNotifier<Entitlements>)
          build(): 1. read drift snapshot for current user → emit `cached`
                   2. when profile lands:
                      set = membership.effectivePermissions ?? membership.role.permissions
                      emit `live`; upsert snapshot (keyed userId + membershipId)
                          │
                          ▼
        entitlementsProvider  (sync Provider<Entitlements>; `none` while loading)
          ├─▶ hasPermission / hasAnyPermission   (rewritten as thin wrappers —
          │       existing call sites unchanged, now plan-masked for free)
          ├─▶ enabledModulesProvider(ModuleSurface) → grids + tabs
          ├─▶ moduleRedirect() via router redirect + RouterRefreshNotifier
          └─▶ ModuleUnavailablePage copy (plan name / status)
```

Files: `lib/core/entitlements/entitlements_controller.dart` (new),
`lib/core/auth/permissions.dart` (wrappers rewritten, same public API),
`lib/features/profile/domain/entities/profile_entity.dart` + DTO/mapper (add
`effectivePermissions: List<String>?` and `plan` to the membership entity).

## 6. Refresh policy

- **Login / cold start:** the existing profile fetch already runs → snapshot
  refreshes as a side effect. No new fetch path.
- **App resume:** if `fetchedAt` > 15 minutes old, fire-and-forget
  `profileController.refresh()`.
- **On 403:** `ForbiddenException` is already minted centrally in
  `lib/core/api/interceptors/error_interceptor.dart`. Add one hook: a callback
  injected at dio construction that debounces (≥30 s) and triggers a profile
  refresh. A server-side revocation (role edit, plan downgrade, expiry)
  self-heals on first contact; the router listener (§7) then bounces the user
  off any now-forbidden page.

## 7. Route guard (go_router 17, flat router kept)

No `StatefulShellRoute` migration — the existing flat `GoRouter` + `ShellRoute`
pattern stays; a shell rewrite is explicitly out of scope.

`lib/core/router/module_guard.dart` (new) — a **pure function**:

```dart
String? moduleRedirect(String location, Entitlements e);
```

- **Segment-aware longest-prefix match.** `'/collection-plus/add'` matches
  `collectionPlus`; `'/collection-plus'` must NOT match the `'/collection'`
  prefix. Match on path segments, never raw `startsWith` — this exact collision
  exists in `Routes` today.
- Locations owned by no module (splash, auth, profile, order detail…) pass through.
- Disabled module → `'/module-unavailable?module=<id>'`.

Wire-up in `lib/core/router/app_router.dart`'s existing `redirect`, after the
auth branch:

```dart
if (auth.status == AuthStatus.authenticated) {
  final bounce = moduleRedirect(state.uri.toString(), ref.read(entitlementsProvider));
  if (bounce != null) return bounce;
}
```

`RouterRefreshNotifier` (exists) additionally listens to `entitlementsProvider`
so a snapshot change re-runs the redirect — a user parked on a revoked page is
bounced immediately.

`ModuleUnavailablePage` (`lib/features/more/presentation/pages/`) — module
title + "not included in your plan" / "not permitted for your role" (picked via
`planMasked` + which check failed) + a Home button. Deep links to disabled
modules land here — never a 403 error screen, never a blank page.

## 8. Tabs and grids

- `HomeShell` (`lib/core/router/shell_scaffold.dart`) becomes a
  `ConsumerWidget`; the tab list is a filtered projection of
  `kModules.where(surface == bottomTab && enabled)` in registry order. Index =
  `indexWhere` on the **visible** list — no magic index math, hiding a tab is
  inherently safe. The Field Ops tab's enablement is the computed any-of rule
  (§3.2). The existing More-tab highlight special case for `/profile`/`/settings`
  stays.
- Both module grids become one-liners:
  `ModuleGrid(modules: ref.watch(enabledModulesProvider(ModuleSurface.fieldOpsGrid)))`.
  Extract the shared tile widget into `lib/shared/widgets/module_tile.dart` +
  `module_grid.dart` — the current `_HubTile` (field-ops) and more-page tile are
  near-identical copies; consolidate while touching them. Delete the local
  `_TileSpec` lists and the gating TODO in `field_ops_page.dart`.
- **Delete** the vestigial `lib/core/constants/module_config.dart`.

## 9. Offline cache — drift schema v16

`lib/core/db/tables/entitlement_snapshots_table.dart` (new):

```dart
@DataClassName('EntitlementSnapshotRow')
class EntitlementSnapshots extends Table {
  TextColumn get userId => text()();
  TextColumn get membershipId => text()();
  TextColumn get orgId => text()();
  TextColumn get permissionsJson => text()();   // JSON array of keys
  BoolColumn get wildcard => boolean().withDefault(const Constant(false))();
  BoolColumn get planMasked => boolean().withDefault(const Constant(false))();
  TextColumn get planKey => text().nullable()();
  TextColumn get planStatus => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {userId, membershipId};
}
```

- `schemaVersion` 15 → **16**; migration is `if (from < 16) createTable(...)` —
  idempotent per the dual-isolate doctrine in `app_database.dart` (both the UI
  and background isolates run `onUpgrade`).
- New `EntitlementsDao` (`lib/core/db/daos/entitlements_dao.dart`): upsert +
  read by (userId, membershipId).
- Rows are **per membership**, so an org switch keeps both orgs' caches for
  offline switch-back.
- Purge on logout alongside the existing user-row cleanup.

## 10. Edge cases

| Case | Behavior |
|---|---|
| Org switch | Membership change flows through profile → controller recomputes + snapshots the new membership; the old org's snapshot is retained. |
| Role/plan change mid-session | Next refresh (resume >15 min or first 403) updates; router listener bounces off now-forbidden pages. |
| Subscription expires while offline | Cache stays open (deliberate, §3.1); individual API calls 403 with existing `ForbiddenException` copy; on reconnect the refreshed empty set closes plan modules. |
| Wildcard role (`*`) | With the backend change, wildcard users receive the concrete plan-masked set — an OrgAdmin on BASIC correctly loses STANDARD tiles. Client-side `*` handling remains only for the interim fallback. |
| System-role user / no membership | Empty set, fail-closed; only ungated modules (Home, Catalog, Order shell, Settings) visible. |
| First launch, offline, cached snapshot exists | `cached` entitlements gate correctly with zero network. |
| First launch ever, no cache | `source == none` → fail-open until profile lands (no flicker), then `live`. |

## 11. Rollout order (each step independently shippable)

1. **Backend:** serialize `effectivePermissions` + `plan` into `/auth/me`.
2. Mobile: extend `Permissions` catalog (transcribe backend keys) + profile
   entity/DTO/mapper fields. Additive, inert.
3. Registry + `Entitlements` + controller + drift v16 + rewrite
   `hasPermission`/`hasAnyPermission` as wrappers. Behavior-neutral for the two
   existing gates.
4. Grids → registry projections (first visible change; Collection Plus finally
   hides for CRM-only tenants).
5. Tab gating.
6. Route guard + `ModuleUnavailablePage`.
7. 403-refresh hook; delete `module_config.dart`; update this doc's status line.

The interim fallback (§4) means steps 2–7 do not block on step 1.

## 12. Testing strategy (per the four established patterns)

1. **Pure unit** — `Entitlements.can/canAny/moduleEnabled` truth table
   (`none`/`cached`/`live` × wildcard × empty set); **registry invariants test**
   (unique ids, unique route prefixes, every `anyOf` key exists in
   `Permissions`, every tiled module has a registered route); segment-aware
   prefix matcher incl. the `/collection` vs `/collection-plus` collision.
2. **Drift in-memory** (`NativeDatabase.memory()`) — `entitlements_dao_test`:
   upsert/read per membership, JSON round-trip; v15→v16 migration.
3. **Riverpod `ProviderContainer`** — controller with overridden
   `profileControllerProvider` + fake DAO: cached-then-live emission order,
   `effectivePermissions` preferred over role fallback, `none` fail-open,
   403-refresh debounce.
4. **Widget** (`ProviderScope.overrides` + pump) — field-ops grid hides
   Collection Plus for a CRM-only set; `HomeShell` tab count full vs gated;
   deep link to a disabled module lands on `ModuleUnavailablePage`.
