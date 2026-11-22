---
item: 1adb
"n": 1
passed: true
commit: d93711caad3dab220f18533600fca60a2f735143
base: 235b0199cf04435e202b7b382887d836a9995190
at: "2026-11-22T01:39:11Z"
by: /Users/jeff/dev/oaks/.claude/worktrees/agent-a11c0073ef452c088
summary: 'The species page and the species source form now read in DESIGN.md''s voice with their structure, ids and bindings unchanged: the boxed gradient header is the title row on a 2px rule (breadcrumb above, italic name, roman author, IUCN status stamp, editor buttons that wrap on phones, fixing bug 10df), relationships, hybrids and external links are rows on hairlines with names italic and the hybrid sign and rank words roman, source tabs stand on the ink rule with the current tab on the ochre underline (scrolling on phones), source fields are Archivo labels beside serif text with the heading levels fixed, and the delete and Make synonym dialogs use the modal panel with an ink-plate confirm. The source form uses the system''s header, back link, section labels and buttons. Built on b4f7''s shared bridge; the next step is the real taxon page in the Taxon pages phase.'
tour:
  - 'Run PORT=4451 mix phx.server in this worktree and open localhost:4451/species/shumardii: the breadcrumb sits above ''Quercus shumardii'' (genus light, epithet bold, italic) with ''Buckley'' roman and grey; at the right ''Species'' and an outlined IUCN LC stamp; a 2px ink rule under the row.'
  - 'KNOWN HYBRIDS (9 known) lists ''Q. × discreta with velutina'' and so on in two columns on hairlines: names italic, the × roman, no left bars. SYNONYMS (2 names) reads ''schneckii, texana Auctores'' with the authority roman.'
  - The source tabs stand on the ink rule with Oaks of the World on an ochre underline; click The Sibley Guide to Trees and the underline and the 'Data from' line move. Compare sources is the ochre button at the right. Fields are bold Archivo labels in a left column beside serif text.
  - EXTERNAL LINKS is a ruled list of blue links, each followed by its site (fs.usda.gov, inaturalist.org ...); no logo boxes.
  - 'Open localhost:4451/species/alba: the Oak Compendium tab says ''preferred''; the synonyms show authorities roman (candida Steud., ...).'
  - 'Open localhost:4451/species/schneckii: it redirects to shumardii.'
  - 'Open localhost:4451/species/acatenangensis: SOURCE DATA with ''No source data available for this species.'' in grey italic.'
  - 'Log in with ''Log in as dev user'' on localhost:4451/users/log-in, open /species/shumardii: Edit, Make synonym of… and Delete are outlined buttons behind a thin divider, Delete set apart; Add source sits beside Compare sources; the source has Edit and Delete.'
  - 'Click Make synonym of…: a square panel with a 2px ink border, a Close Esc button, a white search field; type ''rub'' for ruled results (italic names, author and ''sect. Lobatae'' in grey); Esc or a click outside closes it.'
  - 'Click Delete: ''Delete species'' lists all nine hybrids that mention shumardii; ''Delete species'' is a black plate beside an outlined Cancel; press Esc (don''t confirm).'
  - 'Narrow to 390px: nothing scrolls sideways; the editor buttons wrap under the title; the source tabs stay on one line and fade at the right edge, with Compare sources and Add source on the row under them; the delete dialog''s body scrolls and its buttons stay in view.'
  - 'Open localhost:4451/species/shumardii/sources/new: a Back to species link, ''Add source data'' title with the italic name under it, SOURCE, MORPHOLOGY & DESCRIPTION and ADDITIONAL INFORMATION section labels, white square fields, and an ochre ''Add source data'' button beside an outlined Cancel. /species/alba/sources/2/edit shows ''Edit source data'' with the source named under SOURCE.'
checks:
  tree: 6fc76a2cafe76db03c8e315a17234e8bf446d9dc
  commit: d93711caad3dab220f18533600fca60a2f735143
  at: "2026-11-22T01:38:08Z"
  by: /Users/jeff/dev/oaks/.claude/worktrees/agent-a11c0073ef452c088
  passed: true
  results:
    - command: make done-checks
      exit: 0
      duration_ms: 62920
