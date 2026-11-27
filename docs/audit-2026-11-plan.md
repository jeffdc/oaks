# November 2026 audit

The November 2026 codebase audit fixed security, data-integrity, ops and UI findings; the fixes are in git. One check is left, and then this plan closes.

## Decisions

- Don't rotate the old `OAK_API_KEY`: low risk (Jeff, 2026-11-21). The key has since been replaced by login and agent tokens.

## Check the CSP in a browser on prod

The `:browser` pipeline sends a CSP (`lib/oaks_web/plugs/security_headers.ex`): `script-src 'self'`, inline styles allowed, `img-src https:`. Open these pages on oakcompendium.org with the console open and look for CSP violations: a species page (Markdown, photos and the photo viewer), an article, compare, the merge picker, taxonomy, analytics, and the logged-in forms and editor dialogs. An agent can do this with Playwright.

Done when every page above loads with no CSP violation, or each violation found is fixed.

**Status:** done (2026-11-27). No violations. The public pages were checked on oakcompendium.org: the header matches the plug, and the species page's photo viewer, lightbox and details dialog, compare, taxonomy, analytics, search and sources all loaded with LiveView connected. The logged-in pages were checked on a local dev server (same CSP) against a copy of the database, because prod logins weren't used: every editor form and dialog, the photo dialogs, the merge picker and merge page, a new article and its public page, and the settings pages. A violation listener installed before page scripts caught a deliberately injected inline script both times, so the empty results are real.
