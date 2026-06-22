# Backend Spec — Mobile **Orders** & **Products (Catalog)**

**To:** Backend team (SalesSphereERP-Backend — Bun + Express 5 + Prisma + Postgres)
**From:** Mobile (SalesSphereERP-App — Flutter, Android-first, field-ops)
**Goal:** Stand up the real API for the mobile app's two currently-mock features: the **Product Catalog** and the **Order builder / Order history**. The mobile screens are built and behaviour-complete against mock data; this document is the exact data + behaviour contract they need.

---

## 0. Read this first — these modules already (mostly) exist

We inspected `prisma/schema.prisma` and `src/modules/`. **Do not build greenfield.** The mobile features map onto existing modules:

| Mobile concept | Existing backend model / module |
|---|---|
| **Product** (catalog item) | `Product` (`src/modules/products`) |
| **Category** | `ProductCategory` + `ProductCategoryAssignment` (`src/modules/product-categories`) |
| **Order** (`kind = order`) | `Invoice` + `InvoiceItem` (`src/modules/invoices`) |
| **Estimate** (`kind = estimate`) | `Estimate` + `EstimateItem` (`src/modules/estimates`) |
| **Party** (order customer) | `Customer` (`src/modules/customers`) |
| **Convert estimate → order** | existing estimate→invoice convert path |

So this work is **extend + expose mobile-facing fields/filters/endpoints + reconcile a handful of divergences** — not new tables (except possibly one decision in §1). Treat the rest of this doc as: "here is what the mobile UI renders and does; make the existing modules serve it."

**Mobile constraints to keep in mind**
- **No accounting on mobile.** The app never posts vouchers, never touches ledgers, never sees `DRAFT/POSTED/CANCELLED`. A field rep creates an order/estimate and tracks its *fulfilment*; accounting/posting stays web-only.
- **Offline-first.** The app caches everything in local SQLite and replays writes. Endpoints must be **idempotent-friendly** (accept a client-supplied `clientRequestId`/idempotency key on create) and return the full created/updated resource so the cache can reconcile.
- **Auth:** Bearer JWT + `x-client-type: mobile` (already CSRF-exempt). Reuse existing `authGuard` + `tenantScope`. All data is `organizationId`-scoped.
- **Money** is `Decimal(18,2)` serialised as **strings** ("1250.00"); **quantities** the mobile uses are **whole units** (int) though the schema stores `Decimal(18,3)` — that's fine, send "5.000". Currency is **NPR**.

---

## 1. Decisions we need you to make (the real forks)

These change the shape of the API. Please confirm before building. Our recommendation is given.

1. **Is a mobile "Order" an accounting `Invoice`, or a new `SalesOrder`?**
   The mobile "order" is a *field sales order* with a **fulfilment** lifecycle (Pending → In Progress → In Transit → Completed / Rejected). That is orthogonal to the accounting `InvoiceStatus` (DRAFT/POSTED/CANCELLED). Two options:
   - **(A) Reuse `Invoice`** — add a `fulfillmentStatus` enum + `expectedDeliveryDate` + order-level discount to `Invoice`. Mobile only ever reads/writes the non-accounting fields; the row sits at `status = DRAFT` until web posts it. Least new code.
   - **(B) New `SalesOrder` model** — a field-ops order that later *converts to* an `Invoice` (exactly like `Estimate → Invoice`). Cleaner separation; keeps the accounting `Invoice` table free of fulfilment concerns. More work.
   - **Our recommendation: (A) reuse `Invoice`** for v1, because estimate→invoice conversion, numbering, customer links, and totals already exist. Revisit (B) only if accounting objects to fulfilment fields living on `Invoice`.
   *(The rest of this doc is written assuming (A). If you pick (B), the field contract is identical — just on a new table.)*

2. **Fulfilment status enum.** Add `fulfillmentStatus` (default `PENDING`) to the order model with values: `PENDING | IN_PROGRESS | IN_TRANSIT | COMPLETED | REJECTED`. This is what the mobile history badge + status filter use. Confirm the value names.

