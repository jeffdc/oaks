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
- Consider adding session timeout (optional future enhancement)

## Open Questions

None - design is straightforward given the auth model choice.
