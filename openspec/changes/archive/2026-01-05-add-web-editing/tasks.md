# Tasks: Add Web Editing

## 0. Prerequisite Decisions (BLOCKING)

These must be resolved before implementation begins. See design.md for full discussion.

- [x] 0.1 **Decided: Data model strategy** - Option C: Minimal fixes + write mapping (no schema changes)
- [x] 0.2 **Confirmed: IndexedDB refresh strategy** - Full refresh after each edit
- [x] 0.3 **Confirmed: Offline editing** - Disable when offline
- [x] 0.4 **Decided: Species-source editing** - Edit the currently displayed source (any source)
- [x] 0.5 **Default: Array field UI** - Tag input for simple arrays (local_names, hybrids)
- [x] 0.6 **Default: Taxonomy fields** - Dropdown for subgenus, autocomplete for section/subsection/complex

## 1. Data Model Fixes (Option C)

- [x] 1.1 Fix synonym search in `dataStore.js:101` to handle `[]string` format
- [x] 1.2 Add `toApiFormat(species)` mapping function in `apiClient.js`
- [x] 1.3 Add `toApiFormat` for taxa (simpler, mostly 1:1)
- [x] 1.4 Add `toApiFormat` for sources (simpler, mostly 1:1)
- [x] 1.5 Update test fixtures if needed

## 2. Authentication Infrastructure

- [x] 2.1 Create `authStore.js` with key persistence and derived `isAuthenticated`
- [x] 2.2 Create `/settings/` route with API key input form
- [x] 2.3 Add key validation on entry (call `/api/v1/auth/verify`)
- [x] 2.4 Add "Admin mode" indicator to Header when authenticated
- [x] 2.5 Add logout/clear key functionality to settings page
- [x] 2.6 Handle 401 responses globally (clear key, show error)

## 3. Connectivity & Offline Handling

- [x] 3.1 Add `canEdit` derived store (authenticated AND online AND API available)
- [x] 3.2 Hide/disable edit buttons when `canEdit` is false
- [x] 3.3 Add tooltips explaining why editing is disabled
- [x] 3.4 Handle connection loss during edit (disable submit, show warning)
- [x] 3.5 Handle connection restore during edit (re-enable submit)
- [x] 3.6 Periodic API health check when online

## 4. API Client Write Operations

- [x] 4.1 Add `fetchApiAuthenticated` wrapper with Bearer token
- [x] 4.2 Add `createSpecies`, `updateSpecies`, `deleteSpecies` methods
- [x] 4.3 Add `createTaxon`, `updateTaxon`, `deleteTaxon` methods
- [x] 4.4 Add `createSource`, `updateSource`, `deleteSource` methods
- [x] 4.5 Add species-source CRUD methods
- [x] 4.6 Add error handling for validation errors (400 responses)
- [x] 4.7 Add rate limit handling (429 responses with Retry-After)

## 5. Common UI Components

- [x] 5.1 Create `EditModal.svelte` - reusable modal container
- [x] 5.2 Create `DeleteConfirmDialog.svelte` - confirmation with cascade warning
- [x] 5.3 Create `FormField.svelte` - labeled input with error state
- [x] 5.4 Create `TagInput.svelte` - for array fields (local_names, hybrids)
- [x] 5.5 Create `DynamicList.svelte` - for complex arrays (synonyms)
- [x] 5.6 Create `TaxonSelect.svelte` - dropdown/autocomplete for taxonomy
- [x] 5.7 Add loading spinner component for save operations
- [x] 5.8 Add toast notification component for success/error feedback

## 6. Species Editing

- [x] 6.1 Add Edit button to `SpeciesDetail.svelte` (visible when `canEdit`)
- [x] 6.2 Create `SpeciesEditForm.svelte` with all species fields
- [x] 6.3 Implement core field editing (scientific_name, author, is_hybrid, conservation_status)
- [x] 6.4 Implement taxonomy fields (subgenus dropdown, section/subsection/complex autocomplete)
- [x] 6.5 Implement array fields (synonyms, parent references)
- [x] 6.6 Implement species update flow (edit modal → API → full refresh → close)
- [x] 6.7 Add Delete button with cascade warning dialog
- [x] 6.8 Create "Add New Species" button on list page
- [x] 6.9 Implement species create flow
- [x] 6.10 Show validation errors inline and in summary

