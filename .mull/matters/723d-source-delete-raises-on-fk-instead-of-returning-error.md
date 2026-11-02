---
status: done
tags: [p3, bug]
effort: S
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
---

# Source delete raises on FK instead of returning error

sources.ex:160 Repo.delete with no foreign_key_constraint; ecto_sqlite3 reports FK failure as [foreign_key: nil] -> Ecto.ConstraintError raised, LV crashes (sources_live.ex:53, source_detail_live.ex:58). The 'Cannot delete' path is unreachable. species_source.ex:68-69 foreign_key_constraint(:source_id) also can never match. Fix: explicit reference check before delete. confirm_delete crashes if target nil.
