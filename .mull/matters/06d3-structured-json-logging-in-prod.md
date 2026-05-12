---
status: raw
tags: [tier-1]
created: 2026-05-12
updated: 2026-05-12
epic: gallformers-port
---

# Structured JSON logging in prod

Fly.io log aggregation is wasted on raw text formatting. Switch prod to structured JSON.

Implementation:
- Add :logger_json dep to mix.exs
- Configure in config/runtime.exs under prod branch only — dev stays human-readable
- Include request_id and other standard metadata

Crib from: /Users/jeff/dev/gallformers/config/runtime.exs (lines 68–71) + their mix.exs deps

Effort: S
