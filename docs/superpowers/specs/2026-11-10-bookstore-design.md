# Bookstore — Short Design

**Intent:** Internship exercise. Build exactly the 7 given requirements, nothing more ("เอาแค่ตาม req พอ ไม่ต้อง scope ใหญ่มาก").

## Requirements → design

| # | Requirement | Design |
|---|---|---|
| 1 | Add authentication | `bin/rails generate authentication`; every page requires login (generator default) |
| 2 | Page to display all books | `/books` (root) lists all books |
| 3 | Category buttons to filter | Buttons link to `/books?category_id=` |
| 4 | Search bar | GET form sends `/books?q=`, matches book title |
| 5 | Select book → details | Title links to `/books/:id` |
| 6 | Admin page, admins only | `/admin` behind `Admin::BaseController` (non-admins redirected) |
| 7 | Create/edit/delete book, admins only | `/admin/books` CRUD with one `_form`, same base controller |

Supporting pieces: `users.role` (user/admin), `Category(name)`, `Book(title, author, description, category)`, seeds (1 admin, 1 user, 3 categories, sample books).

## Non-goals

Cover images, price, sign-up page, category management UI, dashboard stats, search by author, special-character search handling.

## Approaches

Only one sensible way: plain Rails 8 conventions (built-in auth generator, namespaced admin controllers, query-param filtering). Gems like Devise/Pundit/Ransack were dropped — they add setup beyond what the requirements need.

## Stack

New app `/home/chonlakon/internship/rails_project/bookstore`: Rails 8.1.4.1, Ruby 4.0.9, PostgreSQL, Tailwind, Minitest — same as the existing `store` project.

## UI

Simple and easy to use, not fancy; muted colors (white/gray, one dark-gray accent), no bright colors, gradients or effects.

## Left to the builder

Exact copy text, seed book titles.
