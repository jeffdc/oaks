Unified search (lib/oaks/search.ex) today searches:

- Species: scientific_name, author, synonyms, local_names
- Taxa: name
- Sources: name, author

Issues:

1. Limited content coverage. It doesn't search range/distribution text, morphological descriptions (leaves, bark, fruits, etc.), notes and miscellaneous fields, or taxon notes.
2. Performance. LIKE patterns on text fields are slow at scale, and there is no indexing strategy for text search.

The aim is to expand coverage to the descriptive content and keep search fast as content grows.

Research areas:

- Full-text search with SQLite FTS5 for descriptive content (https://sqlite.org/fts5.html).
- Result ranking and relevance scoring.
- Debounce/throttle tuning in the LiveView.

LIKE searches must use an ESCAPE clause (search.ex's sanitize_like escapes % _ and backslash, and the fragments need ESCAPE '\\'; SQLite has no default escape character).

From matter 9f80 (and matter 9708 on LIKE escaping).
