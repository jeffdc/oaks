Unified search (lib/oaks/search.ex) covers species scientific_name, author, synonyms and local_names, taxa names, and source names and authors. It does not search range/distribution text, morphological descriptions (leaves, bark, fruits), notes, or taxon notes, and it relies on LIKE patterns with no indexing strategy.

The aim: search the descriptive content too, rank results by relevance, and stay fast as content grows. Candidate approach: SQLite FTS5 (https://sqlite.org/fts5.html), plus LiveView debounce tuning.

From matter 9f80.
