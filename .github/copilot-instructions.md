# GitHub Copilot Instructions for Oak Compendium

## Project Overview

Oak Compendium (the Quercus Database) is a comprehensive database and query
tool for oak (*Quercus*) species and their hybrids. Live at
[oakcompendium.org](https://oakcompendium.org/).

The application is an Elixir/Phoenix LiveView app deployed to Fly.io. The
canonical project guide is `CLAUDE.md`; the conventions reference is
`CODING_STANDARDS.md`. Read those first.

## Tech Stack

- **Framework**: Phoenix 1.8+ with LiveView
- **Database**: SQLite via Ecto + ecto_sqlite3
- **HTTP Server**: Bandit
- **Styling**: Tailwind v4
- **Quality**: Credo, Dialyxir, mix format
- **Deployment**: Fly.io with Litestream (S3 replication)

## Project Structure

| Directory | What |
|---|---|
| `lib/oaks/` | Business logic contexts (species, taxonomy, sources, etc.) |
| `lib/oaks_web/` | Web layer (LiveViews, controllers, components) |
| `config/` | Phoenix configuration |
| `assets/` | JS, CSS, Tailwind |
| `priv/repo/` | Migrations, `structure.sql`, seeds |
| `test/` | Elixir tests |
| `scrapers/` | Python scripts for ingesting external data (local dev only) |
| `cli/` | Legacy Go CLI tool, frozen |
| `ios/` | iOS app source |

## Coding Guidelines

- Follow `CODING_STANDARDS.md` for Elixir/Phoenix conventions
- Always compile with `--warnings-as-errors`
- Run `mix precommit` before committing (format, compile, credo, tests)
- SQLite is the database — do not use PostgreSQL-only constructs (`ilike`,
  `array`, etc.); see CLAUDE.md for the `fragment("lower(?) LIKE ?", ...)`
  pattern

## Git Workflow

- Commit messages: present tense, imperative mood
- Never amend pushed commits; always create new commits
- Never push to `main` without explicit approval (pre-push hook blocks it)
- Stage specific files by name; do not use `git add -A` or `git add .`

## Key Documentation

- **CLAUDE.md** — Project guide (architecture, workflows, conventions)
- **CODING_STANDARDS.md** — Elixir/Phoenix conventions
- **CONTRIBUTING.md** — How to set up the project and submit a PR
