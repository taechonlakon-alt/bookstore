# Devise + Rolify + Pundit + ActiveAdmin v4: Design

**Intent:** The requirement is to use all four gems: Devise, Rolify, Pundit and ActiveAdmin v4. They replace the bookstore's hand-written auth, its role enum, its `require_admin` checks and its hand-written `/admin`. The user wants it to follow `docs/superpowers/auth-and-admin-guide.md`, written for a different Blog project, adapted to this app.

## Goals

- **Devise** replaces the Rails 8 authentication generator code (`Session`, `Current`, the `Authentication` concern, `SessionsController`, `PasswordsController`, `PasswordsMailer`).
- **Rolify** replaces the `users.role` enum.
- **Pundit** decides permissions in the API, and in ActiveAdmin through a separate `ActiveAdmin::` policy namespace.
- **ActiveAdmin v4** fully replaces the hand-written `/admin` (Books, Categories, Markets, Users, dashboard).
- Following the guide: anyone can sign up (`registerable`), guests can browse the book list and book pages without logging in, and new users get a default role automatically.

## Non-goals

- No new book features. Books get no owner, and there is no draft/published state. The guide's `author` / `Post` ownership rules do **not** apply.
- No other gems (no dotenv, no Node/npm, no cssbundling).
- The API keeps its cookie-session design. No token auth.

## Anti-goals (failures even if it "works")

- The tech stack changes: anything other than importmap, `tailwindcss-rails`, Propshaft, PostgreSQL, `bin/dev`, or a Node step in the Dockerfile.
- Existing users lose their passwords.
- A non-admin can reach any ActiveAdmin page or any admin-only API action.
- Committed passwords stay in seeds or the Bruno environment.

## Constraints

- Rails 8.1, Ruby 4.0.9, PostgreSQL, importmap-rails, tailwindcss-rails 4.7 (Tailwind standalone binary 4.3.4 via `tailwindcss-ruby`), Propshaft. Run locally with `bin/dev`. There is no Docker dev setup, so the guide's `docker compose exec web` commands become plain `bin/rails`.
- Gem versions: `devise ~> 5.0`, `rolify ~> 6.0`, `pundit ~> 2.5`, `activeadmin 4.0.0.beta23` (exact pin). `importmap-rails` is already in the Gemfile.
- Org security rule: no hardcoded credentials. Read them from ENV.

## Approaches

**Auth/admin scope** (decided by the user)
- A. ActiveAdmin replaces the old `/admin`. **Picked.**
- B. Keep both admins, with ActiveAdmin at another path. Rejected: two admins doing the same job.

**Role model** (user: "keep the stack, just the 4 gems")
- A. Guide-style `:author` role that owns books, plus a published flag. Rejected: adds domain features.
- B. `:admin` plus a default role. Regular users can only browse. **Picked.**

**ActiveAdmin CSS build** (decided by the user)
1. Build `active_admin.css` with the Tailwind standalone binary that `tailwindcss-rails` already ships. No Node. **Picked.**
2. Add `package.json` and npm only for admin CSS, as in ActiveAdmin's UPGRADING.md. Rejected: adds Node to dev and to the production Dockerfile.
3. Switch to cssbundling-rails. Rejected: changes the stack.

*Spike result (2026-11-16):* the 4.3.4 standalone binary built ActiveAdmin's `plugin.js` (it imports only `tailwindcss/plugin`, `tailwindcss/defaultTheme` and `tailwindcss/colors`) from an unpacked gem path. The output was ~98 KB with dark-mode variants and custom classes from `app/admin/**`. That spike imported the plugin by a literal absolute path. The real config has to resolve the gem path at build time (see "Left to the builder").

## Design

### Data migration (one migration, reversible where practical)
- `users.email_address` → rename to `email` (Devise default). Keep the unique index.
- `users.password_digest` → rename to `encrypted_password`. Both hold bcrypt hashes, and Devise's `database_authenticatable` (no pepper set) verifies existing `has_secure_password` hashes, so **existing users keep their passwords**.
- Add the Devise columns for the chosen modules: `reset_password_token` (unique index), `reset_password_sent_at`, `remember_created_at`.
- Run `rails g rolify Role User` to get the `roles` and `users_roles` tables. A data step gives each user `:admin` if `role == "admin"`, otherwise `:user`. Then drop `users.role`.
- Drop the `sessions` table.

