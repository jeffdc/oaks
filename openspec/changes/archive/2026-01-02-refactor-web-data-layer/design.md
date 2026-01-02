# Design: Web Data Layer Refactor

## Context

The web app currently uses a complex data flow:
1. Fetch full export JSON from API
2. Clear IndexedDB
3. Populate IndexedDB from export
4. Read from IndexedDB for UI
5. On edit: API call → repeat steps 1-4

This creates performance issues (slow edits), complexity (format conversions), and reliability concerns (race conditions during refresh, cache invalidation bugs).

## Goals / Non-Goals

**Goals:**
- API is the sole source of truth; no client-side persistence
- One data format throughout the web app (API format)
- Each component fetches exactly what it needs
- Simple, predictable data flow

**Non-Goals:**
- Offline support (separate future initiative)
- Client-side caching of any kind
- Multi-tab synchronization
- Optimistic updates with rollback

## Decisions

### Decision 1: Remove All Client-Side Persistence

**What**: Delete all IndexedDB/Dexie code and static JSON file. No client-side data storage.

**Why**:
- IndexedDB was causing cache invalidation bugs and race conditions
- Offline support isn't a real requirement right now
- Dramatically simpler code
- Caching/PWA can be added later as a separate initiative

**Trade-offs**:
- Every page load requires API call (acceptable)
- No offline support (acceptable, explicitly deferred)

### Decision 2: Fetch-Per-View Architecture

**What**: Each route/component fetches its own data on mount. No shared "all data" store.

**Data fetching by view**:

| View | API Call | Data Returned |
|------|----------|---------------|
| Species list | `GET /api/v1/species` | All species (basic fields) |
| Species detail | `GET /api/v1/species/{name}/full` | Single species with embedded sources |
| Taxonomy browser | `GET /api/v1/taxa` | All taxa |
| Edit species-source | `GET /api/v1/sources` | All sources (for dropdown) |
| Search | `GET /api/v1/species/search?q=...` | Matching species |

**Why**:
- Each component is self-contained
- No global state to manage
- No stale data concerns within a view
- Easy to reason about data flow

**Trade-offs**:
- More API calls than bulk loading (acceptable with gzip)
- Loading state per component (cleaner UX actually)

### Decision 3: API Format Everywhere

**What**: Use the API's field format (`scientific_name`, flat taxonomy fields) rather than the export's nested format.

**Format differences eliminated**:

| Field | Old Export Format | API Format (now universal) |
|-------|------------------|---------------------------|
| Species name | `name` | `scientific_name` |
| Taxonomy | `taxonomy: { subgenus, section, ... }` | `subgenus`, `section`, ... (flat) |

**Why**:
- Eliminates all format conversion code
- One mental model for developers
- API responses used directly in components

**Trade-offs**:
- UI components need updates to read new field names
- One-time migration effort

### Decision 4: Full Species Endpoint

**What**: `GET /api/v1/species/{name}/full` returns single species with all source data embedded.

**Response format**:
```json
{
  "scientific_name": "alba",
  "author": "L. 1753",
  "is_hybrid": false,
  "conservation_status": "LC",
  "subgenus": "Quercus",
  "section": "Quercus",
  "subsection": null,
  "complex": null,
  "parent1": null,
  "parent2": null,
  "hybrids": ["bebbiana", "jackiana"],
  "closely_related_to": ["stellata"],
  "subspecies_varieties": [],
  "synonyms": [],
  "external_links": [],
  "sources": [
    {
      "source_id": 1,
      "source_name": "Oaks of the World",
      "source_url": "https://oaksoftheworld.fr",
      "is_preferred": true,
      "local_names": ["white oak"],
      "leaves": "...",
      "fruits": "...",
      ...
    }
  ]
}
```

**Why**:
- Single request for species detail view
- Includes source metadata (name, URL) for display
- Format matches what UI needs

### Decision 5: Gzip Compression

**What**: Enable gzip compression for all JSON responses.

**Implementation**: Use Go's `compress/gzip` middleware.

**Why**:
- Species list ~1-2MB uncompressed → ~100-200KB compressed
- Major improvement for page load time
- Standard HTTP feature, no client changes needed

### Decision 6: Delete Cascade Protection

**What**: Prevent deletion of species that are referenced as hybrid parents.

**Behavior**:
- `DELETE /api/v1/species/{name}` checks for referencing hybrids
- If found: Return 409 Conflict with list of blocking hybrids
- User must delete or update hybrids first

**Response format**:
```json
{
  "error": {
    "code": "CONFLICT",
    "message": "Cannot delete: 3 hybrids reference this species as a parent",
    "details": {
      "blocking_hybrids": ["× bebbiana", "× jackiana", "× fernowii"]
    }
  }
}
```

