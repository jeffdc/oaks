---
status: raw
tags: [tier-2]
created: 2026-05-12
updated: 2026-05-12
epic: gallformers-port
---

# Add Oaks.ChangesetHelpers module

Oaks has 5+ schemas duplicating trim/validate logic. Centralize.

Implementation:
- New lib/oaks/changeset_helpers.ex with: trim_strings/2, validate_url/2, empty_strings_to_nil/2
- Refactor existing schemas to use it (Species, Source, Article, Taxonomy at least)
- Add tests

Crib from: /Users/jeff/dev/gallformers/lib/gallformers/changeset_helpers.ex

Effort: S