changes:
  - layer: tests
    files:
      - status: M
        path: test/oaks_web/live/species_detail_live_test.exs
        added: 19
        removed: 11
      - status: M
        path: test/oaks_web/live/species_form_live_test.exs
        added: 1
        removed: 1
      - status: M
        path: test/oaks_web/live/species_source_form_live_test.exs
        added: 3
        removed: 3
  - layer: ui
    files:
      - status: M
        path: assets/css/app.css
        added: 439
        removed: 199
      - status: M
        path: lib/oaks_web/live/species_detail_live.ex
        added: 329
        removed: 531
      - status: M
        path: lib/oaks_web/live/species_source_form_live.ex
        added: 39
        removed: 48
design: |-
  Approach: a bridge, not a rebuild. The species page and the species source form keep their structure, element ids, phx bindings and test hooks; the work is in their templates' classes and inline styles and in the app.css sections 1adb owns (Species Detail - Container, Header, Hybrid Items, External Links, Source Tabs, and the dialogs block at the end, which replaces the old merge picker rules). Every V1 rule in those sections was rewritten on DESIGN.md tokens; nothing outside them changed except one assertion in species_form_live_test.exs that checks the delete dialog's label.

  Shared components over local CSS where the swap was cheap: DesignComponents.section_heading (labels with a right-hand note, replacing the V1 section titles and their icons), status_tag (the IUCN stamp), compare_button (Compare sources, the one ochre call to action); CoreComponents.button (every editor action, ghost compact; the source form's submit is the ochre primary), header and back (not-found view and the source form), and the modal component's classes (oc-modal-backdrop/panel/head/body/actions) applied in place in the three dialogs, so their server-driven show/hide, ids and Esc bindings stay. I did not use the shared .action-btn/.species-name/.edit-content-btn classes at all, so no page-scoped override of fe6d's classes was needed.

  Header: the gradient box becomes the title row on a 2px ink rule, with the V1 breadcrumb moved above it where the ochre band will go. The name is the display serif italic (genus 400, epithet 600), the author 22px roman ink-3, then at the right the kind word in Archivo and the stamp "IUCN LC" (category spelled out in the title and an sr-only span). The editor buttons follow behind a hairline on desktop and take their own row under 760px, so the row wraps instead of widening the page: that fixes bug 10df (logged in at 390px the page was 615px wide).

  Names: one private helper (sci_html) renders any scientific name in the serif with names italic and the hybrid sign and rank words roman, built as one run of HTML so template whitespace can't fall between parts; it is used in the title, hybrid rows ("Q. × discreta with velutina"), parents, related, varieties, synonyms, the dialogs and the merge results. Synonyms are stored as strings with the authority appended, so name_and_authority splits at the first word starting with a capital or "(" and the authority is set roman. Synonyms and common names are a plain comma list in the page's own markup, because b4f7's pill-tag comma started a wrapped line with a comma.

  Lists: relationships, hybrids and external links are rows on hairlines (hybrids two columns from 761px). The 4px left bar, the gradient and the boxed logo buttons are gone; external links are pencil links with their host name in ink-3, and the coloured logos are dropped (captured as a bug: the logo SVGs are now unused).

  Source tabs stay tabs: the tablist moved to an inner wrapper so it holds only tabs; the strip stands on the 2px ink rule and the current tab carries the 3px ochre underline, as the masthead's current item does. On phones the tabs keep one row and scroll sideways with a fade at the right edge (a two-layer mask so the rule under them doesn't fade), and Compare sources and Add source take the row below. The preferred source says "preferred" in words instead of the ★ glyph. Source fields drop their icons and become an 11rem Archivo label column beside the serif text, stacking on phones; "Data from X" is now the h2 and the field labels h3, fixing the h2 to h4 skip. With no sources the section gets a "Source data" label over the italic empty statement.

  Dialogs: the panel is paper with the 2px ink border over the ink wash; the destructive confirm is an ink plate (page-scoped .species-btn-plate) beside a ghost Cancel, so delete is told apart by label, placement and weight rather than red. The delete dialog's body scrolls inside the panel (max 80vh) instead of clipping its list of affected species. The merge picker closes on a backdrop click, and Enter in its search no longer submits the page.

  Rejected: keeping the browser-style tabs or replacing them with the prototype's field-marks table (prototype scope), swapping the dialogs to CoreComponents.modal (different show/hide mechanics for no visual gain), page-scoped overrides of .action-btn (not needed once the buttons became components), a stamp for the kind word (two stamps in one title row), ochre for the destructive confirm, and an ignore entry in .impeccable/config.json for the italic h1 (a shared file other items are editing).

  Review: Playwright at 1440 and 390, logged out and logged in, on shumardii, alba (three sources, tabs switched), acerifolia (authority in a synonym), the formula hybrid agrifolia × parvula shrevei (parents, no sources), acatenangensis (no sources), the schneckii synonym redirect, the delete, delete-source and Make synonym dialogs, /species/shumardii/sources/new and /species/alba/sources/2/edit; no horizontal overflow at 390 on any of them. The detector is clean on the changed files' owned sections; on the live pages it reports only italic-serif-display on the h1, which DESIGN.md's Botanical Italic Rule requires (the prototypes carry an ignore for the same rule). The impeccable finish reviewer scored the first pass 8/10 with six fixes (clipped delete list, glyph star, stamp reading as a button, unmarked phone tab overflow, category only in a tooltip, inconsistent count notes); all six were applied in the second commit.
