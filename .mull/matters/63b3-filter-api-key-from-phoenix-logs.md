---
status: done
tags: [p0, security]
effort: S
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
relates: [5453]
---

# Filter api_key from Phoenix logs

API key is likely logged in plaintext on every authenticated page load.

- assets/js/app.js:239 sends api_key as a LiveView connect param.
- LiveView socket logs connect params at :info; config/prod.exs:16 logger level :info.
- Phoenix default filter_parameters only redacts "password"/"token"; config/*.exs never overrides.
- Fix: config :phoenix, :filter_parameters, ["password", "token", "api_key"] in config/config.exs. Add a test that Phoenix.Logger.filter_values redacts api_key.
- After deploy: consider rotating OAK_API_KEY since it may already be in Fly logs / log drains.

Verified 2026-11-02.
