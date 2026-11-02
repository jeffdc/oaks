---
status: done
tags: [p3, deps]
effort: S
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
---

# Loosen/tighten dependency constraints

mix.exs: ecto_sqlite3 '>= 0.0.0' (0.23.0 installed, 0.26.0 out; 0.23 pins ecto_sql ~> 3.13.0, blocks 3.14). phoenix_live_view '~> 1.1.0' blocks 1.2.x. dns_cluster '~> 0.2.0', sobelow '~> 0.14.1' block upgrades. mdex 0.11.3 vs 0.14.6. Set real constraints and upgrade deliberately (after p0 security bump).

Done 2026-11-02: LV 1.1.22->1.2.13, ecto_sqlite3 0.23->0.26 (exqlite 0.43, ecto/ecto_sql 3.14), sobelow 0.18.1, dns_cluster 0.3.1, plus patch dev deps (6a15401). Precommit, sobelow --exit high, deps.audit clean; dev server pages + websocket OK. Deferred: mdex 0.11->0.14 (with 5453 sanitize decision) and tailwind 0.4->0.5.
