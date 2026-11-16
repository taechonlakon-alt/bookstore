# Devise + Rolify + Pundit + ActiveAdmin v4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the bookstore's hand-written auth, role enum, admin checks and `/admin` with Devise, Rolify, Pundit and ActiveAdmin v4. The tech stack stays the same.

**Architecture:** The gems go in one at a time, in the guide's order (Devise → Rolify → Pundit → ActiveAdmin). The app and the full test suite stay green after every task. ActiveAdmin's CSS is built with the Tailwind standalone binary that `tailwindcss-rails` already ships, so the project needs no Node.

**Tech Stack:** Rails 8.1, Ruby 4.0.9, PostgreSQL, importmap-rails, tailwindcss-rails 4.7 (tailwindcss-ruby 4.3.4), Propshaft, Minitest. Run locally with `bin/dev`; there is no Docker dev setup.

**Spec:** `docs/superpowers/specs/2026-11-16-devise-rolify-pundit-activeadmin-design.md`

## Global Constraints

- Gems, exactly: `gem "devise", "~> 5.0"`, `gem "rolify", "~> 6.0"`, `gem "pundit", "~> 2.5"`, `gem "activeadmin", "4.0.0.beta23"`. No other new gems: no dotenv, no cssbundling, no jsbundling.
- No `package.json`, no npm/yarn, and no Node step in the `Dockerfile`.
- No hardcoded credentials in committed files. Seeds read `ENV.fetch("ADMIN_EMAIL")`, `ENV.fetch("ADMIN_PASSWORD")`, `ENV.fetch("USER_EMAIL")` and `ENV.fetch("USER_PASSWORD")`. Test fixtures may use the test-only password `"password"`.
- Roles are exactly `admin` and `user`, and every user has exactly one.
- The API's JSON shape stays the same except that `email_address` becomes `email`. A user is `{id, email, role, created_at}`. Guests get `401 {"error":"Unauthorized"}`. A non-admin who writes gets `403 {"error":"Forbidden"}`. Deleting yourself or changing your own role gets a 422 with today's messages.
- Follow `CODING_STANDARDS.md` (method ordering, `params.expect`, routing style).
- After each task, `bin/rails test`, `bin/rubocop` and `bin/brakeman --no-pager` all pass.

## Review Focus

1. **A user who existed before the migration logs in with their old password.** Pinned in Task 1 (migration test via fixture digest created with `BCrypt::Password.create`).
2. **Email case:** signing up or logging in as `ADMIN@Example.com` resolves to the same `admin@example.com` account, and a duplicate gives a validation error, not a DB exception. Pinned in Task 1.
3. **A regular user who types `/admin/...` URLs by hand** (including `DELETE` and batch actions) is refused, not just hidden from the menu. Pinned in Task 5.
4. **An admin editing their own record in ActiveAdmin** can change their email or password without setting a new password every time, but can't demote or delete themselves. Pinned in Task 5.
5. **The storefront doesn't pick up ActiveAdmin's CSS** once `active_admin.css` exists in `app/assets/builds`. Pinned in Task 4.

---

### Task 1: Devise replaces Rails 8 authentication

**Files:**
- Modify: `Gemfile`, `Gemfile.lock`, `config/routes.rb`, `app/models/user.rb`, `app/controllers/application_controller.rb`, `app/controllers/books_controller.rb`, `app/controllers/admin/base_controller.rb`, `app/controllers/api/v1/base_controller.rb`, `app/controllers/api/v1/users_controller.rb`, `app/views/layouts/application.html.erb`, `app/views/admin/users/*`, `test/test_helper.rb`, `test/fixtures/users.yml`, every test that calls `sign_in_as` or uses `email_address`
- Create: `config/initializers/devise.rb`, `config/locales/devise.en.yml` (generator), `db/migrate/*_convert_users_to_devise.rb`, `app/views/devise/{sessions,registrations,passwords}/*` (generator, then trimmed and styled), `test/integration/devise_auth_test.rb`
- Delete: `app/models/session.rb`, `app/models/current.rb`, `app/controllers/concerns/authentication.rb`, `app/controllers/sessions_controller.rb`, `app/controllers/passwords_controller.rb`, `app/mailers/passwords_mailer.rb`, `app/views/sessions/`, `app/views/passwords/`, `app/views/passwords_mailer/`, `test/test_helpers/session_test_helper.rb`, `test/controllers/sessions_controller_test.rb`, `test/controllers/passwords_controller_test.rb`, `test/mailers/previews/passwords_mailer_preview.rb` (if present)

