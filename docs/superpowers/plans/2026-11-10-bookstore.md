# Bookstore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new Rails app where logged-in users browse, filter, search and view books, and only admins reach an admin page and create/edit/delete books.

**Architecture:** Fresh `rails new` app. Rails 8 authentication generator + `role` enum on `User`. Public `BooksController` (index/show) filtering by query params; `Admin::` namespace whose `Admin::BaseController` rejects non-admins.

**Tech Stack:** Ruby 4.0.9, Rails 8.1.4.1, PostgreSQL, Tailwind, Minitest + fixtures.

**Spec:** `docs/superpowers/specs/2026-11-10-bookstore-design.md`

## Global Constraints

- App path: `/home/chonlakon/internship/rails_project/bookstore`. Do not touch `book/` or `store/`.
- Scope is exactly the 7 requirements. Non-goals: cover images, price, sign-up, category UI, dashboard stats, author search.
- Every page requires login (generator default). No `allow_unauthenticated_access` on book pages.
- `users.role`: string, `null: false`, `default: "user"`; `enum :role, { user: "user", admin: "admin" }, default: "user"`.
- `Book`: `title` (required), `author`, `description:text`, `category` (required).
- Delete button: `button_to "Delete", ..., method: :delete, form: { data: { turbo_confirm: "Are you sure?" } }`.
- Non-admin redirect: `redirect_to root_path, alert: "Admins only."`.
- UI: simple and easy to use, not fancy. Plain Tailwind — white/gray background, gray text, one muted accent (`gray-800` buttons, `gray-100` for the active category). No gradients, shadows, bright colors or animations. One centered column (`max-w-4xl mx-auto p-4`), plain lists/tables, standard form fields with labels.
- Commit after each task.

## Review Focus

1. A logged-in non-admin sending `POST`/`PATCH`/`DELETE` to `/admin/books` directly changes nothing → Task 4 test.
2. A guest opening any page (including `/books/:id`) is sent to login → Task 3 test.
3. Blank title on create/edit re-renders the form with status 422 and the error → Task 4 test.
4. Search is case-insensitive ("DUNE" finds "Dune") → Task 2 test.
5. A search with no matches shows "No books found", not an error → Task 3 test.

---

### Task 1: New app with authentication and admin role

**Files:**
- Create: `bookstore/` via `rails new`; auth files via generator
- Create: `db/migrate/*_add_role_to_users.rb`
- Modify: `app/models/user.rb`, `test/fixtures/users.yml`
- Test: `test/models/user_test.rb`

**Interfaces:**
- Produces: `User#admin?`; fixtures `users(:admin)`, `users(:regular)` (password `"password"`); test helper `sign_in_as(user)`; `Current.user`.

- [ ] **Step 1: Create app, auth, role**

```bash
cd /home/chonlakon/internship/rails_project
rails _8.1.4.1_ new bookstore -d postgresql -c tailwind
cd bookstore
bin/rails db:create
bin/rails generate authentication
bin/rails generate migration AddRoleToUsers role:string
```
Edit the migration to `add_column :users, :role, :string, null: false, default: "user"`, then `bin/rails db:migrate`.
Copy `../book/docs/superpowers/{specs,plans}` into `docs/superpowers/`.

- [ ] **Step 2: Fixtures and sign-in helper**

`test/fixtures/users.yml`: `admin` (`admin@example.com`, role `admin`) and `regular` (`regular@example.com`, role `user`), both `password_digest: <%= BCrypt::Password.create("password") %>`.
If `test/test_helpers/session_test_helper.rb` with `sign_in_as(user)` was not generated, create it (`post session_path, params: { email_address: user.email_address, password: "password" }`) and include it in `ActionDispatch::IntegrationTest` from `test/test_helper.rb`.

- [ ] **Step 3: Failing test**

```ruby
# test/models/user_test.rb
test "new users default to user role" do
  assert User.create!(email_address: "n@example.com", password: "password").user?
end

test "admin fixture is admin" do
  assert users(:admin).admin?
end
```
Run: `bin/rails test test/models/user_test.rb` — Expected: FAIL, `undefined method 'user?'`.

- [ ] **Step 4: Add enum to `app/models/user.rb`, run tests**

Run: `bin/rails test` — Expected: PASS. Run: `grep database: config/database.yml` — Expected: only `bookstore_*`.

