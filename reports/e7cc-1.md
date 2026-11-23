---
item: e7cc
"n": 1
passed: true
commit: 388b3e6d4403511ce7cd1e3bcce8694c8278ce05
base: a8a5d0665c36952ba62203439eb11e8dc438687f
at: "2026-11-23T14:35:15Z"
by: /Users/jeff/dev/oaks/.claude/worktrees/agent-a8c4443c03e1994f4
summary: Settings sub-pages (password, recovery codes, agent tokens) have a Back to settings link, the site footer links Analytics next to Privacy, and About's statistics are a single prose sentence instead of a row of big figures.
tour:
  - lib/oaks_web/controllers/user_settings_html/password.html.heex
  - lib/oaks_web/components/layouts.ex (site_footer)
  - lib/oaks_web/live/about_live.ex (#about-stats)
checks:
  tree: 1ae7e36c8ea2cb05975447dd5c7fe7e846380498
  commit: 388b3e6d4403511ce7cd1e3bcce8694c8278ce05
  at: "2026-11-23T14:35:06Z"
  by: /Users/jeff/dev/oaks/.claude/worktrees/agent-a8c4443c03e1994f4
  passed: true
  results:
    - command: make done-checks
      exit: 0
      duration_ms: 9449
changes:
  - layer: tests
    files:
      - status: M
        path: test/oaks_web/controllers/user_settings_controller_test.exs
        added: 11
        removed: 0
      - status: M
        path: test/oaks_web/live/about_live_test.exs
        added: 2
        removed: 3
      - status: M
        path: test/oaks_web/live/header_test.exs
        added: 1
        removed: 0
  - layer: ui
    files:
      - status: M
        path: lib/oaks_web/components/layouts.ex
        added: 1
        removed: 0
      - status: M
        path: lib/oaks_web/controllers/user_settings_html/api_tokens.html.heex
        added: 1
        removed: 0
      - status: M
        path: lib/oaks_web/controllers/user_settings_html/password.html.heex
        added: 1
        removed: 0
      - status: M
        path: lib/oaks_web/controllers/user_settings_html/recovery_codes.html.heex
        added: 1
        removed: 0
      - status: M
        path: lib/oaks_web/live/about_live.ex
        added: 5
        removed: 14
design: The settings sub-pages are controller templates; each puts the library <.back> above its <.header> in the page's :head, as forms do. Analytics is a <.link> in the site footer's nav after Privacy (About already linked it, but nothing in the shell did). About's three-figure <dl class="page-figures"> became one .oc-prose sentence, so the statistics read as a fact in the text rather than a dashboard row; page-figures stays for the analytics page, where a figure row fits.
decisions:
  - id: d902
    text: About's statistics are one prose sentence under their heading (The database holds N species and N hybrids, N entries in all.), not a ruled meta line
    detail: About is a prose page; a sentence needs no new CSS. Site copy, not Jeff's About text; shown once the counts load
  - id: 33d7
    text: Only the three settings pages get Back to settings; the one-time New agent token and New recovery codes pages keep their own done button
    detail: those pages show a secret once and already end in a button back
---

# Done report 1: Settings sub-pages have no way back to /settings except Cancel; /analytics is public but linked nowhere; About's statistics are a generic hero-metric row (e7cc)

**Status:** PASSED  
**Commit:** 388b3e6d4403  
**By:** /Users/jeff/dev/oaks/.claude/worktrees/agent-a8c4443c03e1994f4 at 2026-11-23T14:35:15Z

## What was built

### Summary

Settings sub-pages (password, recovery codes, agent tokens) have a Back to settings link, the site footer links Analytics next to Privacy, and About's statistics are a single prose sentence instead of a row of big figures.

### UI tour

1. lib/oaks_web/controllers/user_settings_html/password.html.heex
2. lib/oaks_web/components/layouts.ex (site_footer)
3. lib/oaks_web/live/about_live.ex (#about-stats)

### Checks (run by mull)

- `make done-checks`: pass, 9.4s

## How it was built

### Design notes

The settings sub-pages are controller templates; each puts the library <.back> above its <.header> in the page's :head, as forms do. Analytics is a <.link> in the site footer's nav after Privacy (About already linked it, but nothing in the shell did). About's three-figure <dl class="page-figures"> became one .oc-prose sentence, so the statistics read as a fact in the text rather than a dashboard row; page-figures stays for the analytics page, where a figure row fits.

### Decisions made in the session

Accepting the review ratifies these. To decide one differently, before accepting: `mull decide <id> "..."`

- **d902** About's statistics are one prose sentence under their heading (The database holds N species and N hybrids, N entries in all.), not a ruled meta line
  Why: About is a prose page; a sentence needs no new CSS. Site copy, not Jeff's About text; shown once the counts load
- **33d7** Only the three settings pages get Back to settings; the one-time New agent token and New recovery codes pages keep their own done button
  Why: those pages show a secret once and already end in a button back

### Changes by layer

**tests**: 3 files, +14 −3
- M test/oaks_web/controllers/user_settings_controller_test.exs (+11 −0)
- M test/oaks_web/live/about_live_test.exs (+2 −3)
- M test/oaks_web/live/header_test.exs (+1 −0)

**ui**: 5 files, +9 −14
- M lib/oaks_web/components/layouts.ex (+1 −0)
- M lib/oaks_web/controllers/user_settings_html/api_tokens.html.heex (+1 −0)
- M lib/oaks_web/controllers/user_settings_html/password.html.heex (+1 −0)
- M lib/oaks_web/controllers/user_settings_html/recovery_codes.html.heex (+1 −0)
- M lib/oaks_web/live/about_live.ex (+5 −14)
