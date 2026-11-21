---
kind: decision
text: 'Private API at /api/private/v1 in its own pipeline: no CORS, 401 for missing/bad/expired tokens, 403 for a missing scope; Hammer limits per token (120/min) and failed attempts per IP (10 per 15 min), set in config.'
plan: compendium
item: fbd0
by: /Users/jeff/dev/oaks
created: "2026-11-21T21:09:38Z"
---

Agents aren't browsers; limits follow the LoginLimiter pattern.
