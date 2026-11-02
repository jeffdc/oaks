---
status: done
tags: [p2, bug]
effort: S
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
relates: [7b41]
---

# Search LIKE escaping broken (missing ESCAPE clause)

lib/oaks/search.ex:207 sanitize_like backslash-escapes % _ \ but fragments at :80-83, :106, :127-128 lack ESCAPE '\\'. SQLite has no default escape -> any query containing _ % or \ returns nothing (verified: 'a_b' LIKE '%\_%' = 0). Species.find_synonym already uses ESCAPE (species.ex). Also: synonyms with & stored as \u0026 don't match search.