## 7. Species-Source Editing

- [x] 7.1 Add Edit button to each source tab in species detail view
- [x] 7.2 Create `SpeciesSourceEditForm.svelte` for source-attributed fields
- [x] 7.3 Pre-fill form with current source's data (leaves, range, local_names, etc.)
- [x] 7.4 Save updates to `PUT /api/v1/species/{name}/sources/{source_id}`
- [x] 7.5 Add "Add Source Data" button to add data from a new source
- [x] 7.6 Source selector when adding (dropdown of available sources)
- [x] 7.7 Allow deleting any species-source record (with confirmation)

## 8. Taxa Editing

- [x] 8.1 Add Edit/Delete buttons to `TaxonView.svelte`
- [x] 8.2 Create `TaxonEditForm.svelte`
- [x] 8.3 Add "Create Taxon" option in taxonomy browser
- [x] 8.4 Handle taxon hierarchy (parent selection dropdown)
- [x] 8.5 Show delete cascade warning if taxon has child taxa

## 9. Sources Editing

- [x] 9.1 Add Edit/Delete buttons to sources list page
- [x] 9.2 Create `SourceEditForm.svelte`
- [x] 9.3 Add "Create Source" button
- [x] 9.4 Implement source CRUD flow
- [x] 9.5 Show delete cascade warning if source has species_sources

## 10. Data Refresh & Consistency

- [x] 10.1 Implement full data refresh after successful write operations
- [x] 10.2 Clear and repopulate IndexedDB after refresh
- [x] 10.3 Update Svelte stores from refreshed IndexedDB
- [x] 10.4 Show loading indicator during refresh
- [x] 10.5 Handle refresh failures gracefully (show error, don't lose edit confirmation)

## 11. Testing & Polish

- [x] 11.1 Test all CRUD operations end-to-end
- [x] 11.2 Test auth flow (enter key, logout, invalid key)
- [x] 11.3 Test offline scenarios (edit disabled, connection loss mid-edit)
- [x] 11.4 Test error states (network failure, validation errors, rate limits)
- [x] 11.5 Test success notifications display and dismiss
- [x] 11.6 Verify mobile responsiveness of edit forms
- [x] 11.7 Update web/CLAUDE.md with editing documentation

## 12. Review Findings (Added Items)

### Session & Security
- [x] 12.1 Add session timeout (24 hour default, configurable)
- [x] 12.2 Document XSS risk in security notes (API key in localStorage)
- [x] 12.3 Add input sanitization - max field lengths
- [x] 12.4 Add HTML escaping for user-provided content on display

### UX Safety
- [x] 12.5 Add unsaved changes warning (beforeunload + Cancel confirmation)
- [x] 12.6 Disable form submit during data refresh (prevent race condition)

### Accessibility
- [x] 12.7 Add keyboard navigation (Tab order, Enter submit, Escape close)
- [x] 12.8 Add ARIA labels for form inputs and modals
- [x] 12.9 Focus management (trap focus in modal, return focus on close)

### Form Layout
- [x] 12.10 Design scrollable modal with field sections/groups
- [x] 12.11 Test form layout on mobile (may need full-page on small screens)

### Documentation
- [x] 12.12 Document delete cascade behavior (API constraints)
- [x] 12.13 Document concurrent tab limitation (stale data possible)
- [x] 12.14 Specify API health check frequency (60 seconds with debounce)

## Task Dependencies

```
Section 2 (Auth) ──────────┐
                           ├──▶ Section 4 (API Write Operations)
Section 3 (Connectivity) ──┘

Section 5 (Common UI) ─────┬──▶ Section 6 (Species Editing)
                           ├──▶ Section 7 (Species-Source Editing)
                           ├──▶ Section 8 (Taxa Editing)
                           └──▶ Section 9 (Sources Editing)

Section 1 (Data Model) ────────▶ All editing sections (6-9)
```