### Devise
- Modules: `database_authenticatable, registerable, recoverable, rememberable, validatable`.
- `devise_for :users` comes before `ActiveAdmin.routes(self)`. `root "books#index"` stays.
- `ApplicationController`: remove `include Authentication`. `BooksController` is public (no `authenticate_user!`), matching the guide's "guest can see index/show".
- Delete: `Session`, `Current`, `concerns/authentication.rb`, `SessionsController`, `PasswordsController`, `PasswordsMailer` and its views, `app/views/sessions`, `app/views/passwords`, `test/test_helpers/session_test_helper.rb`, and the related tests. Replace every `Current.user` with `current_user`.
- Navbar (`layouts/application.html.erb`): show Sign in / Sign up when logged out. When logged in, show the email, an "Admin" link (admins only, to `admin_root_path`) and a Sign out `button_to … method: :delete`.
- Style the Devise views (`rails g devise:views`, only the views we use: sessions, registrations, passwords) with Tailwind classes, to match the current sign-in page.
- `config.mailer_sender` is read from ENV, with a harmless default such as `no-reply@bookstore.local`.

### Rolify
- Roles: `:admin` and `:user`. `after_create :assign_default_role` adds `:user` if the new user has no roles.
- `User#admin?` → `has_role?(:admin)`.
- **Exactly one role per user** (`admin` *or* `user`, never both, never none), the same as the old enum. Admins get only `:admin`.
- **API compatibility:** the user JSON and params keep a single `role` string (`"admin"` / `"user"`). `User#role` reads it from Rolify (`"admin"` if `has_role?(:admin)`, else `"user"`). `User#role=` replaces the user's roles with that one role when the user is saved. `role` is validated with `inclusion: %w[admin user]`. So the API's shape and the Bruno tests don't change, apart from `email_address` → `email`. An invalid role still gives a 422 validation error, as it does today.

### Pundit
- `ApplicationController` includes `Pundit::Authorization` and has `rescue_from Pundit::NotAuthorizedError`. For HTML it does `redirect_back_or_to main_app.root_path, alert: …`. `Api::V1::BaseController` overrides this with `403 {"error":"Forbidden"}`.
- The app's policies in `app/policies/` (`ApplicationPolicy` gets an `admin?` helper):
  - `BookPolicy`, `CategoryPolicy`, `MarketPolicy`: `index?`/`show?` true, `create?`/`update?`/`destroy?` admin only.
  - `UserPolicy`: everything admin only. The self-protection rules ("You cannot delete your own account", "You cannot change your own role") stay as checks in `Api::V1::UsersController`, with today's 422 responses and messages. This keeps the existing API test and Bruno contract unchanged.
- The API keeps today's rules: reading needs login (Devise `authenticate_user!` gives JSON `401 {"error":"Unauthorized"}`), and writing goes through `authorize`. `verify_authorized` goes on the API controllers only, never on `ApplicationController` (that would break Devise and ActiveAdmin).

### ActiveAdmin v4
- `rails g active_admin:install --skip-users --skip-comments`.
- Initializer:
  - `authentication_method = :authenticate_user!`, `current_user_method = :current_user`, `logout_link_path = :destroy_user_session_path`
  - `authorization_adapter = ActiveAdmin::PunditAdapter`, `pundit_policy_namespace = :active_admin`, `pundit_default_policy = "ActiveAdmin::ApplicationPolicy"`, `on_unauthorized_access = :user_not_authorized`
- `app/policies/active_admin/application_policy.rb`: admin-only for everything (including `destroy_all?`), with a Scope (`none` for non-admins). `ActiveAdmin::UserPolicy#destroy?` blocks deleting yourself.
- Resources, matching what the old admin could do:
  - **Book**: title, author, description, category (select), markets (checkboxes)
  - **Category**: name. Deleting one that still has books shows the existing `restrict_with_error` message.
  - **Market**: name, books (checkboxes)
  - **User**: email, password (blank on edit = unchanged), and role as a single select (`admin` / `user`) through the `role` virtual attribute. `permit_params` includes `:role`, not `role_ids`. An admin can't change their own role (controller check, flash error).
  - **Dashboard**: counts of users, books, categories and markets, plus recent books.
