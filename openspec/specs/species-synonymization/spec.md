# species-synonymization Specification

## Purpose
TBD - created by archiving change add-species-synonymization. Update Purpose after archive.
## Requirements
### Requirement: Species Synonymization

Authenticated users SHALL be able to merge one species (synonym) into another (target), consolidating duplicate entries caused by synonymous names or outdated nomenclature.

#### Scenario: Initiate synonymization from species detail
- **WHEN** an authenticated user views a species detail page
- **THEN** a "Make Synonym Of..." button is displayed
- **AND** clicking the button opens a species picker dialog

#### Scenario: Select target species
- **WHEN** the species picker dialog is open
- **THEN** the user can search for species by name
- **AND** the current species (synonym) is excluded from results
- **AND** results show: species name, author, section, hybrid indicator
- **AND** selecting a species and confirming navigates to the merge screen

#### Scenario: Cancel species selection
- **WHEN** the species picker dialog is open
- **AND** the user clicks Cancel or closes the dialog
- **THEN** no changes are made
- **AND** the user remains on the species detail page

#### Scenario: Prevent self-synonymization
- **WHEN** the user attempts to select the current species as the target
- **THEN** the selection is blocked
- **AND** an error message explains that a species cannot be a synonym of itself

#### Scenario: Prevent circular synonymization
- **WHEN** the user attempts to select a target species that already has the current species in its synonyms array
- **THEN** the selection is blocked
- **AND** an error message explains that circular synonyms are not allowed

### Requirement: Reference Search API

The API SHALL provide an endpoint to find species that reference a given name in relationship fields.

#### Scenario: Search for references
- **WHEN** a client requests `GET /api/v1/species/references?name={name}`
- **THEN** the API returns species where `parent1`, `parent2`, `hybrids`, or `closely_related_to` contains the given name

#### Scenario: No references found
- **WHEN** a client requests the references endpoint with a name that has no references
- **THEN** the API returns an empty array

### Requirement: Synonym URL Redirect

The API SHALL support redirecting requests for synonym names to the canonical species.

#### Scenario: Fetch species that is a synonym
- **WHEN** a client requests `GET /api/v1/species/{name}` for a name that doesn't exist as a species
- **AND** that name appears in the synonyms array of exactly one other species
- **THEN** the API returns HTTP 404 with `{ "synonym_of": "target_species_name" }`

#### Scenario: Fetch species that is an ambiguous synonym
- **WHEN** a client requests `GET /api/v1/species/{name}` for a name that doesn't exist as a species
- **AND** that name appears in the synonyms array of multiple species
- **THEN** the API returns HTTP 404 with `{ "ambiguous_synonym": true, "matches": ["species1", "species2", ...] }`

#### Scenario: Client handles redirect
- **WHEN** the web client receives a 404 response with `synonym_of` field
- **THEN** it performs a client-side redirect using `goto()` with `replaceState: true`
- **AND** the user sees the target species page

#### Scenario: Client handles ambiguous synonym
- **WHEN** the web client receives a 404 response with `ambiguous_synonym` field
- **THEN** it displays a disambiguation UI showing the list of matching species
- **AND** the user can select which species they meant

#### Scenario: True 404
- **WHEN** a client requests a species that does not exist
- **AND** that name does not appear as a synonym anywhere
- **THEN** the API returns a standard 404 error

### Requirement: Search Includes Synonyms

The species search SHALL match against synonyms in addition to species names.

#### Scenario: Search matches synonym
- **WHEN** a client searches for species with a query that matches a synonym
- **THEN** the species containing that synonym is included in results
- **AND** the result includes `matched_via_synonym: "synonym_name"` to indicate the match type

#### Scenario: Web displays synonym match indicator
- **WHEN** search results include a species matched via synonym
- **THEN** the UI indicates the search term was matched via synonym

### Requirement: Merge Screen Route

The merge screen SHALL be accessible via a dedicated route to support complex editing and browser navigation.

#### Scenario: Navigate to merge screen
- **WHEN** the user confirms target selection in the picker
- **THEN** the browser navigates to `/species/{synonym}/merge/{target}`
- **AND** the merge screen is displayed

