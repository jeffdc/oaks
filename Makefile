# Oaks - Top-level Makefile

.PHONY: dev dev-phx test test-db setup format lint precommit ci build clean download-db help

# =============================================================================
# Phoenix Development (primary)
# =============================================================================

# Start Phoenix dev server on :4444 (auto-installs deps on first run)
dev: setup
	mix phx.server

# Alias for clarity
dev-phx: dev

# =============================================================================
# Setup & Dependencies
# =============================================================================

# Full setup: deps + assets + verify database exists
setup:
	mix setup

# Install Elixir dependencies
deps:
	mix deps.get

# =============================================================================
# Testing
# =============================================================================

# Set up fresh test database from structure.sql + test_seeds.sql
test-db:
	@echo "Setting up test database..."
	@rm -f priv/oaks_test.sqlite*
	@MIX_ENV=test mix ecto.create --quiet
	@MIX_ENV=test mix ecto.load --quiet
	@sqlite3 priv/oaks_test.sqlite < priv/repo/test_seeds.sql
	@echo "Test database ready"

# Run Phoenix tests (rebuilds test DB first)
test: test-db
	mix test

# =============================================================================
# Code Quality
# =============================================================================

# Format Elixir code
format:
	mix format

# Run Credo linter
lint:
	mix credo --strict

# Pre-commit checks (format, compile, credo, tests)
precommit:
	mix precommit

# Full CI checks (precommit + assets + dialyzer)
ci:
	@echo "==> Running precommit checks (format, compile, credo, tests)..."
	mix precommit
	@echo ""
	@echo "==> Building assets (validates JS/CSS bundling)..."
	mix assets.deploy
	@echo "==> Running Dialyzer..."
	mix dialyzer
	@echo "==> All CI checks passed!"

# =============================================================================
# Build & Release
# =============================================================================

# Build production release
build:
	MIX_ENV=prod mix compile
	MIX_ENV=prod mix assets.deploy
	MIX_ENV=prod mix release --overwrite

# =============================================================================
# Database
# =============================================================================

# Download database from Fly.io (overwrites local copy)
# The Fly.io database is the authoritative source of truth
download-db:
	@echo "Downloading database from Fly.io..."
	@fly ssh sftp get /data/oaks.db oaks.db --app oaks
	@echo "Database downloaded to oaks.db"

# =============================================================================
# Cleanup
# =============================================================================

# Clean Phoenix build artifacts
clean:
	rm -rf _build deps priv/static/assets

# =============================================================================
# Help
# =============================================================================

help:
	@echo "Oaks Makefile"
	@echo ""
	@echo "Phoenix Development:"
	@echo "  make dev        Start Phoenix dev server (:4444)"
	@echo "  make setup      Full setup (deps + assets + db check)"
	@echo "  make test       Run Phoenix tests (rebuilds test DB)"
	@echo "  make test-db    Rebuild test database from structure.sql + seeds"
	@echo "  make format     Format Elixir code"
	@echo "  make lint       Run Credo linter"
	@echo "  make precommit  Run all pre-commit checks"
	@echo "  make ci         Run full CI checks (precommit + assets + dialyzer)"
	@echo "  make build      Build production release"
	@echo ""
	@echo "Database:"
	@echo "  make download-db  Download database from Fly.io"
	@echo ""
	@echo "Other:"
	@echo "  make clean       Clean Phoenix build artifacts"
