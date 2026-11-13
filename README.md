# Bookstore

A Rails 8 bookstore app. Signed-in users browse and search a book catalog. Admins manage books, categories, markets (stores that stock books), and users through an admin panel and a JSON API.

## Features

- **Catalog**: list books, search by title, and filter by category (`/books`)
- **Admin panel**: CRUD for books, categories, and markets, plus user creation (`/admin`)
- **JSON API**: `/api/v1` endpoints for books, categories, markets, and users
- **Authentication**: Rails 8 built-in sessions and password reset, with `user` and `admin` roles

## Tech stack

| Area | Choice |
| --- | --- |
| Language / framework | Ruby 4.0.9, Rails 8.1 |
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
bin/setup            # installs gems, prepares the database, starts the server
bin/rails db:seed    # loads sample users, categories, books, and markets
```

`bin/setup` finishes by starting the dev server. To set up without starting the server, run `bin/setup --skip-server`.

By default the app connects to PostgreSQL over a local socket as your OS user. If your database needs a username, password, or host, set `DATABASE_URL` instead of editing `config/database.yml`:

```bash
export DATABASE_URL=postgres://<user>:<password>@localhost:5432
```

### Run the app

```bash
bin/dev
```

This starts the Rails server and the Tailwind watcher (see `Procfile.dev`). Open <http://localhost:3000>.

### Seed accounts

`db/seeds.rb` creates two **development-only** accounts:

| Role | Email | Password |
| --- | --- | --- |
| Admin | `admin@example.com` | `password` |
| User | `user@example.com` | `password` |

Never run these seeds against a production database.

## Usage

### Web

| Path | Who | What |
| --- | --- | --- |
| `/session/new` | Everyone | Sign in |
| `/books` | Signed-in users | Browse, search, and filter books |
| `/admin` | Admins | Manage books, categories, markets, and users |
| `/up` | Everyone | Health check (200 when the app boots) |

### JSON API

All endpoints live under `/api/v1` and use the same session cookie as the web app, so sign in through `POST /session` first.

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
2. Open `bruno/` in Bruno (or the VS Code extension) and select the `local` environment.
3. Run the collection in order, starting with `00 Auth`.

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
    admin/        # admin panel (requires admin role)
    api/v1/       # JSON API
    concerns/     # authentication
  models/         # Book, Category, Market, MarketBook, User, Session
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