3. **Order-level discount.** The mobile applies a single **overall discount %** to the whole order *before* tax. The schema has no document-level discount (only a per-line absolute `discount`). Add `overallDiscountPercent Decimal(5,2) @default(0)` (or an amount) to the order + estimate models. See §B.5 for the exact math.

4. **Per-line "list price + discount %" persistence.** Mobile shows each line's *list price* (struck through) and an implied *discount %*, but the source of truth it stores is the **net unit price** (`basePrice`). Do you want to persist `listPrice` + `discountPercent` per line (so the **PDF/print** can show the markdown), or only store the net `rate`? *Recommendation: persist `listPrice` (optional) per line item so invoices can print the discount; computation still uses net `rate`.*

5. **Stock-on-hand exposure.** The catalog needs an **integer available quantity per product** (it caps order quantities and renders "In stock / Only N left / Out of stock"). Today `Product` only stores `openingBalance`; live balance is flagged as future Inv-2/Inv-3 work and is **not exposed**. We need a computed **`stockOnHand`** on the product list/detail DTO (sum of opening + signed `StockMovement`, across godowns, or a single default godown). If live inventory isn't ready, expose a best-effort number (e.g. `openingBalance`) and a `trackInventory` flag so mobile can soften the UI. Confirm what you can give us.

6. **Document numbering / prefix.** Backend issues `INV-82-0001` / `EST-82-0001` (BS fiscal-year code). Mobile currently mocks `ORD-2026-0001` / `EST-2026-0001` (AD year). **Mobile will display whatever number the server returns** — server is the source of truth. Just confirm the order prefix you want surfaced to field reps (`INV-` vs a sales-order `ORD-`). Numbers must be **server-generated** (mobile will stop generating them).

7. **Delivery date.** Orders carry an **expected delivery date** (required to create an order; absent on estimates). `Invoice.dueDate` is a *payment* due date — semantically different. Add `expectedDeliveryDate DateTime?`.

8. **PDF / print.** Both the order detail and history have a "Download PDF" action. We need `GET /invoices/:id/pdf` and `GET /estimates/:id/pdf` (or a shared print endpoint) returning a PDF (or a short-lived signed URL). Confirm format.

9. **"From" (selling org) block.** Order detail renders a *From* card: org **name, PAN/VAT, phone, address**. Confirm the endpoint that returns the authenticated org's print profile (org + issuing branch). If one exists (`GET /organizations/me`?), point us at it.

---

## 2. Cross-cutting conventions (please confirm these match your house style)

- **Paths:** `/api/v1/...`, kebab-case, standard CRUD + state verbs (`/:id/convert`, `/:id/status`).
- **Pagination:** cursor-based — `?limit=&cursor=` → `{ items, hasMore, nextCursor }`. Mobile lists are modest; default `limit=100`.
- **Envelope:** `{ success, data }` / `{ success, error: { message, code, status, details? } }` (existing middleware).
- **Tenancy:** every read/write filtered by `organizationId` from the session; never trust a client-supplied org.
- **Money:** `Decimal(18,2)` as strings; **server computes all totals/tax — never trust client-sent totals.**
- **Dates:** mobile sends/reads **AD** ISO-8601 (`dateAD`, `expectedDeliveryDate`, `createdAt`). Backend derives `dateBS`. Mobile does not deal in BS.
- **Soft-delete:** `status = INACTIVE` for catalog; hard-delete only where noted.
- **Idempotency:** accept optional `clientRequestId` on POST creates; if replayed, return the original resource (offline replay safety).

---

# Part A — Product Catalog (`products` + `product-categories`)

## A.1 What the mobile UI does

