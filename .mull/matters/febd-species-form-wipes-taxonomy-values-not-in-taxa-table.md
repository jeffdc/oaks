---
status: done
tags: [p1, data-loss]
effort: S
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
---

# Species form wipes taxonomy values not in taxa table

lib/oaks_web/live/species_form_live.ex:209-225: subgenus/section/subsection/complex are <select>s built from taxa rows. options_for_select finds no match for a value not in taxa -> browser selects the "" prompt -> saved as nil.
- 14 species affected in May snapshot: subsections Erythromexicanae (5), Leucomexicanae (7), Salicifoliae (1), Roburoid (1) — e.g. castanea, glaucoides, orocantabrica. Editing their author wipes the subsection.
- Fix: include the current value in options when missing (marked as not-in-taxa), plus fix the data (see data cleanup matter).
