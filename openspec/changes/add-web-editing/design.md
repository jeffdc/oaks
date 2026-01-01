# Design: Web Editing with API Key Auth

## Context

The web app needs to support authenticated write operations to the API. The API already implements Bearer token auth for write methods (POST, PUT, DELETE). Read methods remain public.

The user is the sole admin, so complex user management is unnecessary. The same API key used by CLI and iOS app will be used for web editing.

## Goals / Non-Goals

**Goals:**
- Enable CRUD operations for species, taxa, and sources from the browser
- Simple API key entry with secure storage
- Clear visual indication of admin mode
- Graceful error handling for auth failures

**Non-Goals:**
- Multi-user support (single admin only)
- Role-based access control
- OAuth/social login
- Password management

## Decisions

### Auth State Management

**Decision:** Create a dedicated `authStore.js` Svelte store

```javascript
// authStore.js
import { writable, derived } from 'svelte/store';

const API_KEY_STORAGE_KEY = 'oak_api_key';

function createAuthStore() {
  const apiKey = writable(localStorage.getItem(API_KEY_STORAGE_KEY) || '');

  return {
    subscribe: apiKey.subscribe,
    setKey: (key) => {
      localStorage.setItem(API_KEY_STORAGE_KEY, key);
      apiKey.set(key);
    },
    clearKey: () => {
      localStorage.removeItem(API_KEY_STORAGE_KEY);
      apiKey.set('');
    }
  };
}

export const authStore = createAuthStore();
export const isAuthenticated = derived(authStore, $key => !!$key);
```

**Alternatives considered:**
- Session storage (rejected: would require re-entry on each tab)
- Cookies (rejected: adds complexity, no benefit for SPA)

### API Client Integration

**Decision:** Extend existing `apiClient.js` with authenticated methods

```javascript
// Add to apiClient.js
import { get } from 'svelte/store';
import { authStore } from './stores/authStore.js';

async function fetchApiAuthenticated(endpoint, options = {}) {
  const apiKey = get(authStore);
  if (!apiKey) {
    throw new ApiError('Not authenticated', 401, 'UNAUTHENTICATED');
  }

  return fetchApi(endpoint, {
    ...options,
    headers: {
      ...options.headers,
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    }
  });
}

// Write operations
export async function createSpecies(data) {
  return fetchApiAuthenticated('/api/v1/species', {
    method: 'POST',
    body: JSON.stringify(data)
  });
}

export async function updateSpecies(name, data) {
  return fetchApiAuthenticated(`/api/v1/species/${encodeURIComponent(name)}`, {
    method: 'PUT',
    body: JSON.stringify(data)
  });
}

export async function deleteSpecies(name) {
  return fetchApiAuthenticated(`/api/v1/species/${encodeURIComponent(name)}`, {
    method: 'DELETE'
  });
}
```

### Key Validation

**Decision:** Validate key on entry by calling auth verification endpoint

The API has a `GET /api/v1/auth/verify` endpoint (with ForceAuth middleware) that returns 200 if the key is valid. Use this to validate before storing.

```javascript
export async function verifyApiKey(key) {
  const response = await fetch(`${API_BASE_URL}/api/v1/auth/verify`, {
    headers: { 'Authorization': `Bearer ${key}` }
  });
  return response.ok;
}
```

### Edit UI Pattern

**Decision:** Use modal dialogs for editing, not separate pages

- Keeps user context (species list, taxonomy position)
- Simpler routing
- Standard pattern for CRUD operations

**Components needed:**
- `EditModal.svelte` - generic modal wrapper
- `SpeciesEditForm.svelte` - species-specific form
- `TaxonEditForm.svelte` - taxon-specific form
- `SourceEditForm.svelte` - source-specific form
- `DeleteConfirmDialog.svelte` - confirmation for deletes

### Form Validation

**Decision:** Client-side validation before submit, server-side as backup

Required fields validated in browser; API returns 400 with field errors if something slips through.

