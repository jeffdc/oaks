---
status: done
tags: [p2, ui]
effort: M
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
relates: [2d7d]
---

# Display and UX fixes from audit

- about_live.ex:31 and home_live.ex:55: total = species + hybrids, but species count includes hybrids -> 974 instead of 734.
- Double × : species_compare_live.ex:307 and detail merge picker (species_detail_live.ex ~999-1004) render × then a name already starting with '× '.
- Formula hybrids ('agrifolia × parvula', 36) render 'Quercus × agrifolia × parvula' in header. One shared format_species_name helper.
- No validation tying leading × to is_hybrid.
- species_compare_live.ex:44-52 no synonym redirect (detail page has one).
- 'Add Source' shown when every source already linked -> empty select. Hide when available_sources_for_species is empty.
- Unique/FK errors on species_id have no input -> Save does nothing; show base errors in flash.
- search page_title stays 'Search: foo' after clearing.
- page_description/page_url/page_image assigned on home but root layout never uses them.
- .prose-content lacks pre/table overflow styles (app.css:321) -> mobile horizontal scroll.
