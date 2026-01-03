# Tasks: Web Data Layer Refactor

## Phase 1: API Additions (Non-Breaking)

### 1. Full Species Endpoint

- [ ] 1.1 Add `SpeciesWithSources` response model (species fields + embedded sources array)
- [ ] 1.2 Implement `handleGetSpeciesFull` handler
- [ ] 1.3 Query species and sources in single handler (avoid N+1)
- [ ] 1.4 Include source metadata (name, URL) from sources table
- [ ] 1.5 Order sources by is_preferred DESC, source_id ASC
- [ ] 1.6 Register route `GET /api/v1/species/{name}/full`
- [ ] 1.7 Handle 404 for non-existent species
- [ ] 1.8 Add tests for full species endpoint

### 2. Delete Cascade Protection

- [ ] 2.1 Add query to find hybrids referencing a species as parent1 or parent2
- [ ] 2.2 Update `handleDeleteSpecies` to check for referencing hybrids before delete
- [ ] 2.3 Return 409 Conflict with blocking hybrids list if found
- [ ] 2.4 Add tests for cascade protection (both allowed and blocked cases)

### 3. Gzip Compression

- [ ] 3.1 Add gzip middleware to API server
- [ ] 3.2 Configure minimum size threshold (e.g., 1KB)
- [ ] 3.3 Verify compression on large responses
- [ ] 3.4 Verify small responses are not compressed

### 4. Deploy API (Phase 1)

- [ ] 4.1 Run API tests locally
- [ ] 4.2 Deploy to Fly.io
- [ ] 4.3 Verify new endpoint works in production
- [ ] 4.4 Verify gzip compression in production

## Phase 2: Web App Changes

### 5. Remove Client-Side Persistence

- [ ] 5.1 Remove `dexie` from package.json
- [ ] 5.2 Delete `src/lib/db.js`
- [ ] 5.3 Delete `static/quercus_data.json`
- [ ] 5.4 Remove all imports of db.js
- [ ] 5.5 Run npm install to clean dependencies

### 6. API Client Updates

- [ ] 6.1 Add `fetchSpeciesFull(name)` function
- [ ] 6.2 Add retry logic helper with exponential backoff
- [ ] 6.3 Remove format conversion functions (`speciesToApiFormat`, etc.) — do after Task 12
- [ ] 6.4 Remove `fetchExport()` function
- [ ] 6.5 Update error handling for API failures
- [ ] 6.6 Add tests for retry logic

### 7. Data Store Simplification

- [ ] 7.1 Remove global `allSpecies` store
- [ ] 7.2 Remove global `allSources` store
- [ ] 7.3 Remove `loadSpeciesData()` function
- [ ] 7.4 Remove `refreshData()` function
- [ ] 7.5 Remove all IndexedDB-related code
- [ ] 7.6 Keep simple derived stores if needed (e.g., search query)

### 8. Species List Component

- [ ] 8.1 Add local state for species list
- [ ] 8.2 Fetch `GET /api/v1/species` on mount
- [ ] 8.3 Add loading spinner during fetch
- [ ] 8.4 Add error state for failed fetch
- [ ] 8.5 Update to use `scientific_name` field

### 9. Species Detail Component

- [ ] 9.1 Add local state for species detail
- [ ] 9.2 Fetch `GET /api/v1/species/{name}/full` on mount
- [ ] 9.3 Add loading spinner during fetch
- [ ] 9.4 Add error state for failed fetch / 404
- [ ] 9.5 Update to use API format fields (scientific_name, flat taxonomy)
- [ ] 9.6 Update source display to use embedded sources

### 10. Taxonomy Browser Component

- [ ] 10.1 Add local state for taxa
- [ ] 10.2 Fetch `GET /api/v1/taxa` on mount
- [ ] 10.3 Add loading spinner during fetch
- [ ] 10.4 Add error state for failed fetch

### 11. Search Component

- [ ] 11.1 Update to use `GET /api/v1/species/search?q=...`
- [ ] 11.2 Add debouncing for search input
- [ ] 11.3 Add loading state during search
- [ ] 11.4 Update results display for API format
- [ ] 11.5 Cancel pending search requests when new search starts (prevent race conditions)

### 12. Edit Forms

- [ ] 12.1 Update species edit to fetch sources for dropdown (`GET /api/v1/sources`)
- [ ] 12.2 Update species-source edit form for API format
- [ ] 12.3 Update taxon edit form for API format
- [ ] 12.4 Update source edit form (no format changes needed)

### 13. Edit Flow Updates

- [ ] 13.1 After save: refetch current view's data with retry
- [ ] 13.2 After create: navigate to detail view (which fetches fresh)
- [ ] 13.3 After delete: navigate to list view (which fetches fresh)
- [ ] 13.4 Handle 409 Conflict for blocked species deletion
- [ ] 13.5 Show blocking hybrids in error dialog
- [ ] 13.6 Add toast for "edit saved but display stale" case

### 14. Error Handling

- [ ] 14.1 Add "Unable to connect" message for API failures
- [ ] 14.2 Add retry button on error states
- [ ] 14.3 Handle network errors gracefully
- [ ] 14.4 Remove offline detection code (no longer relevant)

### 15. Deploy Web App

- [ ] 15.1 Run web tests locally
- [ ] 15.2 Test all views manually (list, detail, taxonomy, search)
- [ ] 15.3 Test all edit flows (create, update, delete)
- [ ] 15.4 Test delete cascade error handling
- [ ] 15.5 Deploy to production

## Phase 3: API Cleanup (Breaking)

### 16. Remove Export Endpoint

- [ ] 16.1 Delete `handleExport` handler
- [ ] 16.2 Remove route registration for `/api/v1/export`
- [ ] 16.3 Delete export-related tests
- [ ] 16.4 Deploy to production

## Phase 4: Documentation

### 17. Update Documentation

- [ ] 17.1 Update CLAUDE.md data flow diagram
- [ ] 17.2 Update CLAUDE.md architecture section
- [ ] 17.3 Update web/CLAUDE.md with new data flow
- [ ] 17.4 Remove references to IndexedDB, offline support, quercus_data.json
- [ ] 17.5 Document fetch-per-view pattern

## Integration Testing Checklist

After all phases complete:

- [ ] Species list loads and displays correctly
- [ ] Species detail loads with embedded sources
- [ ] Taxonomy browser loads and navigates
- [ ] Search returns results from API
- [ ] Create species works and navigates to detail
- [ ] Edit species works and refreshes data
- [ ] Delete species works (with cascade protection)
- [ ] Delete blocked shows hybrids list
- [ ] API errors show user-friendly messages
- [ ] Retry logic works for transient failures
- [ ] Gzip compression reduces response sizes
