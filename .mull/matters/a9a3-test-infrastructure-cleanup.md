---
status: refined
tags: [p3, tests]
effort: S
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
relates: [651c]
---

# Test infrastructure cleanup

- priv/oaks_test.sqlite is tracked despite .gitignore:88; committed copy is stale (no page_views table); CI rebuilds it (ci.yml:64). Fix: git rm --cached priv/oaks_test.sqlite (needs Jeff's OK).
- All mix test processes share one SQLite file (config/test.exs:64): concurrent runs -> immediate 'Database busy' (deferred txn read->write upgrade, no busy_timeout wait) + 6-18 failures. Use MIX_TEST_PARTITION or document one runner at a time. Prod hardening: default_transaction_mode: :immediate on Repo.
- Sandbox noise: 'Exqlite.Connection disconnected: client exited' in 6/9 runs, 'cannot find ownership process' 1/30 (test/support/data_case.ex:42-71 — LVs/Tasks outlive owner).
- No LiveView tests for ArticleFormLive, SourceFormLive, SettingsLive (incl. auth redirect).
- Seed-count assertions: species_controller_test.exs:12-51 (==5), sources_controller_test.exs:9 (==3) -> see 651c.

Done 2026-11-02 (a9a3 partial): 'Database busy' flake fixed — default_transaction_mode: :immediate in test/dev/prod Repo config + Analytics.track_async runs inline when :analytics_async false (test). Remaining: sandbox 'client exited' noise, test DB tracked in git, concurrent mix test runs share one file, missing form LiveView tests.

2026-11-02: added ArticleFormLive + SourceFormLive tests (SettingsLive tests added in 74c39cd). Found source form couldn't save a source whose source_type isn't a listed option (test seeds use lowercase 'website'); fixed same way as febd. Still open: test DB tracked in git (needs OK to git rm --cached), per-partition test DBs, sandbox 'client exited' log noise.
