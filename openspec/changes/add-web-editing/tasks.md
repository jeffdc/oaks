# Tasks: Add Web Editing

## 1. Authentication Infrastructure

- [ ] 1.1 Create `authStore.js` with key persistence and derived `isAuthenticated`
- [ ] 1.2 Create `/settings/` route with API key input form
- [ ] 1.3 Add key validation on entry (call `/api/v1/auth/verify`)
- [ ] 1.4 Add "Admin mode" indicator to Header when authenticated
- [ ] 1.5 Add logout/clear key functionality to settings page
- [ ] 1.6 Handle 401 responses globally (clear key, show error)

## 2. API Client Write Operations

- [ ] 2.1 Add `fetchApiAuthenticated` wrapper with Bearer token
- [ ] 2.2 Add `createSpecies`, `updateSpecies`, `deleteSpecies` methods
- [ ] 2.3 Add `createTaxon`, `updateTaxon`, `deleteTaxon` methods
- [ ] 2.4 Add `createSource`, `updateSource`, `deleteSource` methods
- [ ] 2.5 Add species-source CRUD methods
- [ ] 2.6 Add error handling for validation errors (400 responses)

## 3. Common UI Components

- [ ] 3.1 Create `EditModal.svelte` - reusable modal container
- [ ] 3.2 Create `DeleteConfirmDialog.svelte` - confirmation dialog
- [ ] 3.3 Create `FormField.svelte` - labeled input with error state
- [ ] 3.4 Add loading spinner component for save operations
- [ ] 3.5 Add toast/notification component for success/error feedback

## 4. Species Editing

- [ ] 4.1 Add Edit button to `SpeciesDetail.svelte` (visible when authenticated)
- [ ] 4.2 Create `SpeciesEditForm.svelte` with all species fields
- [ ] 4.3 Implement species update flow (edit modal -> API -> refresh)
- [ ] 4.4 Add Delete button with confirmation dialog
- [ ] 4.5 Create "Add New Species" button on list page
- [ ] 4.6 Implement species create flow

## 5. Species-Source Editing

- [ ] 5.1 Add source-attributed data editing to species detail
- [ ] 5.2 Allow adding new source data for a species
- [ ] 5.3 Allow editing existing source data
- [ ] 5.4 Allow deleting source data from species

## 6. Taxa Editing

- [ ] 6.1 Add Edit/Delete buttons to `TaxonView.svelte`
- [ ] 6.2 Create `TaxonEditForm.svelte`
- [ ] 6.3 Add "Create Taxon" option in taxonomy browser
- [ ] 6.4 Handle taxon hierarchy (parent selection)

## 7. Sources Editing

- [ ] 7.1 Add Edit/Delete buttons to sources list page
- [ ] 7.2 Create `SourceEditForm.svelte`
- [ ] 7.3 Add "Create Source" button
- [ ] 7.4 Implement source CRUD flow

## 8. Data Refresh & Sync

- [ ] 8.1 Refresh species list after create/update/delete
- [ ] 8.2 Refresh IndexedDB after successful writes
- [ ] 8.3 Handle concurrent edit conflicts gracefully

## 9. Testing & Polish

- [ ] 9.1 Test all CRUD operations end-to-end
- [ ] 9.2 Test auth flow (enter key, logout, invalid key)
- [ ] 9.3 Test error states (network failure, validation errors)
- [ ] 9.4 Verify mobile responsiveness of edit forms
- [ ] 9.5 Update web/CLAUDE.md with editing documentation
