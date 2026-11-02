---
status: done
tags: [p2, bug]
effort: S
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
---

# Complexes directly under a section are unreachable

taxonomy_live.ex:17-20,157 and search.ex:22 assume complex is always under a subsection. Local data: robur (parent section Quercus) and ilex (parent section Ilex). Section page lists only subsections; search links to /taxonomy/Quercus/robur -> 'Taxon Not Found'. Fix: list subsection + complex children at section level; build paths from actual parent level. Also taxonomy_live.ex:130 card count (all species in taxon) disagrees with page header count (only species with no lower rank).
