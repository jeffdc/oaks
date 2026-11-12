---
plan: gallformers-parity
phase: c3b2
title: Auth plug pipeline cleanup
stage: committed
created: "2026-11-12T00:40:46Z"
updated: "2026-11-12T01:38:56Z"
---

Auth is ad hoc in the router today (:api runs require_auth, :api_force_auth runs force_auth, both in lib/oaks_web/plugs/auth.ex). Replace it with explicit pipeline plugs. This pays back when a second auth tier appears.

- Extract three plugs:
  - FetchAuth: optional; checks the key and populates conn.assigns, never rejects.
  - RequireAuthStrict: requires auth for all methods.
  - RequireAuthRead: requires auth for POST/PUT/DELETE only.
- Apply them via router pipelines, not per-route imports.
- Document each pipeline in the router with a comment.

Bug this fixes (audit 2026-11-02): articles_controller.ex:34, 53 and 84 call Auth.authenticated?(conn), but require_auth (plugs/auth.ex:27) only runs on write methods, so a GET is always unauthenticated. Drafts are never visible via the API even with a key, which contradicts the OpenAPI docs. FetchAuth on GETs fixes it. Done when an authenticated GET returns drafts and an unauthenticated one doesn't (tests).

Crib the pattern from gallformers: lib/gallformers_web/plugs/require_admin.ex.

From matter 4fd7.
