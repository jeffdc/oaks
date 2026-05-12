---
status: raw
tags: [tier-2]
created: 2026-05-12
updated: 2026-05-12
epic: gallformers-port
---

# Auth plug pipeline cleanup

Current auth is ad-hoc in router; replace with explicit pipeline plugs. Pays back when a second auth tier appears.

Implementation:
- Extract: FetchAuth (optional, populates conn.assigns), RequireAuthStrict (all methods), RequireAuthRead (POST/PUT/DELETE only)
- Apply via router pipelines, not per-route imports
- Document each pipeline in router with a comment

Crib pattern from: /Users/jeff/dev/gallformers/lib/gallformers_web/plugs/require_admin.ex

Effort: S
