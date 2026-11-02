---
status: done
tags: [p1, integrity]
effort: M
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
relates: [94ae]
blocks: [59aa]
---

# Shared name-reference updater for species rename/delete

Species reference each other by scientific_name string (parent1, parent2, hybrids, closely_related_to, subspecies_varieties). Nothing keeps those in sync.
- Rename via edit form (species.ex update_species ~:315): references in other species go stale -> dead links; old name not added to synonyms -> old URLs 404 instead of redirecting.
- Delete (species.ex ~:328, species_detail_live.ex:75-95): dangling references; confirm modal only mentions source count.
- Proposal: one context function (reuse Merge.find_references/build_reference_update) used by rename, delete, and merge, run inside a transaction. On rename append old name to synonyms. On delete: show references in modal and block or clear.
- Needs design discussion before implementation. Merge fixes depend on the corrected find_references (escaped \u00d7 issue).

Done 2026-11-02 (ee4dec2): Oaks.Species.References (find/rewrite, name keys ignore case/whitespace/× spacing, decodes JSON so escaped × works). Rename updates all mentions + adds old name as synonym (Jeff: yes). Delete lists mentions in the confirm modal and removes them (Jeff: option b).
