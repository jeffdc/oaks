# Oak Compendium - Top-level Makefile
#
# Phoenix/LiveView app with legacy Go API, CLI, and Svelte web components

.PHONY: dev dev-phx dev-api dev-web test test-db setup format lint precommit ci build clean download-db help

# =============================================================================
# Phoenix Development (primary)
# =============================================================================

# Start Phoenix dev server on :4000 (auto-installs deps on first run)
dev: setup
	mix phx.server

# Alias for clarity
dev-phx: dev

# =============================================================================
# Legacy Components (Go API + Svelte web)
# =============================================================================

# Start Go API server on :8080
dev-api:
	cd api && $(MAKE) run

# Start Svelte web dev server on :5173 (connects to local API)
dev-web:
	cd web && npm run dev:local

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

# Run legacy Go tests
test-go:
	cd api && $(MAKE) test
	cd cli && $(MAKE) test

# Run legacy Svelte tests
test-web:
	cd web && npm test

# Run all tests across all components
test-all: test test-go test-web

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

# Build legacy Go components
build-go:
	cd api && $(MAKE) build
	cd cli && $(MAKE) build

# =============================================================================
# Database
# =============================================================================

# Download database from Fly.io (overwrites local copy)
# The Fly.io database is the authoritative source of truth
download-db:
	@echo "Downloading database from Fly.io..."
	@fly ssh sftp get /data/oak_compendium.db oaks.db --app oak-compendium-api
	@echo "Database downloaded to oaks.db"

# =============================================================================
# Cleanup
# =============================================================================

# Clean Phoenix build artifacts
clean:
	rm -rf _build deps priv/static/assets

# Clean everything including legacy components
clean-all: clean
	cd api && $(MAKE) clean
	cd cli && $(MAKE) clean
	cd web && rm -rf dist .svelte-kit node_modules

# =============================================================================
# Help
# =============================================================================

help:
	@echo "Oak Compendium Makefile"
	@echo ""
	@echo "Phoenix Development:"
	@echo "  make dev        Start Phoenix dev server (:4000)"
	@echo "  make setup      Full setup (deps + assets + db check)"
	@echo "  make test       Run Phoenix tests (rebuilds test DB)"
	@echo "  make test-db    Rebuild test database from structure.sql + seeds"
	@echo "  make format     Format Elixir code"
	@echo "  make lint       Run Credo linter"
	@echo "  make precommit  Run all pre-commit checks"
	@echo "  make ci         Run full CI checks (precommit + assets + dialyzer)"
	@echo "  make build      Build production release"
	@echo ""
	@echo "Legacy Components:"
	@echo "  make dev-api    Start Go API server (:8080)"
	@echo "  make dev-web    Start Svelte web dev server (:5173)"
	@echo "  make test-go    Run Go tests (api + cli)"
	@echo "  make test-web   Run Svelte tests"
	@echo "  make test-all   Run all tests across all components"
	@echo "  make build-go   Build Go binaries"
	@echo ""
	@echo "Database:"
	@echo "  make download-db  Download database from Fly.io"
	@echo ""
	@echo "Other:"
	@echo "  make clean       Clean Phoenix build artifacts"
	@echo "  make clean-all   Clean everything including legacy components"
