# Bookstore Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Admins manage categories, users and markets (markets many-to-many with books), and every model has a JSON CRUD API.

**Architecture:** Same patterns as phase 1. New admin controllers inherit `Admin::BaseController`. API copies the structure of `../store` (`Api::V1::ProductsController`, commit `58e8f51`): `/api/v1/<model>`, five actions, `render json:` with `only:`/`include:`. Unlike store, an `Api::V1::BaseController` adds auth (login to read, admin to write). `Market`↔`Book` through `MarketBook`, like store's `MarketProduct`.

**Tech Stack:** Ruby 4.0.9, Rails 8.1.4.1, PostgreSQL, Tailwind, Minitest + fixtures.

**Spec:** `docs/superpowers/specs/2026-11-11-bookstore-phase2-design.md`

## Global Constraints

- App: `/home/chonlakon/internship/rails_project/bookstore`. Builds on phase 1 (`docs/superpowers/plans/2026-11-10-bookstore.md`).
- "Product" = `Book`.
- Every management page is under `/admin` and inherits `Admin::BaseController` (non-admin → `redirect_to root_path, alert: "Admins only."`).
- API (structure from `../store/app/controllers/api/v1/products_controller.rb`): under `/api/v1`, actions `index, show, create, update, destroy`, `skip_forgery_protection`. Responses:
  - index → `200` array (empty array if none; store's 404-on-empty is NOT copied)
  - show/update → `200` object; create → `201` object
  - missing id → `404 {"error":"<Model> not found"}` (via `find_by`, as in store)
  - validation fail → `422 {"errors":[...full_messages]}`
  - destroy → `200 {"message":"<Model> deleted"}`; destroy blocked (category with books) → `422 {"errors":[...]}`
  - guest → `401 {"error":"Unauthorized"}`; logged-in non-admin on create/update/destroy, or on any users endpoint → `403 {"error":"Forbidden"}`
  - User JSON is exactly `id, email_address, role, created_at` — never `password_digest`.
- UI: simple, muted (white/gray, `gray-800` buttons, `border-gray-300` inputs, no bright colors/shadows), copy the look of `app/views/admin/books/*`.
- Delete buttons: `button_to ..., method: :delete, form: { data: { turbo_confirm: "Are you sure?" } }`.
- Commits: one per logical piece. Never commit `test/` (git-ignored). Stage explicit paths, never `git add .`.

## Review Focus

1. Deleting a category that still has books → nothing deleted, redirect to `/admin/categories` with the error in `alert`. Test in Task 1.
2. Admin creates a user with an email that already exists (any case, e.g. `ADMIN@example.com`) → form re-renders with 422 and "Email address has already been taken", not a 500. Test in Task 2.
3. Editing a market and unticking every book → the market ends up with 0 books (hidden empty value from `collection_check_boxes`). Test in Task 4.
4. A logged-in non-admin sending `POST`/`PATCH`/`DELETE` to `/api/v1/...` changes nothing and gets `403` — the API must not be a back door around the admin-only pages (store's API has no auth at all). Guest gets `401` JSON, not an HTML redirect. Test in Task 5.
5. `/api/v1/users` JSON (index, show, create response) never contains `password_digest`. Test in Task 5.

---

### Task 1: Category management (admin)

**Files:**
- Modify: `app/models/category.rb`, `config/routes.rb`, `app/views/admin/dashboard/index.html.erb`
- Create: `app/controllers/admin/categories_controller.rb`, `app/views/admin/categories/{index,new,edit,_form}.html.erb`
- Test: `test/models/category_test.rb`, `test/controllers/admin/categories_controller_test.rb`

**Interfaces:**
- Produces: `Category` — `has_many :books, dependent: :restrict_with_error`; `validates :name, presence: true, uniqueness: true`. Routes `admin_categories_path`, `new_admin_category_path`, `edit_admin_category_path(c)`, `admin_category_path(c)` (`resources :categories, except: :show` inside `namespace :admin`). Strong params `category: [:name]`.

- [ ] **Step 1: Failing tests**

```ruby
# test/models/category_test.rb
test "requires a name" do
  assert_not Category.new.valid?
end

test "name must be unique" do
  assert_not Category.new(name: categories(:fiction).name).valid?
end

test "cannot be destroyed while it has books" do
  assert_not categories(:fiction).destroy
  assert Category.exists?(categories(:fiction).id)
end

# test/controllers/admin/categories_controller_test.rb
test "non-admin is blocked" do
  sign_in_as users(:regular)
  get admin_categories_path
  assert_redirected_to root_path
  assert_no_difference("Category.count") { post admin_categories_path, params: { category: { name: "X" } } }
end

test "admin creates, edits and deletes an empty category" do
  sign_in_as users(:admin)
  post admin_categories_path, params: { category: { name: "Poetry" } }
  assert_redirected_to admin_categories_path
  poetry = Category.find_by!(name: "Poetry")
  patch admin_category_path(poetry), params: { category: { name: "Poems" } }
  assert_equal "Poems", poetry.reload.name
  assert_difference("Category.count", -1) { delete admin_category_path(poetry) }
end

test "blank name re-renders with 422" do
  sign_in_as users(:admin)
  post admin_categories_path, params: { category: { name: "" } }
  assert_response :unprocessable_entity
end

test "deleting a category with books shows an error" do
  sign_in_as users(:admin)
  assert_no_difference("Category.count") { delete admin_category_path(categories(:fiction)) }
  assert_redirected_to admin_categories_path
  assert_match "Cannot delete", flash[:alert]
end

test "dashboard links to categories" do
  sign_in_as users(:admin)
  get admin_root_path
  assert_select "a[href=?]", admin_categories_path
end
```
Run: `bin/rails test test/models/category_test.rb test/controllers/admin/categories_controller_test.rb` — Expected: FAIL (no route; model validations missing).

- [ ] **Step 2: Implement**

- Model associations/validations per Interfaces.
- `Admin::CategoriesController < Admin::BaseController`: same shape as `Admin::BooksController`. `destroy`: `if @category.destroy` → notice "Category was deleted." `else` → `redirect_to admin_categories_path, alert: @category.errors.full_messages.to_sentence`.
- Views: table (name, number of books, Edit, Delete), `_form` with one `name` field.
- Dashboard: add "Manage categories" link.

- [ ] **Step 3: Run tests**

Run: `bin/rails test` — Expected: PASS.

- [ ] **Step 4: Commit (two commits)**

```bash
git add app/models/category.rb && git commit -m "Validate categories and block deleting ones with books"
git add config/routes.rb app/controllers/admin/categories_controller.rb app/views/admin/categories app/views/admin/dashboard && git commit -m "Add admin category management"
```

---

### Task 2: Admin creates users

**Files:**
- Modify: `app/models/user.rb`, `config/routes.rb`, `app/views/admin/dashboard/index.html.erb`
- Create: `app/controllers/admin/users_controller.rb`, `app/views/admin/users/{index,new}.html.erb`
- Test: `test/models/user_test.rb`, `test/controllers/admin/users_controller_test.rb`

**Interfaces:**
- Produces: `User` — `validates :email_address, presence: true, uniqueness: true` (uniqueness check runs after `normalizes`, so case-insensitive). Routes `admin_users_path`, `new_admin_user_path` (`resources :users, only: %i[index new create]`). Strong params `user: [:email_address, :password, :password_confirmation, :role]`.

- [ ] **Step 1: Failing tests**

```ruby
# test/models/user_test.rb (add)
test "email must be unique ignoring case" do
  assert_not User.new(email_address: "ADMIN@example.com", password: "password").valid?
end

# test/controllers/admin/users_controller_test.rb
test "non-admin is blocked" do
  sign_in_as users(:regular)
  assert_no_difference("User.count") do
    post admin_users_path, params: { user: { email_address: "x@example.com", password: "p", password_confirmation: "p", role: "admin" } }
  end
  assert_redirected_to root_path
end

test "admin creates a user who can log in" do
  sign_in_as users(:admin)
  assert_difference("User.count", 1) do
    post admin_users_path, params: { user: { email_address: "new@example.com", password: "secret123", password_confirmation: "secret123", role: "user" } }
  end
  assert_redirected_to admin_users_path
  assert User.find_by(email_address: "new@example.com").authenticate("secret123")
end

test "admin can create another admin" do
  sign_in_as users(:admin)
  post admin_users_path, params: { user: { email_address: "boss@example.com", password: "p", password_confirmation: "p", role: "admin" } }
  assert User.find_by(email_address: "boss@example.com").admin?
end

test "duplicate email re-renders with 422" do
  sign_in_as users(:admin)
  post admin_users_path, params: { user: { email_address: "ADMIN@example.com", password: "p", password_confirmation: "p", role: "user" } }
  assert_response :unprocessable_entity
  assert_match "Email address has already been taken", response.body
end

test "mismatched password confirmation re-renders with 422" do
  sign_in_as users(:admin)
  post admin_users_path, params: { user: { email_address: "z@example.com", password: "a", password_confirmation: "b", role: "user" } }
  assert_response :unprocessable_entity
end

test "user list never shows password digests" do
  sign_in_as users(:admin)
  get admin_users_path
  assert_match "regular@example.com", response.body
  assert_no_match "$2a$", response.body
  assert_select "a[href=?]", new_admin_user_path
end
```
Run the two files — Expected: FAIL.

- [ ] **Step 2: Implement**

- Validation per Interfaces.
- `Admin::UsersController < Admin::BaseController`: `index` (`User.order(:email_address)`), `new`, `create` (success → `redirect_to admin_users_path, notice: "User was created."`; failure → `render :new, status: :unprocessable_entity`).
- `index`: table email + role, "New user" link. `new`: form with email, password, password confirmation, role `select` (`User.roles.keys`).
- Dashboard: add "Manage users" link.

- [ ] **Step 3: Run tests** — `bin/rails test` → PASS.

- [ ] **Step 4: Commit (two commits)**

```bash
git add app/models/user.rb && git commit -m "Validate user email uniqueness"
git add config/routes.rb app/controllers/admin/users_controller.rb app/views/admin/users app/views/admin/dashboard && git commit -m "Add admin user creation page"
```

---

### Task 3: Market model, many-to-many with Book

**Files:**
- Create: `app/models/market.rb`, `app/models/market_book.rb`, two migrations, `test/fixtures/markets.yml`, `test/fixtures/market_books.yml`
- Modify: `app/models/book.rb`
- Test: `test/models/market_test.rb`

**Interfaces:**
- Produces (shape copied from store's `Market`/`MarketProduct`, except `dependent: :destroy` on the market side so markets with books can still be deleted): `Market` — `has_many :market_books, dependent: :destroy`; `has_many :books, through: :market_books`; `validates :name, presence: true, uniqueness: true`. `MarketBook` — `belongs_to :market`, `belongs_to :book`, `validates :book_id, uniqueness: { scope: :market_id }`. `Book` — `has_many :market_books, dependent: :destroy`; `has_many :markets, through: :market_books`. Fixtures `markets(:central)` (books: dune, cosmos), `markets(:online)` (books: dune).

- [ ] **Step 1: Generate**

```bash
bin/rails g model Market name:string
bin/rails g model MarketBook market:references book:references
```
Add `add_index :market_books, [:market_id, :book_id], unique: true` to the join migration; `bin/rails db:migrate`. Write fixtures.

- [ ] **Step 2: Failing tests**

```ruby
# test/models/market_test.rb
test "requires a name" do
  assert_not Market.new.valid?
end

test "market has many books and book has many markets" do
  assert_equal %w[Cosmos Dune], markets(:central).books.order(:title).pluck(:title)
  assert_equal %w[Central Online], books(:dune).markets.order(:name).pluck(:name)
end

test "same book cannot be added twice to a market" do
  assert_not MarketBook.new(market: markets(:online), book: books(:dune)).valid?
end

test "deleting a book removes its market links" do
  assert_difference("MarketBook.count", -2) { books(:dune).destroy }
end

test "deleting a market keeps the books" do
  assert_no_difference("Book.count") { markets(:central).destroy }
end
```
Run: `bin/rails test test/models/market_test.rb` — Expected: FAIL.

- [ ] **Step 3: Implement associations/validations per Interfaces**

- [ ] **Step 4: Run tests** — `bin/rails test` → PASS.

- [ ] **Step 5: Commit**

```bash
git add app/models/market.rb app/models/market_book.rb app/models/book.rb db/migrate db/schema.rb && git commit -m "Add Market model, many-to-many with Book"
```

---

### Task 4: Market management (admin)

**Files:**
- Modify: `config/routes.rb`, `app/views/admin/dashboard/index.html.erb`
- Create: `app/controllers/admin/markets_controller.rb`, `app/views/admin/markets/{index,new,edit,_form}.html.erb`
- Test: `test/controllers/admin/markets_controller_test.rb`

**Interfaces:**
- Consumes: `Market`, `Book` from Task 3.
- Produces: `resources :markets, except: :show` in `namespace :admin`; strong params `params.expect(market: [:name, book_ids: []])`.

- [ ] **Step 1: Failing tests**

```ruby
test "non-admin is blocked" do
  sign_in_as users(:regular)
  get admin_markets_path
  assert_redirected_to root_path
end

test "admin creates a market with books" do
  sign_in_as users(:admin)
  post admin_markets_path, params: { market: { name: "Night", book_ids: [books(:cosmos).id] } }
  assert_redirected_to admin_markets_path
  assert_equal [books(:cosmos)], Market.find_by!(name: "Night").books.to_a
end

test "unticking every book clears the market" do
  sign_in_as users(:admin)
  patch admin_market_path(markets(:central)), params: { market: { name: "Central", book_ids: [""] } }
  assert_equal 0, markets(:central).reload.books.count
end

test "blank name re-renders with 422" do
  sign_in_as users(:admin)
  post admin_markets_path, params: { market: { name: "" } }
  assert_response :unprocessable_entity
end

test "admin deletes a market" do
  sign_in_as users(:admin)
  assert_difference("Market.count", -1) { delete admin_market_path(markets(:online)) }
end

test "form shows a checkbox per book and dashboard links to markets" do
  sign_in_as users(:admin)
  get new_admin_market_path
  assert_select "input[type=checkbox][name=?]", "market[book_ids][]", count: Book.count
  get admin_root_path
  assert_select "a[href=?]", admin_markets_path
end
```
Run — Expected: FAIL (no route).

- [ ] **Step 2: Implement**

- `Admin::MarketsController < Admin::BaseController`, same shape as `Admin::BooksController`.
- `_form`: `name` field + `form.collection_check_boxes :book_ids, Book.order(:title), :id, :title` (each as a label + checkbox on its own line).
- `index`: table name, number of books, Edit, Delete. Dashboard: "Manage markets" link.

- [ ] **Step 3: Run tests** — `bin/rails test` → PASS.

- [ ] **Step 4: Commit**

```bash
git add config/routes.rb app/controllers/admin/markets_controller.rb app/views/admin/markets app/views/admin/dashboard && git commit -m "Add admin market management"
```

---

### Task 5: JSON CRUD API (structure from store)

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/api/v1/base_controller.rb`, `app/controllers/api/v1/{books,categories,markets,users}_controller.rb`
- Test: `test/controllers/api/v1/books_controller_test.rb`, `test/controllers/api/v1/categories_controller_test.rb`, `test/controllers/api/v1/markets_controller_test.rb`, `test/controllers/api/v1/users_controller_test.rb`
- Reference (read, don't copy blindly): `../store/app/controllers/api/v1/products_controller.rb`

**Interfaces:**
- Consumes: all models; `Current.user`.
- Produces:
  ```ruby
  namespace :api do
    namespace :v1 do
      resources :books, :categories, :markets, :users
    end
  end
  ```
  `Api::V1::BaseController < ApplicationController`:
  - `skip_forgery_protection`
  - overrides private `request_authentication` → `render json: { error: "Unauthorized" }, status: :unauthorized`
  - `require_admin` (private) → `render json: { error: "Forbidden" }, status: :forbidden unless Current.user.admin?`
  - Book/Category/Market controllers: `before_action :require_admin, only: %i[create update destroy]`; Users controller: `before_action :require_admin` (all actions).

  JSON per model (store style: `render json: record, only: [...], include: {...}`):
  | Model | `only:` | `include:` | params (`params.expect`) |
  |---|---|---|---|
  | Book | `id, title, author, description` | `category: { only: [:id, :name] }, markets: { only: [:id, :name] }` | `book: [:title, :author, :description, :category_id]` |
  | Category | `id, name` | `books: { only: [:id, :title] }` | `category: [:name]` |
  | Market | `id, name` | `books: { only: [:id, :title] }` | `market: [:name, book_ids: []]` |
  | User | `id, email_address, role, created_at` | — | `user: [:email_address, :password, :password_confirmation, :role]` |

  Put each controller's `only:`/`include:` options in one private method (e.g. `json_options`) so the five actions don't repeat them as store does.

- [ ] **Step 1: Failing tests** (all use `as: :json`)

```ruby
# test/controllers/api/v1/books_controller_test.rb
test "guest gets 401 json" do
  get api_v1_books_path, as: :json
  assert_response :unauthorized
  assert_equal "Unauthorized", response.parsed_body["error"]
end

test "logged-in user can read" do
  sign_in_as users(:regular)
  get api_v1_books_path, as: :json
  assert_response :ok
  assert_includes response.parsed_body.map { _1["title"] }, "Dune"

  get api_v1_book_path(books(:dune)), as: :json
  body = response.parsed_body
  assert_equal "Fiction", body["category"]["name"]
  assert_equal %w[Central Online], body["markets"].map { _1["name"] }.sort
end

test "unknown id is 404 with message" do
  sign_in_as users(:regular)
  get api_v1_book_path(id: 999_999), as: :json
  assert_response :not_found
  assert_equal "Book not found", response.parsed_body["error"]
end

test "non-admin cannot write" do
  sign_in_as users(:regular)
  assert_no_difference("Book.count") do
    post api_v1_books_path, params: { book: { title: "X", category_id: categories(:fiction).id } }, as: :json
    delete api_v1_book_path(books(:dune)), as: :json
  end
  assert_response :forbidden
  patch api_v1_book_path(books(:dune)), params: { book: { title: "Hacked" } }, as: :json
  assert_response :forbidden
  assert_equal "Dune", books(:dune).reload.title
end

test "admin creates, updates and deletes" do
  sign_in_as users(:admin)
  post api_v1_books_path, params: { book: { title: "New", category_id: categories(:fiction).id } }, as: :json
  assert_response :created
  id = response.parsed_body["id"]

  patch api_v1_book_path(id), params: { book: { title: "Newer" } }, as: :json
  assert_response :ok
  assert_equal "Newer", response.parsed_body["title"]

  delete api_v1_book_path(id), as: :json
  assert_response :ok
  assert_equal "Book deleted", response.parsed_body["message"]
end

test "invalid book gives 422 with errors" do
  sign_in_as users(:admin)
  post api_v1_books_path, params: { book: { title: "" } }, as: :json
  assert_response :unprocessable_entity
  assert_includes response.parsed_body["errors"], "Title can't be blank"
end

# test/controllers/api/v1/categories_controller_test.rb
test "show includes books" do
  sign_in_as users(:regular)
  get api_v1_category_path(categories(:science)), as: :json
  assert_equal ["Cosmos"], response.parsed_body["books"].map { _1["title"] }
end

test "deleting a category with books gives 422" do
  sign_in_as users(:admin)
  assert_no_difference("Category.count") { delete api_v1_category_path(categories(:fiction)), as: :json }
  assert_response :unprocessable_entity
end

test "empty list is 200 []" do
  sign_in_as users(:admin)
  MarketBook.delete_all
  Book.delete_all
  Category.delete_all
  get api_v1_categories_path, as: :json
  assert_response :ok
  assert_equal [], response.parsed_body
end

# test/controllers/api/v1/markets_controller_test.rb
test "admin creates a market with books" do
  sign_in_as users(:admin)
  post api_v1_markets_path, params: { market: { name: "Night", book_ids: [books(:cosmos).id] } }, as: :json
  assert_response :created
  assert_equal ["Cosmos"], response.parsed_body["books"].map { _1["title"] }
end

# test/controllers/api/v1/users_controller_test.rb
test "non-admin cannot read users" do
  sign_in_as users(:regular)
  get api_v1_users_path, as: :json
  assert_response :forbidden
end

test "admin lists and creates users without password digests" do
  sign_in_as users(:admin)
  get api_v1_users_path, as: :json
  assert_equal %w[created_at email_address id role], response.parsed_body.first.keys.sort

  post api_v1_users_path, params: { user: { email_address: "api@example.com", password: "secret123", password_confirmation: "secret123", role: "user" } }, as: :json
  assert_response :created
  assert_no_match "password", response.body
  assert User.find_by(email_address: "api@example.com").authenticate("secret123")
end
```
Run: `bin/rails test test/controllers/api` — Expected: FAIL (no route).

- [ ] **Step 2: Implement**

Routes and `Api::V1::BaseController` per Interfaces. Each model controller follows store's five actions:
- `index`: `render json: Model.includes(...).order(:id), **json_options, status: :ok`
- `show`/`update`/`destroy`: `record = Model.find_by(id: params[:id])`; if nil → `404 {"error":"<Model> not found"}`.
- `create`: `201` on save, else `422 {"errors": record.errors.full_messages}`.
- `destroy`: `if record.destroy` → `200 {"message":"<Model> deleted"}` else `422 {"errors": ...}`.

- [ ] **Step 3: Run tests** — `bin/rails test` → PASS.

- [ ] **Step 4: Commit (one per piece)**

```bash
git add config/routes.rb app/controllers/api/v1/base_controller.rb app/controllers/api/v1/books_controller.rb && git commit -m "Add books API"
git add app/controllers/api/v1/categories_controller.rb && git commit -m "Add categories API"
git add app/controllers/api/v1/markets_controller.rb && git commit -m "Add markets API"
git add app/controllers/api/v1/users_controller.rb && git commit -m "Add users API (admin only)"
```
(Routes for all four go in the first commit; later controllers make them work.)

---

### Task 6: Seeds and manual check

**Files:**
- Modify: `db/seeds.rb`

- [ ] **Step 1:** Keep the existing admin/user/categories/books seeds. Add markets with `find_or_create_by!`: "Central Market" (Dune, Cosmos, Sapiens), "Online Store" (all 6 books). Link with `market.books = Book.where(title: [...])`.

- [ ] **Step 2: Verify**

Run: `bin/rails db:seed && bin/rails db:seed && bin/rails runner 'p [Market.count, MarketBook.count]'`
Expected: `[2, 9]`.

- [ ] **Step 3: Manual walkthrough** (`bin/dev`, log in as `admin@example.com`): Admin → Manage categories (create, rename, delete empty one, try deleting Fiction → error), Manage users (create a user, log in as them), Manage markets (create with ticked books, edit, untick all, delete). With curl or the browser, logged in: `GET /api/v1/books`, `/api/v1/markets/1`, `/api/v1/users` as admin and as a normal user.

- [ ] **Step 4: Commit**

Run: `bin/rails test` — Expected: PASS.
```bash
git add db/seeds.rb && git commit -m "Seed markets"
```
