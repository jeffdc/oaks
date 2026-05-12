---
status: raw
tags: [tier-2]
created: 2026-05-12
updated: 2026-05-12
epic: gallformers-port
---

# Replace seed-count assertions with fixtures module

Known friction: changing test_seeds.sql breaks tests that hardcode counts (5 species, 1 hybrid, etc).

Implementation:
- New test/support/fixtures/species_fixtures.ex (and source_, taxon_, article_)
- Each module exports fixture/1 that inserts with sensible defaults + overrides
- Migrate tests off seed-count assertions to fixture-built data
- Keep test_seeds.sql for minimal baseline (sources, root taxa) — not for assertions

Crib pattern from: /Users/jeff/dev/gallformers/test/support/fixtures/ingestion_pipeline_fixtures.ex

SQLite caveat: single-writer; fixtures must run within DataCase sandbox

Effort: M
