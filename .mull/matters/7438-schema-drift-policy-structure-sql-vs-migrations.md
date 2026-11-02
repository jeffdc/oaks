---
status: done
tags: [p3, ops]
effort: S
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
---

# Schema drift policy: structure.sql vs migrations

CLAUDE.md calls priv/repo/structure.sql the single source of truth, but prod only changes via Release.migrate and there is a single migration (page_views). A change made only in structure.sql passes tests and never reaches prod. Decide the policy (every schema change = migration + structure.sql regen) and document it.

Done 2026-11-02: baseline migration 20260101000000_create_base_schema (IF NOT EXISTS, no-op on prod — verified on May prod copy: records version, schema/data unchanged; fresh migrate == prod schema). structure.sql deleted; mix test/make test-db/CI use ecto.migrate; CLAUDE.md/CONTRIBUTING updated. Re-verify against fresh prod copy from make download-db before pushing.
