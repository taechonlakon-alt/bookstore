# Bookstore

A Rails 8 bookstore app. Signed-in users browse and search a book catalog. Admins manage books, categories, markets (stores that stock books), and users through an ActiveAdmin panel and a JSON API.

## Features

- **Catalog**: list books, search by title, and filter by category (`/books`)
- **Admin panel**: ActiveAdmin at `/admin` for books, categories, markets, and users (admin role only)
- **JSON API**: `/api/v1` endpoints for books, categories, markets, and users
- **Authentication**: Devise (sign up, sign in, password reset), Rolify for the `user` and `admin` roles, and Pundit for authorization

## Tech stack

| Area | Choice |
| --- | --- |
| Language / framework | Ruby 4.0.9, Rails 8.1 |
| Auth | Devise, Rolify, Pundit, ActiveAdmin v4 |
| Database | PostgreSQL |
| Frontend | Hotwire (Turbo + Stimulus), Tailwind CSS, import maps |
| Background jobs / cache / cable | Solid Queue, Solid Cache, Solid Cable |
| Deployment | Docker + Kamal |

## Getting started

### Prerequisites

- Ruby 4.0.9 (see `.ruby-version`)
- PostgreSQL 9.5 or later, running locally
- `libvips` (for Active Storage image variants)

### Setup

```bash
git clone https://github.com/taechonlakon-alt/bookstore.git
cd bookstore
cp .env.example .env      # then fill in the four values (see "Seed accounts")
set -a; source .env; set +a
bin/setup --skip-server   # installs gems, prepares the database, seeds a new one
bin/rails db:seed         # re-run any time to (re)load sample data
```

Set the variables before `bin/setup`: when it creates a new database, Rails seeds it, and the seeds need them. The app has no dotenv, so `source .env` is what puts the variables in your shell. `.env` is git-ignored. `bin/setup` normally ends by starting the dev server; `--skip-server` stops that.

By default the app connects to PostgreSQL over a local socket as your OS user. If your database needs a username, password, or host, set `DATABASE_URL` instead of editing `config/database.yml`:

```bash
export DATABASE_URL=postgres://<user>:<password>@localhost:5432
```

### Run the app

```bash
bin/dev
```

This starts the Rails server, the Tailwind watcher (`css`), and the ActiveAdmin stylesheet watcher (`css_admin`). See `Procfile.dev`. Open <http://localhost:3000>.

### Seed accounts

`db/seeds.rb` creates two **development-only** accounts. It does nothing outside the development environment, and it reads their credentials from the environment, so no password is committed:

| Variable | Used for |
| --- | --- |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | The admin account |
| `USER_EMAIL`, `USER_PASSWORD` | The regular user account |

Choose your own values in `.env` (copy `.env.example`). Passwords need at least 6 characters. If a variable is missing, `bin/rails db:seed` fails with a `KeyError`. Seeding is idempotent: an existing account keeps its current password, and only its role is re-applied.

## Usage

### Web

| Path | Who | What |
| --- | --- | --- |
| `/users/sign_in` | Everyone | Sign in |
| `/users/sign_up` | Everyone | Create a `user` account |
| `/books` | Signed-in users | Browse, search, and filter books |
| `/admin` | Admins | ActiveAdmin panel for books, categories, markets, and users |
| `/up` | Everyone | Health check (200 when the app boots) |

### JSON API

All endpoints live under `/api/v1` and use the same session cookie (`_bookstore_session`) as the web app, so sign in through the Devise form (`POST /users/sign_in`) first. Sign-in is rate limited to 10 attempts per 3 minutes per IP.

| Resource | Read (`GET`) | Write (`POST` / `PATCH` / `DELETE`) |
| --- | --- | --- |
| `books` | Any signed-in user | Admin only |
| `categories` | Any signed-in user | Admin only |
| `markets` | Any signed-in user | Admin only |
| `users` | Admin only | Admin only |

Error responses:

- `401 {"error": "Unauthorized"}` when not signed in
- `403 {"error": "Forbidden"}` when a non-admin calls an admin-only endpoint
- `404 {"error": "... not found"}` for an unknown record
- `422 {"errors": [...]}` for validation failures

Example response for `GET /api/v1/books/1`:

```json
{
  "id": 1,
  "title": "Dune",
  "author": "Frank Herbert",
  "description": "A noble family fights for control of the desert planet Arrakis.",
  "category": { "id": 1, "name": "Fiction" },
  "markets": [{ "id": 1, "name": "Central Market" }]
}
```

### API tests with Bruno

The `bruno/` folder is a [Bruno](https://www.usebruno.com/) collection that covers auth, CRUD for each resource, and permission checks. To run it:

1. Start the app with `bin/dev` and seed the database.
2. Copy `bruno/.env.example` to `bruno/.env` and give it the same four values as your root `.env`: `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `USER_EMAIL` and `USER_PASSWORD`. `bruno/.env` is git-ignored. Bruno reads it as `process.env`, and the `local` environment holds no emails or passwords.
3. Open `bruno/` in Bruno (or the VS Code extension) and select the `local` environment.
4. Run the collection in order, starting with `00 Auth`. From a terminal: `cd bruno && bru run --env local`.

Sign-in is rate limited, so avoid running the collection more than a few times in 3 minutes (each run signs in twice).

## Development

### Tests

```bash
bin/rails db:test:prepare test
```

Tests use Minitest with fixtures in `test/fixtures`.

### Checks

These run in CI (`.github/workflows/ci.yml`) on every pull request and push to `main`:

```bash
bin/rubocop          # style (rubocop-rails-omakase)
bin/brakeman         # Rails security static analysis
bin/bundler-audit    # known vulnerabilities in gems
bin/importmap audit  # known vulnerabilities in JS dependencies
```

Run `bin/ci` to run the full local CI suite in one go.

### Coding standards

Read [CODING_STANDARDS.md](CODING_STANDARDS.md) before you open a pull request.

## Project structure

```
app/
  controllers/
    api/v1/       # JSON API
    users/        # Devise controllers (sessions, passwords)
    concerns/
  admin/          # ActiveAdmin resources (admin role only)
  models/         # Book, Category, Market, MarketBook, User, Role
  policies/       # Pundit policies
  views/
bruno/            # Bruno API test collection
config/deploy.yml # Kamal deployment config
db/seeds.rb       # sample data
test/             # Minitest suite
```

## Deployment

The app ships with a `Dockerfile` and a Kamal config (`config/deploy.yml`). Production needs `RAILS_MASTER_KEY` to decrypt `config/credentials.yml.enc`. Pass it through Kamal secrets (`.kamal/secrets`) or your environment, and never commit it.

```bash
bin/kamal setup    # first deploy
bin/kamal deploy   # later deploys
```
