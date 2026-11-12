---
plan: gallformers-parity
phase: c3b2
title: Replace seed-count assertions with fixture modules
stage: committed
created: "2026-11-12T00:40:46Z"
updated: "2026-11-12T00:40:46Z"
---

From matter 651c (and a9a3). Add test/support/fixtures/{species,source,taxon,article}_fixtures.ex (analytics_fixtures.ex already exists); move tests off seed counts: species_controller_test.exs:12-38 (== 5), sources_controller_test.exs:9 (== 3). Keep test_seeds.sql as a minimal baseline. Fixtures run inside the DataCase sandbox. Crib: gallformers test/support/fixtures/ingestion_pipeline_fixtures.ex.
