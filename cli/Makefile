# Oak CLI Makefile

.PHONY: build lint test check clean help

# Default target
all: build

# Build the CLI binary
build:
	go build -o oak .

# Run linter
lint:
	golangci-lint run

# Run tests
test:
	go test ./...

# Run tests with coverage
test-coverage:
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

# Run all checks (lint + test)
check: lint test

# Clean build artifacts
clean:
	rm -f oak coverage.out coverage.html

# Show help
help:
	@echo "Available targets:"
	@echo "  build          Build the oak binary"
	@echo "  lint           Run golangci-lint"
	@echo "  test           Run tests"
	@echo "  test-coverage  Run tests with coverage report"
	@echo "  check          Run lint + test"
	@echo "  clean          Remove build artifacts"