- [ ] **Step 5: Commit**

```bash
git add . && git commit -m "New app with authentication and admin role"
```

---

### Task 2: Category and Book models

**Files:**
- Create: `app/models/category.rb`, `app/models/book.rb`, migrations, `test/fixtures/categories.yml`, `test/fixtures/books.yml`
- Test: `test/models/book_test.rb`

**Interfaces:**
- Produces: `Category has_many :books`; `Book belongs_to :category`, `validates :title, presence: true`; `Book.search(q)` (title ILIKE, blank → all); `Book.in_category(id)` (blank → all). Fixtures `categories(:fiction)`, `categories(:science)`, `books(:dune)` ("Dune", fiction), `books(:cosmos)` ("Cosmos", science).

- [ ] **Step 1: Generate**

```bash
bin/rails g model Category name:string
bin/rails g model Book title:string author:string description:text category:references
bin/rails db:migrate
```
Write the fixtures above.

- [ ] **Step 2: Failing tests**

```ruby
# test/models/book_test.rb
test "requires a title" do
  assert_not Book.new(category: categories(:fiction)).valid?
end

test "search is case-insensitive" do
  assert_equal [books(:dune)], Book.search("DUNE").to_a
end

test "in_category filters" do
  assert_equal [books(:cosmos)], Book.in_category(categories(:science).id).to_a
end

test "blank filters return all" do
  assert_equal Book.count, Book.search("").in_category(nil).count
end
```
Run: `bin/rails test test/models/book_test.rb` — Expected: FAIL, `undefined method 'search'`.

- [ ] **Step 3: Implement associations, validation, scopes**

`search`: `where("title ILIKE ?", "%#{sanitize_sql_like(q)}%")` when `q.present?`.

- [ ] **Step 4: Run tests**

Run: `bin/rails test` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add . && git commit -m "Add Category and Book models"
```

---

### Task 3: Book list, category filter, search, details

**Files:**
- Create: `app/controllers/books_controller.rb`, `app/views/books/index.html.erb`, `app/views/books/show.html.erb`
- Modify: `config/routes.rb`, `app/views/layouts/application.html.erb`
- Test: `test/controllers/books_controller_test.rb`

**Interfaces:**
- Consumes: `Book.search`, `Book.in_category`, `sign_in_as`.
- Produces: `resources :books, only: %i[index show]`, `root "books#index"`.

- [ ] **Step 1: Failing tests**

```ruby
# test/controllers/books_controller_test.rb
test "guests are sent to login" do
  get book_path(books(:dune))
  assert_redirected_to new_session_path
end

test "lists all books with category buttons" do
  sign_in_as users(:regular)
  get root_path
  assert_select "a[href=?]", book_path(books(:dune))
  assert_select "a[href=?]", book_path(books(:cosmos))
  assert_select "a[href=?]", books_path(category_id: categories(:science).id)
end

test "category filter" do
  sign_in_as users(:regular)
  get books_path(category_id: categories(:science).id)
  assert_select "a[href=?]", book_path(books(:dune)), count: 0
end

test "search" do
  sign_in_as users(:regular)
  get books_path(q: "cos")
  assert_select "a[href=?]", book_path(books(:cosmos))
  assert_select "a[href=?]", book_path(books(:dune)), count: 0
end

test "no matches" do
  sign_in_as users(:regular)
  get books_path(q: "zzz")
  assert_match "No books found", response.body
end

test "details page" do
  sign_in_as users(:regular)
  get book_path(books(:dune))
  assert_select "h1", "Dune"
end
```
Run: `bin/rails test test/controllers/books_controller_test.rb` — Expected: FAIL, no route.

- [ ] **Step 2: Implement**

- Routes per Interfaces.
- `index`: `@categories = Category.order(:name)`; `@books = Book.in_category(params[:category_id]).search(params[:q]).order(:title)`.
- `index.html.erb`: "All" + one button per category; `form_with url: books_path, method: :get` with field `q`; each title `link_to book_path(book)`; "No books found" when empty.
- `show.html.erb`: `<h1>` title, author, category name, description, back link.
- Layout: user email, "Admin" link to `admin_root_path` if `Current.user&.admin?` (add after Task 4 routes exist), "Log out" `button_to session_path, method: :delete`; flash `notice`/`alert`.

- [ ] **Step 3: Run tests**

Run: `bin/rails test` — Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add . && git commit -m "Add book list, filter, search and details"
```

