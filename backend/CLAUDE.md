# Backend — API Reference

> **Authoritative map of the SPBilling backend.** If you are adding an endpoint, changing business logic, running a migration, or wiring the frontend — start here. Do not re-crawl `app/`.

**Stack:** FastAPI · SQLAlchemy 2.0 · PostgreSQL 16 (Docker) · Alembic · JWT · ReportLab · openpyxl
**URL prefix:** `/api` · **Port:** `8001` · **DB:** `postgresql+psycopg://postgres:postgres@localhost:5432/spgasbill`

---

## 1. Directory Map

```
backend/
├── app/
│   ├── config/        settings.py (env) · database.py (engine, SessionLocal, get_db)
│   ├── models/        11 files, 13 tables — ORM definitions only
│   ├── schemas/       Pydantic v2 request/response shapes per module
│   ├── services/      ALL business logic lives here (not in routers)
│   ├── routers/       Thin HTTP layer — delegates to services
│   ├── utils/         auth.py (JWT, hashing, guards), pagination.py, audit.py
│   └── main.py        FastAPI app, CORS, router registration, health endpoint
├── alembic/versions/  001_initial_schema.py
├── scripts/seed.py    Admin user + default settings + product catalog
├── requirements.txt   Pinned to Python 3.14 compatible versions
└── README.md          Setup & run commands
```

**Rule:** ORM queries ONLY in `services/`. Routers never touch the DB directly.

---

## 2. API Endpoints (all under `/api`)

### Auth · `routers/auth.py` → `services/auth_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| POST | `/api/auth/login` | Username/password → JWT | public |
| POST | `/api/auth/logout` | Client-side token drop (stateless) | any |
| GET  | `/api/auth/me` | Current user profile | any |

### Users · `routers/users.py` → `services/user_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| GET / POST | `/api/users` | List / create | **global admin** |
| GET / PUT / DELETE | `/api/users/{id}` | Detail / update / deactivate | **global admin** |

### Distributor Outlets · `routers/distributor_outlets.py` → `services/distributor_outlet_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| GET | `/api/distributor-outlets` | List/search outlets — a DO-scoped login only ever gets its own row back | any |
| GET | `/api/distributor-outlets/search` | Typeahead — same self-only restriction for DO-scoped logins | any |
| GET | `/api/distributor-outlets/{id}` | Detail — 404 if a DO-scoped login requests another DO's id | any |
| POST / PUT / DELETE | `/api/distributor-outlets[, /{id}]` | Create / update / soft-delete the DO master record | **global admin** |
| PATCH | `/api/distributor-outlets/{id}/active` | Toggle active | **global admin** |

### Customers · `routers/customers.py` → `services/customer_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| GET | `/api/customers` | Paginated list + filters | any |
| GET | `/api/customers/search?q=` | Autocomplete by name/mobile | any |
| GET | `/api/customers/{id}` | Detail | any |
| POST / PUT | `/api/customers[, /{id}]` | Create / update | staff+ |
| DELETE | `/api/customers/{id}` | Soft-delete | admin |
| POST | `/api/customers/bulk-delete` | Bulk soft-delete | admin |
| PATCH | `/api/customers/{id}/active` | Activate/deactivate | admin |
| POST | `/api/customers/import` | Bulk Excel import | staff+ |
| GET | `/api/customers/export/excel` | Export Excel | any |

### Products · `routers/products.py` → `services/product_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| POST | `/api/products/categories` | Create category | staff+ |
| PUT / DELETE | `/api/products/categories/{id}` | Edit/deactivate category | admin |
| POST | `/api/products` | Create product | staff+ |
| PUT / DELETE | `/api/products/{id}` | Edit/deactivate product | admin |
| GET  | `/api/products/variants/list` | All variants paginated | any |
| POST | `/api/products/variants` | Create variant (price, GST, stock) | staff+ |
| PUT / DELETE | `/api/products/variants/{id}` | Edit/deactivate variant | admin |

Note: the product catalog is **not** DO-scoped — it's one shared list every
DO bills against. Any staff+ login (including a DO-scoped one) can add a
new category/product/variant, and any admin login (including a DO-scoped
one) can edit or deactivate an existing entry — which means one DO's
admin can change pricing/GST that every other DO also bills against. This
is a deliberate simplicity trade-off, not an oversight.

