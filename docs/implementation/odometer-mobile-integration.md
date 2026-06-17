# Odometer API — Mobile Integration Spec

**For:** SalesSphere mobile app team
**Goal:** Wire the existing odometer feature (currently in-memory at
`lib/features/odometer/`) to the live backend odometer API.

The backend module is now implemented and exposes the endpoints below under
`/api/v1/odometer`. Replace the in-memory `OdometerNotifier` start/stop/list
logic with real calls to these endpoints.

---

## Conventions (same as every other authenticated endpoint)

- **Base URL:** `{apiBaseUrl}/api/v1`
- **Auth:** same session your app already sends for tracking / beat-plans.
- **CSRF:** mutating calls (`POST /start`, `POST /stop`, `DELETE /:id`) require
  the `x-csrf-token` header — reuse the same token you already attach to other
  POST/PUT/PATCH/DELETE calls.
- **Response envelope:** every response is wrapped as
  `{ "success": true, "data": <payload> }`. Read `response.data["data"]`.
  Errors come back as `{ "success": false, "error": { code, message } }` with an
  HTTP 4xx/5xx status.
- **Wire casing:** `status` is lowercase (`not_started` | `in_progress` |
  `completed`); `unit` is lowercase (`km` | `miles`). Map these to your Dart
  enums (`TripStatus`, `DistanceUnit`).