- **Catalog page:** 2-column product grid. Top: search box + a horizontal **category chip row** (leading "All" chip opens a category grid; the rest filter in place). Each card shows: image (or colour-coded initials fallback), **name**, **unit price** (NPR), a **stock line** (green "In stock · N" / amber "Only N left" at ≤5 / red "Out of stock" at 0), and an **add-to-cart stepper** that cannot exceed remaining stock. Pull-to-refresh. Empty state when a search/category yields nothing.
- **Category selection page:** grid of category tiles, each showing category **name** + **item count** ("3 items" / "No items"), plus a leading "All Products" tile. Searchable. Picking one filters the catalog.
- **Search** is by product **name OR SKU** (case-insensitive substring).
- The cart is purely client-side; "checkout" = the picked products are merged into the **order draft** (see Part B). The catalog itself never writes to the server.

## A.2 Data contract the mobile needs

**Product (list item / detail):**
```
id: string
name: string
sku: string | null
categoryId: string | null        // see GAP A.3.3 — mobile treats a product as having ONE primary category
price: string (Decimal)          // unit selling price  → maps to Product.defaultSaleRate
stockOnHand: int                 // available whole units → see GAP A.3.1
imageUrl: string | null          // see GAP A.3.4
isActive: boolean                // → status == ACTIVE
```

**Category:**
```
id: string
name: string
itemCount: int                   // # of ACTIVE products in this category → see GAP A.3.2
```

## A.3 Mapping & GAPS

| Mobile field | Backend today | Action |
|---|---|---|
| `price` | `Product.defaultSaleRate` (`Decimal?`) | Map directly. Decide behaviour when null (mobile needs a number — default `"0"` or require it). |
| `name`, `sku`, `isActive` | `name`, `sku`, `status` | Map directly (`status==ACTIVE → isActive`). |
| **`stockOnHand`** | **Not exposed** (only `openingBalance`; live balance is Inv-2/Inv-3) | **GAP A.3.1** — expose a computed integer available qty on the product DTO. Plus a `trackInventory` flag. |
| **`itemCount`** per category | Not stored | **GAP A.3.2** — return a count of ACTIVE products per category (`_count` on the assignment join). |
| **`categoryId`** (single) | **Many-to-many** (`ProductCategoryAssignment`) | **GAP A.3.3** — mobile filters by exactly one category and shows one chip per product. Either (a) add a `categoryId` filter to the product **list** query (filter products whose assignments include it), and pick a "primary" category for display; or (b) tell us to switch the mobile to multi-category. *Recommendation: add `?categoryId=` list filter; for display, return the product's category ids array and let mobile show the first.* **Note:** the product **list** query currently filters only by `status` + `search` — it does **not** filter by category yet. This must be added. |
| **`imageUrl`** | **`Product` has no image field** (only `ProductCategory.imageUrl` exists) | **GAP A.3.4** — mobile gracefully falls back to initials, so this is optional, but if you want product photos add `imageUrl`/`imagePublicId` to `Product` (or a gallery like `CustomerImage`). Confirm. |
| `search` (name/SKU) | Product list already searches name/sku/alias ✓ | Reuse as-is. |

## A.4 Endpoints needed (catalog)

```
GET /api/v1/products
    ?search=        // name | sku (alias ok), case-insensitive contains
    &categoryId=    // NEW filter (GAP A.3.3)
    &status=ACTIVE  // default ACTIVE only
    &limit=&cursor=
  → { items: Product[], hasMore, nextCursor }
  Product DTO must include: stockOnHand (int), price, imageUrl, categoryId(s), isActive.

GET /api/v1/product-categories
    ?search=&limit=&cursor=
  → categories each with itemCount (ACTIVE product count).

GET /api/v1/products/:id     → single Product (same DTO).   // for cold-open / deep-link
```
*(Create/update/delete of products & categories is web-admin work and already exists — mobile only reads the catalog.)*

---

# Part B — Orders & Estimates (`invoices` + `estimates`)

The mobile has **one** model `Order` with `kind ∈ {order, estimate}`. It maps to two backend tables: `kind=order → Invoice`, `kind=estimate → Estimate`. The two share the same builder UI and pricing math.