#### Scenario: Direct URL access
- **WHEN** a user navigates directly to `/species/{synonym}/merge/{target}`
- **AND** both species exist
- **THEN** the merge screen is displayed with data for both species

#### Scenario: Merge page with missing synonym
- **WHEN** a user navigates to a merge URL where the synonym no longer exists
- **AND** the synonym was already merged (appears as synonym of another species)
- **THEN** the user is redirected to the target species page

#### Scenario: Invalid merge URL
- **WHEN** a user navigates to a merge URL where either species does not exist
- **AND** no redirect is available
- **THEN** an error message is displayed
- **AND** the user can navigate back to safety

### Requirement: Merge Screen Display

The merge screen SHALL display synonym and target species data side-by-side, allowing the user to review and customize the merged result before saving.

#### Scenario: Two-column layout
- **WHEN** the merge screen is displayed
- **THEN** synonym data appears in the left column (read-only)
- **AND** target data appears in the right column (editable)
- **AND** a header shows the merge direction (e.g., "Merge: x asheana -> x ashei")

#### Scenario: Species-level field comparison
- **WHEN** both synonym and target have values for a scalar field
- **THEN** both values are displayed
- **AND** a copy button allows copying the synonym value to the target field
- **AND** the target field is editable for manual adjustment

#### Scenario: Auto-populate empty target fields
- **WHEN** the synonym has a value for a field but the target does not
- **THEN** the synonym value is automatically copied to the target field
- **AND** the field remains editable for adjustment

#### Scenario: Array field union merge
- **WHEN** both synonym and target have values for an array field (subspecies_varieties, external_links)
- **THEN** the values are combined using union (deduplicated)
- **AND** deduplication is case-insensitive for taxonomic names (subspecies_varieties) and case-sensitive for URLs (external_links)
- **AND** the user can manually edit the result

#### Scenario: Synonym array merging
- **WHEN** the merge screen is displayed
- **THEN** a preview shows all names that will be added to target's synonyms
- **AND** this includes the synonym species name plus any existing synonyms from the synonym species
- **AND** duplicates are detected case-insensitively and marked as "already exists"

#### Scenario: is_hybrid excluded
- **WHEN** the merge screen is displayed
- **THEN** the `is_hybrid` field is not shown or editable
- **AND** this is because it is derived from the `x` prefix in the species name

### Requirement: Complete Field Merging

The merge screen SHALL support merging ALL species-level fields, not just a subset.

#### Scenario: Scalar fields
- **WHEN** the merge screen is displayed
- **THEN** the following scalar fields are available for merging: author, conservation_status, subgenus, section, subsection, complex, parent1, parent2

#### Scenario: Array fields
- **WHEN** the merge screen is displayed
- **THEN** array fields are available for merging with union behavior: synonyms, subspecies_varieties, external_links

#### Scenario: Informational fields
- **WHEN** the merge screen is displayed
- **THEN** the hybrids and closely_related_to arrays are shown for reference
- **AND** these are updated via reference updates, not direct merge

### Requirement: Source Data Merging

The merge screen SHALL display source-attributed data from both species, allowing per-source field merging.

