# Polish

Phase 3 of the [Facts expansion](README.md). Make the site look acceptable before building the rest (Jeff, 2026-11-21). The site shell phase put the DESIGN.md shell, system and a bridge restyle on every page, but five page agents worked in parallel and each solved shared problems its own way (three italic-name helpers, four page widths, page-made destructive buttons, the taxonomy band pulled out with negative margins), and no one reviewed the site as a whole. Jeff judged the result janky.

How the work went: collect the problems in one place (Jeff's list and one Impeccable review of every page at desktop and phone width), fix the shared pieces first, one agent at a time, then fix pages from the list one or two at a time, with Jeff seeing each page before it was called done.

## Done when

- Jeff judges the site acceptable on desktop and phone.
- The shared pieces (scientific names, page widths, the band's place in the layout, buttons, title rows) each have one implementation that every page uses.
- `scripts/check-ui` passes, and `assets/css/app.css` restyles no more library components than it does today (12 `.oc-` selectors).

## Status

**Done.** Jeff signed the phase off on 2026-11-26. Every fix is in main:

| Fix | Commit |
|---|---|
| `put_secure_browser_headers` back in the browser pipeline, so Sobelow passes | 533f91d |
| Field Face Rule: prose fields are multi-line serif, every other field one line in Archivo (DESIGN.md, Form Fields) | ba852f6 |
| The merge page's "Added to the target" notice no longer shows an empty list | fc37df2 |
| Species list rows and meta columns; the rank words (var., subsp.) wait for Taxonomy | 83332e9 |
| The source tab's link no longer nested in the tab button; then replaced by `source_tabs` | 4fb96e1, 41bb963 |
| The merge title's arrow on phones, Save Merge's weight, compare headers aligned | 45933e3 |
| The taxonomy pages' sub-group and species grids share columns | f10076a |
| A comma list starting a wrapped line with a comma: moot, `.pill-tag` was removed | 4fb96e1 |
| The setup done page shows the logged-in shell | f761d99 |
| Settings back links, Analytics in the footer, About's statistics | 388b3e6 |
| The merge dialog's "Merging species…" state shows | 6e3d02e |

The sign-off also approved five choices the agents made in them: species list rows are 48px, on a subgrid; long authorities end in an ellipsis; compare's column heads link to the source's page; About's statistics read as a sentence; only the three settings sub-pages get Back to settings.

The fixes to the article "How to Document an Oak" are dropped: Jeff is rewriting it.
