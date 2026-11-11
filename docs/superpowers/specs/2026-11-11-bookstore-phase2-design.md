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
| 7 | API for Book, Category, Market, User | Read-only JSON: `GET /api/<model>` and `GET /api/<model>/:id`. Auth = the same login cookie. Not logged in → `401` JSON. Users API admin-only (non-admin → `403`). Never output `password_digest`. |

## Planner's calls (simplest option, user can flip)

- API is read-only (index/show). Write endpoints would need CSRF/token handling — not the simplest.
- API uses the existing login session, not tokens.
- Market pages are admin-only, like Book and Category pages.
- A category that still has books cannot be deleted; the admin sees "Cannot delete record because dependent books exist".
- Admin user page has list + create only (no edit/delete — not requested).

## Non-goals

API write endpoints, API tokens, pagination, showing markets on public book pages, user edit/delete.

## UI

Same as phase 1: simple, muted (white/gray, `gray-800` buttons), one centered column.