#### Scenario: Source present in both species
- **WHEN** a source has data for both the synonym and the target
- **THEN** a collapsible section displays field-by-field comparison for that source
- **AND** all source fields are available: local_names (array, union merge), range, growth_habit, leaves, flowers, fruits, bark, twigs, buds, hardiness_habitat, miscellaneous, url
- **AND** is_preferred is NOT available for merge (target's value is preserved)
- **AND** the same copy/auto-populate behavior applies as for species-level fields

#### Scenario: Source present only in synonym
- **WHEN** a source has data for the synonym but not the target
- **THEN** the section displays the synonym data in read-only preview
- **AND** a checkbox (default checked) controls whether to include this source in the merge
- **AND** if included, a new species-source record will be created on the target (with is_preferred: false)

#### Scenario: Source present only in target
- **WHEN** a source has data for the target but not the synonym
- **THEN** the section displays the target data for reference
- **AND** no changes are needed for this source

### Requirement: Data Loss Warning

The merge screen SHALL warn users about synonym data that will not be transferred.

#### Scenario: Display warning for unchecked sources
- **WHEN** the user has unchecked synonym-only sources
- **THEN** a warning section displays the source names that will be lost
- **AND** the warning updates dynamically as the user toggles checkboxes

#### Scenario: No warning for kept target values
- **WHEN** the user has not copied a differing synonym value (kept target's value)
- **THEN** no warning is displayed for that field
- **AND** this is because the target's existing value is being preserved, not lost

#### Scenario: No data loss
- **WHEN** all synonym-only sources are checked for inclusion
- **THEN** no data loss warning is displayed

### Requirement: Self-Reference Warning

The merge screen SHALL warn users when the merge would create self-referential data.

#### Scenario: Target references synonym in hybrids
- **WHEN** the target species' hybrids array contains the synonym name
- **THEN** a warning is displayed explaining this would create a self-reference
- **AND** the user can edit the hybrids array before saving

#### Scenario: Target references synonym in closely_related_to
- **WHEN** the target species' closely_related_to array contains the synonym name
- **THEN** a warning is displayed explaining this would create a self-reference
- **AND** the user can edit the closely_related_to array before saving

#### Scenario: Target has synonym as parent
- **WHEN** the target species' parent1 or parent2 equals the synonym name
- **THEN** a warning is displayed explaining this would make the target its own parent
- **AND** the user can clear the parent field before saving

### Requirement: Reference Updates

The system SHALL update other species that reference the synonym in their relationship fields.

#### Scenario: Display affected species
- **WHEN** the synonym is referenced in other species' parent1, parent2, hybrids, or closely_related_to fields
- **THEN** an informational section lists which species will be updated
- **AND** the section groups references by type (parents, hybrids, closely related)

#### Scenario: Update parent references
- **WHEN** the merge is saved
- **AND** other species have the synonym as parent1 or parent2
- **THEN** those parent fields are updated to the target species name

#### Scenario: Update hybrids references
- **WHEN** the merge is saved
- **AND** other species reference the synonym in their hybrids array
- **THEN** those references are updated to the target species name

#### Scenario: Update closely_related_to references
- **WHEN** the merge is saved
- **AND** other species reference the synonym in their closely_related_to array
- **THEN** those references are updated to the target species name

### Requirement: Merge Save Operation

Saving the merge SHALL update the target species, transfer source data, update references, add the synonym as a synonym, and delete the synonym species.

#### Scenario: Successful merge save
- **WHEN** the user clicks Save and confirms the action
- **THEN** the target species is updated with the merged field values
- **AND** the synonym name and its synonyms are added to the target's synonyms (case-insensitive deduplication)
- **AND** source data selected for inclusion is transferred to the target
- **AND** other species referencing the synonym are updated
- **AND** the synonym species is deleted (MUST be final operation)
- **AND** a success message is displayed
- **AND** the user is redirected to the target species page using replaceState

#### Scenario: Save confirmation dialog
- **WHEN** the user clicks Save
- **THEN** a confirmation dialog lists all changes that will be made
- **AND** the dialog shows how many other species will be updated
- **AND** the dialog warns that the synonym species will be deleted
- **AND** the dialog states "This action cannot be undone"
- **AND** the user must explicitly confirm to proceed

#### Scenario: Partial failure during save
- **WHEN** an error occurs during the merge save operation
- **THEN** an error message displays which steps succeeded and which failed
- **AND** the user is informed they can fix the issue manually or refresh and start over
- **AND** no automatic retry is attempted
- **AND** if delete has not yet executed, the synonym still exists for retry

### Requirement: Merge Cancel Operation

Canceling the merge SHALL discard all changes and return to the synonym species page.

#### Scenario: Cancel with no changes
- **WHEN** the user clicks Cancel without modifying any fields
- **THEN** the user is navigated back to the synonym species detail page

#### Scenario: Cancel with unsaved changes
- **WHEN** the user clicks Cancel after modifying fields (user-initiated edits only, not auto-populated values)
- **THEN** a confirmation dialog asks to discard changes
- **AND** confirming navigates back to the synonym species page
- **AND** declining keeps the merge screen open

