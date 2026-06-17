# Unplanned Visits API — Mobile Integration Spec

**For:** SalesSphere backend team
**Goal:** Implement the backend module the mobile app's new **Unplanned Visits**
feature is already wired to. The Flutter side is complete (feature folder
`lib/features/unplanned_visits/`) and talks to the endpoints below under
`/api/v1/unplanned-visits`. This doc defines the contract the app expects —
modeled on the existing **odometer** module (same envelope, same multipart +
CSRF-exempt conventions, same `409` shape).

An unplanned visit is an **ad-hoc field visit** a rep makes to a customer,
prospect, or site that is **not** part of a beat plan — so there is **no live
tracking**. The rep starts the visit on arrival (geofence-gated client-side),
then completes it with a single proof photo, a description, and an optional
follow-up date.

---

## Conventions (same as odometer / every authenticated endpoint)

- **Base URL:** `{apiBaseUrl}/api/v1`
- **Auth:** the same mobile session the app already sends.
- **CSRF:** mobile (`x-client-type: mobile`) / Bearer requests are CSRF-exempt;
  the app sends **no** `x-csrf-token`. Keep `/unplanned-visits` mutations on the
  same exemption odometer/attendance use.
- **Response envelope:** every response is `{ "success": true, "data": <payload> }`.
  Errors are `{ "success": false, "error": { code, message } }` with a 4xx/5xx
  status.
- **Wire casing:** `status` is lowercase (`in_progress` | `completed`);
  `target.type` is lowercase (`customer` | `prospect` | `site`).
- **Server owns time + identity:** the client never sends `id`, timestamps,
  `durationSeconds`, or `tripNumber`-style fields. Timestamps are server-side;
  the day is derived from the organization's timezone.

---

## Permissions (please add to the catalogue)

Mirror the odometer triplet in `src/core/permissions.ts` and gate the routes
with `requirePermission(...)`. OrgAdmin's `*` covers all three.

| Permission                 | Gates                                  |
|----------------------------|----------------------------------------|
| `unplanned-visits:view`    | `GET status/today`, `GET /:id`         |
| `unplanned-visits:record`  | `POST /start`, `POST /stop`            |
| `unplanned-visits:delete`  | `DELETE /:id`                          |

---

## The visit lifecycle

1. A rep has **at most one open visit at a time**. `POST /start` creates a
   visit in status `in_progress`, linked to exactly one target
   (customer / prospect / site).
2. Starting a second visit while one is still `in_progress` returns **409**
   `UNPLANNED_VISIT_IN_PROGRESS`.
3. `POST /stop` completes the rep's open visit (status → `completed`), storing
   the proof photo, description, optional follow-up date, and stop location.
   With no open visit it returns **409** `UNPLANNED_VISIT_NO_ACTIVE`.
4. `durationSeconds = stopTime − startTime` (server-computed; `null` until
   completed).

