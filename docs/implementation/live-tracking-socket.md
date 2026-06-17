# Live Tracking — Socket.io integration guide

Real-time field tracking for **beat plans**. A field rep streams GPS breadcrumbs
while executing a beat plan; managers (and the web app) watch the rep move in
real time. Transport is Socket.io; the REST endpoints under `/api/v1/tracking`
and `/api/v1/beat-plans` are read/management only — **all live writes go over
the socket**.

> The REST request/response types are generated from `/openapi.json` (orval).
> The socket contract below is **not** in OpenAPI, so this doc is the source of
> truth for the realtime layer.

---

## Connection

**Base URLs** (production)

- REST: `https://salessphere360.tech/api/v1` — e.g. `…/api/v1/auth/login`, `…/api/v1/tracking/active`.
- Socket: origin **`https://salessphere360.tech`**, engine path **`/realtime`**, namespace **`/v1/tracking`**.
  The socket is **not** under `/api/v1` — connect to `https://salessphere360.tech/v1/tracking`
  with `{ path: '/realtime' }`.

| | |
|---|---|
| **Path** | `/realtime` |
| **Namespace** | `/v1/tracking` |
| **Transports** | `websocket`, `polling` (fallback) |
| **CORS** | origins from `CORS_ORIGIN`, `credentials: true` |
| **Connection-state recovery** | enabled (~2 min window — brief drops auto-restore rooms + missed events) |

### Auth

Every connection is authenticated with the **access JWT**, resolved in this
order:

1. `socket.handshake.auth.token` — **mobile** (preferred)
2. `Authorization: Bearer <token>` header
3. `ss_access` cookie — **web** (sent automatically with `withCredentials`)

The session must belong to an **active organization** (platform-admin sessions
without a tenant are rejected). On failure the connection is refused with a
`connect_error` whose message is one of `UNAUTHORIZED`, `NO_ACTIVE_ORG`,
`ORG_SUSPENDED`.

#### Mobile (React Native / Expo)

```ts
import { io } from 'socket.io-client';

const socket = io('https://salessphere360.tech/v1/tracking', {
  path: '/realtime',
  transports: ['websocket'],
  auth: { token: accessToken }, // the access JWT
});

socket.on('connect_error', (err) => {
  // err.message === 'UNAUTHORIZED' | 'NO_ACTIVE_ORG' | 'ORG_SUSPENDED'
});
```

#### Web (cookie auth)

```ts
const socket = io('/v1/tracking', { path: '/realtime', withCredentials: true });
```

---

## Lifecycle at a glance

```
rep:      connect ─ start-tracking ─ update-location* ─ (pause/resume)* ─ stop-tracking
manager:  connect ─ watch-beatplan ─ …receives location-update / status… ─ unwatch-beatplan
```

A rep auto-joins the beat-plan's broadcast room on `start-tracking`; watchers
join via `watch-beatplan`. You never address rooms directly — the server scopes
them per `organization + beatPlan`.

---

## Client → server events

All client→server events are **ack-bearing**: pass a callback as the last
argument and the server resolves it with an `Ack`.

```ts
type Ack =
  | ({ ok: true } & Record<string, unknown>) // event-specific fields
  | { ok: false; code: string; message?: string };
```

> **Only treat a ping as delivered once you receive `{ ok: true }`.** Keep
> unacked pings in a local outbox and replay them (see *Resilience*).

### `start-tracking`
Begin (or resume an existing) session for an assigned beat plan. Idempotent.

```ts
socket.emit('start-tracking', { beatPlanId }, (ack) => {
  // ack: { ok: true, sessionId, status: 'ACTIVE' }
  //   |  { ok: false, code: 'BEAT_PLAN_NOT_ASSIGNED' }
});
```

### `update-location`
One live GPS fix. **Rate-limited** (see below).

```ts
socket.emit('update-location', {
  beatPlanId,
  latitude, longitude,
  accuracy?, speed?, heading?,     // optional
  recordedAt?,                     // ISO string; server fills now() if omitted
  clientPingId?,                   // client-minted id → enables dedup on replay
  address?,                        // reverse-geocoded string (client geocodes)
}, (ack) => {
  // ack: { ok: true, persisted: 1 }
  //   |  { ok: false, code: 'RATE_LIMITED' | 'NO_ACTIVE_SESSION' | 'SESSION_PAUSED' }
});
```

