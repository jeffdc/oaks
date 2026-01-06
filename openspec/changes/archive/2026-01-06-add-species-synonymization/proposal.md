# Change: Add Species Synonymization (Merge and Redirect)

## Why

The Oak Compendium aggregates data from multiple sources (iNaturalist, Oaks of the World, personal observations). These sources sometimes use different names for the same species - old synonyms, outdated nomenclature, or regional name variations. Currently there's no way to consolidate these duplicate entries, leaving the database with redundant species that confuse users.

For example: `× asheana` (from Oaks of the World) is an old name for `× ashei`. We need a way to merge these entries, declaring the old name as a synonym while preserving valuable data under the canonical name.

## What Changes

### API Server (`api/`)

**New endpoint required:**
- `GET /api/v1/species/references?name={name}` - Returns species where `parent1`, `parent2`, `hybrids`, or `closely_related_to` contains the given name.

**Modified behavior:**
- `GET /api/v1/species/{name}` - If species doesn't exist but name is found as a synonym of another species, return HTTP 404 with `{ "synonym_of": "target_name" }`. This clearly indicates the species doesn't exist while providing redirect information. If the name appears as a synonym in multiple species, return HTTP 404 with `{ "ambiguous_synonym": true, "matches": ["species1", "species2", ...] }` so the client can show the user which species to choose.

**Search behavior:**
- `GET /api/v1/species` (with search query) - Search should match against synonyms arrays in addition to species names. When a match is via synonym, include `matched_via_synonym: "synonym_name"` in the result so the UI can indicate this.

### Web Application (`web/`)

**Synonym Button (Admin UI):**
- **ADDED**: "Make Synonym Of..." button on species detail page (visible when authenticated)
- **ADDED**: Species picker dialog to select the target species
- **ADDED**: Merge preview screen showing side-by-side comparison
- **ADDED**: Route `/species/{name}/merge/{target}` for merge screen

**Merge Screen:**
- **ADDED**: Two-column layout: synonym (left, read-only) vs target (right, editable)
- **ADDED**: Field-by-field comparison for ALL species-level fields
- **ADDED**: Auto-copy for empty target fields (synonym data fills gaps)
- **ADDED**: Manual copy buttons for fields where both have data
- **ADDED**: Array fields use union (deduplicated) merge by default
- **ADDED**: Source-level data merging (same rules as species-level)
- **ADDED**: Data loss warning section (shows unchecked synonym-only sources)
- **ADDED**: Self-reference warning (shows if target would reference itself in hybrids/closely_related_to after merge)
- **ADDED**: Cancel/Save action buttons with confirmation dialogs

