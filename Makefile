# Oak Compendium - Top-level Makefile
#
# Coordinates development across all components:
#   - api/  - Go REST API server
#   - cli/  - Go command-line tool
#   - web/  - Svelte PWA

.PHONY: dev dev-api dev-web build build-api build-cli test clean help

# Start both API and web dev servers
# API runs on :8080, web on :5173
# Ctrl+C kills both
dev:
	@echo "Starting API server on http://localhost:8080"
	@echo "Starting web dev server on http://localhost:5173"
	@echo "Press Ctrl+C to stop both..."
	@trap 'kill 0' INT; \
		(cd api && $(MAKE) run) & \
		(cd web && npm run dev:local) & \
		wait

# Start only the API server
dev-api:
	cd api && $(MAKE) run

# Start only the web dev server (connects to local API)
dev-web:
	cd web && npm run dev:local

# Build all components
build: build-api build-cli
	cd web && npm run build

# Build API server
build-api:
	cd api && $(MAKE) build

# Build CLI tool
build-cli:
	cd cli && $(MAKE) build

# Run all tests
test:
	cd api && $(MAKE) test
	cd cli && $(MAKE) test
	cd web && npm test

# Clean all build artifacts
clean:
	cd api && $(MAKE) clean
	cd cli && $(MAKE) clean
	cd web && rm -rf dist .svelte-kit

# Show help
help:
	@echo "Oak Compendium Makefile"
	@echo ""
	@echo "Development:"
	@echo "  make dev        Start API (:8080) and web (:5173) together"
	@echo "  make dev-api    Start only the API server"
	@echo "  make dev-web    Start only the web dev server"
	@echo ""
	@echo "Building:"
	@echo "  make build      Build all components"
	@echo "  make build-api  Build API server only"
	@echo "  make build-cli  Build CLI tool only"
	@echo ""
	@echo "Other:"
	@echo "  make test       Run all tests"
	@echo "  make clean      Clean build artifacts"
