---
item: 0edd
"n": 1
passed: true
commit: ba852f6700eca109b31fbfa7232ff61f169c4937
base: 388b3e6d4403511ce7cd1e3bcce8694c8278ce05
at: "2026-11-23T14:36:50Z"
by: /Users/jeff/dev/oaks/.claude/worktrees/agent-a8c4443c03e1994f4
summary: 'DESIGN.md now has a Form Fields section with the Field Face Rule: prose fields are multi-line and serif, every other field one line and Archivo. The input component''s doc and the field CSS name it; all forms already followed it, so no fields changed.'
tour:
  - DESIGN.md (Form Fields); lib/oaks_web/components/core_components.ex (input/1 doc, Faces)
checks:
  tree: fcc35b6342dfe82f51ea97e43d27414b70c39912
  commit: ba852f6700eca109b31fbfa7232ff61f169c4937
  at: "2026-11-23T14:36:40Z"
  by: /Users/jeff/dev/oaks/.claude/worktrees/agent-a8c4443c03e1994f4
  passed: true
  results:
    - command: make done-checks
      exit: 0
      duration_ms: 9943
changes:
  - layer: docs
    files:
      - status: M
        path: DESIGN.md
        added: 4
        removed: 0
  - layer: ui
    files:
      - status: M
        path: assets/css/system/components.css
        added: 2
        removed: 0
      - status: M
        path: lib/oaks_web/components/core_components.ex
        added: 10
        removed: 0
design: 'I checked every form''s fields (source, article, species, species source, taxon, auth and settings pages): every textarea holds prose and every one-line input, select or tag field holds a short value, so the existing CSS split (textarea.oc-input and .oc-md-text serif, .oc-input and .oc-tags-input Archivo) already matched the rule. The change states it as a named rule in DESIGN.md (Form Fields) and in the input component''s doc and CSS comment, framed by content (prose vs short value) so the input type follows the content rather than the face following the element.'
---

# Done report 1: Forms: text inputs are Archivo while Notes/Content textareas are serif, with no stated rule (0edd)

**Status:** PASSED  
**Commit:** ba852f6700ec  
**By:** /Users/jeff/dev/oaks/.claude/worktrees/agent-a8c4443c03e1994f4 at 2026-11-23T14:36:50Z

## What was built

### Summary

DESIGN.md now has a Form Fields section with the Field Face Rule: prose fields are multi-line and serif, every other field one line and Archivo. The input component's doc and the field CSS name it; all forms already followed it, so no fields changed.

### UI tour

1. DESIGN.md (Form Fields); lib/oaks_web/components/core_components.ex (input/1 doc, Faces)

### Checks (run by mull)

- `make done-checks`: pass, 9.9s

## How it was built

### Design notes

I checked every form's fields (source, article, species, species source, taxon, auth and settings pages): every textarea holds prose and every one-line input, select or tag field holds a short value, so the existing CSS split (textarea.oc-input and .oc-md-text serif, .oc-input and .oc-tags-input Archivo) already matched the rule. The change states it as a named rule in DESIGN.md (Form Fields) and in the input component's doc and CSS comment, framed by content (prose vs short value) so the input type follows the content rather than the face following the element.

### Decisions made in the session

None recorded.

### Changes by layer

**docs**: 1 files, +4 −0
- M DESIGN.md (+4 −0)

**ui**: 2 files, +12 −0
- M assets/css/system/components.css (+2 −0)
- M lib/oaks_web/components/core_components.ex (+10 −0)