**Interfaces:**
- Produces: `User` with `email` and `encrypted_password` columns and Devise modules `:database_authenticatable, :registerable, :recoverable, :rememberable, :validatable`. Controller/view helpers `current_user`, `user_signed_in?` and `authenticate_user!`. Route helpers `new_user_session_path`, `destroy_user_session_path`, `new_user_registration_path` and `new_user_password_path`. `Api::V1::BaseController#authenticate_api_user!`, which renders `401 {"error":"Unauthorized"}`. In tests, `sign_in(user)` / `sign_out(user)` from `Devise::Test::IntegrationHelpers`.
- `users.role` (enum `user`/`admin`) is **unchanged** in this task. `User#admin?` still comes from the enum.

- [ ] **Step 1: Add the gem and run the generators**

Add `gem "devise", "~> 5.0"`, then run `bundle install` and `bin/rails g devise:install`. Set `config.mailer_sender = ENV.fetch("MAILER_SENDER", "no-reply@bookstore.local")`.

- [ ] **Step 2: Write the migration `ConvertUsersToDevise`**

In `change`, rename the columns `email_address` → `email` and `password_digest` → `encrypted_password`. Add `reset_password_token` (string, unique index), `reset_password_sent_at` (datetime) and `remember_created_at` (datetime). Drop the `sessions` table with its full definition (`user_id` FK, `ip_address`, `user_agent`, timestamps) so the migration can be rolled back. Rename the email index to `index_users_on_email`. Then run `bin/rails db:migrate` and confirm that `db/schema.rb` has no `sessions` table and that `users` has `email` and `encrypted_password`.

- [ ] **Step 3: Update fixtures and the test helper**

In `test/fixtures/users.yml`, use the key `email:` and `encrypted_password: <%= BCrypt::Password.create("password") %>`. Use `BCrypt::Password.create` on purpose, not `Devise::Encryptor`: it's exactly what `has_secure_password` stored, so the fixture proves Review Focus #1. Keep `role:`. In `test/test_helper.rb`, drop the `session_test_helper` require and add `class ActionDispatch::IntegrationTest; include Devise::Test::IntegrationHelpers; end`. Across the tests, replace `sign_in_as x` with `sign_in x`, and `email_address` with `email`.

- [ ] **Step 4: Write the failing tests in `test/integration/devise_auth_test.rb`**

```ruby
test "existing bcrypt user logs in with the old password" do
  post user_session_path, params: { user: { email: "ADMIN@example.com", password: "password" } }
  assert_redirected_to root_path
  follow_redirect!
  assert_select "nav", /admin@example.com/
end

test "wrong password is rejected" do
  post user_session_path, params: { user: { email: "admin@example.com", password: "nope" } }
  assert_response :unprocessable_content
end

test "sign up creates a user with default role and logs them in" do
  assert_difference("User.count", 1) do
    post user_registration_path, params: { user: { email: "New@Example.com", password: "secret123", password_confirmation: "secret123" } }
  end
  assert_equal "new@example.com", User.last.email
  assert_redirected_to root_path
end

test "duplicate email on sign up is a validation error" do
  assert_no_difference("User.count") do
    post user_registration_path, params: { user: { email: "ADMIN@example.com", password: "secret123", password_confirmation: "secret123" } }
  end
  assert_response :unprocessable_content
end

test "guest can browse books" do
  get root_path
  assert_response :success
  get book_path(books(:dune))
  assert_response :success
end

test "sign out" do
  sign_in users(:regular)
  delete destroy_user_session_path
  assert_redirected_to root_path
end
```

