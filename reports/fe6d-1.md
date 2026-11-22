---
item: fe6d
"n": 1
passed: true
commit: 195bbaac25c3b46bbcb1491f6dac1e9e1252912d
base: 235b0199cf04435e202b7b382887d836a9995190
at: "2026-11-22T01:43:08Z"
by: /Users/jeff/dev/oaks/.claude/worktrees/agent-a6b12642d455b4bb4
summary: 'The sources and articles pages now speak DESIGN.md without being restructured: both lists are ruled rows (whole-row links, paper-2 hover, descriptions at a 68ch measure), source types and drafts are status tags (Draft dashed), the source page is a title row over a ruled term list, a count and a ruled list of italic names, the article page is a ruled title row over b4f7''s prose, and the forms, back links, dialogs and buttons use the system''s header, back link and buttons, all six pages in one column width. The shared .action-btn, .edit-content-btn and .create-taxon-btn are now the system''s outlined ink button, .species-name stays the serif italic, and the unused .markdown-editor and .tag-* rules are deleted.'
tour:
  - 'Run PORT=4454 mix phx.server in this worktree and open localhost:4454/sources: DATA SOURCES title on a 2px ink rule, then each source as a row on a hairline with its type as an outlined ink stamp, Archivo author and year, the count at the right, and descriptions wrapping at a reading measure; hover a row and it tints paper-2 with the name underlined.'
  - 'Open localhost:4454/sources/4: Back to Sources, the name in large serif with a BOOK stamp, a ruled Author/Year/ISBN list, the description in serif at a measure, notes in small grey Archivo, COVERAGE reading ''46 species'', and the species as a ruled four-column list of italic names.'
  - 'Open localhost:4454/sources/5: the long name wraps over two lines with Edit and Delete (when logged in) staying at the top right; the URL row is a pencil link that wraps on phones.'
  - 'Open localhost:4454/articles: Articles title row, the topic filter, and rows on hairlines; no amber anywhere.'
  - 'Log in with ''Log in as dev user'' on localhost:4454/users/log-in and reopen localhost:4454/sources: Create Source is an outlined button at the title row''s right; hover a row (or Tab into it) and compact Edit and Delete appear at its right.'
  - 'Click Delete on the Oak Compendium row: a square paper dialog with a 2px ink border titled Can''t Delete Source, the reason between two ink rules, and one Close button; Escape also closes it.'
  - 'Open localhost:4454/articles: the draft row carries a dashed DRAFT stamp; open it: the title at display size with the dashed DRAFT stamp, By Jeff Clark, the topic as a pencil link, and Edit and Delete at the top right on a 2px rule; click Delete to see Cancel and an ochre Delete (press Cancel).'
  - 'Open localhost:4454/sources/4/edit and localhost:4454/articles/new: Back link, serif title, sections on 2px rules 48px apart, white square fields, the draft hint under the Published checkbox, Cancel and an ochre Create or Save button on a hairline.'
  - 'Open localhost:4454/species/shumardii and localhost:4454/taxonomy/Quercus: Edit, Delete, Create Taxon and Add Content are square outlined ink buttons without icons that invert on hover (the purple Make Synonym Of... is item 1adb''s).'
  - 'Narrow to 390px on the sources and articles pages: nothing scrolls sideways; on /sources the editor buttons are always shown and the counts sit at the right.'
checks:
  tree: 673b75550bd193874f58e20f762139154900b22a
  commit: 195bbaac25c3b46bbcb1491f6dac1e9e1252912d
  at: "2026-11-22T01:41:53Z"
  by: /Users/jeff/dev/oaks/.claude/worktrees/agent-a6b12642d455b4bb4
  passed: true
  results:
    - command: make done-checks
      exit: 0
      duration_ms: 74925
changes:
  - layer: tests
    files:
      - status: M
        path: test/oaks_web/live/articles_live_test.exs
        added: 12
        removed: 0
      - status: M
        path: test/oaks_web/live/source_detail_live_test.exs
        added: 19
        removed: 2
      - status: M
        path: test/oaks_web/live/sources_live_test.exs
        added: 13
        removed: 0
  - layer: ui
    files:
      - status: M
        path: assets/css/app.css
        added: 248
        removed: 397
      - status: M
        path: lib/oaks_web/live/article_form_live.ex
        added: 15
        removed: 35
      - status: M
        path: lib/oaks_web/live/article_live.ex
        added: 48
        removed: 101
      - status: M
        path: lib/oaks_web/live/articles_live.ex
        added: 46
        removed: 70
      - status: M
        path: lib/oaks_web/live/source_detail_live.ex
        added: 35
        removed: 58
      - status: M
        path: lib/oaks_web/live/source_form_live.ex
        added: 15
        removed: 33
      - status: M
        path: lib/oaks_web/live/sources_live.ex
        added: 38
        removed: 77
