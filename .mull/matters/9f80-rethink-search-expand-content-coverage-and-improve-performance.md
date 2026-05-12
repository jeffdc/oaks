---
status: raw
tags: [p1]
created: 2026-05-12
updated: 2026-05-12
---

# Rethink search: expand content coverage and improve performance

Rethink search in the Phoenix app: expand content coverage and improve performance.

## Current State
Unified search searches:
- Species: scientific_name, author, synonyms, local_names
- Taxa: name
- Sources: name, author

## Issues
1. **Limited content coverage** - doesn't search:
   - Range/distribution text
   - Morphological descriptions (leaves, bark, fruits, etc.)
   - Notes/miscellaneous fields
   - Taxon notes

2. **Performance concerns** - current implementation:
   - LIKE patterns on text fields are slow at scale
   - No indexing strategy for text search

## Research Areas
- Full-text search (SQLite FTS5) for descriptive content
- Search result ranking/relevance scoring
- Debounce/throttle optimization in LiveView
- SQLite FTS5 docs: https://sqlite.org/fts5.html
