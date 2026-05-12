---
status: raw
tags: [tier-2]
created: 2026-05-12
updated: 2026-05-12
epic: gallformers-port
---

# API ETag / Cache-Control plug

Public API GET endpoints are uncached. ~60-line plug yields free bandwidth on read traffic.

Implementation:
- New OaksWeb.Plugs.ApiCache
- Compute MD5(body) as ETag, set on response
- Honor If-None-Match for 304 Not Modified
- Skip on status >= 400
- Add to :api pipeline (or per-route)
- Test with curl -I

Crib from: /Users/jeff/dev/gallformers/lib/gallformers_web/plugs/api_cache.ex

Effort: S