- Ransack allowlists (`ransackable_attributes` / `ransackable_associations`) on Book, Category, Market, User, Role. Never `encrypted_password` or the reset token.
- Delete the old `app/controllers/admin/*`, `app/views/admin/*`, `test/controllers/admin/*` and the `namespace :admin` routes. `admin_root_path` now comes from ActiveAdmin.

### ActiveAdmin CSS without Node
- `app/assets/stylesheets/active_admin.css`: `@import "tailwindcss";` + `@config "../../../tailwind-active_admin.config.mjs";`
- `tailwind-active_admin.config.mjs` resolves the activeadmin gem path at build time and loads `plugin.js` from it. `content` covers the gem's views and `flowbite.js`, plus `app/admin/**` and `app/views/active_admin/**`. `darkMode: "selector"`.
- `lib/tasks/active_admin.rake`:
  - `active_admin:build_css` runs `Tailwindcss::Ruby.executable -i … -o app/assets/builds/active_admin.css --minify` and is hooked into `tailwindcss:build`, so `assets:precompile` and the Dockerfile build it with no changes.
  - `active_admin:watch_css` does the same with `--watch`.
- `Procfile.dev`: add `css_admin: bin/rails active_admin:watch_css`.
- Layout: `stylesheet_link_tag :app` would also pull `builds/active_admin.css` into the storefront, so it gets explicit names: `stylesheet_link_tag "tailwind", "application"`.

### Secrets / seeds / Bruno
- `db/seeds.rb` reads `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `USER_EMAIL` and `USER_PASSWORD` with `ENV.fetch`, so a missing value fails loudly. It runs only in development. The categories, books and markets seeds stay as they are.
- There's no dotenv, so the README says to export these vars in the shell (or a git-ignored `.env` sourced by hand). Add `.env.example` with empty values, and add `!/.env.example` to `.gitignore`, since `/.env*` currently ignores it.
- Bruno: the login flow changes to `GET /users/sign_in` (CSRF token) and `POST /users/sign_in` with `user[email]` / `user[password]`. The password comes from a git-ignored `bruno/.env` (`{{process.env.…}}`), not the committed `environments/local.yml`. Requests and assertions that use `email_address` change to `email`.
- ⚠️ The current seeds and the Bruno environment have the password `"password"` committed. Remove it in this work. The user confirmed (2026-11-16) that it was only ever used for local dev, so **no git-history rewrite**. It is removed going forward only.

### Tests
- `test_helper`: `Devise::Test::IntegrationHelpers` replaces `SessionTestHelper`.
- Fixtures: `users.yml` uses `email` + `encrypted_password: <%= Devise::Encryptor.digest(User, "password") %>` (test-only value). Add `roles.yml` (admin, user), and link users to roles through the habtm label (`roles: admin`).
- Update the API controller tests (`email`, sign-in helper). Add policy tests (`test/policies/`) and ActiveAdmin integration tests: guest → redirected to sign in, regular user → refused, admin → 200 on each resource index. Update the sessions/passwords tests to Devise flows, or delete them where they only tested the removed code.
- `bin/rails test`, `bin/rubocop` and `bin/brakeman` must pass.

## Calls made by Claude (user can flip)

- Rename `email_address` → `email` instead of configuring Devise's `authentication_keys`. This follows the guide and Devise conventions, but it changes the API's JSON key.
- The API keeps a single `role` string, mapped onto Rolify.
- The default role is named `:user` (continuity with the old enum value).
- Exactly one role per user. ActiveAdmin uses a single role select, not checkboxes.
- Self-delete and self-role-change stay as 422 controller checks in the API, so the existing API contract is kept. In ActiveAdmin, `ActiveAdmin::UserPolicy#destroy?` hides and blocks deleting yourself.
- Seeds also create a regular user from ENV, so Bruno's "login as user" keeps working.

## Left to the builder

- The exact way `tailwind-active_admin.config.mjs` gets the gem path: `execSync('bundle show activeadmin')` with a dynamic `await import()`, or an ENV var set by the rake task. Verify it with the real binary.
- Devise flash/redirect details, and the Tailwind styling of the Devise views.
- The commit breakdown. The guide's order (Devise → Rolify → Pundit → ActiveAdmin) is the natural sequence, and the app should stay working after each gem.
