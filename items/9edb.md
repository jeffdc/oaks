---
plan: gallformers-parity
phase: c3b2
title: Replace seed-count assertions with fixture modules
stage: committed
created: "2026-11-12T00:40:46Z"
updated: "2026-11-12T01:38:56Z"
---

Known friction: changing priv/repo/test_seeds.sql breaks tests that hardcode seed counts (5 species, 1 hybrid, etc.).

- New fixture modules in test/support/fixtures/: species_fixtures.ex, source_fixtures.ex, taxon_fixtures.ex, article_fixtures.ex (analytics_fixtures.ex already exists there).
- Each module exports fixture/1 that inserts a record with sensible defaults, merged with the overrides passed in.
- Migrate tests off seed-count assertions onto fixture-built data. Known sites: test/oaks_web/controllers/api/species_controller_test.exs:12-38 (count == 5, length(data) == 5) and test/oaks_web/controllers/api/sources_controller_test.exs:9 (length == 3).
- Keep test_seeds.sql as the minimal baseline (sources, root taxa), not something tests assert counts against.
- SQLite caveat: single writer, so fixtures must run inside the DataCase sandbox.

Done when changing the counts in test_seeds.sql no longer breaks tests that aren't about the seeds.

Crib the pattern from gallformers: test/support/fixtures/ingestion_pipeline_fixtures.ex.

From matter 651c (and the seed-count note in matter a9a3).
