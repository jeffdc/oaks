---
status: raw
tags: [p2, data]
effort: L
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
---

# Production data cleanup from audit

From May 2026 snapshot (oaks.db). Re-measure against fresh prod copy (make download-db) before acting. All writes go to prod -> needs Jeff's approval and a backup.
- Normalize JSON columns: 210 rows store literal 'null' in all four list columns; external_links mix NULL/[]; 65 rows with escaped \u00d7 in hybrids and 32 in synonyms (re-encode as UTF-8) — fixes merge find_references and find_synonym prefilter.
- Collapse whitespace/newline runs: 136 synonym entries, 183 local_names, 4 authors.
- closely_related_to and subspecies_varieties empty for all 734 species; 27 species have subspecies rows but empty subspecies_varieties -> drop or derive.
- 2 hybrids with ASCII x (berberidifolia x cornelius-mulleri, dumosa x engelmannii).
- 59 hybrids with no parents (34 of 36 formula names) -> fill from name.
- 7 dangling parents: falcata parent1='Mich' parent2='1803'; × drummondii->margaretta (margaretiae); × introgressa->prinoïdes; × munzii->cornelius; × takaoyamensis->Cyclobalanopsis/takaoyamensis.
- 4 asymmetric hybrid links (× acutidens/mulleri, × pastorensis/clivicola, × succulenta/geminata, × tharpii/graciliformis); × takaoyamensis lists itself.
- Synonyms: 30 equal accepted names; ~30 junk ('not Trel. 1924', 'nom. illeg.', 'nom. inval.', '...Diagnosis here...', 'look', '5(4'); ~13-20 concatenated multi-name strings; 21 misapplied (non/sensu/auct.); 58 homonym epithets resolve to lowest-id species.
- 7 authors hold full citations (brantii: 'Lindl. 1840 Bot. Reg. 26: t. 41 1840'); 220 species no author.
- conservation_status = LC for all 734 (default fill, not real data).
- 4 subsection values missing from taxa (Erythromexicanae, Leucomexicanae, Roburoid, Salicifoliae).
- × oviedoensis source 3 not preferred; × prasina/source 2 content-free row.
- make download-db (Makefile:90) copies only oaks.db, not -wal -> may miss unchecked writes.
