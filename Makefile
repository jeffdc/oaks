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

# Set up fresh test database from migrations + test_seeds.sql
test-db:
	@echo "Setting up test database..."
	@rm -f priv/oaks_test.sqlite*
	@MIX_ENV=test mix ecto.create --quiet
	@MIX_ENV=test mix ecto.migrate --quiet
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

# Restore the latest production database from the Litestream replica in S3
# (overwrites the local oaks.db). Reads S3 only; never touches the Fly machine.
# The Fly.io database is the authoritative source of truth.
#
# Needs S3 read access to the bucket via LITESTREAM_ACCESS_KEY_ID /
# LITESTREAM_SECRET_ACCESS_KEY (or AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY).
#
# Production replicates with Litestream 0.3.x; 0.5+ uses an incompatible
# replica format, so a pinned 0.3 binary is fetched into bin/. 0.3.14 has no
# macOS builds, so macOS uses 0.3.13 (same replica format).
LITESTREAM_REPLICA := s3://oaks-db-backups/litestream
LITESTREAM_BIN := bin/litestream-0.3

download-db: $(LITESTREAM_BIN)
	@echo "Restoring latest production database from $(LITESTREAM_REPLICA)..."
	@rm -f /tmp/oaks-restore.db /tmp/oaks-restore.db-*
	$(LITESTREAM_BIN) restore -o /tmp/oaks-restore.db $(LITESTREAM_REPLICA)
	@sqlite3 /tmp/oaks-restore.db "PRAGMA integrity_check;" | grep -qx ok || { \
		echo "ERROR: Restored database failed integrity check"; exit 1; }
	@sqlite3 /tmp/oaks-restore.db "SELECT count(*) FROM species;" | grep -qE '^[1-9]' || { \
		echo "ERROR: Restored database has no species"; exit 1; }
	@# Drop any WAL/SHM left from the old local copy so SQLite can't replay them onto the new file.
	@rm -f oaks.db-wal oaks.db-shm
	@mv /tmp/oaks-restore.db oaks.db
	@echo "Database restored to oaks.db ($$(sqlite3 oaks.db 'SELECT count(*) FROM species;') species)"

$(LITESTREAM_BIN):
	@mkdir -p bin
	@case "$$(uname -s)-$$(uname -m)" in \
	  Darwin-arm64)  url=https://github.com/benbjohnson/litestream/releases/download/v0.3.13/litestream-v0.3.13-darwin-arm64.zip; \
	                 sha=6d1689487432613f5c10aee75ee77c95250dcce4da49695bf0a448c794eb7daa ;; \
	  Darwin-x86_64) url=https://github.com/benbjohnson/litestream/releases/download/v0.3.13/litestream-v0.3.13-darwin-amd64.zip; \
	                 sha=6f68536bd24a0b6c4fdefb2f91ba27332e2146fb9f1be7985adfee8cdfce9784 ;; \
	  Linux-x86_64)  url=https://github.com/benbjohnson/litestream/releases/download/v0.3.14/litestream-v0.3.14-linux-amd64.tar.gz; \
	                 sha=880ccafc9514650c4a2a0cc78eb1e61aaad95dd3e86e877c8694f955c9095436 ;; \
	  Linux-aarch64) url=https://github.com/benbjohnson/litestream/releases/download/v0.3.14/litestream-v0.3.14-linux-arm64.tar.gz; \
	                 sha=4d375a66653e4a9b27a5b38ce9cb73681c39893ba0485f81ab860d4cd427e642 ;; \
	  *) echo "Unsupported platform: $$(uname -s)-$$(uname -m)"; exit 1 ;; \
	esac; \
	tmp=$$(mktemp -d); \
	curl -fsSL -o "$$tmp/pkg" "$$url" && \
	echo "$$sha  $$tmp/pkg" | shasum -a 256 -c - >/dev/null && \
	case "$$url" in \
	  *.zip) unzip -q -o "$$tmp/pkg" litestream -d "$$tmp" ;; \
	  *)     tar -xzf "$$tmp/pkg" -C "$$tmp" litestream ;; \
	esac && \
	mv "$$tmp/litestream" $(LITESTREAM_BIN) && chmod +x $(LITESTREAM_BIN); \
	status=$$?; rm -rf "$$tmp"; exit $$status
	@echo "Installed $$($(LITESTREAM_BIN) version) at $(LITESTREAM_BIN)"

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
	@echo "  make test-db    Rebuild test database from migrations + seeds"
	@echo "  make format     Format Elixir code"
	@echo "  make lint       Run Credo linter"
	@echo "  make precommit  Run all pre-commit checks"
	@echo "  make ci         Run full CI checks (precommit + assets + dialyzer)"
	@echo "  make build      Build production release"
	@echo ""
	@echo "Database:"
	@echo "  make download-db  Restore latest prod database from the Litestream S3 replica"
	@echo ""
	@echo "Other:"
	@echo "  make clean       Clean Phoenix build artifacts"