decisions:
  - id: 07ba
    text: Copy on the species page and source form moves to sentence case (Make synonym of…, Add source, Compare sources, Delete species, Species not found, Back to species list, Add source data, Save changes)
    detail: Matches the shell's Add species and DESIGN.md's labels; tests updated, including the one assertion in species_form_live_test.exs
  - id: 23c0
    text: 'Source tabs stay tabs: the tablist is an inner wrapper on the 2px ink rule, the current tab carries the 3px ochre underline, the tabs scroll sideways on phones with Compare sources (the ochre compare_button) and Add source on the row under them'
    detail: DESIGN.md's current-item mark is the ochre underline; wrapping tabs on phones left the underline floating off the rule
  - id: 4ef9
    text: External links are a ruled list of pencil links, each followed by its host name in ink-3; the brand logos (including the iNaturalist wordmark shown without text) are dropped
    detail: Coloured logos are off-palette and DESIGN.md has no boxed link buttons; the host tells the reader where the link goes
  - id: 8c98
    text: 'Source fields drop their icons: each is an Archivo label in an 11rem column beside the serif text on a hairline, stacking on phones; ''Data from X'' is the h2 and the field labels are h3 (was h4 under no h2)'
    detail: Follows the prototype's trait-name column and fixes the skipped heading level
  - id: "8e04"
    text: The V1 breadcrumb moves above the title row inside the species header, where the ochre band will go, and the header's 2px rule runs under the title
    detail: DESIGN.md stacks band, then title row on a 2px rule; moving it within the header keeps the page structure
  - id: 9c56
    text: 'Scientific names on the species page follow the Botanical Italic Rule through one helper: names italic, the hybrid sign and rank words (var., subsp., f. ...) roman; a stored synonym string splits its authority at the first word starting with a capital or ''('' (shumardii var. acerifolia | E.J.Palmer 1927)'
    detail: Synonyms are stored as plain strings with the authority appended; epithets and rank words are lower case
  - id: d272
    text: Species page editor buttons (Edit, Make synonym of…, Delete, source Edit and Delete, Add source) are CoreComponents ghost compact buttons rather than the shared .action-btn classes; Delete is set apart at the end of its row, and a dialog's destructive confirm is an ink plate (.species-btn-plate, page-scoped)
    detail: No colour for destruction (DESIGN.md has no red); label, placement and the plate carry it; ochre stays for Compare; avoids depending on fe6d's parallel .action-btn restyle
  - id: fcc9
    text: 'The species title row shows the conservation status as a status tag reading IUCN plus the code (IUCN LC), with the category spelled out in its title (IUCN Red List: Least Concern) and no source mark; the kind (Species or Hybrid) is plain Archivo text beside it, not a second stamp'
    detail: The stored codes are exactly the IUCN Red List categories; the data holds no assessment edition to cite, so no source mark is invented
  - id: 904c
    text: The species detail dialogs (delete, delete source data, Make synonym of) use the modal component's classes (oc-modal-backdrop, oc-modal-panel, head, body, actions) in place, keeping their ids and phx bindings; the merge picker closes on a backdrop click and its search no longer submits the page on Enter
    detail: Swapping to CoreComponents.modal would change its show/hide mechanics; the classes give the same look with the existing server-driven state
  - id: c670
    text: With no sources, the source section gets a 'Source data' section label over the empty statement (italic ink-3) and the Add source button
    detail: Without the tab strip the empty state had no rule or label of its own
  - id: 5d74
    text: Synonyms and common names on the species page are a plain comma list in the page's own markup, not b4f7's pill-tag comma trick
    detail: In a wrapping flex row the pill-tag comma started the second line
  - id: a394
    text: The preferred source's tab says 'preferred' in Archivo 12.5px ink-3 instead of the ★ glyph
    detail: DESIGN.md reserves a drawn star for key difference and the floor bans glyph icons; the word also reaches screen readers and touch
