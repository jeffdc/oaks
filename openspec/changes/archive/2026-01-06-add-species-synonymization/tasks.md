# Tasks: Add Species Synonymization

## 1. API: Reference Search Endpoint

- [ ] 1.1 Add `GET /api/v1/species/references?name={name}` endpoint
  - Returns species where `parent1`, `parent2`, `hybrids`, or `closely_related_to` contains the given name
- [ ] 1.2 Add handler in `species.go`
- [ ] 1.3 Add database query for reference search
- [ ] 1.4 Add tests for reference search endpoint

## 2. API: Synonym Redirect Support

- [ ] 2.1 Modify `GET /api/v1/species/{name}` behavior
  - If species doesn't exist, search synonyms array across all species
  - If found in one species, return HTTP 404 with `{ "synonym_of": "target_name" }`
  - If found in multiple species, return HTTP 404 with `{ "ambiguous_synonym": true, "matches": ["species1", ...] }`
- [ ] 2.2 Add tests for redirect behavior
- [ ] 2.3 Add tests for ambiguous synonym behavior

## 2b. API: Search Includes Synonyms

- [ ] 2b.1 Modify species search to match against synonyms arrays
- [ ] 2b.2 Include `matched_via_synonym` field in results when match is via synonym
- [ ] 2b.3 Add tests for synonym search behavior

## 3. Web: Route & Navigation

- [ ] 3.1 Create route `/species/[name]/merge/[target]/+page.svelte`
- [ ] 3.2 Add "Make Synonym Of..." button to SpeciesDetail.svelte (gated by `canEdit`)
- [ ] 3.3 Create SpeciesPickerDialog.svelte component
  - Search input with autocomplete
  - Species list filtered by search query
  - Excludes current species from results (self-synonymization)
  - Blocks selection if target already has current species as synonym (circular)
  - Shows: species name, author, section, hybrid indicator (simplified from original)
  - Click to select, button to confirm
  - URL encoding for hybrid names (× character) already handled by existing code
- [ ] 3.4 Navigate to merge route on picker confirmation
- [ ] 3.5 Handle picker cancel (close dialog, no navigation)

## 4. Web: Synonym Redirect Handling

- [ ] 4.1 Update species detail page to handle synonym 404 response
  - Check for `synonym_of` field in HTTP 404 response body
  - Call `goto()` with `replaceState: true` to redirect to target
- [ ] 4.2 Handle ambiguous synonym response
  - Check for `ambiguous_synonym` field in HTTP 404 response body
  - Display disambiguation UI with list of matching species
- [ ] 4.3 Update merge page to handle missing synonym
  - If synonym fetch returns 404 with `synonym_of`, redirect to target species page

## 5. Web: Merge Screen Layout

- [ ] 5.1 Create SpeciesMergeScreen.svelte component
  - Two-column layout (synonym left, target right)
  - Header showing "Merge: × asheana → × ashei"
  - Sticky action bar with Cancel/Save buttons
- [ ] 5.2 Fetch both species with `fetchSpeciesFull()` on mount
- [ ] 5.3 Fetch referencing species using new references endpoint
- [ ] 5.4 Show loading state while fetching
- [ ] 5.5 Handle fetch errors (species not found, network error)
- [ ] 5.6 Create MergeFieldRow.svelte component
  - Field label
  - Synonym value (read-only)
  - Target value (editable input/textarea)
  - Copy button (synonym → target) when both have values
  - Visual indicator when values differ

## 6. Web: Species-Level Field Merging

- [ ] 6.1 Implement field merging for scalar fields:
  - `author`
  - `conservation_status`
  - `taxonomy` (subgenus, section, subsection, complex)
  - `parent1`, `parent2`
- [ ] 6.2 Implement array field merging with union (deduplicated):
  - `subspecies_varieties` (case-insensitive deduplication)
  - `external_links` (case-sensitive deduplication - URLs)
- [ ] 6.3 Implement synonym array merging
  - Show synonym's existing synonyms
  - Preview: "Will add: × asheana, [synonym's synonyms...]"
  - Skip duplicates (case-insensitive)
- [ ] 6.4 Auto-populate empty target fields from synonym
- [ ] 6.5 Copy button for manual override when both have values
- [ ] 6.6 Note: `is_hybrid` is not shown (derived from name prefix)

## 7. Web: Source Data Merging

- [ ] 7.1 Create SourceMergeSection.svelte component
  - Collapsible section per source
  - Shows source name and indicator (both have / synonym only / target only)
