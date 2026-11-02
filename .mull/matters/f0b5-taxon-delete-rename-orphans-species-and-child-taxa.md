---
status: done
tags: [p1, integrity]
effort: M
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
---

# Taxon delete/rename orphans species and child taxa

taxa has no FK; species store taxon *names* (subgenus/section/subsection/complex), child taxa store parent name.
- Delete: lib/oaks/taxonomy.ex:209-221 bare Repo.delete; taxonomy_live.ex:68. Modal (~taxonomy_live.ex:484) says 'This will fail if species or child taxa reference it' — false. Fix: count species + children, refuse with message.
- Rename: taxon_form_live.ex:172 updates only the taxa row. Fix: in one transaction update matching species column + child taxa parent.
- taxon content_updated_at never set by the edit form.
- TaxonFormLive crashes on non-numeric /taxonomy/abc/edit (String.to_integer, :70); confirm_delete_taxon crashes when target nil.