### Optimistic Updates

**Decision:** Don't use optimistic updates initially

- Simpler implementation
- Data is authoritative, prefer consistency over speed
- Can add later if edit latency is problematic

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| API key exposed in browser devtools | Acceptable for single-user; document in security notes |
| Key stored in localStorage persists indefinitely | Add "Logout" button that clears key |
| Accidental deletes | Confirmation dialogs for all destructive actions |
| Stale data after edit | Refresh data from API after successful write |

## Security Notes

- API key grants full write access - treat like a password
- Key transmitted only over HTTPS (GitHub Pages + Fly.io)
- localStorage is same-origin isolated
- Session timeout: 24 hours (configurable), clears key on expiry

### Known Risks (Documented)

**XSS Attack Vector**: API key stored in localStorage is accessible to any JavaScript running on the same origin. If the web app ever has an XSS vulnerability, the key could be exfiltrated. Mitigations:
- Single-user scenario limits exposure
- No third-party scripts loaded
- Content Security Policy headers recommended for production
- Key can be manually revoked via Settings page if compromised

**Input Sanitization**: All user-provided content is HTML-escaped on display to prevent stored XSS. Field length limits enforced client-side and server-side.

### Known Limitations (Documented)

**Concurrent Tabs**: If the same species is open in multiple browser tabs, saving in one tab triggers a full data refresh. Other tabs may show stale data until manually refreshed. Users should work in a single tab when editing.

**No Optimistic Concurrency**: This v1 implementation does not detect concurrent edits. In the rare case where the same record is edited on two devices simultaneously, the last save wins. Future versions may add ETag-based conflict detection.

## Resolved: Data Model Strategy

**Decision: Option C - Minimal fixes + write mapping**

Analysis revealed the divergence is smaller than initially thought:

| Aspect | Database | Export Format | Web (IndexedDB) | Status |
|--------|----------|---------------|-----------------|--------|
| Species name | `scientific_name` | `name` | `name` | ✓ Export translates |
| Synonyms | `[]string` | `[]string` | Handles both | ✓ UI works, search needs fix |
| Sources | Separate table | Embedded `sources[]` | Embedded `sources[]` | ✓ Aligned |

The export format (`api/internal/export/types.go`) was deliberately designed to be web-friendly. It maps `scientific_name` → `name` at export time. The web model doesn't need to change.

**Required fixes:**

1. **Fix synonym search** (`dataStore.js:101`) - currently assumes `{name}` objects but API sends strings:
   ```javascript
   // Before:
   species.synonyms.some(syn => syn.name?.toLowerCase().includes(query))

   // After:
   species.synonyms.some(syn =>
     (typeof syn === 'string' ? syn : syn.name)?.toLowerCase().includes(query)
   )
   ```

2. **Add write-side mapping** - `toApiFormat()` utility to convert web format to API format:
   ```javascript
   // web/src/lib/apiClient.js
   function toApiFormat(species) {
     return {
       scientific_name: species.name,
       author: species.author,
       is_hybrid: species.is_hybrid,
       conservation_status: species.conservation_status,
       subgenus: species.taxonomy?.subgenus,
       section: species.taxonomy?.section,
       subsection: species.taxonomy?.subsection,
       complex: species.taxonomy?.complex,
       parent1: species.parent1,
       parent2: species.parent2,
       synonyms: species.synonyms?.map(s => typeof s === 'string' ? s : s.name),
     };
   }
   ```

**Rationale:**
- Export format is the canonical "web format" by design
- No schema migrations or component refactoring needed
- ~25 lines of mapping code vs days of refactoring
- Maintains clean separation: API uses DB terms, web uses display terms

---

### Resolved: IndexedDB and Offline Strategy

**Current data flow (read-only):**
```
API/JSON → populateFromJson() → IndexedDB → getAllSpecies() → Svelte stores → UI
```

#### Decision 2a: Full refresh after edits

