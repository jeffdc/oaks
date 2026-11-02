---
status: refined
tags: [p1, integrity]
effort: M
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
needs: [1450]
---

# Merge: missed references, self-parent, dropped data

lib/oaks/species/merge.ex + lib/oaks_web/live/species_merge_live.ex:
1. find_references (merge.ex:89,117,129) prefilters with raw LIKE '%"× foo"%', but 65 rows store hybrids as ["\u00d7 numidica"] (280 refs to 171 hybrid names) -> refs missed, dangle after merge. Fix: decode in Elixir or json_each; or normalize stored JSON.
2. Self-parent: refs computed before txn; if target.parent1 == source, update_references sets target.parent1 = target_name, overriding user's edit (merge.ex:274-296, 333-358). Skip refs where ref.species.id == target.id.
3. Drops synonym's hybrids/closely_related_to/subspecies_varieties/external_links (merge.ex:274-297) -> one-sided relationships. Union into target; show in preview.
4. shared_sources computed (merge.ex:162) but never shown; synonym's text for shared sources silently lost.
5. Transferred species_sources hard-coded is_preferred: false (merge.ex:325) -> target can lose its preferred source.
6. execute_merge has no source==target guard (only preview checks) -> deletes the species.
7. Save Merge permanently disabled by self-refs computed from preview.target (DB copy) instead of edited_fields (species_merge_live.ex:734-740); only parent1/parent2 should block since remove_self_references already handles lists.
8. A merged into B where hybrid is A×B -> 'B × B' with no warning (merge.ex:352-358).
9. preview_merge returns :source_not_found for missing target (merge.ex:42).
10. compute_synonyms_to_add (merge.ex:255,267) String.downcase on every entry; crashes on {name,author} map entries that find_synonym supports.
11. String.to_existing_atom in copy_field (species_merge_live.ex:94) -> whitelist @scalar_fields.
Related: [[shared name-reference updater]].
