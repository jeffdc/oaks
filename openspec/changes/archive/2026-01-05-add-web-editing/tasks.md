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

- [ ] 1.1 Fix synonym search in `dataStore.js:101` to handle `[]string` format
- [ ] 1.2 Add `toApiFormat(species)` mapping function in `apiClient.js`
- [ ] 1.3 Add `toApiFormat` for taxa (simpler, mostly 1:1)
- [ ] 1.4 Add `toApiFormat` for sources (simpler, mostly 1:1)
- [ ] 1.5 Update test fixtures if needed

## 2. Authentication Infrastructure

- [ ] 2.1 Create `authStore.js` with key persistence and derived `isAuthenticated`
- [ ] 2.2 Create `/settings/` route with API key input form
- [ ] 2.3 Add key validation on entry (call `/api/v1/auth/verify`)
- [ ] 2.4 Add "Admin mode" indicator to Header when authenticated
- [ ] 2.5 Add logout/clear key functionality to settings page
- [ ] 2.6 Handle 401 responses globally (clear key, show error)

## 3. Connectivity & Offline Handling

- [ ] 3.1 Add `canEdit` derived store (authenticated AND online AND API available)
- [ ] 3.2 Hide/disable edit buttons when `canEdit` is false
- [ ] 3.3 Add tooltips explaining why editing is disabled
- [ ] 3.4 Handle connection loss during edit (disable submit, show warning)
- [ ] 3.5 Handle connection restore during edit (re-enable submit)
- [ ] 3.6 Periodic API health check when online

## 4. API Client Write Operations

- [ ] 4.1 Add `fetchApiAuthenticated` wrapper with Bearer token
- [ ] 4.2 Add `createSpecies`, `updateSpecies`, `deleteSpecies` methods
- [ ] 4.3 Add `createTaxon`, `updateTaxon`, `deleteTaxon` methods
- [ ] 4.4 Add `createSource`, `updateSource`, `deleteSource` methods
- [ ] 4.5 Add species-source CRUD methods
- [ ] 4.6 Add error handling for validation errors (400 responses)
- [ ] 4.7 Add rate limit handling (429 responses with Retry-After)

## 5. Common UI Components

- [ ] 5.1 Create `EditModal.svelte` - reusable modal container
- [ ] 5.2 Create `DeleteConfirmDialog.svelte` - confirmation with cascade warning
- [ ] 5.3 Create `FormField.svelte` - labeled input with error state
- [ ] 5.4 Create `TagInput.svelte` - for array fields (local_names, hybrids)
- [ ] 5.5 Create `DynamicList.svelte` - for complex arrays (synonyms)
- [ ] 5.6 Create `TaxonSelect.svelte` - dropdown/autocomplete for taxonomy
- [ ] 5.7 Add loading spinner component for save operations
- [ ] 5.8 Add toast notification component for success/error feedback

## 6. Species Editing

- [ ] 6.1 Add Edit button to `SpeciesDetail.svelte` (visible when `canEdit`)
- [ ] 6.2 Create `SpeciesEditForm.svelte` with all species fields
- [ ] 6.3 Implement core field editing (scientific_name, author, is_hybrid, conservation_status)
- [ ] 6.4 Implement taxonomy fields (subgenus dropdown, section/subsection/complex autocomplete)
- [ ] 6.5 Implement array fields (synonyms, parent references)
- [ ] 6.6 Implement species update flow (edit modal → API → full refresh → close)
- [ ] 6.7 Add Delete button with cascade warning dialog
- [ ] 6.8 Create "Add New Species" button on list page
- [ ] 6.9 Implement species create flow
- [ ] 6.10 Show validation errors inline and in summary

## 7. Species-Source Editing

- [ ] 7.1 Add Edit button to each source tab in species detail view
- [ ] 7.2 Create `SpeciesSourceEditForm.svelte` for source-attributed fields
- [ ] 7.3 Pre-fill form with current source's data (leaves, range, local_names, etc.)
- [ ] 7.4 Save updates to `PUT /api/v1/species/{name}/sources/{source_id}`
- [ ] 7.5 Add "Add Source Data" button to add data from a new source
- [ ] 7.6 Source selector when adding (dropdown of available sources)
- [ ] 7.7 Allow deleting any species-source record (with confirmation)

## 8. Taxa Editing

- [ ] 8.1 Add Edit/Delete buttons to `TaxonView.svelte`
- [ ] 8.2 Create `TaxonEditForm.svelte`
- [ ] 8.3 Add "Create Taxon" option in taxonomy browser
- [ ] 8.4 Handle taxon hierarchy (parent selection dropdown)
- [ ] 8.5 Show delete cascade warning if taxon has child taxa

## 9. Sources Editing

- [ ] 9.1 Add Edit/Delete buttons to sources list page
- [ ] 9.2 Create `SourceEditForm.svelte`
- [ ] 9.3 Add "Create Source" button
- [ ] 9.4 Implement source CRUD flow
- [ ] 9.5 Show delete cascade warning if source has species_sources

## 10. Data Refresh & Consistency

- [ ] 10.1 Implement full data refresh after successful write operations
- [ ] 10.2 Clear and repopulate IndexedDB after refresh
- [ ] 10.3 Update Svelte stores from refreshed IndexedDB
- [ ] 10.4 Show loading indicator during refresh
- [ ] 10.5 Handle refresh failures gracefully (show error, don't lose edit confirmation)

## 11. Testing & Polish

- [ ] 11.1 Test all CRUD operations end-to-end
- [ ] 11.2 Test auth flow (enter key, logout, invalid key)
- [ ] 11.3 Test offline scenarios (edit disabled, connection loss mid-edit)
- [ ] 11.4 Test error states (network failure, validation errors, rate limits)
- [ ] 11.5 Test success notifications display and dismiss
- [ ] 11.6 Verify mobile responsiveness of edit forms
- [ ] 11.7 Update web/CLAUDE.md with editing documentation

## 12. Review Findings (Added Items)

### Session & Security
- [ ] 12.1 Add session timeout (24 hour default, configurable)
- [ ] 12.2 Document XSS risk in security notes (API key in localStorage)
- [ ] 12.3 Add input sanitization - max field lengths
- [ ] 12.4 Add HTML escaping for user-provided content on display

### UX Safety
- [ ] 12.5 Add unsaved changes warning (beforeunload + Cancel confirmation)
- [ ] 12.6 Disable form submit during data refresh (prevent race condition)

### Accessibility
- [ ] 12.7 Add keyboard navigation (Tab order, Enter submit, Escape close)
- [ ] 12.8 Add ARIA labels for form inputs and modals
- [ ] 12.9 Focus management (trap focus in modal, return focus on close)

### Form Layout
- [ ] 12.10 Design scrollable modal with field sections/groups
- [ ] 12.11 Test form layout on mobile (may need full-page on small screens)

### Documentation
- [ ] 12.12 Document delete cascade behavior (API constraints)
- [ ] 12.13 Document concurrent tab limitation (stale data possible)
- [ ] 12.14 Specify API health check frequency (60 seconds with debounce)

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