## B.1 What the mobile UI does

**Order builder (create):**
1. **Party** — searchable picker over customers (search by name / owner / address). Selecting a party **auto-fills a read-only "Owner name"** from `customer.ownerName`.
2. **Expected delivery date** — date picker, today-or-later. **Required for an order; not used for an estimate.**
3. **Items** — "Add Item" jumps to the catalog; chosen products become editable line rows. Each line:
   - thumbnail, name, **list price** (struck through when discounted),
   - **quantity** stepper (≥1, capped to the product's `stockOnHand`; typing over stock snaps back with a warning),
   - **Unit Price** field (editable net price) **and** **Discount %** field — *these are two views of the same number*: editing one updates the other. Discount % = markdown of unit price off list price.
   - live **subtotal** = quantity × unit price, and a "Save Rs X" hint.
4. **Summary** — an **overall discount %** field (applies to the whole order), a **Tax** picker (single selection: **No Tax** or **VAT 13%**), then a breakdown: Subtotal → (− overall discount) → Taxable amount → VAT → **Total**, plus item/unit counts and total savings.
5. Two actions: **Create Order** (requires party + ≥1 item + delivery date) or **Create Estimate** (requires party + ≥1 item).

**Order history:** two tabs — **Orders** and **Estimates** — with per-tab counts. Search by **document number or party name** (both tabs). Orders tab additionally has a **status filter** (All / Pending / In Progress / In Transit / Completed / Rejected). Each card: number, fulfilment status badge (orders only), party, amount (grand total), created date, delivery date (orders only), and **Download PDF** / **View Details**. Estimates have a **delete** affordance instead of a status badge.

**Order/Estimate detail (read-only):** summary header (number, fulfilment status, created + expected-delivery dates); **From** card (selling org); **Bill To** card (party: owner, PAN/VAT, phone, address); **Items** (per line: qty, unit price, discount %, amount, struck list price when discounted); **Summary** (subtotal, overall discount, taxable, VAT, total, savings). Order action: **Download PDF**. Estimate actions: **Convert to Order** (asks for a delivery date) + **Download PDF**.

> Mobile is **read-only on fulfilment status** for now — it displays the badge but has no UI to advance it (status is set server-side / by web). If you want the app to advance status later, expose `PATCH /:id/status` and we'll add the control.

## B.2 Data contract the mobile needs

**Order / Estimate (read):**
```
id: string
number: string                       // server-issued (INV-…/EST-…); display only
kind: "order" | "estimate"           // = which table; mobile keys off this
fulfillmentStatus: enum              // orders only: PENDING|IN_PROGRESS|IN_TRANSIT|COMPLETED|REJECTED
party: {                             // from Customer
  id, name, ownerName, address, panVat, phone
}
expectedDeliveryDate: date | null    // orders only
overallDiscountPercent: string(Decimal)
tax: { rate: number }                // single order-level rate (0 or 13); label derived client-side
items: LineItem[]
subtotal, overallDiscountAmount, taxableBase, taxAmount, grandTotal: string(Decimal)  // server-computed
createdAt: datetime
```

**LineItem (read):**
```
productId: string | null
name: string                         // snapshot (= product name at add time)
imageUrl: string | null
listPrice: string(Decimal)           // reference price (for struck-through + discount %)
unitPrice: string(Decimal)           // net selling price  (= backend rate)
quantity: int
discountPercent: string(Decimal)     // derived: markdown of unitPrice vs listPrice
lineSubtotal: string(Decimal)        // quantity * unitPrice
```

**Create payload (mobile → server):**
```
POST /api/v1/invoices            (kind=order)   |   POST /api/v1/estimates  (kind=estimate)
{
  clientRequestId: string,             // idempotency (offline replay)
  customerId: string,
  expectedDeliveryDate: date,          // required for order; omit for estimate
  overallDiscountPercent: number,      // 0..100
  taxRate: number,                     // 0 or 13 (single order-level rate)
  items: [
    { productId, quantity, unitPrice, listPrice? }   // server computes line + order totals
  ]
}
→ returns the full created resource (B.2 read shape), incl. server-issued number + totals.
```
Server **ignores any client-sent totals** and recomputes per §B.5.

## B.3 Mapping & GAPS

| Mobile field / behaviour | Backend today | Action |
|---|---|---|
| `party` | `Invoice.customerId → Customer` (has name, ownerName, panNo, phone, address) | Map directly. PAN/VAT = `Customer.panNo`. |
| **`fulfillmentStatus`** (Pending/In Progress/In Transit/Completed/Rejected) | **Missing.** `InvoiceStatus` is accounting-only (DRAFT/POSTED/CANCELLED) | **GAP B.3.1** — add `fulfillmentStatus` enum (§1.2). Independent of accounting status. |
| **`expectedDeliveryDate`** | **Missing** (`dueDate` is a payment date) | **GAP B.3.2** — add `expectedDeliveryDate DateTime?`. Required at order-create. |
| **`overallDiscountPercent`** | **Missing** (only per-line absolute `discount`) | **GAP B.3.3** — add doc-level discount field + fold into totals (§B.5). |
| **Order-level single `tax`** | Per-line `vatRate` | **GAP B.3.4** — accept one `taxRate`, apply to every line, **but tax the post-overall-discount base** (§B.5). |
| Per-line `unitPrice` + `listPrice` + derived `discountPercent` | `InvoiceItem.rate` (net) + absolute `discount`; **no list price** | **GAP B.3.5** — set `rate = unitPrice`, `discount = 0`; optionally persist `listPrice` per line for the PDF (§1.4). Return `discountPercent` derived from listPrice/unitPrice. |
| `quantity` (whole units, capped to stock) | `Decimal(18,3)` | Accept int, store as decimal. **Optionally** validate `quantity ≤ stockOnHand` when `trackInventory` (confirm — see §B.6). |
| `number` server-issued | `INV-…`/`EST-…` generators exist ✓ | Keep server-side; return it. Mobile stops generating numbers. |
| **History: two tabs + counts** | Separate `invoices` / `estimates` lists ✓ | Mobile calls both; needs counts (use `hasMore=false` page or a count) — confirm cheapest way. |
| **History search** (number OR party name) | Confirm invoice/estimate list supports it | **GAP B.3.6** — add `?search=` matching `invoiceNo`/`estimateNo` OR `customer.name` (insensitive). |
| **Orders status filter** | n/a (no fulfilment status yet) | **GAP B.3.7** — `?fulfillmentStatus=` filter on the invoice list. |
| **Convert estimate → order** (+ delivery date) | estimate→invoice convert exists ✓ | Extend convert to accept `expectedDeliveryDate` and set `fulfillmentStatus=PENDING`. Backend keeps the estimate as `ACCEPTED` + linked (mobile will hide/disable accepted estimates — confirm you return the link). |
| **Delete estimate** | Confirm estimate delete (pre-sent/DRAFT) | Allow `DELETE /estimates/:id` for not-yet-accepted estimates; hard or soft, your call. |
| **PDF** | Not present | **GAP B.3.8** — add PDF endpoints (§1.8). |
| **"From" org block** | org/branch profile | Point mobile at the org print-profile endpoint (§1.9). |

## B.4 Endpoints needed (orders/estimates)

```
# Orders (Invoices)
GET    /api/v1/invoices?search=&fulfillmentStatus=&customerId=&limit=&cursor=
GET    /api/v1/invoices/:id
POST   /api/v1/invoices                 # create (B.2 payload) → returns full resource
GET    /api/v1/invoices/:id/pdf
PATCH  /api/v1/invoices/:id/status      # OPTIONAL (only if mobile advances fulfilment later)

# Estimates
GET    /api/v1/estimates?search=&customerId=&limit=&cursor=
GET    /api/v1/estimates/:id
POST   /api/v1/estimates                # create (B.2 payload, no delivery date)
POST   /api/v1/estimates/:id/convert    # body: { expectedDeliveryDate } → creates order, returns it
DELETE /api/v1/estimates/:id            # delete a not-yet-accepted estimate
GET    /api/v1/estimates/:id/pdf

# Supporting (confirm existing)
GET    /api/v1/customers?search=        # party picker (name/owner/address)
GET    /api/v1/organizations/me (or similar)  # "From" print profile
```

## B.5 Canonical pricing math — **must match the mobile exactly**

The mobile computes totals as below. The server must produce the **same** numbers (it is the source of truth; mobile only displays). Order of operations matters — **overall discount is applied before tax.**

```
Per line:
  lineSubtotal      = quantity * unitPrice            // unitPrice is the NET price
  (discountPercent  = max(0, (1 - unitPrice/listPrice) * 100))   // display only
  (lineSavings      = max(0, (listPrice - unitPrice) * quantity)) // display only

Order:
  itemsSubtotal        = Σ lineSubtotal
  overallDiscountAmount = itemsSubtotal * overallDiscountPercent / 100
  taxableBase          = itemsSubtotal - overallDiscountAmount
  taxAmount            = taxableBase * taxRate / 100
  grandTotal           = taxableBase + taxAmount
```

Mapping onto the existing `Invoice/InvoiceItem` cached totals:
- Set each `InvoiceItem.rate = unitPrice`, `discount = 0`, so `item.taxable = quantity * unitPrice = lineSubtotal`.
- `Invoice.subtotal` must equal **`taxableBase`** (i.e. after the overall discount) **or** keep `subtotal = itemsSubtotal` and store `overallDiscountAmount` separately — **your choice, but `vatAmount` must be computed on `taxableBase`, not on `itemsSubtotal`.** The simplest correct approach: store `overallDiscountPercent`, compute `taxableBase`, set `vatAmount = taxableBase * taxRate/100`, `totalAmount = taxableBase + vatAmount`.
- Rounding: round half-up to 2 dp at each money step (confirm your rounding convention so mobile matches).

## B.6 Validation rules (server-enforced)

- **Order create:** `customerId` required & belongs to org; ≥1 item; **`expectedDeliveryDate` required** and ≥ today; each item `quantity ≥ 1`, `unitPrice ≥ 0`; `overallDiscountPercent ∈ [0,100]`; `taxRate ∈ {0,13}` (or your configured set).
- **Estimate create:** same, **minus** the delivery-date requirement.
- **Stock (confirm):** when `trackInventory`, optionally reject `quantity > stockOnHand` (mobile already caps client-side; server should be authoritative). Say whether you want a hard reject or just a warning.
- **Numbers/totals** always server-computed; reject/ignore client totals.

## B.7 Status & lifecycle summary

- **Order (`Invoice`)**: `fulfillmentStatus` starts `PENDING` on create. Accounting `status` stays `DRAFT` (mobile never sees it). Web handles POST/cancel. Fulfilment transitions are web/back-office for now (mobile read-only).
- **Estimate**: created in its normal editable state; **Convert** creates an order (Invoice) with a delivery date + `fulfillmentStatus=PENDING`, marks the estimate accepted/linked. Estimates can be deleted before acceptance.

---

## 3. Suggested delivery order (so mobile can integrate incrementally)

1. **Catalog reads** — `GET /products` with `stockOnHand`, `categoryId` filter, image; `GET /product-categories` with `itemCount`. *(Unblocks the whole Catalog tab + the order builder's item picker.)*
2. **Order/estimate create + read + list** with the new fields (`fulfillmentStatus`, `expectedDeliveryDate`, `overallDiscountPercent`, single `taxRate`) and the §B.5 math.
3. **History search + status filter**, **convert**, **delete estimate**.
4. **PDF** endpoints + **org print profile**.

Please reply on the **§1 decisions** first — those gate the schema migration. Everything else is additive.