After each successful write operation, re-fetch entire `/api/v1/export` and repopulate IndexedDB.

**Rationale:** Simple and consistent. With ~670 species and typical edit frequency (a few per session), the ~2MB download is acceptable. Optimize later if latency becomes problematic.

#### Decision 2b: Disable editing when offline

Edit buttons are hidden/disabled when offline. No queued edits, no sync conflicts.

**Rationale:** Queued offline edits require conflict resolution (what if data changed on server?), which adds significant complexity. Single-user scenario makes this acceptable.

#### API Health Check Specification

- **Frequency**: Check every 60 seconds when page is visible
- **Endpoint**: `GET /health` (lightweight, no auth required)
- **Timeout**: 3 seconds (fail fast)
- **Debounce**: Skip check if one is already in flight
- **On failure**: Set `apiAvailable` to false, disable edit buttons
- **On recovery**: Set `apiAvailable` to true, re-enable edit buttons
- **Visibility API**: Pause checks when tab is hidden, resume on focus

#### Decision 2c: Preserve form data on connection loss

If connection drops mid-edit:
- Show warning message "Connection lost. Your changes are preserved."
- Disable submit button
- Keep form data intact
- Re-enable when connection restored

No auto-retry - user should confirm the submit.

---

### Resolved: Species-Source Editing

**Decision: Edit the currently displayed source**

The multi-source architecture is a core feature - each species can have data from multiple sources, and users must be able to edit ANY source's data for a species. This is fundamental to how the app works.

**UI behavior:**
- Species detail shows source tabs (one per source with data for this species)
- Each source tab has its own Edit button
- Clicking Edit opens form pre-filled with THAT source's data
- Saving updates `PUT /api/v1/species/{name}/sources/{source_id}`
- Can also "Add Source Data" to create a new species_source record for a different source

**Example:**
For species "alba" with data from Sources 1, 2, and 3:
- User views Source 2 (Oaks of the World) tab
- Clicks Edit → form shows Source 2's leaves, range, etc.
- Saves → updates species_sources record for alba + source_id=2

This matches the iOS app and is essential for data curation.

---

### Resolved: Array Field Editing UI

**Decision:** Tag input for simple string arrays (`local_names`, `hybrids`, `synonyms`).

- Chips that can be added/removed (like email recipients)
- Enter key or comma adds new tag
- Click X to remove
- Clean, familiar UX pattern

---

### Resolved: Taxonomy Field Editing

**Decision:** Dropdown for subgenus, autocomplete for others.

- **Subgenus**: Dropdown with 3 fixed values (Quercus, Cerris, Cyclobalanopsis)
- **Section/Subsection/Complex**: Text input with autocomplete populated from `/api/v1/taxa`

This balances validation (subgenus is constrained) with flexibility (many sections exist).

---

## Resolved Decisions

### Validation Error Display

**Decision:** Inline errors below each field, plus summary at top of form if multiple errors.

### Success Feedback

**Decision:** Toast notification that auto-dismisses after 3 seconds. "Species updated successfully."

### Delete Cascade Warning

**Decision:** Confirmation dialog shows: "Delete [species name]? This will also remove data from X sources."

### Delete Cascade Behavior (API Constraints)

The API enforces referential integrity:

| Entity | Cascade Behavior |
|--------|------------------|
| Species | Deleting a species also deletes all its species_sources records |
| Taxon | Cannot delete a taxon if species reference it (returns 409 Conflict) |
| Source | Cannot delete a source if species_sources reference it (returns 409 Conflict) |
| Species-Source | Can always be deleted (no dependents) |

**UI Implications:**
- Species delete: Show count of sources that will be removed
- Taxon delete: If species exist, show error "Cannot delete: X species use this taxon"
- Source delete: If species_sources exist, show error "Cannot delete: X species have data from this source"

### Rate Limit Handling

**Decision:** On 429 response, show message "Too many requests. Please wait a moment and try again." Disable submit button for duration of Retry-After header.
