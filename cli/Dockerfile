# Build stage
FROM golang:1.24-alpine AS builder
RUN apk add --no-cache gcc musl-dev
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=1 go build -o oak .

# Runtime stage
FROM alpine:3.19
RUN apk add --no-cache ca-certificates sqlite
WORKDIR /app
COPY --from=builder /app/oak /app/oak
EXPOSE 8080
CMD ["/app/oak", "serve", "--host", "0.0.0.0"]