---

# Done report 1: Bridge restyle: species detail and species source form (1adb)

**Status:** PASSED  
**Commit:** d93711caad3d  
**By:** /Users/jeff/dev/oaks/.claude/worktrees/agent-a11c0073ef452c088 at 2026-11-22T01:39:11Z

## What was built

### Summary

The species page and the species source form now read in DESIGN.md's voice with their structure, ids and bindings unchanged: the boxed gradient header is the title row on a 2px rule (breadcrumb above, italic name, roman author, IUCN status stamp, editor buttons that wrap on phones, fixing bug 10df), relationships, hybrids and external links are rows on hairlines with names italic and the hybrid sign and rank words roman, source tabs stand on the ink rule with the current tab on the ochre underline (scrolling on phones), source fields are Archivo labels beside serif text with the heading levels fixed, and the delete and Make synonym dialogs use the modal panel with an ink-plate confirm. The source form uses the system's header, back link, section labels and buttons. Built on b4f7's shared bridge; the next step is the real taxon page in the Taxon pages phase.

### UI tour

1. Run PORT=4451 mix phx.server in this worktree and open localhost:4451/species/shumardii: the breadcrumb sits above 'Quercus shumardii' (genus light, epithet bold, italic) with 'Buckley' roman and grey; at the right 'Species' and an outlined IUCN LC stamp; a 2px ink rule under the row.
2. KNOWN HYBRIDS (9 known) lists 'Q. × discreta with velutina' and so on in two columns on hairlines: names italic, the × roman, no left bars. SYNONYMS (2 names) reads 'schneckii, texana Auctores' with the authority roman.
3. The source tabs stand on the ink rule with Oaks of the World on an ochre underline; click The Sibley Guide to Trees and the underline and the 'Data from' line move. Compare sources is the ochre button at the right. Fields are bold Archivo labels in a left column beside serif text.
4. EXTERNAL LINKS is a ruled list of blue links, each followed by its site (fs.usda.gov, inaturalist.org ...); no logo boxes.
5. Open localhost:4451/species/alba: the Oak Compendium tab says 'preferred'; the synonyms show authorities roman (candida Steud., ...).
6. Open localhost:4451/species/schneckii: it redirects to shumardii.
7. Open localhost:4451/species/acatenangensis: SOURCE DATA with 'No source data available for this species.' in grey italic.
8. Log in with 'Log in as dev user' on localhost:4451/users/log-in, open /species/shumardii: Edit, Make synonym of… and Delete are outlined buttons behind a thin divider, Delete set apart; Add source sits beside Compare sources; the source has Edit and Delete.
9. Click Make synonym of…: a square panel with a 2px ink border, a Close Esc button, a white search field; type 'rub' for ruled results (italic names, author and 'sect. Lobatae' in grey); Esc or a click outside closes it.
10. Click Delete: 'Delete species' lists all nine hybrids that mention shumardii; 'Delete species' is a black plate beside an outlined Cancel; press Esc (don't confirm).
11. Narrow to 390px: nothing scrolls sideways; the editor buttons wrap under the title; the source tabs stay on one line and fade at the right edge, with Compare sources and Add source on the row under them; the delete dialog's body scrolls and its buttons stay in view.
12. Open localhost:4451/species/shumardii/sources/new: a Back to species link, 'Add source data' title with the italic name under it, SOURCE, MORPHOLOGY & DESCRIPTION and ADDITIONAL INFORMATION section labels, white square fields, and an ochre 'Add source data' button beside an outlined Cancel. /species/alba/sources/2/edit shows 'Edit source data' with the source named under SOURCE.

### Checks (run by mull)

- `make done-checks`: pass, 62.9s

## How it was built

### Design notes

Approach: a bridge, not a rebuild. The species page and the species source form keep their structure, element ids, phx bindings and test hooks; the work is in their templates' classes and inline styles and in the app.css sections 1adb owns (Species Detail - Container, Header, Hybrid Items, External Links, Source Tabs, and the dialogs block at the end, which replaces the old merge picker rules). Every V1 rule in those sections was rewritten on DESIGN.md tokens; nothing outside them changed except one assertion in species_form_live_test.exs that checks the delete dialog's label.

Shared components over local CSS where the swap was cheap: DesignComponents.section_heading (labels with a right-hand note, replacing the V1 section titles and their icons), status_tag (the IUCN stamp), compare_button (Compare sources, the one ochre call to action); CoreComponents.button (every editor action, ghost compact; the source form's submit is the ochre primary), header and back (not-found view and the source form), and the modal component's classes (oc-modal-backdrop/panel/head/body/actions) applied in place in the three dialogs, so their server-driven show/hide, ids and Esc bindings stay. I did not use the shared .action-btn/.species-name/.edit-content-btn classes at all, so no page-scoped override of fe6d's classes was needed.

Header: the gradient box becomes the title row on a 2px ink rule, with the V1 breadcrumb moved above it where the ochre band will go. The name is the display serif italic (genus 400, epithet 600), the author 22px roman ink-3, then at the right the kind word in Archivo and the stamp "IUCN LC" (category spelled out in the title and an sr-only span). The editor buttons follow behind a hairline on desktop and take their own row under 760px, so the row wraps instead of widening the page: that fixes bug 10df (logged in at 390px the page was 615px wide).

Names: one private helper (sci_html) renders any scientific name in the serif with names italic and the hybrid sign and rank words roman, built as one run of HTML so template whitespace can't fall between parts; it is used in the title, hybrid rows ("Q. × discreta with velutina"), parents, related, varieties, synonyms, the dialogs and the merge results. Synonyms are stored as strings with the authority appended, so name_and_authority splits at the first word starting with a capital or "(" and the authority is set roman. Synonyms and common names are a plain comma list in the page's own markup, because b4f7's pill-tag comma started a wrapped line with a comma.

Lists: relationships, hybrids and external links are rows on hairlines (hybrids two columns from 761px). The 4px left bar, the gradient and the boxed logo buttons are gone; external links are pencil links with their host name in ink-3, and the coloured logos are dropped (captured as a bug: the logo SVGs are now unused).

Source tabs stay tabs: the tablist moved to an inner wrapper so it holds only tabs; the strip stands on the 2px ink rule and the current tab carries the 3px ochre underline, as the masthead's current item does. On phones the tabs keep one row and scroll sideways with a fade at the right edge (a two-layer mask so the rule under them doesn't fade), and Compare sources and Add source take the row below. The preferred source says "preferred" in words instead of the ★ glyph. Source fields drop their icons and become an 11rem Archivo label column beside the serif text, stacking on phones; "Data from X" is now the h2 and the field labels h3, fixing the h2 to h4 skip. With no sources the section gets a "Source data" label over the italic empty statement.

Dialogs: the panel is paper with the 2px ink border over the ink wash; the destructive confirm is an ink plate (page-scoped .species-btn-plate) beside a ghost Cancel, so delete is told apart by label, placement and weight rather than red. The delete dialog's body scrolls inside the panel (max 80vh) instead of clipping its list of affected species. The merge picker closes on a backdrop click, and Enter in its search no longer submits the page.

Rejected: keeping the browser-style tabs or replacing them with the prototype's field-marks table (prototype scope), swapping the dialogs to CoreComponents.modal (different show/hide mechanics for no visual gain), page-scoped overrides of .action-btn (not needed once the buttons became components), a stamp for the kind word (two stamps in one title row), ochre for the destructive confirm, and an ignore entry in .impeccable/config.json for the italic h1 (a shared file other items are editing).

Review: Playwright at 1440 and 390, logged out and logged in, on shumardii, alba (three sources, tabs switched), acerifolia (authority in a synonym), the formula hybrid agrifolia × parvula shrevei (parents, no sources), acatenangensis (no sources), the schneckii synonym redirect, the delete, delete-source and Make synonym dialogs, /species/shumardii/sources/new and /species/alba/sources/2/edit; no horizontal overflow at 390 on any of them. The detector is clean on the changed files' owned sections; on the live pages it reports only italic-serif-display on the h1, which DESIGN.md's Botanical Italic Rule requires (the prototypes carry an ignore for the same rule). The impeccable finish reviewer scored the first pass 8/10 with six fixes (clipped delete list, glyph star, stamp reading as a button, unmarked phone tab overflow, category only in a tooltip, inconsistent count notes); all six were applied in the second commit.

### Decisions made in the session

Accepting the review ratifies these. To decide one differently, before accepting: `mull decide <id> "..."`

- **07ba** Copy on the species page and source form moves to sentence case (Make synonym of…, Add source, Compare sources, Delete species, Species not found, Back to species list, Add source data, Save changes)
  Why: Matches the shell's Add species and DESIGN.md's labels; tests updated, including the one assertion in species_form_live_test.exs
- **23c0** Source tabs stay tabs: the tablist is an inner wrapper on the 2px ink rule, the current tab carries the 3px ochre underline, the tabs scroll sideways on phones with Compare sources (the ochre compare_button) and Add source on the row under them
  Why: DESIGN.md's current-item mark is the ochre underline; wrapping tabs on phones left the underline floating off the rule
- **4ef9** External links are a ruled list of pencil links, each followed by its host name in ink-3; the brand logos (including the iNaturalist wordmark shown without text) are dropped
  Why: Coloured logos are off-palette and DESIGN.md has no boxed link buttons; the host tells the reader where the link goes
- **8c98** Source fields drop their icons: each is an Archivo label in an 11rem column beside the serif text on a hairline, stacking on phones; 'Data from X' is the h2 and the field labels are h3 (was h4 under no h2)
  Why: Follows the prototype's trait-name column and fixes the skipped heading level
- **8e04** The V1 breadcrumb moves above the title row inside the species header, where the ochre band will go, and the header's 2px rule runs under the title
  Why: DESIGN.md stacks band, then title row on a 2px rule; moving it within the header keeps the page structure
- **9c56** Scientific names on the species page follow the Botanical Italic Rule through one helper: names italic, the hybrid sign and rank words (var., subsp., f. ...) roman; a stored synonym string splits its authority at the first word starting with a capital or '(' (shumardii var. acerifolia | E.J.Palmer 1927)
  Why: Synonyms are stored as plain strings with the authority appended; epithets and rank words are lower case
- **d272** Species page editor buttons (Edit, Make synonym of…, Delete, source Edit and Delete, Add source) are CoreComponents ghost compact buttons rather than the shared .action-btn classes; Delete is set apart at the end of its row, and a dialog's destructive confirm is an ink plate (.species-btn-plate, page-scoped)
  Why: No colour for destruction (DESIGN.md has no red); label, placement and the plate carry it; ochre stays for Compare; avoids depending on fe6d's parallel .action-btn restyle
- **fcc9** The species title row shows the conservation status as a status tag reading IUCN plus the code (IUCN LC), with the category spelled out in its title (IUCN Red List: Least Concern) and no source mark; the kind (Species or Hybrid) is plain Archivo text beside it, not a second stamp
  Why: The stored codes are exactly the IUCN Red List categories; the data holds no assessment edition to cite, so no source mark is invented
- **904c** The species detail dialogs (delete, delete source data, Make synonym of) use the modal component's classes (oc-modal-backdrop, oc-modal-panel, head, body, actions) in place, keeping their ids and phx bindings; the merge picker closes on a backdrop click and its search no longer submits the page on Enter
  Why: Swapping to CoreComponents.modal would change its show/hide mechanics; the classes give the same look with the existing server-driven state
- **c670** With no sources, the source section gets a 'Source data' section label over the empty statement (italic ink-3) and the Add source button
  Why: Without the tab strip the empty state had no rule or label of its own
- **5d74** Synonyms and common names on the species page are a plain comma list in the page's own markup, not b4f7's pill-tag comma trick
  Why: In a wrapping flex row the pill-tag comma started the second line
- **a394** The preferred source's tab says 'preferred' in Archivo 12.5px ink-3 instead of the ★ glyph
  Why: DESIGN.md reserves a drawn star for key difference and the floor bans glyph icons; the word also reaches screen readers and touch

### Changes by layer

**tests**: 3 files, +23 −15
- M test/oaks_web/live/species_detail_live_test.exs (+19 −11)
- M test/oaks_web/live/species_form_live_test.exs (+1 −1)
- M test/oaks_web/live/species_source_form_live_test.exs (+3 −3)

**ui**: 3 files, +807 −778
- M assets/css/app.css (+439 −199)
- M lib/oaks_web/live/species_detail_live.ex (+329 −531)
- M lib/oaks_web/live/species_source_form_live.ex (+39 −48)
