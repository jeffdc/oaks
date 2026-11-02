# Oaks - Phoenix Dockerfile
# Multi-stage build for Phoenix release with Litestream

# Stage 1: Build Elixir release
# Keep the builder's Alpine version identical to the runtime stage below:
# the release links against that Alpine's OpenSSL and musl.
FROM hexpm/elixir:1.17.3-erlang-27.3.4.19-alpine-3.24.3 AS builder

# Install build dependencies
RUN apk add --no-cache build-base git

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy application code
COPY lib lib
COPY priv priv
COPY assets assets

# Copy release overlays (server, migrate scripts)
COPY rel rel

# Copy runtime config
COPY config/runtime.exs config/

# Compile first (needed for colocated hooks)
RUN mix compile

# Build assets (esbuild + tailwind are installed via mix)
RUN mix assets.deploy

# Build the release
RUN mix release

# Stage 2: Runtime
FROM alpine:3.24.3 AS runtime

# Runtime dependencies
RUN apk add --no-cache libstdc++ openssl ncurses-libs sqlite su-exec

# Install Litestream for continuous SQLite replication, verifying the
# download against the release's published SHA-256 digests.
# TARGETARCH is set by BuildKit from the build platform; it must not have a
# default here or it would override that. Fall back to amd64 (Fly) if unset.
ARG LITESTREAM_VERSION=v0.3.14
ARG TARGETARCH
RUN arch="${TARGETARCH:-amd64}" && \
    case "$arch" in \
      amd64) sha=880ccafc9514650c4a2a0cc78eb1e61aaad95dd3e86e877c8694f955c9095436 ;; \
      arm64) sha=4d375a66653e4a9b27a5b38ce9cb73681c39893ba0485f81ab860d4cd427e642 ;; \
      *) echo "Unsupported architecture: $arch" && exit 1 ;; \
    esac && \
    wget -qO /tmp/litestream.tar.gz \
      "https://github.com/benbjohnson/litestream/releases/download/${LITESTREAM_VERSION}/litestream-${LITESTREAM_VERSION}-linux-${arch}.tar.gz" && \
    echo "$sha  /tmp/litestream.tar.gz" | sha256sum -c - && \
    tar -C /usr/local/bin -xzf /tmp/litestream.tar.gz && \
    rm /tmp/litestream.tar.gz

WORKDIR /app

# Create non-root user
RUN addgroup -g 1000 oaks && \
    adduser -u 1000 -G oaks -s /bin/sh -D oaks

# Copy release from builder
COPY --from=builder --chown=oaks:oaks /app/_build/prod/rel/oaks ./
COPY --chown=oaks:oaks litestream.yml /etc/litestream.yml

# Create data directory
RUN mkdir -p /data && chown oaks:oaks /data

# Copy entrypoint script (runs as root to fix permissions, then drops to oaks)
COPY --chmod=755 docker-entrypoint.sh /app/docker-entrypoint.sh

ENV HOME=/app
ENV DATABASE_PATH=/data/oaks.db

EXPOSE 4000

# Run entrypoint as root - it fixes permissions then drops to oaks user
CMD ["/app/docker-entrypoint.sh"]
