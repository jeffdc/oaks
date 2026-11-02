---
status: done
tags: [p1, data-loss]
effort: M
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
relates: [1450]
---

# JSON list fields: comma input silently dropped, bad elements crash pages

Species relationship fields (hybrids, closely_related_to, subspecies_varieties, synonyms) and species_sources.local_names are JSON arrays stored as TEXT and edited as raw text.
- species_form_live.ex:270 says "Enter names separated by commas. JSON arrays are also accepted." Nothing parses commas; species/species.ex:40-56 changeset casts the raw string. Species.parse_json_array returns [] on decode failure -> list silently vanishes from detail page, API, merge reference lookup.
- Same for local_names: species_source_form_live.ex:271.
- Valid JSON with non-string elements (e.g. [1], [{"name":"x"}]) crashes the detail page for every visitor: Ecto.Query.CastError in get_hybrids_with_parents (in ^hybrid_names), HEEx/~p crash for maps (species_detail_live.ex:1047-1053, 492-516).
- Fix: changeset normalizes comma text -> JSON array of trimmed strings; validates array-of-strings with visible error; parse_json_array callers filter to binaries defensively.
- external_links has no form input at all (can't edit in UI) — consider adding here.
