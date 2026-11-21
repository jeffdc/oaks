---
item: fbd0
"n": 1
passed: true
commit: ee001c948b6061cbf8cf67f84f0ac21398fdaf43
base: c421e3b3db818b4ad7ea7b97b6c49db2bdef41c5
at: "2026-11-21T21:18:00Z"
by: /Users/jeff/dev/oaks
summary: 'Agent tokens for a private API: Jeff issues and revokes scoped, expiring tokens at /users/settings/api-tokens (login plus sudo mode), and agents call /api/private/v1 with Authorization: Bearer. Tokens are oak_ plus 32 random bytes, SHA-256 hashed, shown once, with scopes materials:read and packages:submit and a 30/90/365-day expiry. The only route so far is GET /api/private/v1/token (whoami); the materials and package items add their routes behind require_api_scope/2. Requests are rate limited per token (120/min) and failed attempts per IP (10 per 15 min). Tokens survive a password change; account recovery from a setup link revokes them. Public pages and the public API are unchanged.'
tour:
  - 'Log in, open Settings: there is a new Agent tokens button beside Change password and Recovery codes.'
  - 'Click Agent tokens (log in again if your login is older than 20 minutes). The page has a New token form (name, the two scope checkboxes, Expires after: 30/90/365 days, 90 selected) and an empty Tokens list.'
  - 'Submit with no name and no scope: the form comes back with can''t be blank and pick at least one.'
  - 'Make a token named test with packages:submit: a New agent token page shows oak_… once, with what it grants and until when.'
  - 'In a terminal: curl -i https://<host>/api/private/v1/token -H ''Authorization: Bearer oak_…'' returns 200 with the name, scopes and expiry; without the header it returns 401 with www-authenticate: Bearer.'
  - 'Click I''ve copied it: the token is listed with its scope, made and expiry dates, and last used.'
  - 'Click Revoke: a flash says the token is revoked, the list is empty, and the curl call now gets 401.'
checks:
  tree: 92098ee6f8f19a16462f20004c1a78354986b0e4
  commit: ee001c948b6061cbf8cf67f84f0ac21398fdaf43
  at: "2026-11-21T21:17:53Z"
  by: /Users/jeff/dev/oaks
  passed: true
  results:
    - command: make done-checks
      exit: 0
      duration_ms: 7044
changes:
  - layer: data
    files:
      - status: A
        path: priv/repo/migrations/20261121210000_create_api_tokens.exs
        added: 24
        removed: 0
  - layer: docs
    files:
      - status: M
        path: CLAUDE.md
        added: 2
        removed: 1
  - layer: domain
    files:
      - status: M
        path: lib/oaks/accounts.ex
        added: 67
        removed: 2
      - status: A
        path: lib/oaks/accounts/api_token.ex
        added: 115
        removed: 0
  - layer: other
    files:
      - status: M
        path: config/test.exs
        added: 1
        removed: 0
  - layer: tests
    files:
      - status: M
        path: test/oaks/accounts_test.exs
        added: 116
        removed: 1
      - status: A
        path: test/oaks_web/controllers/private_api/token_controller_test.exs
        added: 118
        removed: 0
      - status: M
        path: test/oaks_web/controllers/user_settings_controller_test.exs
        added: 77
        removed: 1
      - status: M
        path: test/support/fixtures/accounts_fixtures.ex
        added: 24
        removed: 1
  - layer: ui
    files:
      - status: M
        path: assets/css/app.css
        added: 47
        removed: 0
      - status: M
        path: lib/oaks_web/components/auth_components.ex
        added: 14
        removed: 5
      - status: A
        path: lib/oaks_web/controllers/private_api/token_controller.ex
        added: 21
        removed: 0
      - status: M
        path: lib/oaks_web/controllers/user_settings_controller.ex
        added: 45
        removed: 2
      - status: M
        path: lib/oaks_web/controllers/user_settings_html.ex
        added: 13
        removed: 0
      - status: A
        path: lib/oaks_web/controllers/user_settings_html/api_tokens.html.heex
        added: 90
        removed: 0
      - status: A
        path: lib/oaks_web/controllers/user_settings_html/new_api_token.html.heex
        added: 24
        removed: 0
      - status: M
        path: lib/oaks_web/live/settings_live.ex
        added: 9
        removed: 2
      - status: A
        path: lib/oaks_web/plugs/api_token.ex
        added: 106
        removed: 0
      - status: M
        path: lib/oaks_web/router.ex
        added: 19
        removed: 1
