# Oak Compendium API Server Makefile

# Binary name
BINARY := oak-api

# Version information
VERSION ?= dev
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build flags
LDFLAGS := -ldflags "-X main.Version=$(VERSION) -X main.GitCommit=$(GIT_COMMIT) -X main.BuildDate=$(BUILD_DATE)"

# Go settings
GOBIN ?= $(shell go env GOPATH)/bin

.PHONY: all build lint test test-coverage clean setup docker-build

# Default target
all: lint test build

# Build the binary
build:
	CGO_ENABLED=1 go build $(LDFLAGS) -o $(BINARY) .

# Run linter
lint:
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
	elif [ -f $(GOBIN)/golangci-lint ]; then \
		$(GOBIN)/golangci-lint run ./...; \
	else \
		echo "golangci-lint not found, skipping lint"; \
	fi

# Run tests
test:
	go test -v ./...

# Run tests with coverage
test-coverage:
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"

# Clean build artifacts
clean:
	rm -f $(BINARY) coverage.out coverage.html

# Setup development tools
setup:
	@echo "Installing development tools..."
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install golang.org/x/tools/cmd/goimports@latest

# Build Docker image
docker-build:
	docker build -t oak-api:$(VERSION) -f Dockerfile ..

# Run the server locally (for development)
run: build
	OAK_DB_PATH=../cli/oak_compendium.db ./$(BINARY)

# Check all (lint + test)
check: lint test

# Tidy dependencies
tidy:
	go mod tidy

# Verify dependencies
verify:
	go mod verify

# Show help
help:
	@echo "Oak Compendium API Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make              Build with lint and test"
	@echo "  make build        Build the oak-api binary"
	@echo "  make lint         Run golangci-lint"
	@echo "  make test         Run tests"
	@echo "  make test-coverage Run tests with coverage report"
	@echo "  make clean        Remove build artifacts"
	@echo "  make setup        Install development tools"
	@echo "  make docker-build Build Docker image"
	@echo "  make run          Build and run locally"
	@echo "  make check        Run lint and tests"
	@echo "  make tidy         Run go mod tidy"
	@echo "  make verify       Verify module dependencies"
