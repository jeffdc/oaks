---
kind: decision
text: 'Login: TOTP secrets encrypted at rest with AES-256-GCM under a Fly secret, LOGIN_ENCRYPTION_KEY (Jeff, 2026-11-21).'
plan: compendium
item: "0249"
by: /Users/jeff/dev/oaks
created: "2026-11-21T18:46:06Z"
---

A leaked DB copy (Litestream backup, make download-db) must not hold usable secrets.
