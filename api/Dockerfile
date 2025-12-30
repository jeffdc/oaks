# Build stage
FROM golang:1.24-alpine AS builder
RUN apk add --no-cache gcc musl-dev git

WORKDIR /app

# Copy go.mod and go.sum first for better layer caching
COPY api/go.mod api/go.sum ./
RUN go mod download

# Copy source code
COPY api/ .

# Build with version info
ARG VERSION=dev
RUN CGO_ENABLED=1 go build \
    -ldflags "-X main.Version=${VERSION} -X main.GitCommit=$(git rev-parse --short HEAD 2>/dev/null || echo unknown) -X main.BuildDate=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -o oak-api .

# Runtime stage
FROM alpine:3.19
RUN apk add --no-cache ca-certificates sqlite

WORKDIR /app
COPY --from=builder /app/oak-api /app/oak-api

EXPOSE 8080
CMD ["/app/oak-api"]
