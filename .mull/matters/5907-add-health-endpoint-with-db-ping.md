---
status: raw
tags: [tier-1]
created: 2026-05-12
updated: 2026-05-12
epic: gallformers-port
---

# Add /health endpoint with DB ping

Fly.io load balancer probes need this; oaks has none.

Implementation:
- New OaksWeb.HealthController with index action
- DB check: simple Repo.query!("SELECT 1")
- Returns 200 + JSON body when healthy, 503 when DB unreachable
- Route: GET /health (public, no auth)

Crib from: /Users/jeff/dev/gallformers/lib/gallformers_web/controllers/health_controller.ex

Effort: S
