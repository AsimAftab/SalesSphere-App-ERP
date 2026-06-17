# Beat-Plan Stop Visit — timing, notes, follow-up & photo

Integration guide for the **mobile app**. Covers the extended *mark-visit* endpoint
and the per-stop **visit-proof photo** endpoints, plus the updated stop shape the
visited card renders from.

> REST request/response types are generated from `/openapi.json` (orval) — this doc
> is the human-readable companion. If anything here disagrees with `/openapi.json`,
> believe the spec.

**Base URL** (production): `https://salessphere360.tech/api/v1`
**Permission:** every endpoint below requires `beat-plans:visit`.
**Auth:** access JWT (cookie on web, `Authorization: Bearer` / session on mobile), same as the rest of the API.
**CSRF:** the write calls (`POST`/`DELETE`) require the `X-CSRF-Token` header, like all mutations.

---

## 1. Mark a stop visited — `POST /beat-plans/{id}/visit`

`{id}` is the **beat plan** id. Marks one stop visited and records timing, notes,
and an optional follow-up date. Returns the **full beat plan** (with all stops).

### Request body (JSON)

| Field | Type | Required | Notes |
|---|---|---|---|
| `stopId` | string | ✅ | The stop being visited |
| `latitude` | number | — | −90..90; where the rep was |
| `longitude` | number | — | −180..180 |
| `visitStartedAt` | string (ISO 8601) | — | When the rep tapped **Start** / arrived |
| `visitEndedAt` | string (ISO 8601) | — | Visit end time; **defaults to server `now()`** if omitted |
| `notes` | string | — | Visit notes, **max 1000 chars** |
| `followUpDate` | string (ISO 8601) | — | Optional; **must be today or future** (org timezone) |

### Server behavior

- `visitedAt` (the canonical **end** time) = `visitEndedAt ?? now()`.
- `visitStartedAt` is stored as sent (or `null`).
- **`visitDurationSec` is computed by the server** = `max(0, round((visitedAt − visitStartedAt) / 1000))` when both timestamps are present, otherwise `null`. Any client-sent duration is ignored — don't bother sending one.
- The stop's `status` becomes `VISITED`. When it was the last pending stop, the **whole plan auto-completes** (`status: "COMPLETED"`) and its live-tracking session is closed.

### Validation errors (HTTP 422)

| `code` | Meaning |
|---|---|
| `INVALID_VISIT_TIMING` | both timestamps sent and `visitStartedAt > visitEndedAt` |
| `INVALID_FOLLOW_UP_DATE` | `followUpDate` is before today (org timezone) |

`400` for a malformed body (e.g. `notes` over 1000 chars), `403` if the caller may not manage this plan, `404` if the plan/stop doesn't exist.

### Example

```http
POST /api/v1/beat-plans/cmqd…001/visit
Content-Type: application/json
X-CSRF-Token: <token>

{
  "stopId": "stop_abc",
  "latitude": 27.7172,
  "longitude": 85.3240,
  "visitStartedAt": "2026-06-14T09:05:00.000Z",
  "visitEndedAt":   "2026-06-14T09:23:30.000Z",
  "notes": "Met the store manager, restocked shelf, collected partial payment.",
  "followUpDate": "2026-06-20"
}
```

