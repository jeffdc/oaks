# Contributing to Oak Compendium

Thank you for your interest in contributing! This document covers how to get
the project running locally and the conventions for submitting changes.

## How to Contribute

### Reporting Bugs

Open an issue with:
- A clear, descriptive title
- Steps to reproduce
- Expected vs. actual behavior
- Your environment (OS, Elixir/OTP version)
- Relevant logs or error messages

### Suggesting Enhancements

Open an issue with:
- A clear description of the enhancement
- Why it would be useful
- Any implementation ideas you have

### Pull Requests

1. **Fork the repository** and create a branch from `main`
2. **Make your changes** following the conventions in `CODING_STANDARDS.md`
3. **Run the quality gate** before pushing:
   ```bash
   mix precommit
   ```
4. **Submit a pull request** referencing any related issues

## Development Setup

Requirements:
- Elixir 1.17+ / OTP 27+
- SQLite 3
- Node.js (for asset tooling)

```bash
# Clone your fork
git clone https://github.com/yourusername/oaks.git
cd oaks

# Install deps, set up DB, build assets
mix setup

# Start the dev server at http://localhost:4444
mix phx.server
```

## Code Style

- Run `mix format` before committing
- Run `mix credo --strict` and `mix dialyzer` and address findings
- Follow Elixir/Phoenix conventions documented in `CODING_STANDARDS.md`
- Keep functions small and focused
- Use the database via Ecto; remember the project uses **SQLite**, not
  PostgreSQL — see `CLAUDE.md` for the SQLite-compatible query patterns

## Testing

```bash
mix test                           # Run all tests
mix test test/path/to/test.exs     # Run a specific file
mix test test/path/to/test.exs:42  # Run a specific test
```

The test suite uses a separate `priv/oaks_test.sqlite` database built from
`priv/repo/structure.sql` plus `priv/repo/test_seeds.sql`. See `CLAUDE.md`
for instructions on rebuilding the test database if you change the schema
or seeds.

## Commit Message Guidelines

- Use present tense, imperative mood ("Add feature", not "Added feature")
- Limit the first line to 72 characters
- Reference related issues in the body when relevant

## Questions?

Open an issue for any questions about contributing.