### Bills · `routers/bills.py` → `services/billing_service.py` + `services/pdf_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| GET | `/api/bills` | List (by customer / date / status) | any |
| POST / PUT | `/api/bills[, /{id}]` | Create / edit — runs GST, empty-bottle, stock, customer-balance updates | staff+ |
| GET | `/api/bills/{id}` | Detail with items | any |
| DELETE | `/api/bills/{id}` | Hard-delete, DO-scoped (reverses balance/stock/empty, frees the bill #) | admin |
| POST | `/api/bills/bulk-delete` | Bulk hard-delete, DO-scoped | admin |
| GET | `/api/bills/{id}/pdf` | Single A4 PDF | any |
| GET | `/api/bills/print/batch?from=&to=&format=9up` | Batch 9-up or single | any |
| GET | `/api/bills/customer/{id}/ledger` | Full customer account ledger | any |
| POST | `/api/bills/reset` | Wipe every bill company-wide, restart numbering | **global admin** |

### DO Sales · `routers/do_sales.py` → `services/do_sale_service.py`
A DO does **not** bill. It records sale lines here; S.P. Gas bills them with `POST /api/do-sales/bill` (one customer + one day → one cash, fully-paid bill, same product/rate lines merged; global login only). Internally that is `POST /api/bills` with `do_sale_ids`, which marks the lines billed in the same transaction. Deleting or cancelling the bill puts the lines back to pending.
| Method | Path | Purpose | Role |
|---|---|---|---|
| POST | `/api/do-sales/bill` | Bill a customer's pending lines for `sale_date` → returns the bill | staff+ (global only) |
| POST | `/api/do-sales` | Record lines `{customer_id, product_variant_id, quantity, rate?, empty_returned}` for a day. DO-scoped login only; customer must belong to that DO | staff+ |
| GET | `/api/do-sales?status=pending\|billed\|all&from=&to=&do_id=&customer_id=` | Lines with customer, product, bill # — DO-scoped logins only see their own | any |
| GET | `/api/do-sales/export?from=&to=&fmt=excel\|pdf&do_id=` | DO's Report as a file — same rows as the list, no bill numbers | any |
| GET | `/api/do-sales/summary?from=&to=` | Total qty, distinct customers, qty per product (DO's Report header) | any |

**Pricing note:** every `ProductVariant` carries two independent prices — `unit_price` (what a DO charges its own customer, used by billing) and `cost_price` (what the DO pays S.P. Gas, used only by Indent rate calculation). Set both in Products; they are never derived from each other.

### Indents · `routers/indents.py` → `services/indent_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| GET | `/api/indents/summary` | Per size (4/12/15/21 kg): Stock = cylinders the DO recorded as sold in DO Sales (all time) minus the Filled of its earlier indents + Rate = first active variant of that size | any |
| GET | `/api/indents?do_id=` | Submitted indents, newest first (DO-scoped logins only see their own) | any |
| GET | `/api/indents/{id}` | Detail with per-size items — 404 for another DO's indent | any |
| POST | `/api/indents` | Submit an indent (DO-scoped login only). Server recomputes stock/rate/amount; `filled` ≤ stock, `paid` ≤ total, at least one filled/empty | staff+ |
| PUT | `/api/indents/{id}` | Admin correction — re-prices off each item's own stored rate (not re-fetched), recomputes totals; `paid` ≤ total | **global admin** |
| POST | `/api/indents/{id}/approve` | Mark reviewed + approved | **global admin** |
| POST | `/api/indents/{id}/reject` | Mark reviewed + rejected, optional `note` shown to the DO. A rejected indent's `filled` no longer counts as consumed stock — the DO can correct and resubmit | **global admin** |

### Payments · `routers/payments.py` → `services/payment_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| GET / POST | `/api/payments` | List / record standalone receipt | staff+ |
| GET / PUT | `/api/payments/{id}` | Detail / update | staff+ |
| DELETE | `/api/payments/{id}` | Delete | admin |

### Cheques · `routers/cheques.py` → `services/payment_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| GET | `/api/cheques` | Register (by status / date) | any |
| PUT | `/api/cheques/{id}/status` | pending → cleared / bounced / cancelled (cascades to payment + customer balance) | staff+ |

### Reports · `routers/reports.py` → `services/report_service.py`
| Method | Path | Purpose |
|---|---|---|
| GET | `/api/reports/dashboard` | Today's sales, cash, empty pending, dues |
| GET | `/api/reports/daily-sales` | Date-range sales |
| GET | `/api/reports/outstanding` | Customers with dues |
| GET | `/api/reports/empty-bottles` | Empty cylinder register |
| GET | `/api/reports/product-sales` | Variant-wise sold qty + revenue |
| GET | `/api/reports/cash-book` | Day-wise cash in |
| GET | `/api/reports/gst` | Monthly GST for filing |

### Settings · `routers/settings.py` → `services/setting_service.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| GET | `/api/settings[, /{key}]` | List / fetch | any |
| PUT | `/api/settings/{key}` | Upsert | **global admin** |
| DELETE | `/api/settings/{key}` | Delete | **global admin** |

### Audit Logs · `routers/audit.py`
| Method | Path | Purpose | Role |
|---|---|---|---|
| GET | `/api/audit-logs` | Mutation trail (by entity / user / date) | **global admin** |

---

## 3. Services (business logic)

| File | Responsibility |
|---|---|
| `auth_service.py` | `authenticate()` — verify password, issue JWT |
| `user_service.py` | User CRUD, role & active checks |
| `customer_service.py` | CRUD · Excel import/export · `(mobile, village)` uniqueness |
| `product_service.py` | Category / product / variant CRUD · stock |
| `billing_service.py` | `_fy_prefix()`, `_next_bill_number()`, `create_bill()`, `cancel_bill()`, `customer_ledger()` — FY numbering, empty tracking, stock, customer-balance cascade |
| `do_sale_service.py` | `create_sales()`, `list_sales()`, `summary()`, `link_to_bill()` (used by `billing_service.create_bill`) |
| `indent_service.py` | `size_summary()` (stock = sold via `do_sale_service.quantities_by_variant_name` minus non-rejected indents' filled, rate = variant's **`cost_price`** — never `unit_price`, see note below), `create_indent()`, `update_indent()`, `approve_indent()`, `reject_indent()` |
| `payment_service.py` | Payments CRUD · cheque status transitions → payment + customer balance |
| `pdf_service.py` | `render_bill_pdf()` · `render_bills_9up_pdf()` (3×3 A4 grid) |
| `report_service.py` | All `/reports/*` aggregations |
| `setting_service.py` | Key/value settings upsert |

---

## 4. Models / Tables (15)

| Model file | Table(s) | Key constraints |
|---|---|---|
| `user.py` | `users` | UK(username), UK(email), IX(role, is_active) |
| `customer.py` | `customers` | UK(consumer_number) WHERE NOT is_deleted, IX(status, is_deleted), IX(mobile, is_deleted) |
| `product.py` | `product_categories`, `products`, `product_variants` | UK(category.name), UK(variant.sku_code), variants cascade-delete with product |
| `bill.py` | `bills`, `bill_items` | UK(bill_number), IX(customer_id, bill_date), IX(bill_date, status); items → bill CASCADE, → variant RESTRICT |
| `payment.py` | `payments` | UK(payment_number), IX(customer_id, payment_date) |
| `cheque.py` | `cheques` | IX(status, cheque_date); FKs to customer/bill/payment SET NULL |
| `empty_bottle.py` | `empty_bottle_transactions` | FK → customer CASCADE, IX(customer_id, created_at) |
| `audit.py` | `audit_logs` | IX(entity_type, entity_id, created_at), IX(user_id, created_at) |
| `setting.py` | `settings` | UK(key) |
| `distributor_outlet.py` | `distributor_outlets` | UK(code) WHERE NOT is_deleted, IX(is_active, is_deleted) |
| `do_sale.py` | `do_sales` | FK bill_id SET NULL (NULL = pending), IX(do_id, sale_date) |
| `indent.py` | `indents`, `indent_items` | indents: FK do_id RESTRICT, IX(do_id, indent_date), IX(status); status pending/approved/rejected, reviewed_by_id FK users SET NULL; items → indent CASCADE |

---

## 5. Auth & Roles

- JWT HS256 via `python-jose`. Payload: `sub=user_id (str)`, `role`, `exp`. TTL 7 days (`ACCESS_TOKEN_EXPIRE_MINUTES=10080`).
- Password hashed via `passlib[bcrypt]` (bcrypt pinned `<5.0` — passlib compat).
- Roles: `admin` · `billing_staff` · `viewer`.
- Guards (in `app/utils/auth.py`): `get_current_user` (any), `require_staff` (admin+staff), `require_admin` (admin — DO-scoped or global), `require_global_admin` (admin AND `do_id is None`, i.e. S.P. Gas itself). Apply via `Depends()` in the router signature.
- **Multi-tenant DO scoping** (`app/utils/scope.py`): `User.do_id` is `NULL` for a global S.P. Gas login (sees/manages every DO) or set to lock a login to one Distributor Outlet. `enforce_do_scope(user, entity_do_id)` 404s a DO-scoped user reaching another DO's row; `resolve_do_filter(user, requested_do_id)` pins list/report filters to the caller's own DO. Applied throughout customers/bills/payments/cheques/reports.
- **A DO-scoped `admin` login has full CRUD over its own customers/bills/payments and the shared product catalog** (`require_admin`/`require_staff` — same guards as a global login) **but never anything company-wide or cross-DO**: managing other DOs, managing users, settings, audit logs, and `/bills/reset` all require `require_global_admin` (admin **and** `do_id is None`), regardless of the DO login's own role. `enforce_do_scope` also keeps a DO-scoped admin's deletes/edits confined to its own DO's rows (e.g. `DELETE /bills/{id}` 404s on another DO's bill before the delete even runs). Use `require_global_admin` for anything company-wide; `require_admin`/`require_staff` for everything else.
- **Creating a DO auto-provisions its login** (`distributor_outlet_service._create_do_login`, called from `create_do`): username is the owner's name lowercased/slugified (deduped with a numeric suffix on collision), password is `<CODE>@123`, role `admin`, `do_id` set to the new outlet. `POST /distributor-outlets` returns this credential in plain text once (`DOCreateResult.login_username`/`login_password`) — it is never retrievable again after that response, since only the hash is stored.
- **Default admin (from `scripts/seed.py`):** `admin` / `admin123` — rotate before production.

---

## 6. Running

```bash
source venv/bin/activate
docker start spgasbill-postgres         # if not already up
alembic upgrade head                    # apply schema
python -m scripts.seed                  # idempotent — admin + catalog
uvicorn app.main:app --reload --port 8001
# Swagger: http://localhost:8001/docs
```

Login smoke test:
```bash
curl -X POST http://localhost:8001/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}'
```

---

## 7. Where to Look for What

| Task | File(s) |
|---|---|
| Add a new endpoint | `routers/<module>.py` + delegate to `services/` + register in `app/main.py` |
| Change business logic (any bill / payment / empty rule) | `services/<module>_service.py` — never in routers |
| Add a DB column / table | `models/<domain>.py` → `alembic revision --autogenerate -m "..."` → `alembic upgrade head` |
| Change bill number format | `billing_service._fy_prefix()` and `_next_bill_number()` |
| Change PDF layout (single or 9-up) | `services/pdf_service.py` |
| Change role permissions on a route | `Depends(require_admin / require_staff / require_global_admin)` in the router |
| Change what a DO-scoped login can see/touch vs. S.P. Gas | `app/utils/scope.py` (`enforce_do_scope`, `resolve_do_filter`) + `require_global_admin` in `app/utils/auth.py` |
| Tweak env / JWT TTL / bill code | `app/config/settings.py` + `.env` |
| Seed data (admin, categories, variants) | `scripts/seed.py` |
| Response shape | `schemas/common.py` — `APIResponse`, `PaginatedResponse` |
| Pagination helper | `app/utils/pagination.py` — `paginate(db, stmt, page, per_page, item_schema)` |
| Audit helper | `app/utils/audit.py` — `write_audit(...)`. Call from services on mutations. |

**Conventions:** success → `{"success": true, "message": "OK", "data": ...}` · error → `{"detail": "..."}` via `HTTPException` · store UTC, display IST in frontend · CORS currently `*` (tighten in `main.py` for prod).