Response: `200 OK` → the full beat plan (`BeatPlanDetail`). The affected stop now
carries `status: "VISITED"`, `visitDurationSec: 1110` (18m30s), your notes, and the
follow-up date. See [§3](#3-stop-shape) for the stop shape.

> **Offline replay / retries:** this call is **naturally idempotent** — it's a *set*,
> not an increment. Replaying the same body (same `visitEndedAt`) produces the same
> result, so it's safe to keep in an offline outbox and resend. Always send an explicit
> `visitEndedAt` so a retry doesn't re-stamp the time to a later `now()`.

---

## 2. Visit-proof photo

**One** photo per stop. Slot-based upload (re-uploading replaces the existing photo).
Stored on Cloudinary; the row keeps the URL the app renders.

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/beat-plans/{id}/stops/{stopId}/images` | List the stop's photo(s) |
| `POST` | `/beat-plans/{id}/stops/{stopId}/images` | Upload / replace the photo (multipart) |
| `DELETE` | `/beat-plans/{id}/stops/{stopId}/images/{slot}` | Remove the photo (also deletes from Cloudinary) |

### Upload — `POST …/images` (multipart/form-data)

| Field | Type | Notes |
|---|---|---|
| `imageNumber` | text | **Send first.** Slot number — only **`1`** is supported |
| `image` | file | JPEG or PNG, **≤ 5 MB** |

- Send `imageNumber` **before** the `image` part in the multipart body (the server reads the slot from the form field).
- Re-uploading to slot `1` **replaces** the existing photo and deletes the old Cloudinary asset.
- `X-CSRF-Token` header required.

Errors: `400` (`imageNumber` missing or ≠ 1), `404` (stop not found), `415` (not JPEG/PNG).

```ts
// React Native
const form = new FormData();
form.append('imageNumber', '1');                 // first
form.append('image', { uri, name: 'visit.jpg', type: 'image/jpeg' } as any);

await fetch(`${BASE}/beat-plans/${planId}/stops/${stopId}/images`, {
  method: 'POST',
  headers: { 'X-CSRF-Token': csrf /*, auth header */ },
  body: form,
});
```

Response: `200 OK`
```json
{ "id": "img_…", "slot": 1, "url": "https://res.cloudinary.com/…/visit.jpg", "sortOrder": 1 }
```

### List — `GET …/images`
`200 OK` → array of the shape above (0 or 1 item), ordered by `sortOrder`/`slot`.

### Delete — `DELETE …/images/1`
`200 OK`
```json
{ "stopId": "stop_abc", "slot": 1, "deletedAt": "2026-06-14T09:30:00.000Z" }
```
Errors: `400` (slot ≠ 1), `404` (no photo at that slot).

> The photo lives in its own table, so it survives across visit re-marks. Deleting the
> beat plan / stop cascades the photo row and you should treat the Cloudinary asset as
> gone once `DELETE` returns.

---

## 3. Stop shape

Every stop inside the beat-plan response (`GET /beat-plans/{id}` and the `/visit`
response) now looks like this — the new fields are what the visited card renders:

```jsonc
{
  "id": "stop_abc",
  "kind": "CUSTOMER",                 // CUSTOMER | SITE | PROSPECT
  "entityId": "cus_123",
  "name": "Acme Stores",
  "address": "Thamel, Kathmandu",
  "latitude": 27.7172,
  "longitude": 85.3240,
  "sortOrder": 0,
  "status": "VISITED",                // PENDING | VISITED | SKIPPED

  "visitStartedAt":   "2026-06-14T09:05:00.000Z",  // null until set
  "visitedAt":        "2026-06-14T09:23:30.000Z",  // = visit END time, null if not visited
  "visitDurationSec": 1110,                         // server-computed → "Time Spent"; null if unknown
  "visitNotes":       "Met the store manager…",     // null if none
  "followUpDate":     "2026-06-20T00:00:00.000Z",   // null if none (org-TZ start of day)
  "visitLatitude":  27.7172,
  "visitLongitude": 85.3240,

  "images": [
    { "id": "img_…", "slot": 1, "url": "https://res.cloudinary.com/…/visit.jpg", "sortOrder": 1 }
  ],

  "distanceToNextKm": 1.42            // to the next stop in route order; null for the last
}
```

**Rendering the visited card:**
- **Time Spent** → `visitDurationSec` (seconds). `null` means the rep didn't record a start time — show a blank/placeholder, not `0`.
- **Notes** → `visitNotes`.
- **Photo** → `images[0]?.url` (0 or 1 entry).
- **Follow-up** → `followUpDate` (date only; the time is always midnight org-time).

---

## Field rep flow (recap)

1. Rep taps **Start** on a stop → capture `visitStartedAt` locally.
2. Rep fills the **End-Visit** sheet → `POST /visit` with `visitEndedAt`, `notes`, `followUpDate`.
3. Rep attaches a photo → `POST …/stops/{stopId}/images` (`imageNumber=1`, `image`).
4. Card renders duration + notes + photo + follow-up from the returned stop.