---

### Task 4: Admin page and book create/edit/delete

**Files:**
- Create: `app/controllers/admin/base_controller.rb`, `app/controllers/admin/dashboard_controller.rb`, `app/controllers/admin/books_controller.rb`
- Create: `app/views/admin/dashboard/index.html.erb`, `app/views/admin/books/{index,new,edit,_form}.html.erb`
- Modify: `config/routes.rb`, `app/views/layouts/application.html.erb` (Admin link)
- Test: `test/controllers/admin/books_controller_test.rb`

**Interfaces:**
- Consumes: `User#admin?`, `Book`, `Category`, `sign_in_as`.
- Produces: `namespace :admin do root "dashboard#index"; resources :books, except: :show end`; strong params `book: [:title, :author, :description, :category_id]`.

- [ ] **Step 1: Failing tests**

```ruby
# test/controllers/admin/books_controller_test.rb
test "non-admin is blocked from admin page and changes" do
  sign_in_as users(:regular)
  get admin_root_path
  assert_redirected_to root_path
  assert_no_difference "Book.count" do
    post admin_books_path, params: { book: { title: "X", category_id: categories(:fiction).id } }
    delete admin_book_path(books(:dune))
  end
  patch admin_book_path(books(:dune)), params: { book: { title: "Hacked" } }
  assert_equal "Dune", books(:dune).reload.title
end

test "admin sees admin page" do
  sign_in_as users(:admin)
  get admin_root_path
  assert_select "a[href=?]", admin_books_path
end

test "admin creates a book" do
  sign_in_as users(:admin)
  assert_difference "Book.count", 1 do
    post admin_books_path, params: { book: { title: "New", category_id: categories(:fiction).id } }
  end
  assert_redirected_to admin_books_path
end

test "blank title re-renders with 422" do
  sign_in_as users(:admin)
  post admin_books_path, params: { book: { title: "", category_id: categories(:fiction).id } }
  assert_response :unprocessable_entity
end

test "admin edits a book" do
  sign_in_as users(:admin)
  patch admin_book_path(books(:dune)), params: { book: { title: "Dune 2" } }
  assert_equal "Dune 2", books(:dune).reload.title
end

test "admin deletes a book" do
  sign_in_as users(:admin)
  assert_difference "Book.count", -1 do
    delete admin_book_path(books(:dune))
  end
end
```
Run: `bin/rails test test/controllers/admin` — Expected: FAIL, no route.

- [ ] **Step 2: Implement**

- `Admin::BaseController < ApplicationController`: `before_action :require_admin` → redirect per Global Constraints unless `Current.user&.admin?`.
- `Admin::DashboardController#index` (inherits base): page with "Manage books" link to `admin_books_path`.
- `Admin::BooksController` (inherits base): `index, new, create, edit, update, destroy`; success → `redirect_to admin_books_path, notice: ...`; failure → `render :new/:edit, status: :unprocessable_entity`.
- `_form` (local `book`): `form_with model: [:admin, book]`, errors, title, author, description, `collection_select :category_id`.
- `index`: list with Edit link and Delete button per Global Constraints, "New book" link.
- Layout: add the Admin link.

- [ ] **Step 3: Run tests**

Run: `bin/rails test` — Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add . && git commit -m "Add admin page and book CRUD"
```

---

### Task 5: Seeds and manual check

**Files:**
- Modify: `db/seeds.rb`

- [ ] **Step 1: Seeds** with `find_or_create_by!`: `admin@example.com` / `password` (admin), `user@example.com` / `password` (user), categories Fiction / Science / History, 2 books each.

- [ ] **Step 2: Verify**

Run: `bin/rails db:seed && bin/rails db:seed && bin/rails runner 'p [User.count, Category.count, Book.count]'`
Expected: `[2, 3, 6]`.

- [ ] **Step 3: Manual walkthrough**

`bin/dev` → `http://localhost:3000`: login as user → list, filter, search, details work; `/admin` redirects home. Login as admin → `/admin` → create, edit, delete a book.

- [ ] **Step 4: Commit**

Run: `bin/rails test` — Expected: PASS.
```bash
git add . && git commit -m "Add seed data"
```