The breadcrumb is written durably (queued); the session's **current location
updates immediately**, and watchers get a `location-update` broadcast right away.

### `update-location-batch`
Replay buffered (offline) fixes. **Not** rate-limited; capped at
`TRACKING_BATCH_MAX` (default 500). Idempotent — any ping whose
`(session, clientPingId)` already exists is skipped.

```ts
socket.emit('update-location-batch', { beatPlanId, pings: [ /* PingInput[] */ ] }, (ack) => {
  // ack: { ok: true, persisted: N, deduped: M }   (N + M === pings.length)
  //   |  { ok: false, code: 'BATCH_TOO_LARGE' | 'NO_ACTIVE_SESSION' }
});
```

### `pause-tracking` / `resume-tracking`

```ts
socket.emit('pause-tracking',  { beatPlanId }, (ack) => { /* { ok, status: 'PAUSED' } */ });
socket.emit('resume-tracking', { beatPlanId }, (ack) => { /* { ok, status: 'ACTIVE' } */ });
```

### `stop-tracking`
Completes the session and returns the computed summary.

```ts
socket.emit('stop-tracking', { beatPlanId }, (ack) => {
  // ack: { ok: true, summary: { totalDistanceKm, totalDurationMin, averageSpeedKmh, directoriesVisited } }
});
```

### `watch-beatplan` / `unwatch-beatplan`
For managers / the web app. Join a beat plan's room and get the current active
session snapshot (or `null`).

```ts
socket.emit('watch-beatplan', { beatPlanId }, (ack) => {
  // ack: { ok: true, activeSession: TrackingSession | null }
  //   |  { ok: false, code: 'NOT_FOUND' | 'FORBIDDEN' }
});
socket.emit('unwatch-beatplan', { beatPlanId }, (ack) => { /* { ok: true } */ });
```

Visibility: a watcher may see a session only if it's their own, they're an
OrgAdmin, or the rep is in their role-hierarchy subtree (subordinate visibility).

---

## Server → client events

