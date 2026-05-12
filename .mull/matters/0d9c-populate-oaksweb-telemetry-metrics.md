---
status: raw
tags: [tier-2]
created: 2026-05-12
updated: 2026-05-12
epic: gallformers-port
---

# Populate OaksWeb.Telemetry.metrics()

Telemetry skeleton exists in oaks but metrics/0 is empty. Define metrics now, pick a reporter later.

Implementation:
- Phoenix.Endpoint.*, Phoenix.Router.dispatch.*, Ecto query timings, VM stats
- Match gallformers' set
- No reporter yet — that's a future decision (Prometheus / DataDog / etc)

Crib from: /Users/jeff/dev/gallformers/lib/gallformers_web/telemetry.ex (metrics/0 function, lines ~22–84)

Effort: M
