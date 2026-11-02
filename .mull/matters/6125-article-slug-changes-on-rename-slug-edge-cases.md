---
status: done
tags: [p2, integrity]
effort: S
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
---

# Article slug changes on rename; slug edge cases

lib/oaks/articles.ex:
- :110 slug regenerated whenever title changes, no redirect -> shared links 404. Keep slug stable on edit (or store old slugs + redirect).
- :191-198 non-Latin/punctuation-only titles -> empty slug -> validate_required(:slug) fails on a field with no input -> silent no-op. Accents stripped ('Québec' -> 'qubec'). Fallback article-<id>, transliterate.
- Title 'New' -> slug 'new' collides with /articles/new route. Reserve.
- changeset/2 skips 200-char title/author limits that only form_changeset applies.
- Unescaped LIKE in article search (articles.ex:229).
