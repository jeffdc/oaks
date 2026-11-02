---
status: done
tags: [p1, data-loss]
effort: S
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
---

# Markdown editor Preview tab drops content on save

lib/oaks_web/components/form_components.ex:68: in Preview the <textarea> is removed via :if, so the form no longer submits content.
- Edit body -> Preview -> Save: edit discarded (new article saves with empty content). Changing title while in Preview resets body. Used by article and taxon forms.
- Fix: keep textarea in DOM and hide with CSS (or hidden input carrying value). Add LiveView test.
- Related a11y: markdown editor and tag input <label>s not associated (form_components.ex:43,131).
