---
status: raw
tags: [tier-1]
created: 2026-05-12
updated: 2026-05-12
epic: gallformers-port
---

# Custom 403/404/500 error pages

Oaks currently renders Phoenix default error pages. ~30min for brand polish.

Implementation:
- Create lib/oaks_web/controllers/error_html/{403,404,500}.html.heex
- Update OaksWeb.ErrorHTML to embed them via embed_templates
- Match site header/footer styling
- 404 should suggest /species and search

Crib from: /Users/jeff/dev/gallformers/lib/gallformers_web/controllers/error_html.ex and /error_html/*.heex

Effort: S
