# Expense Claims API — Mobile Integration Spec

**For:** SalesSphere backend team
**From:** SalesSphere mobile app team
**Goal:** Build a new `expense-claims` resource so we can wire the mobile
expenses feature (currently in-memory mock at `lib/features/expenses/`) to a
live backend.

The mobile screens — list, add, and detail/edit — are already built and
working on hardcoded mock data. There is **no API, DTO, repository, or
persistence** on our side yet. We're blocked on this resource. The endpoint
path `/expense-claims` is already reserved in our client
(`Endpoints.expenseClaims`).

Please follow the **same conventions as the existing `/leaves` and `/notes`
endpoints** — the mobile client already assumes them, so matching them means
zero surprises on our side.

---

## Conventions (same as every other authenticated mobile endpoint)

- **Base URL:** `{apiBaseUrl}/api/v1`
- **Auth:** Bearer token + `x-client-type: mobile`, same session the app already
  sends for leaves / notes / attendance. Mobile is CSRF-exempt (handled
  globally) — no `x-csrf-token` needed.
- **Response envelope:** every response is wrapped as
  `{ "success": true, "data": <payload> }`. The client hard-rejects a
  missing or non-boolean `success`. Errors come back as
  `{ "success": false, "error": { code, message } }` with a 4xx/5xx status.
- **List pagination:** cursor envelope under `data` →
  `{ "items": [...], "hasMore": bool, "nextCursor": string|null }`. Query
  params `limit` (default 10, max 200) and `cursor`. Identical to `GET /notes`.
- **"My" scoping:** the field rep only ever sees their own claims. Resolve the
  employee from the session — never trust a client-supplied employee id.
- **Server owns identity + time:** the server sets `id`, `status`,
  `rejectionReason`, `createdAt`, and the employee id. The client never sends
  these. Stop any client-side ID generation on our side once this ships.
- **Wire casing:** `status` and `category` are **uppercase** enums (see below),
  matching the leaves `LeaveCategory` / status convention.

---

## The claim lifecycle (matches the current mobile UX)

1. A rep submits a claim via `POST`. The server **forces status to `PENDING`**
   regardless of anything the client sends.
2. While `PENDING`, the rep may edit the claim via `PATCH`. Once the claim is
   `APPROVED` or `REJECTED`, edits must be rejected (4xx) — the mobile detail
   page already opens read-only in those states, but the server is the
   authority.
3. An approver (web side) moves `PENDING → APPROVED | REJECTED`. A rejection
   must carry a `rejectionReason`. Mobile reads these fields back read-only.

This is the same approval shape as `Leave` and `TourPlan`.

---

## Endpoints

### 1. List my claims — `GET /api/v1/expense-claims/my-requests`

Paginated list of the **caller's own** claims, newest first by `createdAt`.

Query params:

| param    | type   | required | notes                        |
|----------|--------|----------|------------------------------|
| `limit`  | number | ❌       | default 10, max 200          |
| `cursor` | string | ❌       | opaque cursor from `nextCursor` |

Response `data`:

```json
{
  "items": [ /* claim objects, see schema below */ ],
  "hasMore": true,
  "nextCursor": "eyJ..."
}
```

### 2. Create a claim — `POST /api/v1/expense-claims`

Returns `201` with the created claim. Status forced to `PENDING`; employee
resolved from session.

Writable body:

| field         | type        | required | notes                                   |
|---------------|-------------|----------|-----------------------------------------|
| `title`       | string      | ✅       | short label                             |
| `amount`      | number      | ✅       | NPR, raw number (e.g. `850`, `1240.5`). Must be `> 0` |
| `date`        | ISO date    | ✅       | day the expense was incurred (date-only) |
| `category`    | enum string | ✅       | uppercase enum — see below              |
| `description` | string      | ❌       | free text; default `""`                 |
| `partyId`     | string\|null| ❌       | optional party link — **see open question 1** |

### 3. Update a claim — `PATCH /api/v1/expense-claims/:id`

Partial update, **PENDING-only**. Returns the updated claim. Must 4xx if the
claim is already `APPROVED` / `REJECTED`. Same writable shape as create.

### 4. Receipt images (optional — see open question 2)

Slot-based image upsert, **identical contract to `/notes/:id/images`**:

- **`GET /api/v1/expense-claims/:id/images`** — list slots, ordered by slot.
- **`POST /api/v1/expense-claims/:id/images`** — `multipart/form-data` with
  `imageNumber` (form field, **streamed before** the file part) + `image` file.
  JPEG/PNG only via Cloudinary. Re-posting the same slot replaces it.
  **Max 2 slots** (receipts).
- **`DELETE /api/v1/expense-claims/:id/images/:slot`** — remove one slot.

---

## Claim schema (read model returned by all endpoints)

| field             | type           | notes                                          |
|-------------------|----------------|------------------------------------------------|
| `id`              | string         | server-assigned                                |
| `title`           | string         | required                                       |
| `amount`          | number         | NPR raw number; the app formats with a `Rs` prefix |
| `date`            | ISO date       | date-only, UTC-midnight of the org-TZ day (same as leaves `startDate`) |
| `category`        | enum string    | uppercase — see values below                   |
| `status`          | enum string    | `PENDING \| APPROVED \| REJECTED`              |
| `description`     | string         | optional, default `""`                         |
| `rejectionReason` | string \| null | only set when `status == REJECTED`             |
| `partyId`         | string \| null | optional party FK — see open question 1        |
| `createdAt`       | ISO datetime   | full timestamp; drives list ordering           |

### `category` enum values

Map these exactly — the mobile client maps wire value → Dart enum by string:

```
TRAVEL | MEALS | ACCOMMODATION | FUEL | SUPPLIES | COMMUNICATION | OTHER
```

### Date / timezone handling

Match the leaves convention: store `date` as UTC-midnight of the organization's
timezone day so the calendar Y/M/D never shifts across a device timezone
boundary. The client rebuilds it at local midnight from the wire value.

---

## Open questions — please confirm before building

1. **Party link in v1?** The mobile add screen has an optional party picker
   (currently mock parties). Should `partyId` be a real FK now — and to which
   entity (`customers`?), validated against the caller's org — or should we drop
   it from the body for v1 and add it later? If kept, the read model should
   return enough to render a label (either an embedded `party { id, name }`
   object or we resolve the name from the parties feature — your call).
2. **Receipts in v1?** The UI supports up to 2 gallery images. Ship the
   slot-based image endpoints now (recommended — reuse the `/notes` image
   machinery), or defer and we hide the picker?
3. **Amount validation:** max value, allowed decimal places, currency (we assume
   NPR-only)?
4. **Categories — fixed enum or catalogue?** Are these 7 categories final as a
   hardcoded enum, or should the backend own a categories catalogue (like
   `customer-types`) that we fetch instead?
5. **Approver flow:** confirm the web-side `PENDING → APPROVED/REJECTED`
   transition (with `rejectionReason` on reject) exists or is planned, so the
   status / rejection fields are actually drivable.

---

## What we'll do on our side once confirmed

After you confirm the field names, enum casing, and questions 1–5, we'll wire:

- `lib/features/expenses/data/expenses_api.dart` (typed by the wire DTO)
- `ExpenseClaimDto` + `fromJson` / writable `toJson`
- `ExpenseRepository` (abstract) + `ExpenseRepositoryImpl` (DTO ↔ domain mapping)
- usecases for create / update, and reactive list / by-id providers

No changes needed to our existing `ExpenseClaim` domain model — it's already
decoupled from the wire shape.
