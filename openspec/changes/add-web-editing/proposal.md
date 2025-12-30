# Change: Add Web Editing with API Key Authentication

## Why

The web app is currently read-only. All data editing requires either the CLI tool, direct API calls, or the in-development iOS app. Adding edit capabilities to the web app would:

- Enable quick corrections when browsing species data
- Provide a full CRUD interface accessible from any browser
- Reduce friction for data maintenance tasks
- Complement the iOS app (which focuses on field notes)

The API already supports full CRUD operations with API key auth. This change adds the web UI layer on top.

## What Changes

### Web Application (`web/`)

**Authentication:**
- **ADDED**: Settings page (`/settings/`) with API key input
- **ADDED**: Auth store to manage API key state and persistence
- **ADDED**: Authenticated API client wrapper for write operations
- **ADDED**: "Admin mode" indicator in header when authenticated

**Species Editing:**
- **ADDED**: Edit button on species detail page (visible when authenticated)
- **ADDED**: Species edit form (modal or dedicated page)
- **ADDED**: Delete species with confirmation dialog
- **ADDED**: Create new species form

**Taxa Editing:**
- **ADDED**: Edit/create/delete taxa in taxonomy browser

**Sources Editing:**
- **ADDED**: Edit/create/delete sources in sources page

**Error Handling:**
- **ADDED**: Graceful handling of 401 responses (clear auth, show message)
- **ADDED**: Optimistic updates with rollback on error
- **ADDED**: Loading states for write operations

### API Server (`api/`)
- No changes required - existing API key auth works as-is

## Impact

- **Affected specs**: web-editing (new capability)
- **Affected code**:
  - `web/src/lib/stores/authStore.js` (new)
  - `web/src/lib/apiClient.js` (modify for auth headers)
  - `web/src/routes/settings/+page.svelte` (new)
  - `web/src/lib/components/SpeciesDetail.svelte` (add edit UI)
  - `web/src/lib/components/SpeciesEditForm.svelte` (new)
  - `web/src/lib/components/Header.svelte` (admin indicator)
  - Plus similar changes for taxa and sources
- **Breaking changes**: None - purely additive
- **Security considerations**:
  - API key stored in localStorage (standard for SPAs)
  - Key visible in browser devtools (acceptable for single-user scenario)
  - All writes go over HTTPS to api.oakcompendium.com

## Scope

- Estimated effort: ~5-7 days of focused work
- Priority: After consolidate-db-code and other pending changes
