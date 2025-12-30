# Oak CLI Makefile

.PHONY: build lint test check clean setup help

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

# Install development tools
setup:
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install golang.org/x/tools/cmd/goimports@latest

# Show help
help:
	@echo "Available targets:"
	@echo "  build          Build the oak binary"
	@echo "  lint           Run golangci-lint"
	@echo "  test           Run tests"
	@echo "  test-coverage  Run tests with coverage report"
	@echo "  check          Run lint + test"
	@echo "  clean          Remove build artifacts"
	@echo "  setup          Install development tools"
