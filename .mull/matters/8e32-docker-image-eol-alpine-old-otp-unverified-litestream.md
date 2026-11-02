---
status: done
tags: [p2, ops]
effort: S
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
---

# Docker image: EOL Alpine, old OTP, unverified Litestream

Dockerfile:5,51,57: runtime alpine:3.20 (EOL ~Apr 2026); builder OTP 27.1.2; Litestream v0.3.13 via ADD with no checksum, amd64 hard-coded. Move to current alpine + matching hexpm/elixir image; verify litestream sha256. CI uses elixir 1.17 / OTP 27 (ci.yml:47-48) — keep in sync.

Done 2026-11-02: builder hexpm/elixir:1.17.3-erlang-27.3.4.19-alpine-3.24.3, runtime alpine:3.24.3, Litestream v0.3.14 with sha256 per arch (TARGETARCH, no default). Verified native linux/arm64 build: litestream runs, OpenSSL 3.5.9, migrations OK. linux/amd64 could not be verified locally (QEMU emulation breaks mix deps.compile even for the old Dockerfile at e0a6128) — first Fly deploy is the real amd64 test. Litestream 0.5.x is a separate migration (new replication format).
