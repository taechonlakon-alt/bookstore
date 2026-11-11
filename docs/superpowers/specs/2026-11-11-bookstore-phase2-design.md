# Bookstore Phase 2 — Short Design

**Intent:** Add the second batch of requirements to the existing `bookstore` app. User asked for the simplest version of everything ("ใช้แบบง่ายที่สุด").

"Product" in the requirements means **Book** — this app has no Product model.

## Requirements → design

| # | Requirement | Design |
|---|---|---|
| 1 | Category one-to-many with product | Already done (`Category has_many :books`, `Book belongs_to :category`). Add `dependent: :restrict_with_error` and name validation. |
| 2 | Create/edit/delete Category, admin only | `/admin/categories` CRUD, behind `Admin::BaseController` |
| 3 | Create User page, admin only | `/admin/users/new` + list at `/admin/users`; fields email, password, password confirmation, role |
| 4 | Seed for an admin user | Already done (`admin@example.com` / `password`). Seeds also get markets. |
| 5 | Market many-to-many with product | `Market(name)` + join table `market_books(market_id, book_id)` with a unique pair index; `has_many :through` on both sides |
| 6 | Create/edit/delete Market | `/admin/markets` CRUD, admin only (same as all other management pages); books chosen with checkboxes |
| 7 | API for Book, Category, Market, User | Same structure as `store`'s `Api::V1::ProductsController`: `/api/v1/<model>`, full CRUD (index/show/create/update/destroy), `skip_forgery_protection`, `render json:` with `only:`/`include:`, `find_by` + `{ error: "... not found" }` 404, `{ errors: [...] }` 422, `{ message: "... deleted" }` on destroy. |

## Following `store`

User asked to follow the structure of `../store` (commit `58e8f51 api`). Copied from it:
- `namespace :api do namespace :v1 do resources ... end end`
- One controller per model, five actions, same response shapes and status codes.
- `render json: record, only: [...], include: { assoc: { only: [...] } }`.
- Join model pattern `MarketProduct` → `MarketBook` with `validates :book_id, uniqueness: { scope: :market_id }`.

Deliberate differences from `store` (and why):
- **Auth on the API.** `store`'s API uses `allow_unauthenticated_access`, so anyone can create/delete products. Copying that would break this app's rule that only admins create/edit/delete. Here: reading needs login (same as the web pages), writing needs admin, the users API is admin-only. Auth is the existing login cookie. Guest → `401 {"error":"Unauthorized"}`, non-admin write → `403 {"error":"Forbidden"}`.
- **Empty list returns `200 []`,** not `store`'s `404 "No products found"` — an empty list isn't an error.
- **Deleting a market removes its book links** (`dependent: :destroy`), unlike `store`'s `restrict_with_error`, which would block deleting any market that has books, against requirement 6.
- **Strong params use `params.expect`** (Rails 8 style, already used in this app) instead of `require/permit`.
- User JSON is exactly `id, email_address, role, created_at`; `password_digest` never goes out.

## Planner's calls (simplest option, user can flip)

- API uses the existing login session, not tokens. The cookie is `same_site: :lax`, so other sites can't send it on POST/PATCH/DELETE, and `skip_forgery_protection` (as in `store`) stays safe enough here.
- Market pages are admin-only, like Book and Category pages.
- A category that still has books cannot be deleted; the admin sees "Cannot delete record because dependent books exist".
- Admin user page has list + create only (no edit/delete — not requested).

## Non-goals

API tokens, API versions beyond v1, pagination, showing markets on public book pages, user edit/delete.

## UI

Same as phase 1: simple, muted (white/gray, `gray-800` buttons), one centered column.
