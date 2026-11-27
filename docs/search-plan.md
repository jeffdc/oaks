# Search rethink

Search covers names, published entry sections and facts, and stays fast as content grows. Still being shaped. It comes after [Taxon pages](facts-expansion/taxon-pages.md) in the Facts expansion, since what it searches is that plan's model. Its steps are written when Jeff agrees the shape.

## Today

Unified search (`lib/oaks/search.ex`) searches:

- Species: scientific name, author, synonyms, local names.
- Taxa: name.
- Sources: name, author.

It doesn't search range text, the morphological descriptions (leaves, bark, fruits, …), notes and miscellaneous fields, or taxon notes. LIKE on text fields is slow at scale, and there is no text-search index. Its LIKE fragments use `ESCAPE '\\'` with `sanitize_like` escaping `%`, `_` and backslash; keep that, since SQLite has no default escape character.

## Known bugs and ideas

- Search no longer works: an earlier agent broke the search index with SQLite changes (it used to work). It waits until shaping; first confirm it still reproduces (Jeff).
- Say why a result matched when it was found by a common name.

## To work out

- Coverage: names, published entry sections and facts, through SQLite FTS5 (https://sqlite.org/fts5.html).
- Whether relevance ranking is needed, or grouping results by kind is enough. Leaning: results stay grouped by kind, with ranking inside a group only if FTS5's bm25 is enough.
- Debounce and throttle tuning in the LiveView.