**Species-Level Fields to Merge:**
- `author`
- `conservation_status`
- `taxonomy` (subgenus, section, subsection, complex)
- `parent1`, `parent2` (hybrid parents)
- `synonyms` (synonym's existing synonyms merged into target)
- `subspecies_varieties` (array - union merge)
- `external_links` (array - union merge)
- `hybrids` (informational - references updated separately)
- `closely_related_to` (informational - references updated separately)

**Explicitly excluded from merge:**
- `is_hybrid` - Derived from `×` prefix in name, not editable

**Source-Level Fields to Merge:**
- `local_names` (array - union merge, case-insensitive deduplication)
- `range`, `growth_habit`, `leaves`, `flowers`, `fruits`
- `bark`, `twigs`, `buds` (separate fields)
- `hardiness_habitat`, `miscellaneous`, `url`

**Data Operations on Save:**
1. Add synonym name to target's synonyms array
2. Merge synonym's existing synonyms into target's synonyms (case-insensitive deduplication)
3. Update target species with merged field data
4. Update target's species-source records with merged source data
5. Update OTHER species that reference the synonym:
   - In `parent1` or `parent2` fields (string match)
   - In `hybrids` or `closely_related_to` arrays
6. Delete the synonym species (cascade deletes its species-sources)

**IMPORTANT**: Delete must be the final operation. If earlier steps fail, the synonym still exists and the user can retry.

**Synonym URL Handling:**
- **ADDED**: When fetching a species that doesn't exist, API returns 404 with `synonym_of` field if name is a synonym
- **ADDED**: Client checks for `synonym_of` in 404 response and performs `goto()` with `replaceState` to redirect
- **ADDED**: If 404 contains `ambiguous_synonym`, client shows disambiguation UI with list of matching species

### CLI Tool (`cli/`)

No changes required - synonymization is a web-only workflow for now.

## Impact

- **New spec**: species-synonymization
- **Affected code**:
  - `api/internal/handlers/species.go` (redirect logic, new search endpoint)
  - `web/src/lib/components/SpeciesDetail.svelte` (add synonym button, handle redirect)
  - `web/src/routes/species/[name]/merge/[target]/+page.svelte` (new route)
  - `web/src/lib/components/SpeciesMergeScreen.svelte` (new)
  - `web/src/lib/components/MergeFieldRow.svelte` (new)
  - `web/src/lib/components/SourceMergeSection.svelte` (new)
  - `web/src/lib/components/MergeDataLossWarning.svelte` (new)
  - `web/src/lib/apiClient.js` (helper for multi-step merge)
- **Breaking changes**: None - purely additive
- **Dependencies**: Uses existing web-editing infrastructure (auth, edit modals, API client)

## User Flow

1. Navigate to synonym species (e.g., `× asheana`)
2. Click "Make Synonym Of..." button (visible when authenticated)
3. Species picker dialog opens - search/select target species (`× ashei`)
4. Browser navigates to `/species/× asheana/merge/× ashei`
5. Merge screen displays:
   - Left column: synonym data (read-only)
   - Right column: target data (editable)
   - Fields with data in both show copy buttons (synonym → target)
   - Empty target fields auto-populated from synonym
   - Array fields show union of both values
   - Data loss section highlights unchecked synonym-only sources
6. Review merged data, make manual adjustments
7. Click "Save" → confirmation dialog explains:
   - Synonym name added as synonym of target
   - All shown changes applied to target
   - References in other species will be updated (with count)
   - Synonym species will be deleted
   - **This action cannot be undone**
8. Confirm → operations execute → redirect to target species page
9. Cancel → return to synonym species page (no changes)

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Self-synonymization attempt | Picker blocks selection of the current species as target |
| Circular synonym attempt | Picker blocks selection if target already has current species in its synonyms array |
| Synonym has no unique data | Show merge screen anyway (just adds synonym) |
| Target already has synonym name as synonym | Skip adding duplicate (case-insensitive check) |
| Synonym has sources target doesn't have | Create new species-source records on target |
| Both have same source with different data | Show merge UI for that source |
| User cancels mid-merge | No changes made, return to synonym page |
| Partial failure during save | Show error with details of what succeeded vs failed; no automatic retry; user can fix manually or start over |
| Synonym URL accessed after deletion | API returns redirect info, client redirects to target |
| Merge page accessed after synonym deleted | Page detects missing synonym, redirects to target |
| Synonym referenced in other species' hybrids | Update those references to point to target |
| Synonym referenced in other species' closely_related_to | Update those references to point to target |
| Synonym is parent1/parent2 of hybrids | Update those parent fields to point to target |
| Hybrid merged into non-hybrid (or vice versa) | Allowed - user reviewing merge can adjust other fields |
| Array fields in both species | Union (deduplicated) by default; user can manually edit |
| Target's hybrids/closely_related_to contains synonym | Warning shown - merge would create self-reference; user can edit arrays before saving |
| Synonym is parent1/parent2 of target | Warning shown - merge would make target its own parent; user can clear parent field before saving |
| Same synonym name in multiple species | API returns ambiguous_synonym error with list of matching species |
| Both species have same value in synonyms array | Deduplicated (case-insensitive) during merge |

## Design Decisions

1. **No API endpoint for atomic merge**: Using existing endpoints sequentially. If partial failure occurs, error shows what succeeded vs failed. No automatic retry - user can fix manually or refresh and start over. Acceptable for single-user admin scenario.

2. **Synonym deleted after merge**: No "soft delete". Species is fully removed. Synonym entry preserves discoverability. Old URL redirects to target via API response.

3. **Web-only workflow**: CLI doesn't need this - power users can manually edit synonyms and delete species.

4. **Merge screen always shown**: Even if no conflicts, user should review what's happening before a destructive operation.

5. **Per-source merging**: Sources are merged independently. Target may end up with more source records than before.

6. **Target's is_preferred unchanged**: The target's `is_preferred` values are preserved; the synonym's `is_preferred` values are ignored. New sources from synonym are added as non-preferred.

7. **Full-page route**: Merge screen is complex enough to warrant its own route (`/species/{name}/merge/{target}`) rather than a modal.

8. **Reference updates include parent fields**: Other species referencing the synonym in `parent1`, `parent2`, `hybrids`, or `closely_related_to` are automatically updated to reference the target instead.

9. **Array fields use union merge**: When both species have array values, they are combined with deduplication. Deduplication is case-insensitive for taxonomic names (`synonyms`, `subspecies_varieties`) and case-sensitive for URLs (`external_links`). User can manually edit the result before saving.

10. **is_hybrid excluded**: This field is derived from the `×` prefix in the species name and is not editable in the merge screen.

11. **Client-side redirect via 404**: API returns HTTP 404 with `{ "synonym_of": "target_name" }` for synonym URLs; client checks 404 responses for this field and performs `goto()` with `replaceState`. The 404 status correctly indicates the species doesn't exist while the body provides redirect information.

12. **Data loss warning is narrow**: Only warns about unchecked synonym-only sources (data that will truly be lost). Does not warn about differing values where user kept target's value.

13. **Dirty tracking excludes auto-populate**: The cancel confirmation dialog only appears for user-initiated edits. Auto-populated values (synonym data filling empty target fields on load) do not count as "changes" for dirty tracking purposes.

14. **Desktop-only admin UI**: Mobile responsiveness is not required for the merge screen. Admin workflows assume desktop usage.

15. **Self-reference warnings**: If the merge would cause the target species to reference itself (in hybrids, closely_related_to, parent1, or parent2), a warning is displayed in the merge preview. The user can edit the affected fields before saving.

16. **local_names uses union merge**: The `local_names` array field in source data uses union merge with case-insensitive deduplication, like other taxonomic arrays.

17. **Ambiguous synonym handling**: If a synonym name appears in multiple species' synonyms arrays, the API returns an error listing all matching species rather than arbitrarily picking one. The client shows disambiguation UI.

18. **Search includes synonyms**: The species search matches against synonyms arrays in addition to species names. Results indicate when a match was via synonym.

## Future Enhancements

- **Parent field species lookup**: The `parent1` and `parent2` fields should use species autocomplete/picker rather than free text input. This is a separate enhancement to the species edit form, not part of this change.

- **Audit trail**: A separate proposal will cover logging of destructive operations (who, when, what data was affected). Currently, synonymization has no audit trail.

- **Synonym redirect performance**: The current implementation scans all species' synonyms arrays on each redirect lookup (O(n)). For scale, a dedicated synonym lookup table or index would provide O(1) resolution.
