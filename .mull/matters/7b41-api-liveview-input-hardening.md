---
status: done
tags: [p2, bug]
effort: S
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
relates: [9708]
---

# API/LiveView input hardening

- species.ex:139 min(limit, 500) with no lower bound: limit=-1 -> SQLite LIMIT -1 = unlimited. species_controller.ex:32 echoes raw requested limit. Use max(1)|>min(500) like Oaks.Search.
- Array query params crash: ?q[]=x, ?hybrid[]=1, ?limit[]=1 (species.ex:412-426, 439) -> 500 / crashed LV. Guard is_binary.
- Unescaped LIKE in species.ex:140,413 search terms.
- String.to_integer on phx-values / URL params: species_detail_live.ex:53,129; species_compare_live.ex:72; species_merge_live.ex:107; species_source_form_live.ex:73. Use Integer.parse.
- Optional: rate-limit /api/v1/auth/verify (CORS is *); confirm key is 32+ random bytes.
- Analytics plug (plugs/analytics.ex:52) inserts a row for every 404 with unbounded path length -> truncate/sample.
