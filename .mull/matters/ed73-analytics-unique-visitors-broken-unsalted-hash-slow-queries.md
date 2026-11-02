---
status: done
tags: [p2, analytics]
effort: M
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
---

# Analytics: unique visitors broken, unsalted hash, slow queries

- endpoint.ex:14-16 LiveView socket connect_info only has :session; track_page_view.ex reads :peer_data/:user_agent -> nil -> every LV visitor hashes to sha256(date). May snapshot: all 111 views on 2026-05-13 share one hash. Fix: connect_info [:peer_data, :user_agent, :x_headers, session: ...], IP from fly-client-ip.
- analytics.ex:40-43 hash has no secret salt; rows kept forever -> contradicts privacy_live.ex:143-147 'no way to identify'. Add in-memory random daily salt; optional retention pruning.
- analytics.ex:85-213 filter on date(inserted_at) -> can't use index; public dashboard does 5 full scans on mount (x2). Use inserted_at range.
- Bot regex misses curl, python-requests, Go-http-client, HeadlessChrome; LV hook has no bot filter.
- CHECK PROD: May snapshot has page_views only 2026-05-12..16. Confirm prod is still recording.

From 7b41: 404 page-view inserts are bounded per row (PageView validates path <= 2000) but not rate-limited/sampled — consider sampling 404 inserts under flood.

Done 2026-11-02: connect_info peer_data/user_agent/x_headers; LV IP from X-Forwarded-For (fly-client-ip isn't in x_headers); random in-memory daily salt; Analytics.bot? shared by plug+hook with broader regex; indexed inserted_at range filters; privacy page updated. NOT done: retention pruning, 404 sampling, and checking whether prod has recorded page views since May 16 (needs prod access).