| Event | Payload | When |
|---|---|---|
| `location-update` | `{ beatPlanId, userId, location: { latitude, longitude, accuracy, speed, heading, recordedAt, address }, nearest: { stopId, kind, name, distanceKm } \| null }` | A rep sent a fix (broadcast to watchers; the sending rep does **not** receive its own echo) |
| `tracking-status-update` | `{ beatPlanId, userId, status: 'ACTIVE'\|'PAUSED'\|'COMPLETED', summary?, reason? }` | Start / pause / resume / stop / sweeper |
| `tracking-force-stopped` | `{ beatPlanId, userId, sessionId, reason, summary }` | The session was closed server-side (not by the rep's own `stop-tracking`) — see reasons below |
| `tracking-error` | `{ code, message }` | A handler threw (also reflected in the failing ack) |
| `auth-expired` | `{}` | Access token expired mid-session — refresh + reconnect |
| `server-shutting-down` | `{}` | Graceful server shutdown; reconnect shortly |

### `reason` values

`tracking-force-stopped.reason` is one of:

| `reason` | Meaning |
|---|---|
| `beat_plan_completed` | Every stop was visited/skipped, so the plan auto-completed (incl. via the **skip button** finishing the last stop). |
| `force_completed` | A manager force-completed the plan. |
| `attendance_checkout` | **The rep checked out for the day** → their active plan's remaining stops were auto-skipped, the plan completed, and tracking closed. |
| `stale_timeout` | The stale-session sweeper auto-completed a session that stopped pinging. |

`tracking-status-update.reason` (when present) is `beat_plan_started` (plan started) or `stale` (sweeper auto-paused an idle session). Pause/resume/stop driven by the rep carry no `reason`.

> Clients should treat **any** `tracking-force-stopped` as "this session is over" and stop the GPS stream. The `reason` is only for display (e.g. "Auto-closed on checkout").

---

## Error codes

| Code | Meaning |
|---|---|
| `BEAT_PLAN_NOT_ASSIGNED` | You're not an assignee of this beat plan |
| `NO_ACTIVE_SESSION` | No open session for this beat plan/user |
| `SESSION_PAUSED` | Resume before sending live locations |
| `RATE_LIMITED` | Live ping rate exceeded — back off |
| `BATCH_TOO_LARGE` | Batch over `TRACKING_BATCH_MAX` |
| `AUTH_EXPIRED` | Token expired; refresh + reconnect |
| `VALIDATION_ERROR` | Malformed payload |
| `NOT_FOUND` / `FORBIDDEN` | Beat plan missing / not visible to you |
| `INTERNAL_ERROR` | Unexpected server error |

---

## Resilience — client responsibilities

The backend is built to survive flaky mobile networks and multiple server
instances. The client should cooperate:

- **Outbox + acks.** Hold each fix in a local queue with a `clientPingId`; only
  remove it after `{ ok: true }`. On reconnect, flush the queue via
  `update-location-batch` — duplicates are de-duped server-side, so over-sending
  is safe.
- **Throttle live pings** to stay under the rate limit (default **5/s** sustained,
  burst **20**). A `RATE_LIMITED` ack means slow down (and/or batch).
- **`auth-expired`** → call `POST /api/v1/auth/refresh`, then reconnect with the
  new token. (A proactive timer also disconnects right at token expiry.)
- **Brief drops** (tunnel, signal loss) are handled automatically by connection-
  state recovery — rooms and missed broadcasts restore without a full re-auth.
- **Idle sessions** are auto-**paused** after `TRACKING_STALE_MINUTES` (default 10)
  and auto-**completed** after `TRACKING_STALE_COMPLETE_MINUTES` (default 60) if no
  pings arrive — watchers get `tracking-status-update` / `tracking-force-stopped`.
  Send `resume-tracking` (or a fresh `start-tracking`) if a rep comes back.

---

## REST companions (read / management)

Writes are socket-only; these are for setup and history.

- `…/beat-plans` — create / assign / start / visit / **skip** / optimize-route /
  force-complete / stats (see `beat-plans` tag in `/openapi.json`).
  - `POST /api/v1/beat-plans/:id/visit` `{ stopId, latitude?, longitude? }` — mark a stop visited.
  - `POST /api/v1/beat-plans/:id/skip` `{ stopId, latitude?, longitude? }` — mark a stop skipped
    (the **skip button**). Both need `beat-plans:visit`. Finishing the last pending stop completes
    the plan and emits `tracking-force-stopped` (`reason: 'beat_plan_completed'`).
- `GET /api/v1/tracking/active` — live sessions visible to the caller.
- `GET /api/v1/tracking/:beatPlanId` — active session for a plan.
- `GET /api/v1/tracking/:beatPlanId/current-location`
- `GET /api/v1/tracking/:beatPlanId/history`
- `GET /api/v1/tracking/sessions/:sessionId/breadcrumbs` — paginated trail.
- `GET /api/v1/tracking/sessions/:sessionId/summary`
- `GET /api/v1/tracking/completed` — completed-session history.

Permissions: `live-tracking:view` (active + current) and
`live-tracking:view-history` (completed, breadcrumbs, summary);
`beat-plans:*` for the management actions.

---

## Server config knobs (env)

| Var | Default | Effect |
|---|---|---|
| `TRACKING_STALE_MINUTES` | 10 | Idle → auto-pause |
| `TRACKING_STALE_COMPLETE_MINUTES` | 60 | Idle → auto-complete |
| `TRACKING_PING_RATE_PER_SEC` | 5 | Live-ping sustained rate |
| `TRACKING_PING_BURST` | 20 | Live-ping burst allowance |
| `TRACKING_BATCH_MAX` | 500 | Max pings per batch |
| `TRACKING_RETENTION_DAYS` | 30 | Breadcrumb prune age (summaries kept) |
| `TRACKING_RECOVERY_MS` | 120000 | Connection-state-recovery window |
