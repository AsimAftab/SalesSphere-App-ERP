# Expense Claims API — Backend Contract (response to the mobile integration spec)

**For:** SalesSphere mobile app team
**From:** SalesSphere backend team
**Re:** `docs/implementation/expense-claims-mobile-integration.md`
**Status:** ✅ Shipped. `/expense-claims` + `/expense-claim-categories` are live and follow the
`/leaves` + `/notes` conventions you asked for.

This document answers your 5 open questions and pins the exact wire contract so you can wire
`expenses_api.dart`, the DTO, the repository, and the providers.

---

## TL;DR of the decisions

| # | Your question | Answer |
|---|---------------|--------|
| 1 | Party link in v1? | **Yes — optional FK to a Customer.** Send `partyId` (a customer id). The read model returns an embedded `party { id, companyName }` for the label. |
| 2 | Receipts in v1? | **Yes — shipped.** Slot-based image endpoints, identical contract to `/notes/:id/images`. Max **2** slots. |
| 3 | Amount validation | **NPR only**, raw number, must be `> 0`, max `9,999,999.99`, **2 decimal places** (DB scale 2 — extra precision is rounded). |
| 4 | Categories — enum or catalogue? | **Catalogue.** Categories are an **org-managed list**, exactly like `customer-types`/party types. Fetch them from `GET /expense-claim-categories`. The claim carries the category **name string** (the server resolves/creates the catalogue row). See "Category migration" below — this changes your Dart enum into a fetched list. |
| 5 | Approver flow | **Exists.** Web approvers move `PENDING → APPROVED/REJECTED` via `POST /expense-claims/:id/status` (mirrors leaves: role-hierarchy, no self-approval, rejection requires a reason). Mobile reads `status` / `rejectionReason` read-only. |

---

## Conventions (unchanged from leaves / notes / attendance)

- **Base URL:** `{apiBaseUrl}/api/v1`
- **Auth:** Bearer token + `x-client-type: mobile` — the same session you already send for leaves/notes.
  Mobile is CSRF-exempt globally (no `x-csrf-token` needed).
- **Envelope:** `{ "success": true, "data": <payload> }`; errors are
  `{ "success": false, "error": { code, message } }` with a 4xx/5xx status.
- **List pagination:** cursor envelope under `data` → `{ "items": [...], "hasMore": bool, "nextCursor": string|null }`.
  Query params `limit` (default 100, max 200) and `cursor`. Identical to `GET /notes`.
- **Server owns identity + time + status:** the server sets `id`, `status` (forced `PENDING` on create),
  `rejectionReason`, `reviewedBy`/`reviewedAt`, `createdAt`, and the employee id (resolved from the session).
  Stop any client-side id generation.
- **Wire casing:** `status` is an **uppercase** enum (`PENDING | APPROVED | REJECTED`). `category` is a
  **free string** (the catalogue row name), no longer an enum.

---

## Endpoints

### 1. List my claims — `GET /api/v1/expense-claims/my-requests`
Caller's own claims, newest first by `createdAt`. Query: `limit`, `cursor` (+ optional `status`, `category`,
`month`, `dateFrom`, `dateTo`, `search`). Response `data` = `{ items: ExpenseClaim[], hasMore, nextCursor }`.
List items are **lean**: `images` is an array of **URL strings** (call `GET /:id` for the full image records).

### 2. Get one — `GET /api/v1/expense-claims/:id`
Full record, including `images` as full objects (see schema).

### 3. Create — `POST /api/v1/expense-claims`
Returns `201` with the created claim (`status` forced to `PENDING`). Writable body:

| field         | type          | required | notes |
|---------------|---------------|----------|-------|
| `title`       | string        | ✅       | 1–200 chars |
| `amount`      | number        | ✅       | NPR raw number, `> 0`, ≤ 9,999,999.99 |
| `date`        | ISO date      | ✅       | day the expense was incurred — send `"YYYY-MM-DD"` (date-only) |
| `category`    | string        | ✅       | the category **name** (resolved to / created as a catalogue row in your org) |
| `description` | string        | ❌       | default `""` |
| `partyId`     | string\|null  | ❌       | a Customer id in your org; validated server-side (404 if foreign) |

### 4. Update — `PATCH /api/v1/expense-claims/:id`
Partial update, **PENDING-only** (4xx once `APPROVED`/`REJECTED`). Same writable fields as create, all optional.
`partyId: null` clears the party link.

### 5. Delete — `DELETE /api/v1/expense-claims/:id`
**PENDING-only**. Returns `{ id, deletedAt }`.

### 6. Receipt images — identical to `/notes/:id/images`
- `GET /api/v1/expense-claims/:id/images` — list slots, ordered by slot.
- `POST /api/v1/expense-claims/:id/images` — `multipart/form-data`: `imageNumber` (form field, **streamed
  before** the file part) + `image` file. JPEG/PNG, ≤ 5 MB, via Cloudinary. Re-posting the same slot replaces it.
  **Max 2 slots.**