design: |-
  Approach: a bridge, not a rebuild. Page structure, element ids, phx bindings and test hooks are kept; the change is CSS in app.css's two fe6d sections (Sources List Page, Source Detail Page) plus template classes, with the system components swapped in where the swap is one line: CoreComponents.header for the list and not-found title rows, .button for every V1 inline-styled button and link-button, .back for the back links, DesignComponents.status_tag for source types and Draft. No shared file (assets/css/system/*, core/design/form components, layouts) was edited.

  Lists: the sources list and the articles list are DESIGN.md's ruled lists. Each row is one link (the sources row keeps its stretched anchor so its editor buttons stay clickable), tints paper-2 on hover and bleeds 12px past the column on each side so its text lines up with the title row; the hairline is a background gradient inset by the bleed, so it ends with the column instead of poking out. Descriptions and excerpts hold a 68ch measure (they ran about 100 characters a line). Source names are serif 600 21px, meta and counts Archivo with lining tabular figures, the count pushed right even when it wraps on phones. The editor's Edit/Delete were icon-only buttons with a title; they are now compact outlined text buttons with aria-labels naming the source, hidden until the row is hovered or has keyboard focus (and taking no clicks while hidden), always shown where there is no hover and under 640px. The articles list's row is a new .article-row in the same section, replacing card-interactive, whose unlayered border would have run past the column. The amber side stripe and amber Draft badge are gone: Draft is the status tag with a dashed outline (DESIGN.md's Draft state). Card tags are a plain Archivo comma list; excerpts now end on a word with an ellipsis.

  Source page: the shadowed box is gone. The title row is the name at the display size with its type as a status tag and Edit/Delete held at the top right on a 2px rule (they drop below the name on phones), with a Back to Sources link above it as on the article pages. The facts are a term list on hairlines like CoreComponents.list (132px Archivo term, serif value with tabular figures; one column under 480px); the Type row is dropped since the tag already says it. The description is serif 17px at 68ch, notes are Archivo ink-3 metadata (not italic, which belongs to scientific names). Coverage stays as a section (structure and tests) but is the line 'N species' rather than a big-number tile. The species are a ruled list of serif italic names in up to four columns, the hybrid sign roman.

  Articles: the article page's header is the back link, the title at display size with the dashed Draft tag, an Archivo byline, topic links in pencil Archivo (so Draft is the only stamp), and compact Edit/Delete at the top right, all on a 2px rule; the body loses the card padding and keeps b4f7's prose. Forms: titles are serif 600 clamp(28-36px) without a rule (each section already stands on one), sections sit 48px apart with no card padding, grid row gaps no longer double the field margins, the draft hint sits under its checkbox label, the source description and notes textareas get 6 and 3 rows, and Cancel (ghost) and the submit (primary ochre, DESIGN.md's editor primary) stand on a hairline.

  Dialogs: the hand-built delete overlays are kept (swapping to CoreComponents.modal would change their show/hide and Escape bindings) on an ink wash with b4f7's bordered card; Cancel is ghost and Delete primary, as in the /dev/components dialog. A source with species data now gets 'Can't Delete Source', the reason between 2px ink rules and one Close button, instead of asking 'Are you sure' and then refusing.

  Shared classes in my section: .action-btn, .edit-content-btn and .create-taxon-btn are the system's outlined ink button (Archivo 700, 1.5px ink, square, inverting to ink on hover) at compact (13px), small (12.5px) and regular (14px) sizes; edit and delete variants look the same because DESIGN.md has no destructive colour, and heroicons inside are hidden (the label carries the meaning, as b4f7 did for Write/Preview). Labels may wrap as in V1, so the class never forces a row wider than its page. .species-name stays the serif italic. Page-specific overrides (the species page's purple .action-btn-synonym) stay with their own items. The unused .markdown-editor*, .tag-*, .type-badge and .source-stat-* rules were deleted after grepping lib and assets/js.

  Width: all six pages now share max-w-4xl (56rem), after the finish review found the title jumping in width and size between sibling pages. The list headers use a page-level arbitrary variant ([&>div:first-child]:flex-[1_1_20rem]) so the header's text column flexes and the action sits at the right beside a long subtitle; the clean fix is in CoreComponents.header (noted as a shared need).

  Rejected: rebuilding the source page around the section label's right-hand note (moving coverage into the species heading) since it removes a section; restyling the topic filter (b4f7's badges already read right there); changing the article markdown (scientific names not italic in Jeff's text is content).

  Review: own headless Chromium at 1440 and 390, logged out and in, on /sources, /sources/2, /sources/4 (long description, 46 species), /sources/5 (long name, URL), /sources/999, /sources/new, /sources/4/edit, /articles, /articles?tag=none (empty state), the draft article, /articles/nope, /articles/new and the article edit, plus /species/shumardii and /taxonomy/Quercus for the shared buttons; hover, keyboard focus on a row and its Edit button, and both delete dialogs. No page body overflows at 390 except /species/shumardii, whose header action row has no wrap (item 1adb; it overflowed before this item too). The detector is clean on the changed files apart from two advisories (21px and 14px, both on DESIGN.md's prose ramp); URL scans are clean at 1280 and leave one 390px monotonous-spacing warning on /sources from the status tags' 4px padding, which is DESIGN.md's spec. The impeccable finish reviewer scored the first pass 7/10 with eight fixes; they and its three smaller items were applied in the second commit, except moving coverage into the species heading's note (noted above); the forms' titles stay smaller than the display size, which the reviewer listed as out of scope.
decisions:
  - id: 091f
    text: 'Sources and articles lists are ruled rows: the whole row is the link, it tints paper-2 on hover with a 12px bleed each side while its hairline ends with the column; source descriptions and article previews hold a 68ch measure'
    detail: DESIGN.md's ruled lists; the bleed keeps the text aligned with the title row while the hover ground has room
  - id: 2df3
    text: The shared .action-btn, .edit-content-btn and .create-taxon-btn are the system's outlined ink button (Archivo 700, 1.5px ink, inverting to ink on hover) at compact, small and regular sizes; Edit and Delete look the same, and heroicons inside them are hidden
    detail: DESIGN.md has no destructive colour (marks not colours); the label carries the meaning, as b4f7 did for Write/Preview
  - id: 7a14
    text: Source type is a status tag on the list and the source page; the source page's facts are a term list on hairlines (132px term column, stacking under 480px), notes are Archivo ink-3 metadata, coverage is a count in lining figures, and the species are a ruled list of italic names in columns
    detail: Statements on rules, not cards or stat tiles
  - id: cf0e
    text: Draft is the status tag with a dashed outline (the editor's Draft state in DESIGN.md); the amber badge and the amber side stripe on draft rows are gone
    detail: Marks not colours; a coloured side stripe is banned
  - id: d916
    text: Form submits are the primary ochre button with Cancel as the ghost button on a hairline; form titles are serif 600 at clamp(28px, 3vw, 36px) without a rule, since each form section already stands on a 2px rule
    detail: DESIGN.md's editor uses ochre for the primary action; a ruled title over ruled section labels doubled the rules
  - id: e880
    text: The pages keep their V1 centred column widths (max-w-3xl, 4xl, 5xl); list and not-found titles use CoreComponents.header, with a page-level arbitrary variant letting its text column flex so the action sits at the right
    detail: 'Bridge scope: page width is structure, left to the rebuild; the header''s text column not flexing is a shared-component need'
  - id: f02e
    text: Delete dialogs keep their hand-built overlay (ink wash, the b4f7 bordered card); Cancel is the ghost button and the confirming action (Delete, or OK when it can't delete) the primary ochre button, as in the /dev/components dialog; 'Cannot delete' stands between 2px ink rules
    detail: Swapping to CoreComponents.modal would change the show/hide and Escape bindings the pages and tests rely on
  - id: 05c4
    text: 'Replaces e880: the six sources and articles pages share one centred column (max-w-4xl, 56rem) and their detail titles take DESIGN.md''s display size, clamp(34px, 4vw, 50px), like the CoreComponents.header titles on the lists; the title row''s Edit and Delete hold its top right however the title wraps'
    detail: The finish review found the title jumping in width and size between sibling pages; the column width is a one-class change per page, so it fits the bridge
  - id: ccb9
    text: On the source page the type is shown once, as the title row's status tag (the Type row is dropped), coverage is the line 'N species' in Archivo, and a Back to Sources link sits above the title as on the article pages; an article's topics are pencil Archivo links in its title row, so Draft is the only stamp there
    detail: 'Finish review: duplicate type, a hero-metric count, and the topic tag reading as a status'
  - id: f15b
    text: A source that can't be deleted gets a dialog titled 'Can't Delete Source' with the reason between 2px rules and a single ghost Close, instead of asking 'Are you sure' and offering Cancel and an ochre OK
    detail: The old copy asked a question it then refused; ochre is for the next step, and closing isn't one
---

# Done report 1: Bridge restyle: sources and articles (fe6d)

**Status:** PASSED  
**Commit:** 195bbaac25c3  
**By:** /Users/jeff/dev/oaks/.claude/worktrees/agent-a6b12642d455b4bb4 at 2026-11-22T01:43:08Z

## What was built

### Summary

The sources and articles pages now speak DESIGN.md without being restructured: both lists are ruled rows (whole-row links, paper-2 hover, descriptions at a 68ch measure), source types and drafts are status tags (Draft dashed), the source page is a title row over a ruled term list, a count and a ruled list of italic names, the article page is a ruled title row over b4f7's prose, and the forms, back links, dialogs and buttons use the system's header, back link and buttons, all six pages in one column width. The shared .action-btn, .edit-content-btn and .create-taxon-btn are now the system's outlined ink button, .species-name stays the serif italic, and the unused .markdown-editor and .tag-* rules are deleted.

### UI tour

1. Run PORT=4454 mix phx.server in this worktree and open localhost:4454/sources: DATA SOURCES title on a 2px ink rule, then each source as a row on a hairline with its type as an outlined ink stamp, Archivo author and year, the count at the right, and descriptions wrapping at a reading measure; hover a row and it tints paper-2 with the name underlined.
2. Open localhost:4454/sources/4: Back to Sources, the name in large serif with a BOOK stamp, a ruled Author/Year/ISBN list, the description in serif at a measure, notes in small grey Archivo, COVERAGE reading '46 species', and the species as a ruled four-column list of italic names.
3. Open localhost:4454/sources/5: the long name wraps over two lines with Edit and Delete (when logged in) staying at the top right; the URL row is a pencil link that wraps on phones.
4. Open localhost:4454/articles: Articles title row, the topic filter, and rows on hairlines; no amber anywhere.
5. Log in with 'Log in as dev user' on localhost:4454/users/log-in and reopen localhost:4454/sources: Create Source is an outlined button at the title row's right; hover a row (or Tab into it) and compact Edit and Delete appear at its right.
6. Click Delete on the Oak Compendium row: a square paper dialog with a 2px ink border titled Can't Delete Source, the reason between two ink rules, and one Close button; Escape also closes it.
7. Open localhost:4454/articles: the draft row carries a dashed DRAFT stamp; open it: the title at display size with the dashed DRAFT stamp, By Jeff Clark, the topic as a pencil link, and Edit and Delete at the top right on a 2px rule; click Delete to see Cancel and an ochre Delete (press Cancel).
8. Open localhost:4454/sources/4/edit and localhost:4454/articles/new: Back link, serif title, sections on 2px rules 48px apart, white square fields, the draft hint under the Published checkbox, Cancel and an ochre Create or Save button on a hairline.
9. Open localhost:4454/species/shumardii and localhost:4454/taxonomy/Quercus: Edit, Delete, Create Taxon and Add Content are square outlined ink buttons without icons that invert on hover (the purple Make Synonym Of... is item 1adb's).
10. Narrow to 390px on the sources and articles pages: nothing scrolls sideways; on /sources the editor buttons are always shown and the counts sit at the right.

### Checks (run by mull)

- `make done-checks`: pass, 74.9s

## How it was built

### Design notes

Approach: a bridge, not a rebuild. Page structure, element ids, phx bindings and test hooks are kept; the change is CSS in app.css's two fe6d sections (Sources List Page, Source Detail Page) plus template classes, with the system components swapped in where the swap is one line: CoreComponents.header for the list and not-found title rows, .button for every V1 inline-styled button and link-button, .back for the back links, DesignComponents.status_tag for source types and Draft. No shared file (assets/css/system/*, core/design/form components, layouts) was edited.

Lists: the sources list and the articles list are DESIGN.md's ruled lists. Each row is one link (the sources row keeps its stretched anchor so its editor buttons stay clickable), tints paper-2 on hover and bleeds 12px past the column on each side so its text lines up with the title row; the hairline is a background gradient inset by the bleed, so it ends with the column instead of poking out. Descriptions and excerpts hold a 68ch measure (they ran about 100 characters a line). Source names are serif 600 21px, meta and counts Archivo with lining tabular figures, the count pushed right even when it wraps on phones. The editor's Edit/Delete were icon-only buttons with a title; they are now compact outlined text buttons with aria-labels naming the source, hidden until the row is hovered or has keyboard focus (and taking no clicks while hidden), always shown where there is no hover and under 640px. The articles list's row is a new .article-row in the same section, replacing card-interactive, whose unlayered border would have run past the column. The amber side stripe and amber Draft badge are gone: Draft is the status tag with a dashed outline (DESIGN.md's Draft state). Card tags are a plain Archivo comma list; excerpts now end on a word with an ellipsis.

Source page: the shadowed box is gone. The title row is the name at the display size with its type as a status tag and Edit/Delete held at the top right on a 2px rule (they drop below the name on phones), with a Back to Sources link above it as on the article pages. The facts are a term list on hairlines like CoreComponents.list (132px Archivo term, serif value with tabular figures; one column under 480px); the Type row is dropped since the tag already says it. The description is serif 17px at 68ch, notes are Archivo ink-3 metadata (not italic, which belongs to scientific names). Coverage stays as a section (structure and tests) but is the line 'N species' rather than a big-number tile. The species are a ruled list of serif italic names in up to four columns, the hybrid sign roman.

Articles: the article page's header is the back link, the title at display size with the dashed Draft tag, an Archivo byline, topic links in pencil Archivo (so Draft is the only stamp), and compact Edit/Delete at the top right, all on a 2px rule; the body loses the card padding and keeps b4f7's prose. Forms: titles are serif 600 clamp(28-36px) without a rule (each section already stands on one), sections sit 48px apart with no card padding, grid row gaps no longer double the field margins, the draft hint sits under its checkbox label, the source description and notes textareas get 6 and 3 rows, and Cancel (ghost) and the submit (primary ochre, DESIGN.md's editor primary) stand on a hairline.

Dialogs: the hand-built delete overlays are kept (swapping to CoreComponents.modal would change their show/hide and Escape bindings) on an ink wash with b4f7's bordered card; Cancel is ghost and Delete primary, as in the /dev/components dialog. A source with species data now gets 'Can't Delete Source', the reason between 2px ink rules and one Close button, instead of asking 'Are you sure' and then refusing.

Shared classes in my section: .action-btn, .edit-content-btn and .create-taxon-btn are the system's outlined ink button (Archivo 700, 1.5px ink, square, inverting to ink on hover) at compact (13px), small (12.5px) and regular (14px) sizes; edit and delete variants look the same because DESIGN.md has no destructive colour, and heroicons inside are hidden (the label carries the meaning, as b4f7 did for Write/Preview). Labels may wrap as in V1, so the class never forces a row wider than its page. .species-name stays the serif italic. Page-specific overrides (the species page's purple .action-btn-synonym) stay with their own items. The unused .markdown-editor*, .tag-*, .type-badge and .source-stat-* rules were deleted after grepping lib and assets/js.

Width: all six pages now share max-w-4xl (56rem), after the finish review found the title jumping in width and size between sibling pages. The list headers use a page-level arbitrary variant ([&>div:first-child]:flex-[1_1_20rem]) so the header's text column flexes and the action sits at the right beside a long subtitle; the clean fix is in CoreComponents.header (noted as a shared need).

Rejected: rebuilding the source page around the section label's right-hand note (moving coverage into the species heading) since it removes a section; restyling the topic filter (b4f7's badges already read right there); changing the article markdown (scientific names not italic in Jeff's text is content).

Review: own headless Chromium at 1440 and 390, logged out and in, on /sources, /sources/2, /sources/4 (long description, 46 species), /sources/5 (long name, URL), /sources/999, /sources/new, /sources/4/edit, /articles, /articles?tag=none (empty state), the draft article, /articles/nope, /articles/new and the article edit, plus /species/shumardii and /taxonomy/Quercus for the shared buttons; hover, keyboard focus on a row and its Edit button, and both delete dialogs. No page body overflows at 390 except /species/shumardii, whose header action row has no wrap (item 1adb; it overflowed before this item too). The detector is clean on the changed files apart from two advisories (21px and 14px, both on DESIGN.md's prose ramp); URL scans are clean at 1280 and leave one 390px monotonous-spacing warning on /sources from the status tags' 4px padding, which is DESIGN.md's spec. The impeccable finish reviewer scored the first pass 7/10 with eight fixes; they and its three smaller items were applied in the second commit, except moving coverage into the species heading's note (noted above); the forms' titles stay smaller than the display size, which the reviewer listed as out of scope.

### Decisions made in the session

Accepting the review ratifies these. To decide one differently, before accepting: `mull decide <id> "..."`

- **091f** Sources and articles lists are ruled rows: the whole row is the link, it tints paper-2 on hover with a 12px bleed each side while its hairline ends with the column; source descriptions and article previews hold a 68ch measure
  Why: DESIGN.md's ruled lists; the bleed keeps the text aligned with the title row while the hover ground has room
- **2df3** The shared .action-btn, .edit-content-btn and .create-taxon-btn are the system's outlined ink button (Archivo 700, 1.5px ink, inverting to ink on hover) at compact, small and regular sizes; Edit and Delete look the same, and heroicons inside them are hidden
  Why: DESIGN.md has no destructive colour (marks not colours); the label carries the meaning, as b4f7 did for Write/Preview
- **7a14** Source type is a status tag on the list and the source page; the source page's facts are a term list on hairlines (132px term column, stacking under 480px), notes are Archivo ink-3 metadata, coverage is a count in lining figures, and the species are a ruled list of italic names in columns
  Why: Statements on rules, not cards or stat tiles
- **cf0e** Draft is the status tag with a dashed outline (the editor's Draft state in DESIGN.md); the amber badge and the amber side stripe on draft rows are gone
  Why: Marks not colours; a coloured side stripe is banned
- **d916** Form submits are the primary ochre button with Cancel as the ghost button on a hairline; form titles are serif 600 at clamp(28px, 3vw, 36px) without a rule, since each form section already stands on a 2px rule
  Why: DESIGN.md's editor uses ochre for the primary action; a ruled title over ruled section labels doubled the rules
- **e880** The pages keep their V1 centred column widths (max-w-3xl, 4xl, 5xl); list and not-found titles use CoreComponents.header, with a page-level arbitrary variant letting its text column flex so the action sits at the right
  Why: Bridge scope: page width is structure, left to the rebuild; the header's text column not flexing is a shared-component need
- **f02e** Delete dialogs keep their hand-built overlay (ink wash, the b4f7 bordered card); Cancel is the ghost button and the confirming action (Delete, or OK when it can't delete) the primary ochre button, as in the /dev/components dialog; 'Cannot delete' stands between 2px ink rules
  Why: Swapping to CoreComponents.modal would change the show/hide and Escape bindings the pages and tests rely on
- **05c4** Replaces e880: the six sources and articles pages share one centred column (max-w-4xl, 56rem) and their detail titles take DESIGN.md's display size, clamp(34px, 4vw, 50px), like the CoreComponents.header titles on the lists; the title row's Edit and Delete hold its top right however the title wraps
  Why: The finish review found the title jumping in width and size between sibling pages; the column width is a one-class change per page, so it fits the bridge
- **ccb9** On the source page the type is shown once, as the title row's status tag (the Type row is dropped), coverage is the line 'N species' in Archivo, and a Back to Sources link sits above the title as on the article pages; an article's topics are pencil Archivo links in its title row, so Draft is the only stamp there
  Why: Finish review: duplicate type, a hero-metric count, and the topic tag reading as a status
- **f15b** A source that can't be deleted gets a dialog titled 'Can't Delete Source' with the reason between 2px rules and a single ghost Close, instead of asking 'Are you sure' and offering Cancel and an ochre OK
  Why: The old copy asked a question it then refused; ochre is for the next step, and closing isn't one

### Changes by layer

**tests**: 3 files, +44 −2
- M test/oaks_web/live/articles_live_test.exs (+12 −0)
- M test/oaks_web/live/source_detail_live_test.exs (+19 −2)
- M test/oaks_web/live/sources_live_test.exs (+13 −0)

**ui**: 7 files, +445 −771
- M assets/css/app.css (+248 −397)
- M lib/oaks_web/live/article_form_live.ex (+15 −35)
- M lib/oaks_web/live/article_live.ex (+48 −101)
- M lib/oaks_web/live/articles_live.ex (+46 −70)
- M lib/oaks_web/live/source_detail_live.ex (+35 −58)
- M lib/oaks_web/live/source_form_live.ex (+15 −33)
- M lib/oaks_web/live/sources_live.ex (+38 −77)