**Why**:
- Prevents data corruption (orphaned parent references)
- Explicit user action required
- Clear error message with actionable information

### Decision 7: Data Flow Patterns

**Species List View**:
```
Component mounts
  → Show loading spinner
  → GET /api/v1/species
  → Store in component state
  → Render list
```

**Species Detail View**:
```
Component mounts (with name param)
  → Show loading spinner
  → GET /api/v1/species/{name}/full
  → Store in component state
  → Render detail
```

**Taxonomy View**:
```
Component mounts
  → Show loading spinner
  → GET /api/v1/taxa
  → Store in component state
  → Render tree
```

**Edit Species**:
```
User saves edit
  → PUT /api/v1/species/{name}
  → On success: GET /api/v1/species/{name}/full (with retry)
  → Update component state
  → Show success toast
```

**Create Species**:
```
User creates species
  → POST /api/v1/species
  → On success: Navigate to species detail
  → Detail view fetches fresh data
```

**Delete Species**:
```
User deletes species
  → DELETE /api/v1/species/{name}
  → On 409: Show blocking hybrids error
  → On success: Navigate to list
  → List view fetches fresh data
```

### Decision 8: Edit Recovery with Retry

**What**: Retry GET requests after successful edits to handle transient failures.

**Flow**:
1. PUT/POST succeeds
2. GET to refresh data
3. If GET fails: retry up to 3 times with exponential backoff (1s, 2s, 4s)
4. If still failing: Show toast "Edit saved. Display may be stale—refresh to see changes."

**Why**:
- Network failures are often transient
- User's work is saved (PUT succeeded)
- Simple retry logic improves UX significantly
- Graceful degradation after retries exhausted

### Decision 9: Remove Export Endpoint

**What**: Delete `/api/v1/export` endpoint.

**Why**:
- Only used by web app, which now uses individual endpoints
- CLI has its own `oak export` command (doesn't use API)
- Reduces API surface area

**Migration**: Web app updated before endpoint removed.

## API Endpoint Structure

```
Health:
  GET /health
  GET /health/ready
  GET /api/v1/health

Auth:
  GET /api/v1/auth/verify

Species:
  GET    /api/v1/species             → List all
  GET    /api/v1/species/search      → Search
  POST   /api/v1/species             → Create
  GET    /api/v1/species/{name}      → Get (basic)
  GET    /api/v1/species/{name}/full → Get (with sources) [NEW]
  PUT    /api/v1/species/{name}      → Update
  DELETE /api/v1/species/{name}      → Delete (with cascade protection)

Species-Sources:
  GET    /api/v1/species/{name}/sources           → List
  POST   /api/v1/species/{name}/sources           → Create
  GET    /api/v1/species/{name}/sources/{id}      → Get
  PUT    /api/v1/species/{name}/sources/{id}      → Update
  DELETE /api/v1/species/{name}/sources/{id}      → Delete

Sources:
  GET    /api/v1/sources      → List
  POST   /api/v1/sources      → Create
  GET    /api/v1/sources/{id} → Get
  PUT    /api/v1/sources/{id} → Update
  DELETE /api/v1/sources/{id} → Delete

Taxa:
  GET    /api/v1/taxa                   → List
  POST   /api/v1/taxa                   → Create
  GET    /api/v1/taxa/{level}/{name}    → Get
  PUT    /api/v1/taxa/{level}/{name}    → Update
  DELETE /api/v1/taxa/{level}/{name}    → Delete

REMOVED:
  GET /api/v1/export  → Use individual endpoints instead
```

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| More API calls per session; species list ~150KB gzipped per load | Gzip compression keeps payloads acceptable |
| No offline support | Explicit decision; separate future initiative |
| API outage = app unusable | Acceptable for now; future PWA can cache |
| Data lost on page refresh mid-edit | Standard web behavior; could add beforeunload warning later |

## Migration Plan

1. **API additions (non-breaking)**:
   - Add `/species/{name}/full` endpoint
   - Add gzip compression middleware
   - Add delete cascade protection for species
   - Deploy to production

2. **Web app changes**:
   - Remove Dexie.js dependency
   - Delete `db.js`
   - Delete `quercus_data.json`
   - Update components to fetch on mount
   - Update components to use API format fields
   - Remove format conversion code
   - Add retry logic for GET-after-edit
   - Add per-component loading states
   - Deploy to production

3. **API cleanup (breaking)**:
   - Remove `/export` endpoint
   - Deploy to production

4. **Documentation**:
   - Update CLAUDE.md with new architecture
   - Update web/CLAUDE.md
