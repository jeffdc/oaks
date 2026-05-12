---
status: raw
tags: [p1, web]
created: 2026-05-12
updated: 2026-05-12
---

# Display backlinks on species pages

Show content that references the current species on species detail pages.

Implementation (Phoenix LiveView):
1. Add backlinks query to Oaks context (find articles/taxa referencing a species)
2. Add backlinks section to species detail LiveView
3. Handle empty backlinks gracefully (hide section)

UX:
- Section labeled 'Referenced In' or 'See Also'
- Each backlink shows type icon + title
- Backlinks are clickable, navigate to source

Display:
- Taxa: 'Section Quercus' (links to taxon page)
- Articles: 'How to Document an Oak' (links to article)