> **Geofencing is enforced client-side** (the rep must be within 50 m of the
> target's coordinates to start). The server does **not** need to enforce
> distance — it just stores the start/stop coordinates the app sends. This
> mirrors how attendance / beat-plan geofences work today.

---

## Endpoints

### 1. Start a visit — `POST /api/v1/unplanned-visits/start`

`application/json`. Send **exactly one** of the three id fields (XOR, same as
notes):

| field        | type   | required | notes                              |
|--------------|--------|----------|------------------------------------|
| `customerId` | string | one-of   | the customer (party) being visited |
| `prospectId` | string | one-of   | the prospect being visited         |
| `siteId`     | string | one-of   | the site being visited             |
| `latitude`   | number | ❌       | rep's start GPS (-90..90)          |
| `longitude`  | number | ❌       | rep's start GPS (-180..180)        |
| `address`    | string | ❌       | reverse-geocoded start address     |

**201** → `data` is a **Visit object** with `status: "in_progress"`.
**409** `UNPLANNED_VISIT_IN_PROGRESS` → a visit is already open.
**404** if the referenced customer/prospect/site doesn't belong to the org.

### 2. Stop the active visit — `POST /api/v1/unplanned-visits/stop`

`multipart/form-data` — no id needed; the server finds the rep's open visit:

| field          | type   | required | notes                          |
|----------------|--------|----------|--------------------------------|
| `description`  | string | ✅       | what happened on the visit     |
| `followUpDate` | string | ❌       | `YYYY-MM-DD` — planned revisit |
| `latitude`     | number | ❌       | rep's stop GPS                 |
| `longitude`    | number | ❌       | rep's stop GPS                 |
| `address`      | string | ❌       | reverse-geocoded stop address  |
| `image`        | file   | ✅       | JPEG/PNG ≤ 5 MB (proof photo)  |

> The app **requires** `description` + `image`; `followUpDate` is optional.
> (`image` is optional at the API level if you prefer, but the UI always sends
> it.)

**200** → `data` is the completed **Visit object** (`status: "completed"`,
`durationSeconds` populated, `image` now a remote URL).
**409** `UNPLANNED_VISIT_NO_ACTIVE` → nothing to stop.

### 3. Today's visits — `GET /api/v1/unplanned-visits/status/today`

**200** → `data`:
```json
{
  "visits": [ /* Visit object[] for today, newest first */ ],
  "hasActiveVisit": true,
  "activeVisitId": "clx...",
  "organizationTimezone": "Asia/Kathmandu"
}
```
The app hydrates the home page (active visit + today's list) from this.

### 4. Visit detail — `GET /api/v1/unplanned-visits/:id` → `data` is one Visit object.

### 5. Delete a visit — `DELETE /api/v1/unplanned-visits/:id`
**200** → `data`: `{ "id": "...", "deletedAt": "2026-06-17T..." }`
(also removes the visit's photo). Requires `unplanned-visits:delete`.

---

## The Visit object (what `data` looks like)

```jsonc
{
  "id": "clx9f...",
  "status": "in_progress",              // in_progress | completed
  "target": {
    "type": "customer",                 // customer | prospect | site
    "id": "clx1a...",
    "name": "Acme Traders",             // denormalised for list/detail render
    "address": "Putalisadak, Kathmandu",// or null
    "latitude": 27.7041,                // or null — geofence anchor
    "longitude": 85.3145                // or null
  },
  "startTime": "2026-06-17T03:49:00.000Z",
  "startLocation": {                    // or null
    "latitude": 27.7042, "longitude": 85.3146, "address": "..."
  },
  "stopTime": "2026-06-17T04:35:00.000Z",   // or null until completed
  "stopLocation": { "latitude": 27.70, "longitude": 85.31, "address": "..." }, // or null
  "image": "https://res.cloudinary.com/.../visit.jpg",  // or null until stop
  "description": "Discussed Q3 order; needs a quote.",  // or null
  "followUpDate": "2026-06-24",         // YYYY-MM-DD, or null
  "durationSeconds": 2760,              // stop − start, or null until completed
  "createdAt": "2026-06-17T03:49:00.000Z",
  "updatedAt": "2026-06-17T04:35:00.000Z"
}
```

### Notes for the Prisma model

- One row per visit: `organizationId`, `employeeId`, `status`, the three
  nullable FK columns (`customerId` / `prospectId` / `siteId`, with a DB-level
  or service-level XOR check), `startTime`, `startLat/Lng/Address`, `stopTime`,
  `stopLat/Lng/Address`, `imageUrl` + `imagePublicId`, `description`,
  `followUpDate` (date), `createdAt`, `updatedAt`.
- `target.name` / `address` / `latitude` / `longitude` are resolved from the
  linked entity at read time (join + serialize), not stored on the visit.
- `durationSeconds` is computed in the serializer from `stopTime − startTime`.

---

## Integration checklist (backend)

- [ ] Prisma `UnplannedVisit` model + migration (XOR on the three FKs).
- [ ] `unplanned-visits:{view,record,delete}` in the permission catalogue.
- [ ] Routes: `POST /start` (json), `POST /stop` (multipart `image`),
      `GET /status/today`, `GET /:id`, `DELETE /:id` — all CSRF-exempt for mobile.
- [ ] One-open-visit-per-rep guard → `409 UNPLANNED_VISIT_IN_PROGRESS` /
      `UNPLANNED_VISIT_NO_ACTIVE` (structured `error.code`).
- [ ] Serialize `target` as `{ type, id, name, address, latitude, longitude }`.
- [ ] Cloudinary upload for the stop photo (same pipeline as odometer/notes).
- [ ] Add to `GET /openapi.json` so `tool/gen_dto.sh` can replace the
      hand-written mobile DTOs later.
```
