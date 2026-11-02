---
status: raw
tags: [tier-2]
created: 2026-05-12
updated: 2026-11-02
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

Audit 2026-11-02: articles_controller.ex:34,53,84 call Auth.authenticated?(conn) but require_auth (plugs/auth.ex:28) only runs on write methods, so GET is always unauthenticated -> drafts never visible via API even with key (contradicts OpenAPI docs). FetchAuth optional plug fixes this.
