---
status: done
tags: [p0, security]
effort: S
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
---

# Article delete has no server-side auth check

CRITICAL. Anyone (no API key) can delete any article.

- lib/oaks_web/live/article_live.ex:61 handle_event("delete") calls Articles.delete_article/1 with no socket.assigns.authenticated check. Button is hidden in UI only; event can be pushed from browser console.
- Also guard confirm_delete in the same file.
- Same class, not currently exploitable: species_merge_live.ex execute_merge (:125) / show_confirm / other merge events (:92-160) have no server-side guard; only protected because source_name is nil when unauthenticated.
- Add tests: unauthenticated delete event leaves article intact.

Found by security + UI reviews, verified 2026-11-02.