- [ ] 7.2 Handle case: source exists in both synonym and target
  - Show side-by-side field comparison
  - Fields: local_names (array, union merge), range, growth_habit, leaves, flowers, fruits, bark, twigs, buds, hardiness_habitat, miscellaneous, url
  - Note: is_preferred is not merged (target's value preserved)
  - Same auto-populate / copy button behavior as species-level
- [ ] 7.3 Handle case: source exists only in synonym
  - Show synonym data (read-only preview)
  - Checkbox to include in merge (default: checked)
  - Will create new species-source on target
- [ ] 7.4 Handle case: source exists only in target
  - Show target data (read-only, no changes)
  - Informational only

## 8. Web: Data Loss Warning

- [ ] 8.1 Create MergeDataLossWarning.svelte component
- [ ] 8.2 Track unchecked synonym-only sources
- [ ] 8.3 Display warning section listing data that will be lost
  - Only show for unchecked sources (NOT for differing values where user kept target)
- [ ] 8.4 Update warning dynamically as user toggles source checkboxes

## 8b. Web: Self-Reference Warning

- [ ] 8b.1 Detect if target's hybrids array contains synonym name
- [ ] 8b.2 Detect if target's closely_related_to array contains synonym name
- [ ] 8b.3 Detect if target's parent1 or parent2 equals synonym name
- [ ] 8b.4 Display warning for each self-reference that would be created
- [ ] 8b.5 Allow user to edit affected fields before saving

## 9. Web: Reference Updates Display

- [ ] 9.1 Display section showing which species will be updated
  - Group by reference type: parent1, parent2, hybrids, closely_related_to
  - Show species names that will be modified
- [ ] 9.2 Show count in confirmation dialog

## 10. Web: Save Operation

- [ ] 10.1 Create confirmation dialog for Save action
  - List all changes that will be made
  - Show count of other species that will be updated
  - Warn that synonym will be deleted
  - State: "This action cannot be undone"
  - Require explicit confirmation
- [ ] 10.2 Implement merge execution sequence
  1. Update target species (add synonyms, merge fields)
  2. For each source to merge:
     - If target has source: update species-source
     - If target doesn't have source: create species-source
  3. Update species with parent1/parent2 references
  4. Update species with hybrids/closely_related_to references
  5. Delete synonym species
- [ ] 10.3 Handle partial failure
  - Show error with details of what succeeded vs failed
  - No automatic retry
  - User can fix manually or refresh and start over
- [ ] 10.4 Success handling
  - Show success toast
  - Redirect to target species page (using goto with replaceState)

## 11. Web: Cancel Operation

- [ ] 11.1 Create confirmation dialog for Cancel action
  - "Discard changes and return to [synonym name]?"
  - Only show if form has been modified by user (auto-populated values don't count)
- [ ] 11.2 Handle cancel navigation
  - Navigate back to synonym species detail page
  - No data changes

## 12. Web: Edge Cases & Polish

- [ ] 12.1 Handle self-synonymization attempt
  - Prevent selecting the same species as target in picker
- [ ] 12.2 Case-insensitive duplicate synonym check
- [ ] 12.3 Loading states
  - Show spinner during API operations
  - Disable buttons during save
- [ ] 12.4 (Nice-to-have) Keyboard accessibility
  - Tab navigation through merge fields
  - Enter to submit, Escape to cancel

## 13. Testing

- [ ] 13.1 API test: reference search endpoint
- [ ] 13.2 API test: synonym redirect response (HTTP 404 with synonym_of)
- [ ] 13.3 API test: ambiguous synonym response (HTTP 404 with ambiguous_synonym)
- [ ] 13.4 API test: search includes synonyms
- [ ] 13.5 Manual test: basic synonymization (no conflicts)
- [ ] 13.6 Manual test: synonym with data in all fields
- [ ] 13.7 Manual test: multiple source merge
- [ ] 13.8 Manual test: synonym-only source creation
- [ ] 13.9 Manual test: reference updates (parent1, parent2, hybrids, closely_related_to)
- [ ] 13.10 Manual test: partial failure during save
- [ ] 13.11 Manual test: URL redirect after deletion
- [ ] 13.12 Manual test: cancel with unsaved changes
- [ ] 13.13 Manual test: array field union merge (including local_names)
- [ ] 13.14 Manual test: circular synonym blocked in picker
- [ ] 13.15 Manual test: self-synonymization blocked in picker
- [ ] 13.16 Manual test: self-reference warning displayed
- [ ] 13.17 Manual test: ambiguous synonym disambiguation UI
