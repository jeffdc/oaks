---
plan: gallformers-parity
phase: c3b2
title: Auth plug pipeline cleanup
stage: committed
created: "2026-11-12T00:40:46Z"
updated: "2026-11-12T00:40:46Z"
---

From matter 4fd7. Extract FetchAuth (optional, populates assigns), RequireAuthStrict, RequireAuthRead; apply via router pipelines with comments. Fixes the audit note: articles_controller.ex:34,53,84 call Auth.authenticated?/1 on GETs, but require_auth (plugs/auth.ex:27) only runs on writes, so drafts are never visible via the API even with a key (contradicts the OpenAPI docs). Crib: gallformers lib/gallformers_web/plugs/require_admin.ex.