- `DELETE /api/v1/expense-claims/:id/images/:imageNumber` — remove one slot (1-indexed).

### 7. Category catalogue — `GET /api/v1/expense-claim-categories`
Paginated (`limit`/`cursor`); fetch once with `limit=200` to populate the picker. Each item:
`{ id, name, claimCount, createdAt }`. (Admins manage these from the web Admin panel; reps only read.)

### (Web-only) Approve / reject — `POST /api/v1/expense-claims/:id/status`
`{ action: "APPROVED" | "REJECTED", rejectionReason? }`. Driven by web approvers. Mobile never calls this;
it just reads `status` / `rejectionReason` back.

---

## Claim schema (read model)

```jsonc
{
  "id": "clx...",
  "organizationId": "clx...",
  "employeeId": "clx...",                       // the rep
  "employee":   { "id": "clx...", "name": "Aarav Sharma", "email": "aarav@..." },
  "title": "Taxi to client site",
  "amount": 850,                                 // raw number, NPR (app prefixes "Rs")
  "date": "2026-06-16T00:00:00.000Z",           // UTC-midnight of the org-TZ day → take the date part
  "categoryId": "clx...",
  "category": "Travel",                          // resolved catalogue name (string)
  "status": "PENDING",                           // PENDING | APPROVED | REJECTED
  "description": "Round trip for the quarterly review.",
  "partyId": "clx..." ,                          // or null
  "party": { "id": "clx...", "companyName": "Himalayan Traders" },  // or null
  "rejectionReason": null,                       // string only when status == REJECTED
  "reviewedById": null,
  "reviewedBy": null,                            // { id, name, role } once reviewed
  "reviewedAt": null,                            // ISO datetime once reviewed
  "createdById": "clx...",
  "createdBy":  { "id": "clx...", "name": "Aarav Sharma", "email": "aarav@..." },
  "images": [                                    // full record: objects; list items: [ "https://..." ]
    { "id": "clx...", "expenseClaimId": "clx...", "imageUrl": "https://res.cloudinary.com/...",
      "imagePublicId": "sales-sphere/.../abc", "sortOrder": 0, "createdAt": "2026-06-16T18:30:00.000Z" }
  ],
  "createdAt": "2026-06-16T18:30:00.000Z",       // drives list ordering
  "updatedAt": "2026-06-16T18:30:00.000Z"
}
```

### Date / timezone
`date` is stored as UTC-midnight of the org's timezone day (same as leaves `startDate`). Send `"YYYY-MM-DD"`;
read the wire value and rebuild it at local midnight (take the `YYYY-MM-DD` slice).

### Status mapping
`PENDING → pending`, `APPROVED → approved`, `REJECTED → rejected` (your existing `ExpenseClaimStatus`).

---

## Category migration — the one real change on your side

Per your open question 4, categories are now a **catalogue**, not a fixed enum. Concretely:

1. **Fetch** the list from `GET /expense-claim-categories` (mirror your existing party-types / `/customer-types`
   flow: a DTO + repository method + a Riverpod provider feeding `CustomOptionPicker`, with `onBeforeOpen` to
   pre-load). Each row is `{ id, name }` (+ `claimCount`, `createdAt`).
2. **Store/send the category NAME string** on the claim (`category` field), not an enum value. The picker's
   selected value is the catalogue `name`.
3. **Icon & color:** the catalogue carries **`name` only** — there is no per-category icon/color on the wire
   (same as party types). Your current `ExpenseCategory` enum's `icon`/`accent` map can stay as a **local
   lookup keyed by the lowercased name** with a sensible default (e.g. `Icons.category_outlined` /
   `AppColors.textSecondary`) for any name not in the map. So a claim with `category: "Travel"` still renders
   the plane icon; a new admin-defined `"Per Diem"` falls back to the default. No backend change needed for icons.
4. The `expenseCategoryFromLabel` enum lookup is replaced by "find the catalogue row whose `name` matches".

Everything else you listed in "What we'll do on our side" is unchanged: `ExpenseClaimDto.fromJson` /
writable `toJson`, `ExpenseRepository` (abstract) + `Impl`, create/update usecases, reactive list / by-id
providers. The receipt upload follows your `/notes` image machinery (multipart, `imageNumber` 1..2).

---

## Quick checklist for wiring

- [ ] `expenses_api.dart`: list (`/my-requests`), getById, create, update, delete, image upload/delete,
      and `expenseCategories()` (`GET /expense-claim-categories`, `limit=200`).
- [ ] `ExpenseClaimDto.fromJson` / writable `toJson` (send `category` name + `partyId`; status read-only).
- [ ] `ExpenseClaimCategoryDto` `{ id, name }` + provider feeding the category picker.
- [ ] Category icon/color → local name-keyed lookup with a default fallback.
- [ ] Receipts via the slot endpoints (max 2), URLs read back from the claim's `images`.

Ping us if any field name or status value doesn't line up — the server is the authority and we'll keep it
matching this doc.
