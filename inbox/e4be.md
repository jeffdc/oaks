---
kind: decision
text: 'Login: phx.gen.auth code generated into the repo and hardened; Argon2id password hashes (Jeff, 2026-11-21).'
plan: compendium
item: "0249"
by: /Users/jeff/dev/oaks
created: "2026-11-21T18:46:06Z"
---

Generated code we own and read, not a library. Argon2id via argon2_elixir, min 12 chars, dummy hash for unknown emails.