- **Server owns time + identity:** do **not** send `tripNumber`, `startTime`,
  `stopTime`, `date`, or `id` — the server sets them (timestamps are server-side;
  the day is derived from the organization's timezone). Stop client-side ID
  generation (`millisecondsSinceEpoch`).

---

## The trip lifecycle (matches your current start → stop UX)

1. A rep has **at most one open trip per day**. `POST /start` creates a trip in
   status `in_progress`.
2. `POST /stop` completes the rep's open trip (status → `completed`) and the
   server stores the stop reading.
3. `distance = stopReading − startReading` (server-computed; returned as
   `distance`, `null` until completed).
4. Multiple trips per day are allowed: each new start increments `tripNumber`.
   Starting a second trip while one is still `in_progress` returns **409**.

---

## Endpoints

### 1. Start a trip — `POST /api/v1/odometer/start`

`multipart/form-data` (so the odometer photo rides along in one request):

| field             | type    | required | notes                          |
|-------------------|---------|----------|--------------------------------|
| `startReading`    | number  | ✅       | ≥ 0                            |
| `startUnit`       | string  | ✅       | `km` or `miles`                |
| `startDescription`| string  | ❌       |                                |
| `latitude`        | number  | ❌       | -90..90                        |
| `longitude`       | number  | ❌       | -180..180                      |
| `address`         | string  | ❌       | reverse-geocoded address       |
| `image`           | file    | ❌*      | JPEG/PNG ≤ 5 MB (the odometer photo) |

\* Optional at the API level; your UI requires it, so always send it.

**201** → `data` is a **Trip object** (see below) with `status: "in_progress"`.
**409** `ODOMETER_TRIP_IN_PROGRESS` → a trip is already open today; stop it first.

### 2. Stop the active trip — `POST /api/v1/odometer/stop`

`multipart/form-data` — no id needed; the server finds the rep's open trip:

| field            | type   | required | notes            |
|------------------|--------|----------|------------------|
| `stopReading`    | number | ✅       | ≥ 0              |
| `stopUnit`       | string | ✅       | `km` or `miles`  |
| `stopDescription`| string | ❌       |                  |
| `latitude`       | number | ❌       |                  |
| `longitude`      | number | ❌       |                  |
| `address`        | string | ❌       |                  |
| `image`          | file   | ❌*      | JPEG/PNG ≤ 5 MB  |

**200** → `data` is the completed **Trip object** (`status: "completed"`,
`distance` now populated).
**409** `ODOMETER_NO_ACTIVE_TRIP` → nothing to stop.

> Validate `stopReading >= startReading` client-side before submitting (the
> server accepts it but the distance would be negative).

### 3. Today's trips — `GET /api/v1/odometer/status/today`

**200** → `data`:
```json
{
  "trips": [ /* Trip object[] for today, ordered by tripNumber */ ],
  "totalTrips": 2,
  "hasActiveTrip": true,
  "activeTripId": "clx...",
  "organizationTimezone": "Asia/Kathmandu"
}
```
Use this to hydrate the home page (active trip + today's history) on launch.

### 4. My monthly history — `GET /api/v1/odometer/my-monthly-report?month=6&year=2026`

`month`/`year` optional (default = current org month). **200** → `data`:
```json
{
  "month": 6, "year": 2026,
  "records": [ /* Trip object[] across the month */ ],
  "summary": {
    "totalDistance": 145.9, "distanceUnit": "km",
    "totalTrips": 3, "tripsCompleted": 3, "tripsInProgress": 0,
    "avgDistancePerTrip": 49
  },
  "organizationTimezone": "Asia/Kathmandu"
}
```

### 5. Trip detail — `GET /api/v1/odometer/:id` → `data` is one Trip object.

### 6. Delete a trip — `DELETE /api/v1/odometer/:id`
**200** → `data`: `{ "id": "...", "deletedAt": "2026-06-17T..." }`
(also removes the trip's photos). Requires the `odometer:delete` permission.

---

## The Trip object (what `data` looks like)

```jsonc
{
  "id": "clx9f...",
  "employeeId": "clx1a...",
  "date": "2026-06-17",                 // org calendar day (YYYY-MM-DD)
  "tripNumber": 1,
  "status": "in_progress",              // not_started | in_progress | completed
  "startReading": 15000,
  "startUnit": "km",                    // km | miles
  "startImage": "https://res.cloudinary.com/.../start.jpg", // or null
  "startDescription": "Starting day",   // or null
  "startTime": "2026-06-17T03:49:00.000Z", // ISO, or null
  "startLocation": {                    // or null
    "latitude": 27.7172, "longitude": 85.3240, "address": "..."
  },
  "stopReading": 15025.5,               // or null until completed
  "stopUnit": "km",
  "stopImage": "https://...stop.jpg",   // or null
  "stopDescription": "Reached client",  // or null
  "stopTime": "2026-06-17T06:10:00.000Z", // or null
  "stopLocation": { "latitude": 27.67, "longitude": 85.31, "address": "..." },
  "distance": 25.5,                     // stop − start, or null until completed
  "createdAt": "2026-06-17T03:49:00.000Z",
  "updatedAt": "2026-06-17T06:10:00.000Z"
}
```

### Mapping to your current Dart `OdometerTrip`

| Dart field          | API field        |
|---------------------|------------------|
| `id`                | `id`             |
| `status`            | `status` (lowercase enum) |
| `distanceUnit`      | `startUnit` / `stopUnit` (`km`/`miles`) |
| `startedAt`         | `startTime`      |
| `startReading`      | `startReading`   |
| `startPhotoUrl`     | `startImage` (now a remote URL, not a local path) |
| `startDescription`  | `startDescription` |
| `stoppedAt`         | `stopTime`       |
| `stopReading`       | `stopReading`    |
| `stopPhotoUrl`      | `stopImage`      |
| `stopDescription`   | `stopDescription`|
| `distanceTravelled` | `distance` (server-computed; drop the local getter) |

New fields to capture/show that the backend now persists: `startLocation` /
`stopLocation` (lat/lng/address) and `tripNumber`.

---

## Integration checklist

- [ ] Add an `OdometerRepository` (Dio) with: `start`, `stop`, `statusToday`,
      `myMonthlyReport`, `tripById`, `deleteTrip`.
- [ ] Send start/stop as `multipart/form-data` with the photo in field `image`
      and the `x-csrf-token` header.
- [ ] Unwrap `response.data["data"]`; map lowercase `status`/`unit` to enums.
- [ ] Drop client-side id + timestamp generation; trust server values.
- [ ] On launch, hydrate from `GET /status/today` (replaces in-memory seed).
- [ ] Handle `409 ODOMETER_TRIP_IN_PROGRESS` / `409 ODOMETER_NO_ACTIVE_TRIP`
      with the appropriate toast instead of optimistic local state.
- [ ] Permissions: actions require `odometer:record` (start/stop/view) and
      `odometer:delete` (delete). OrgAdmin holds `*` so it has all of them.
```
