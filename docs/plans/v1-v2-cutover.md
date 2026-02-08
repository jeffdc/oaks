# V1 → V2 Cutover Plan

V1 is two services: a Svelte static site on GitHub Pages + a Go API on Fly.io.
V2 is a single Phoenix app on Fly.io that replaces both.

## Current State

| Domain | Record Type | Value | Service |
|--------|-------------|-------|---------|
| `oakcompendium.org` | A (x4) | 185.199.108-111.153 | GitHub Pages |
| `oakcompendium.com` | A | 162.255.119.189 | Namecheap parking |
| `www.oakcompendium.org` | CNAME | jeffdc.github.io | GitHub Pages |
| `www.oakcompendium.com` | — | (not set) | — |
| `api.oakcompendium.org` | A | 66.241.125.170 | V1 Fly.io |
| `api.oakcompendium.com` | A | 66.241.125.170 | V1 Fly.io |

## Target State

All six domains → V2 Phoenix app (`oaks` on Fly.io).

---

## Phase 1: Prep V2 on Fly.io

Run these from the project root.

V2 IPs (already allocated):
- **IPv4**: `66.241.125.105` (shared)
- **IPv6**: `2a09:8280:1::d1:2463:0` (dedicated)

- [x] **Add all custom domains to the `oaks` app**
  ```bash
  fly certs add oakcompendium.org --app oaks
  fly certs add oakcompendium.com --app oaks
  fly certs add www.oakcompendium.org --app oaks
  fly certs add www.oakcompendium.com --app oaks
  fly certs add api.oakcompendium.org --app oaks
  fly certs add api.oakcompendium.com --app oaks
  ```

- [ ] **Check cert status** (repeat until all show "Ready") — currently all "Awaiting configuration"
  ```bash
  fly certs list --app oaks
  ```
  Apex domains require DNS validation — certs won't become Ready until Phase 2 DNS changes are in place. Subdomain certs (www, api) may provision immediately via HTTP validation.

---

## Phase 2: DNS Cutover in Namecheap

Log in to Namecheap → Domain List → Manage → Advanced DNS.

Update records for **both domains**. Delete any existing records that conflict before adding new ones.

### oakcompendium.org

| Host | Type | Value | TTL |
|------|------|-------|-----|
| `@` | A | `66.241.125.105` | Automatic |
| `@` | AAAA | `2a09:8280:1::d1:2463:0` | Automatic |
| `www` | CNAME | `361z313.oaks.fly.dev` | Automatic |
| `api` | CNAME | `361z313.oaks.fly.dev` | Automatic |

Delete: all old A records for `@` (the four GitHub Pages IPs), old CNAME for `www` → jeffdc.github.io, old A record for `api`.

### oakcompendium.com

| Host | Type | Value | TTL |
|------|------|-------|-----|
| `@` | A | `66.241.125.105` | Automatic |
| `@` | AAAA | `2a09:8280:1::d1:2463:0` | Automatic |
| `www` | CNAME | `361z313.oaks.fly.dev` | Automatic |
| `api` | CNAME | `361z313.oaks.fly.dev` | Automatic |

Delete: any existing A record for `@` (Namecheap parking IP), old A record for `api`.

---

## Phase 3: Verify

Wait for DNS propagation (usually minutes, can take up to an hour).

- [ ] **Check DNS resolution**
  ```bash
  dig +short oakcompendium.org A
  dig +short oakcompendium.com A
  dig +short www.oakcompendium.org CNAME
  dig +short www.oakcompendium.com CNAME
  dig +short api.oakcompendium.org CNAME
  dig +short api.oakcompendium.com CNAME
  ```

- [ ] **Check certs are Ready**
  ```bash
  fly certs list --app oaks
  ```

- [ ] **Test HTTPS on all domains** — each should serve the V2 Phoenix app
  ```bash
  curl -sI https://oakcompendium.org | head -5
  curl -sI https://oakcompendium.com | head -5
  curl -sI https://www.oakcompendium.org | head -5
  curl -sI https://www.oakcompendium.com | head -5
  curl -sI https://api.oakcompendium.org | head -5
  curl -sI https://api.oakcompendium.com | head -5
  ```

- [ ] **Smoke test the app** — browse `https://oakcompendium.org`, click around, verify pages load.

---

## Phase 4: Teardown

Do this once you're satisfied V2 is stable. No rush — V1 costs nothing while idle.

### GitHub Pages

- [ ] **Disable GitHub Pages** for the repo
  - Go to github.com → repo Settings → Pages → set Source to "None" / disable
- [ ] **Disable the deploy workflow**
  - Go to repo Settings → Actions → General, or simply delete/rename `.github/workflows/deploy.yml`
  - Alternatively, add `if: false` to the workflow to keep it in history

### V1 Fly.io App

- [ ] **Stop the V1 app** (keeps it around for rollback)
  ```bash
  fly scale count 0 --app oak-compendium-api
  ```
- [ ] **Remove custom certs** from V1 (avoids cert renewal conflicts)
  ```bash
  fly certs remove api.oakcompendium.com --app oak-compendium-api
  fly certs remove api.oakcompendium.org --app oak-compendium-api
  ```
- [ ] **Destroy the V1 app** (when you're sure you don't need rollback)
  ```bash
  fly apps destroy oak-compendium-api
  ```

### Cleanup

- [ ] Delete V1 source directories (`api/`, `web/`, `cli/`) from the repo
- [ ] Remove `.github/workflows/deploy.yml` and `.github/workflows/deploy-api.yml`
