---
status: done
tags: [p0, security, deps]
effort: S
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
---

# Update vulnerable production deps (bandit, plug, phoenix)

mix deps.audit (2026-11-02) — 12 advisories. Security Audit workflow fails until fixed.

Ships to prod:
- bandit 1.11.0 -> >=1.11.1: 2 high (unauth DoS via chunked TE / trailers)
- plug 1.19.1 -> >=1.19.3: 2 high (multipart header buffer, quadratic nested params); multipart parser enabled at endpoint.ex:49
- phoenix 1.8.7 -> >=1.8.9: high (unbounded channel joins, reaches LV sockets) + moderate (Presence keys)
Dev/test only (smoke_test via Req):
- req 0.5.17 -> >=0.6.1 (high + moderate); mint 1.7.1 -> 1.9.0 (2 high, moderate, low) via finch

All within current mix.exs constraints: mix deps.update bandit plug phoenix req mint finch. Req 0.5->0.7 may have breaking changes; verify lib/mix/tasks/smoke_test.ex.
Note: Security Audit workflow re-enabled 2026-11-02 (was disabled_inactivity since July).

Done 2026-11-02: bandit 1.14.1, plug 1.20.3, phoenix 1.8.16, req 0.7.5, mint 1.11.0, finch 0.24.0 (+ transitive). deps.audit clean; smoke test passes against prod with Req 0.7; dev server boots, LV websocket upgrades (101).