In `test/controllers/books_controller_test.rb`, the "guests are sent to login" test becomes "guests can see a book" (`assert_response :success`). In `test/controllers/muted_ui_test.rb`, check `new_user_session_path`, `new_user_password_path` and `new_user_registration_path`. In `test/models/user_test.rb`, replace `email_address` with `email`, drop the "downcases and strips" test (Devise's `case_insensitive_keys`/`strip_whitespace_keys` handle it), and add `assert_equal "x@example.com", User.create!(email: " X@Example.com ", password: "secret123").email`. Replace `authenticate("secret123")` in the tests with `valid_password?("secret123")`. In the API users test, change the duplicate message to `"Email has already been taken"` and the key list to `%w[created_at email id role]`.

- [ ] **Step 5: Run the tests to see them fail**

Run: `bin/rails test`
Expected: FAIL (`user_session_path` undefined, Devise modules missing).

- [ ] **Step 6: Implement**

- `User`: remove `has_secure_password`, `has_many :sessions` and `normalizes`, and add the five Devise modules. Remove the presence/uniqueness validation on email, since `validatable` provides it. Keep the role enum.
- Routes: replace `resource :session` and `resources :passwords` with `devise_for :users`.
- `ApplicationController`: remove `include Authentication`. `BooksController` stays public, with no filter.
- `Admin::BaseController`: add `before_action :authenticate_user!` and use `current_user&.admin?`.
- `Api::V1::BaseController`: add `before_action :authenticate_api_user!`, which renders `401 {"error":"Unauthorized"}` unless `user_signed_in?`. `require_admin` uses `current_user.admin?`.
- `Api::V1::UsersController`: replace `Current.user` with `current_user`. `email_address` becomes `email` in `json_options` and `user_params`.
- Old admin user form and views: use `email` instead of `email_address`, and use `valid_password?` in the tests.
- Layout navbar: when logged in, show the Admin link (if admin), `current_user.email`, and `button_to "Sign out", destroy_user_session_path, method: :delete`. When logged out, show `link_to "Sign in"` and `link_to "Sign up"`.
- Run `bin/rails g devise:views -v sessions registrations passwords`. Delete the generated views that are not used. Restyle the forms with the same classes as the old `sessions/new.html.erb` (gray, no `blue-` or `shadow-`).
- Delete the files listed under Delete.

- [ ] **Step 7: Run the tests and lint to see them pass**

Run: `bin/rails test && bin/rubocop && bin/brakeman --no-pager`
Expected: all pass, 0 offenses, 0 warnings.

- [ ] **Step 8: Manual check**

Run `bin/dev`. Sign up, sign out, and sign in with the seeded `admin@example.com`. The old seed password still works because seeds are unchanged until Task 6. Open `/admin` as admin.

- [ ] **Step 9: Commit**

```bash
git add -A && git commit -m "Replace Rails auth generator with Devise"
```

---

### Task 2: Rolify replaces the role enum

**Files:**
- Modify: `Gemfile`, `Gemfile.lock`, `app/models/user.rb`, `test/fixtures/users.yml`, `test/models/user_test.rb`
- Create: `app/models/role.rb`, `config/initializers/rolify.rb` and the roles migration (all from `bin/rails g rolify Role User`), `db/migrate/*_move_user_role_to_rolify.rb`, `test/fixtures/roles.yml`

**Interfaces:**
- Consumes: `User` from Task 1.
- Produces:
  - `User::ROLES = %w[admin user]`.
  - `User#role -> String`: `"admin"` if `has_role?(:admin)`, else `"user"`. An unsaved assigned value wins.
  - `User#role=(String)`.
  - `validates :role, inclusion: { in: ROLES }`.
  - An `after_save` that makes the user's roles exactly `[role]`. New users with no role assigned get `"user"`.
  - `User#admin? -> Boolean` (`has_role?(:admin)`).
  - The `users.role` column no longer exists.

- [ ] **Step 1: Add the gem and generate**

Add `gem "rolify", "~> 6.0"`, then run `bundle install` and `bin/rails g rolify Role User`.

- [ ] **Step 2: Write the data migration `MoveUserRoleToRolify`**

Order it after the rolify table migration. It runs SQL (no model classes) to insert the `admin` and `user` rows into `roles`. Then it inserts into `users_roles`, choosing the role by `users.role`. Then it removes `users.role`. `down` re-adds the column with `default: "user", null: false` and backfills it from `users_roles`. Run `bin/rails db:migrate` and `bin/rails db:rollback STEP=1 && bin/rails db:migrate` to prove both directions work.

- [ ] **Step 3: Update fixtures**

`test/fixtures/roles.yml` has `admin: { name: admin }` and `user: { name: user }`. In `users.yml`, remove `role:` and set `roles: admin` / `roles: user` (habtm labels).

- [ ] **Step 4: Write the failing model tests in `test/models/user_test.rb`**

```ruby
test "new users get the user role" do
  user = User.create!(email: "n@example.com", password: "secret123")
  assert_equal %w[user], user.roles.pluck(:name)
  assert_equal "user", user.role
end

test "role= replaces the role, never two" do
  user = users(:regular)
  user.update!(role: "admin")
  assert_equal %w[admin], user.reload.roles.pluck(:name)
  assert user.admin?
end

test "admin fixture is admin" do
  assert users(:admin).admin?
end

test "invalid role is a validation error" do
  user = User.new(email: "r@example.com", password: "secret123", role: "boss")
  assert_not user.valid?
  assert_includes user.errors[:role], "is not included in the list"
end
```

Remove the old `.user?` enum assertion.

- [ ] **Step 5: Run the tests to see them fail**

Run: `bin/rails test test/models/user_test.rb`
Expected: FAIL (`roles` association or `role=` behaviour missing).

- [ ] **Step 6: Implement in `User`**

Remove the `enum`. `rolify` is already added by the generator. Add `ROLES`, `role`, `role=`, the validation, the `after_save` sync and `admin?` as described in Interfaces.

- [ ] **Step 7: Run the full suite and lint**

Run: `bin/rails test && bin/rubocop && bin/brakeman --no-pager`
Expected: all pass. The API users tests (role update, invalid role 422, "cannot change own role") pass unchanged, which proves the `role` API contract is kept.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "Move user roles to Rolify"
```

---

### Task 3: Pundit authorizes the API

**Files:**
- Modify: `Gemfile`, `Gemfile.lock`, `app/controllers/application_controller.rb`, `app/controllers/api/v1/*.rb`
- Create: `app/policies/application_policy.rb` (from `bin/rails g pundit:install`), `app/policies/book_policy.rb`, `app/policies/category_policy.rb`, `app/policies/market_policy.rb`, `app/policies/user_policy.rb`, `test/policies/*_policy_test.rb`

**Interfaces:**
- Consumes: `User#admin?` from Task 2.
- Produces:
  - `ApplicationPolicy#admin?` (private): `user&.admin?`.
  - `BookPolicy`, `CategoryPolicy` and `MarketPolicy`: `index?`/`show?` → `true`, and `create?`/`update?`/`destroy?` → `admin?`.
  - `UserPolicy`: every action → `admin?`.
  - `ApplicationController#user_not_authorized`, for HTML: `redirect_back_or_to main_app.root_path, alert: "You are not authorized to perform this action."`.
  - The API base overrides it to render `403 {"error":"Forbidden"}`.

- [ ] **Step 1: Add the gem and install**

Add `gem "pundit", "~> 2.5"`, then run `bundle install` and `bin/rails g pundit:install`.

- [ ] **Step 2: Write the failing policy tests**

Write `test/policies/book_policy_test.rb`, and the same for category and market:

```ruby
test "everyone can read, only admin can write" do
  [ nil, users(:regular), users(:admin) ].each do |u|
    assert BookPolicy.new(u, books(:dune)).show?
    assert BookPolicy.new(u, Book).index?
  end
  %i[create? update? destroy?].each do |action|
    assert_not BookPolicy.new(nil, books(:dune)).public_send(action)
    assert_not BookPolicy.new(users(:regular), books(:dune)).public_send(action)
    assert BookPolicy.new(users(:admin), books(:dune)).public_send(action)
  end
end
```

Write `test/policies/user_policy_test.rb`: for `index? show? create? update? destroy?`, regular → false and admin → true.

- [ ] **Step 3: Run the tests to see them fail**

Run: `bin/rails test test/policies`
Expected: FAIL (`uninitialized constant BookPolicy`).

- [ ] **Step 4: Implement the policies and wire up the controllers**

- `ApplicationController`: `include Pundit::Authorization` and `rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized`.
- `Api::V1::BaseController`: override `user_not_authorized`, add `after_action :verify_authorized`, and delete `require_admin`.
- Each API action calls `authorize` on the record, or on the class for `index`/`create`. Remove the `before_action :require_admin` lines.
- The `users` self-delete and self-role checks stay in the controller, after `authorize`.
- Do **not** put `verify_authorized` in `ApplicationController`.

- [ ] **Step 5: Run the full suite and lint**

Run: `bin/rails test && bin/rubocop && bin/brakeman --no-pager`
Expected: all pass. The existing API tests prove the contract still holds: a non-admin write gets 403 `Forbidden`, a non-admin read of users gets 403, and a guest gets 401.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "Authorize the API with Pundit policies"
```

---

### Task 4: ActiveAdmin installed behind Devise + Pundit, Node-free CSS, old admin removed

**Files:**
- Modify: `Gemfile`, `Gemfile.lock`, `config/routes.rb`, `Procfile.dev`, `app/views/layouts/application.html.erb`, `.gitignore` (only if the generator adds build output)
- Create: `config/initializers/active_admin.rb` and `app/admin/dashboard.rb` (both generator), `app/assets/stylesheets/active_admin.css`, `tailwind-active_admin.config.mjs` (renamed from the generator's `.js`), `lib/tasks/active_admin.rake`, `app/policies/active_admin/application_policy.rb`, `test/integration/active_admin_access_test.rb`, `test/integration/storefront_assets_test.rb`
- Delete: `app/controllers/admin/`, `app/views/admin/`, `test/controllers/admin/`, and the `namespace :admin` block in routes

**Interfaces:**
- Consumes: `authenticate_user!`, `current_user` and `destroy_user_session_path` (Task 1), `User#admin?` (Task 2), `ApplicationController#user_not_authorized` (Task 3).
- Produces:
  - `ActiveAdmin::ApplicationPolicy` (`index? show? new? create? edit? update? destroy? destroy_all?` → `admin?`), plus a `Scope#resolve` that returns all records for an admin and `none` for everyone else.
  - Route helper `admin_root_path`, now provided by ActiveAdmin.
  - Rake tasks `active_admin:build_css` and `active_admin:watch_css`.
  - `app/assets/builds/active_admin.css`.

- [ ] **Step 1: Add the gem and install**

Add `gem "activeadmin", "4.0.0.beta23"`, then run `bundle install` and `bin/rails g active_admin:install --skip-users --skip-comments` followed by `bin/rails db:migrate`. Delete the old admin controllers, views, tests and the `namespace :admin` routes. In `routes.rb`, `devise_for :users` comes before `ActiveAdmin.routes(self)`.

- [ ] **Step 2: Configure the initializer**

Set these values in `config/initializers/active_admin.rb`:

| Setting | Value |
|---|---|
| `authentication_method` | `:authenticate_user!` |
| `current_user_method` | `:current_user` |
| `logout_link_path` | `:destroy_user_session_path` |
| `authorization_adapter` | `ActiveAdmin::PunditAdapter` |
| `pundit_policy_namespace` | `:active_admin` |
| `pundit_default_policy` | `"ActiveAdmin::ApplicationPolicy"` |
| `on_unauthorized_access` | `:user_not_authorized` |

- [ ] **Step 3: Write the failing access tests in `test/integration/active_admin_access_test.rb`**

```ruby
test "guest is sent to sign in" do
  get admin_root_path
  assert_redirected_to new_user_session_path
end

test "regular user is refused" do
  sign_in users(:regular)
  get admin_root_path
  assert_redirected_to root_path
  assert_equal "You are not authorized to perform this action.", flash[:alert]
end

test "admin sees the dashboard" do
  sign_in users(:admin)
  get admin_root_path
  assert_response :success
end
```

`test/integration/storefront_assets_test.rb` (Review Focus #5):

```ruby
test "storefront does not link the admin stylesheet" do
  get root_path
  assert_select "link[rel=stylesheet][href*='active_admin']", count: 0
end
```

- [ ] **Step 4: Run the tests to see them fail**

Run: `bin/rails test test/integration`
Expected: FAIL. The regular user reaches the dashboard because no policy exists yet, and the storefront links `active_admin` once the CSS is built.

- [ ] **Step 5: Implement the policy, CSS build and layout**

- `app/policies/active_admin/application_policy.rb`: as described in Interfaces.
- `active_admin.css`: `@import "tailwindcss";` followed by `@config "../../../tailwind-active_admin.config.mjs";`.
- `tailwind-active_admin.config.mjs`: get the gem path from `execSync('bundle show activeadmin')` (last line of output). Load the plugin with `const { default: activeAdminPlugin } = await import(\`${activeAdminPath}/plugin.js\`)`. Use the generator's `content` list, keep `darkMode: "selector"` and set `plugins: [activeAdminPlugin]`. If top-level `await import` isn't supported by the 4.3.4 binary, have the rake task write the absolute plugin path into an env var and import from that instead. Either way, verify the result with the real binary in Step 6.
- `lib/tasks/active_admin.rake`: `active_admin:build_css` runs `system(Tailwindcss::Ruby.executable, "-i", "app/assets/stylesheets/active_admin.css", "-o", "app/assets/builds/active_admin.css", "--minify", exception: true)`. `active_admin:watch_css` runs the same command with `--watch`. Hook the build in with `Rake::Task["tailwindcss:build"].enhance { Rake::Task["active_admin:build_css"].invoke }`.
- `Procfile.dev`: add `css_admin: bin/rails active_admin:watch_css`.
- Layout: change `stylesheet_link_tag :app` to `stylesheet_link_tag "tailwind", "application", "data-turbo-track": "reload"`.

- [ ] **Step 6: Verify the CSS build**

Run: `bin/rails tailwindcss:build && ls -l app/assets/builds/active_admin.css && grep -c '\.dark' app/assets/builds/active_admin.css`
Expected: the file exists, is larger than 50 KB, and the `.dark` count is greater than 0.

- [ ] **Step 7: Run the full suite and lint**

Run: `bin/rails test && bin/rubocop && bin/brakeman --no-pager`
Expected: all pass.

- [ ] **Step 8: Manual check**

Run `bin/dev` and check that four processes start (web, css, css_admin). As admin, `/admin` is styled and the dark mode toggle works. The storefront looks the same as before. As a regular user, `/admin` redirects with the alert.

- [ ] **Step 9: Commit**

```bash
git add -A && git commit -m "Install ActiveAdmin v4 behind Devise and Pundit"
```

---

### Task 5: ActiveAdmin resources (Book, Category, Market, User) and dashboard

**Files:**
- Create: `app/admin/books.rb`, `app/admin/categories.rb`, `app/admin/markets.rb`, `app/admin/users.rb`, `app/policies/active_admin/user_policy.rb`, `test/integration/active_admin_resources_test.rb`
- Modify: `app/admin/dashboard.rb`, `app/models/book.rb`, `app/models/category.rb`, `app/models/market.rb`, `app/models/user.rb`, `app/models/role.rb` (Ransack allowlists)

**Interfaces:**
- Consumes: `ActiveAdmin::ApplicationPolicy` (Task 4), `User#role` / `User#role=` / `User::ROLES` (Task 2).
- Produces:
  - `ActiveAdmin::UserPolicy < ActiveAdmin::ApplicationPolicy` with `destroy?` → `admin? && record != user`.
  - Ransack allowlists:

    | Model | `ransackable_attributes` | `ransackable_associations` |
    |---|---|---|
    | Book | `%w[title author category_id created_at]` | `%w[category markets]` |
    | Category | `%w[name created_at]` | none |
    | Market | `%w[name created_at]` | none |
    | User | `%w[email created_at]` | `%w[roles]` |
    | Role | `%w[name]` | none |

- [ ] **Step 1: Write the failing tests in `test/integration/active_admin_resources_test.rb`**

```ruby
test "admin opens every index" do
  sign_in users(:admin)
  [ admin_books_path, admin_categories_path, admin_markets_path, admin_users_path ].each do |path|
    get path
    assert_response :success, path
  end
end

test "regular user cannot write by URL" do
  sign_in users(:regular)
  assert_no_difference("Book.count") { delete admin_book_path(books(:dune)) }
  assert_redirected_to root_path
  assert_no_difference("Category.count") { post admin_categories_path, params: { category: { name: "X" } } }
  post batch_action_admin_books_path, params: { batch_action: "destroy", collection_selection: [ books(:dune).id ] }
  assert Book.exists?(books(:dune).id)
end

test "admin creates a book with markets" do
  sign_in users(:admin)
  post admin_books_path, params: { book: { title: "New", author: "A", category_id: categories(:fiction).id, market_ids: [ markets(:central).id ] } }
  assert_equal [ "Central" ], Book.find_by(title: "New").markets.pluck(:name)
end

test "admin creates a user with a role" do
  sign_in users(:admin)
  post admin_users_path, params: { user: { email: "aa@example.com", password: "secret123", password_confirmation: "secret123", role: "admin" } }
  assert User.find_by(email: "aa@example.com").admin?
end

test "admin edits own email without a password" do
  sign_in users(:admin)
  patch admin_user_path(users(:admin)), params: { user: { email: "boss@example.com", password: "", password_confirmation: "", role: "admin" } }
  assert_equal "boss@example.com", users(:admin).reload.email
end

test "admin cannot demote or delete themselves" do
  sign_in users(:admin)
  patch admin_user_path(users(:admin)), params: { user: { role: "user" } }
  assert users(:admin).reload.admin?
  assert_no_difference("User.count") { delete admin_user_path(users(:admin)) }
end

test "category with books cannot be deleted" do
  sign_in users(:admin)
  assert_no_difference("Category.count") { delete admin_category_path(categories(:fiction)) }
end
```
- [ ] **Step 2: Run the tests to see them fail**

Run: `bin/rails test test/integration/active_admin_resources_test.rb`
Expected: FAIL (`admin_books_path` undefined).

- [ ] **Step 3: Implement the resources**

Run `bin/rails g active_admin:resource` once each for Book, Category, Market and User, then fill them in:

- **Book:** `permit_params :title, :author, :description, :category_id, market_ids: []`, `includes :category, :markets`. Index columns: title, author, category. Filters: title, author, category. Form: category select and `markets` as check_boxes.
- **Category:** `permit_params :name`. On a failed destroy, show `resource.errors.full_messages.to_sentence` in a flash alert.
- **Market:** `permit_params :name, book_ids: []`. Form: `books` as check_boxes.
- **User:** `permit_params :email, :password, :password_confirmation, :role`, `includes :roles`. Index columns: email, role, created_at. Form: email, password (hint on edit), confirmation, and `role` as a select over `User::ROLES`. The `controller` block:
  - `update` removes blank `password`/`password_confirmation` before calling `super`.
  - If `resource == current_user` and the submitted role differs from the current role, it redirects back with `alert: "You cannot change your own role"`.
- **Dashboard:** count cards for Users, Books, Categories and Markets, plus a "Recent books" panel (last 5, linking to `admin_book_path`).
- Add the Ransack allowlists to the models, and `ActiveAdmin::UserPolicy`.

- [ ] **Step 4: Run the full suite and lint**

Run: `bin/rails test && bin/rubocop && bin/brakeman --no-pager`
Expected: all pass.

- [ ] **Step 5: Manual check**

As admin, with `bin/dev` running, do CRUD on every resource and use the filters. Check that the Delete link is missing on your own user row. Promote a regular user to admin: that user can then open `/admin`.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "Add ActiveAdmin resources for books, categories, markets and users"
```

---

### Task 6: Secrets out of seeds and Bruno; docs

**Files:**
- Modify: `db/seeds.rb`, `.gitignore`, `bruno/environments/local.yml`, `bruno/00 Auth/Get CSRF token.yml`, `bruno/00 Auth/Login as admin.yml`, `bruno/00 Auth/Login as user.yml`, `bruno/04 Users/*.yml` (those using `email_address`), `README.md`
- Create: `.env.example`, `bruno/.env.example`, `bruno/.gitignore`

**Interfaces:**
- Consumes: Devise routes (Task 1), `User#role=` (Task 2).
- Produces: the ENV contract `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `USER_EMAIL`, `USER_PASSWORD`, and in Bruno `process.env.ADMIN_PASSWORD` / `process.env.USER_PASSWORD`.

- [ ] **Step 1: Seeds**

- Start with `return unless Rails.env.development?`.
- Create the admin with `find_or_create_by!(email: ENV.fetch("ADMIN_EMAIL"))`, setting `password` to `ENV.fetch("ADMIN_PASSWORD")` and `role = "admin"`. Create the user the same way, from `USER_*`, with `role = "user"`.
- Leave the categories, books and markets seeds unchanged.
- Verify by running `bin/rails db:seed` with the vars unset. Expected: `KeyError: key not found: "ADMIN_EMAIL"`. Then export the vars and run it again. Expected: success, and running it twice is idempotent.

- [ ] **Step 2: Env files and gitignore**

- `.env.example` lists the four vars with empty values.
- Add `!/.env.example` to `.gitignore`.
- `bruno/.gitignore` contains `.env`.
- `bruno/.env.example` contains `ADMIN_PASSWORD=` and `USER_PASSWORD=`.

- [ ] **Step 3: Bruno**

- In `environments/local.yml`, remove the `password` variable.
- "Get CSRF token": `GET {{baseUrl}}/users/sign_in`.
- Both logins:
  - `POST {{baseUrl}}/users/sign_in` with the form fields `authenticity_token`, `user[email]` and `user[password]`, where the password is `{{process.env.ADMIN_PASSWORD}}` or `{{process.env.USER_PASSWORD}}`.
  - Read the `_bookstore_session` cookie, not `session_id`, into `adminCookie` / `userCookie`, and update the cookie-name test assertion to match.
- In the user requests and assertions, change `email_address` to `email`.
- Verify: with `bin/dev` running and the env set, run the whole collection in order (Bruno app or `bru run --env local`). Expected: every request passes.

- [ ] **Step 4: README**

Update these sections:
- Setup: export the vars from `.env.example` before `bin/rails db:seed`.
- Auth: Devise with sign up. Admin is `/admin` (ActiveAdmin), for the admin role only.
- Running: `bin/dev` now also runs `css_admin`.
- Bruno: copy `bruno/.env.example` to `bruno/.env`.

Remove every mention of `password` as the seed password.

- [ ] **Step 5: Final verification**

Run: `bin/rails db:drop db:create db:migrate && bin/rails db:seed && bin/rails test && bin/rubocop && bin/brakeman --no-pager && bin/importmap audit && git grep -n '"password"' -- db bruno`
Expected: everything passes, and the final `git grep` prints nothing.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "Read seed and Bruno credentials from env; update README"
```
