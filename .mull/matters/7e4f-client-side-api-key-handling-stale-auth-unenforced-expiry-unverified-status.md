---
status: done
tags: [p2, security]
effort: M
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
relates: [5453]
---

# Client-side API key handling: stale auth, unenforced expiry, unverified status

- assets/js/app.js:239 reads localStorage key once at page load -> saving/clearing key on /settings has no effect until full reload.
- Expiry check (app.js:147-174) only runs in ApiKeySettings hook on /settings; every other page sends the key regardless of age -> effectively never expires.
- settings_live.ex:12,46 mount overwrites hook-assigned authenticated with false; client reports auth_status: true whenever a key is stored, never verified server-side -> stale 'Authenticated' after key rotation; header Add Species button disappears on /settings.
Fix: params as a function checking timestamp; full reload after save/clear; keep server auth value, show 'key stored' separately (or verify via /api/v1/auth/verify).

Done 2026-11-02: currentApiKey() checks expiry, LiveSocket params is a function, save/clear reloads with a one-shot sessionStorage notice, SettingsLive no longer accepts client auth claims. JS change built but NOT browser-tested (no Chrome for Playwright) — needs a manual check of save/clear/expiry on /settings.