design: |-
  Shape. Oak's Accounts context owns tokens: a new schema Oaks.Accounts.ApiToken (table api_tokens: user_id, name, hashed_token, scopes as a JSON array, expires_at, last_used_at) and five functions in Oaks.Accounts (change_api_token, create_api_token, list_api_tokens, delete_api_token, fetch_api_token). The web side is a plug, OaksWeb.Plugs.ApiToken, in a new :private_api router pipeline under /api/private/v1, with one controller, OaksWeb.PrivateAPI.TokenController (whoami). The settings page is three actions on the existing UserSettingsController with two templates, inside the existing login-plus-sudo scope.

  Why its own table. Accounts.expire_tokens/2 deletes every users_tokens row on a password change or setup; putting agent tokens there would silently revoke them whenever Jeff changed his password. A separate table also keeps the session-token code untouched. complete_setup (account recovery) deletes api_tokens explicitly, since recovery implies the account may have been compromised; password change leaves them.

  Token format and storage. oak_ plus 32 random bytes, URL-safe base64, the same entropy as session tokens. Only SHA-256 is stored (fast hash is right for high-entropy random tokens; Argon2 would add cost per API call for no gain). The prefix makes leaked tokens easy to grep and lets verify_query reject junk without a database lookup. Revoking deletes the row: a revoked token has nothing left to show, and expiry already gives the list an expired state.

  The plug. Reads Authorization: Bearer (either case of the scheme), looks up an unexpired token with its user, and assigns :current_api_token. Every failure is the same 401 with www-authenticate: Bearer and one message, so callers can't tell an unknown token from an expired or revoked one. Limits follow OaksWeb.LoginLimiter (Hammer ETS, config :oaks, :api_token_rate_limits): per token 120 a minute, keyed by the token hash rather than the id because SQLite can reuse a deleted row's id (a test caught a new token inheriting an old token's count); failures per IP 10 per 15 minutes, checked with get/2 before verifying so a blocked IP can't keep guessing. 429s carry retry-after. require_api_scope/2 is a function plug for later controllers; it returns 403 naming the missing scope.

  Not a Scope. The token is assigned as :current_api_token, not as current_scope, because UserAuth.editor?/1 treats any Scope with a user as an editor; putting a token-authenticated request into a Scope would quietly give agents editor rights wherever later code checks a scope. The package and materials items can decide how a token maps onto their writes.

  last_used_at is written at most once a minute per token, so a busy agent doesn't turn every read into a SQLite write.

  Private API placement. Its own pipeline without CORS (agents aren't browsers) and without the OpenAPI plug; TokenController doesn't declare operations, so Paths.from_router leaves it out of the public spec (a test checks). ApiHost already allows /api/ on api.* hosts, so it works there too.

  The page. Plain controller pages like the other security settings (decision 1928), using the settings-* styles plus a few small classes for the checkbox list and token rows. AuthComponents gained field_errors/1, now used by auth_field and by the scope checkboxes. A hidden empty scopes[] value keeps no-boxes-ticked submissions well formed; the changeset drops blanks and requires at least one scope with a custom check, since validate_length only checks changes.

  Rejected. A release command for issuing (Jeff chose the page). Storing tokens in users_tokens (password change would wipe them). Keying limits by token id (id reuse). Shipping a draft-articles endpoint now (Jeff: whoami only).

  Verified in a browser against a scratch copy of the dev database: issue, show once, whoami 200 and 401, list, revoke.
decisions:
  - id: "0504"
    text: 'Jeff picks a token''s lifetime when issuing it: 30, 90 or 365 days, 90 by default (Jeff, 2026-11-21).'
  - id: "0531"
    text: Agent tokens are issued and revoked on a settings page behind login and sudo mode (Jeff, 2026-11-21).
  - id: 391a
    text: Tokens are oak_ plus 32 random bytes (base64url), SHA-256 hashed at rest, shown once; scopes materials:read and packages:submit.
    detail: The prefix makes leaked tokens easy to spot; hashing matches session tokens.
  - id: 5e3f
    text: fbd0 ships only GET /api/private/v1/token (whoami); materials:read and packages:submit routes come with their items (Jeff, 2026-11-21).
  - id: 714a
    text: Agent tokens live in their own api_tokens table, not users_tokens.
    detail: Accounts.expire_tokens/2 deletes every users_tokens row on password change, which would silently revoke agent tokens.
  - id: 738a
    text: Agent tokens survive a password change; account recovery from a setup link revokes them all.
    detail: A token is a separate credential; recovery implies the account may have been compromised.
  - id: dbb9
    text: 'Private API at /api/private/v1 in its own pipeline: no CORS, 401 for missing/bad/expired tokens, 403 for a missing scope; Hammer limits per token (120/min) and failed attempts per IP (10 per 15 min), set in config.'
    detail: Agents aren't browsers; limits follow the LoginLimiter pattern.
  - id: 5d6d
    text: The agent tokens page reuses the existing settings page styles (settings-* classes, a few new ones) without an impeccable design pass.
    detail: It's an editor-only form beside the password and recovery-code pages; phase 6b12 (site shell and design system) restyles settings later.
---

# Done report 1: Scoped API tokens for agents (fbd0)

**Status:** PASSED  
**Commit:** ee001c948b60  
**By:** /Users/jeff/dev/oaks at 2026-11-21T21:18:00Z

## What was built

### Summary

Agent tokens for a private API: Jeff issues and revokes scoped, expiring tokens at /users/settings/api-tokens (login plus sudo mode), and agents call /api/private/v1 with Authorization: Bearer. Tokens are oak_ plus 32 random bytes, SHA-256 hashed, shown once, with scopes materials:read and packages:submit and a 30/90/365-day expiry. The only route so far is GET /api/private/v1/token (whoami); the materials and package items add their routes behind require_api_scope/2. Requests are rate limited per token (120/min) and failed attempts per IP (10 per 15 min). Tokens survive a password change; account recovery from a setup link revokes them. Public pages and the public API are unchanged.

### UI tour

1. Log in, open Settings: there is a new Agent tokens button beside Change password and Recovery codes.
2. Click Agent tokens (log in again if your login is older than 20 minutes). The page has a New token form (name, the two scope checkboxes, Expires after: 30/90/365 days, 90 selected) and an empty Tokens list.
3. Submit with no name and no scope: the form comes back with can't be blank and pick at least one.
4. Make a token named test with packages:submit: a New agent token page shows oak_… once, with what it grants and until when.
5. In a terminal: curl -i https://<host>/api/private/v1/token -H 'Authorization: Bearer oak_…' returns 200 with the name, scopes and expiry; without the header it returns 401 with www-authenticate: Bearer.
6. Click I've copied it: the token is listed with its scope, made and expiry dates, and last used.
7. Click Revoke: a flash says the token is revoked, the list is empty, and the curl call now gets 401.

### Checks (run by mull)

- `make done-checks`: pass, 7.0s

## How it was built

### Design notes

Shape. Oak's Accounts context owns tokens: a new schema Oaks.Accounts.ApiToken (table api_tokens: user_id, name, hashed_token, scopes as a JSON array, expires_at, last_used_at) and five functions in Oaks.Accounts (change_api_token, create_api_token, list_api_tokens, delete_api_token, fetch_api_token). The web side is a plug, OaksWeb.Plugs.ApiToken, in a new :private_api router pipeline under /api/private/v1, with one controller, OaksWeb.PrivateAPI.TokenController (whoami). The settings page is three actions on the existing UserSettingsController with two templates, inside the existing login-plus-sudo scope.

Why its own table. Accounts.expire_tokens/2 deletes every users_tokens row on a password change or setup; putting agent tokens there would silently revoke them whenever Jeff changed his password. A separate table also keeps the session-token code untouched. complete_setup (account recovery) deletes api_tokens explicitly, since recovery implies the account may have been compromised; password change leaves them.

Token format and storage. oak_ plus 32 random bytes, URL-safe base64, the same entropy as session tokens. Only SHA-256 is stored (fast hash is right for high-entropy random tokens; Argon2 would add cost per API call for no gain). The prefix makes leaked tokens easy to grep and lets verify_query reject junk without a database lookup. Revoking deletes the row: a revoked token has nothing left to show, and expiry already gives the list an expired state.

The plug. Reads Authorization: Bearer (either case of the scheme), looks up an unexpired token with its user, and assigns :current_api_token. Every failure is the same 401 with www-authenticate: Bearer and one message, so callers can't tell an unknown token from an expired or revoked one. Limits follow OaksWeb.LoginLimiter (Hammer ETS, config :oaks, :api_token_rate_limits): per token 120 a minute, keyed by the token hash rather than the id because SQLite can reuse a deleted row's id (a test caught a new token inheriting an old token's count); failures per IP 10 per 15 minutes, checked with get/2 before verifying so a blocked IP can't keep guessing. 429s carry retry-after. require_api_scope/2 is a function plug for later controllers; it returns 403 naming the missing scope.

Not a Scope. The token is assigned as :current_api_token, not as current_scope, because UserAuth.editor?/1 treats any Scope with a user as an editor; putting a token-authenticated request into a Scope would quietly give agents editor rights wherever later code checks a scope. The package and materials items can decide how a token maps onto their writes.

last_used_at is written at most once a minute per token, so a busy agent doesn't turn every read into a SQLite write.

Private API placement. Its own pipeline without CORS (agents aren't browsers) and without the OpenAPI plug; TokenController doesn't declare operations, so Paths.from_router leaves it out of the public spec (a test checks). ApiHost already allows /api/ on api.* hosts, so it works there too.

The page. Plain controller pages like the other security settings (decision 1928), using the settings-* styles plus a few small classes for the checkbox list and token rows. AuthComponents gained field_errors/1, now used by auth_field and by the scope checkboxes. A hidden empty scopes[] value keeps no-boxes-ticked submissions well formed; the changeset drops blanks and requires at least one scope with a custom check, since validate_length only checks changes.

Rejected. A release command for issuing (Jeff chose the page). Storing tokens in users_tokens (password change would wipe them). Keying limits by token id (id reuse). Shipping a draft-articles endpoint now (Jeff: whoami only).

Verified in a browser against a scratch copy of the dev database: issue, show once, whoami 200 and 401, list, revoke.

### Decisions made in the session

Accepting the review ratifies these. To decide one differently, before accepting: `mull decide <id> "..."`

- **0504** Jeff picks a token's lifetime when issuing it: 30, 90 or 365 days, 90 by default (Jeff, 2026-11-21).
- **0531** Agent tokens are issued and revoked on a settings page behind login and sudo mode (Jeff, 2026-11-21).
- **391a** Tokens are oak_ plus 32 random bytes (base64url), SHA-256 hashed at rest, shown once; scopes materials:read and packages:submit.
  Why: The prefix makes leaked tokens easy to spot; hashing matches session tokens.
- **5e3f** fbd0 ships only GET /api/private/v1/token (whoami); materials:read and packages:submit routes come with their items (Jeff, 2026-11-21).
- **714a** Agent tokens live in their own api_tokens table, not users_tokens.
  Why: Accounts.expire_tokens/2 deletes every users_tokens row on password change, which would silently revoke agent tokens.
- **738a** Agent tokens survive a password change; account recovery from a setup link revokes them all.
  Why: A token is a separate credential; recovery implies the account may have been compromised.
- **dbb9** Private API at /api/private/v1 in its own pipeline: no CORS, 401 for missing/bad/expired tokens, 403 for a missing scope; Hammer limits per token (120/min) and failed attempts per IP (10 per 15 min), set in config.
  Why: Agents aren't browsers; limits follow the LoginLimiter pattern.
- **5d6d** The agent tokens page reuses the existing settings page styles (settings-* classes, a few new ones) without an impeccable design pass.
  Why: It's an editor-only form beside the password and recovery-code pages; phase 6b12 (site shell and design system) restyles settings later.

### Changes by layer

**data**: 1 files, +24 −0
- A priv/repo/migrations/20261121210000_create_api_tokens.exs (+24 −0)

**docs**: 1 files, +2 −1
- M CLAUDE.md (+2 −1)

**domain**: 2 files, +182 −2
- M lib/oaks/accounts.ex (+67 −2)
- A lib/oaks/accounts/api_token.ex (+115 −0)

**other**: 1 files, +1 −0
- M config/test.exs (+1 −0)

**tests**: 4 files, +335 −3
- M test/oaks/accounts_test.exs (+116 −1)
- A test/oaks_web/controllers/private_api/token_controller_test.exs (+118 −0)
- M test/oaks_web/controllers/user_settings_controller_test.exs (+77 −1)
- M test/support/fixtures/accounts_fixtures.ex (+24 −1)

**ui**: 10 files, +388 −10
- M assets/css/app.css (+47 −0)
- M lib/oaks_web/components/auth_components.ex (+14 −5)
- A lib/oaks_web/controllers/private_api/token_controller.ex (+21 −0)
- M lib/oaks_web/controllers/user_settings_controller.ex (+45 −2)
- M lib/oaks_web/controllers/user_settings_html.ex (+13 −0)
- A lib/oaks_web/controllers/user_settings_html/api_tokens.html.heex (+90 −0)
- A lib/oaks_web/controllers/user_settings_html/new_api_token.html.heex (+24 −0)
- M lib/oaks_web/live/settings_live.ex (+9 −2)
- A lib/oaks_web/plugs/api_token.ex (+106 −0)
- M lib/oaks_web/router.ex (+19 −1)
