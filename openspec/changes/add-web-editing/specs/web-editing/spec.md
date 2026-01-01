# web-editing Specification

## Purpose

Enable authenticated CRUD operations in the Oak Compendium web application using API key authentication.

## ADDED Requirements

### Requirement: API Key Authentication

The web application SHALL provide a mechanism for users to authenticate using an API key to enable write operations.

#### Scenario: Enter valid API key
- **WHEN** user navigates to Settings page
- **AND** enters a valid API key
- **AND** clicks Save
- **THEN** key is validated against `/api/v1/auth/verify`
- **AND** key is stored in localStorage
- **AND** admin mode is activated
- **AND** success message is displayed

#### Scenario: Enter invalid API key
- **WHEN** user enters an invalid API key
- **AND** clicks Save
- **THEN** verification fails
- **AND** key is not stored
- **AND** error message is displayed

#### Scenario: Clear API key (logout)
- **WHEN** user clicks Logout on Settings page
- **THEN** key is removed from localStorage
- **AND** admin mode is deactivated
- **AND** edit UI elements are hidden

#### Scenario: Admin mode indicator
- **WHEN** user has valid API key stored
- **THEN** Header displays admin mode indicator
- **AND** edit buttons are visible on detail pages

#### Scenario: Session persistence
- **WHEN** user closes and reopens browser
- **AND** API key was previously stored
- **THEN** admin mode is restored automatically

### Requirement: Species Editing

The web application SHALL allow authenticated users to create, update, and delete species entries.

#### Scenario: Edit existing species
- **WHEN** authenticated user views species detail
- **AND** clicks Edit button
- **THEN** edit form modal opens with current data
- **AND** user can modify fields
- **AND** clicking Save sends PUT request to API
- **AND** species detail refreshes with updated data

#### Scenario: Create new species
- **WHEN** authenticated user clicks "Add Species" on list page
- **THEN** create form modal opens
- **AND** user enters species data
- **AND** clicking Save sends POST request to API
- **AND** new species appears in list

#### Scenario: Delete species
- **WHEN** authenticated user clicks Delete on species detail
- **THEN** confirmation dialog appears showing species name and source data count
- **AND** dialog warns "This will also remove data from X sources"
- **AND** confirming sends DELETE request to API
- **AND** user is redirected to species list
- **AND** species is removed from list

#### Scenario: Edit validation error
- **WHEN** user submits edit form with invalid data
- **THEN** API returns 400 with field errors
- **AND** form displays field-level error messages
- **AND** modal remains open for correction

### Requirement: Species-Source Editing

The web application SHALL allow authenticated users to manage source-attributed data for any source associated with a species. This is a core feature - each species can have data from multiple sources, and users must be able to edit any source's data.

#### Scenario: Edit button per source tab
- **WHEN** authenticated user views species detail
- **THEN** each source tab displays an Edit button
- **AND** Edit button is specific to that source's data

#### Scenario: Edit source data for displayed source
- **WHEN** authenticated user views a source tab (e.g., "Oaks of the World")
- **AND** clicks Edit on that tab
- **THEN** form opens pre-filled with THAT source's data (leaves, range, local_names, etc.)
- **AND** form clearly indicates which source is being edited
- **AND** saving sends PUT to `/api/v1/species/{name}/sources/{source_id}`
- **AND** source tab refreshes with updated data

#### Scenario: Add source data from new source
- **WHEN** authenticated user views species detail
- **AND** clicks "Add Source Data"
- **THEN** form opens with source selector dropdown
- **AND** dropdown shows sources not yet associated with this species
- **AND** user selects source and enters data
- **AND** saving sends POST to `/api/v1/species/{name}/sources`
- **AND** new source tab appears in species detail

#### Scenario: Delete source data
- **WHEN** authenticated user clicks Delete on a source tab
- **AND** confirms deletion
- **THEN** DELETE request removes that source's data for this species
- **AND** source tab is removed from display

### Requirement: Taxa Editing

The web application SHALL allow authenticated users to create, update, and delete taxa entries.

#### Scenario: Edit taxon
- **WHEN** authenticated user views taxon in taxonomy browser
- **AND** clicks Edit
- **THEN** edit form opens with current data
- **AND** user can modify name, parent, author, notes
- **AND** saving sends PUT to `/api/v1/taxa/{level}/{name}`

#### Scenario: Create taxon
- **WHEN** authenticated user clicks "Add Taxon" in taxonomy browser
- **THEN** create form opens
- **AND** user selects level and enters data
- **AND** saving sends POST to `/api/v1/taxa`

#### Scenario: Delete taxon
- **WHEN** authenticated user deletes a taxon
- **AND** confirms deletion
- **THEN** DELETE request removes taxon
- **AND** taxonomy view refreshes

### Requirement: Sources Editing

The web application SHALL allow authenticated users to create, update, and delete source entries.

#### Scenario: Edit source
- **WHEN** authenticated user views source detail
- **AND** clicks Edit
- **THEN** edit form opens with current data
- **AND** saving sends PUT to `/api/v1/sources/{id}`

#### Scenario: Create source
- **WHEN** authenticated user clicks "Add Source" on sources page
- **THEN** create form opens
- **AND** saving sends POST to `/api/v1/sources`

#### Scenario: Delete source
- **WHEN** authenticated user deletes a source
- **AND** confirms deletion
- **THEN** DELETE request removes source
- **AND** source is removed from list

### Requirement: Delete Confirmation

The web application SHALL require explicit confirmation before executing any delete operation.

#### Scenario: Delete confirmation required
- **WHEN** authenticated user initiates any delete operation (species, taxon, source, species-source)
- **THEN** confirmation dialog appears before the delete is executed
- **AND** dialog clearly identifies what will be deleted
- **AND** user must explicitly confirm to proceed
- **AND** cancel returns user to previous state without changes

#### Scenario: Delete confirmation shows cascade effects
- **WHEN** deletion would cascade to related data
- **THEN** confirmation dialog warns about cascade effects
- **AND** dialog shows count of related records that will be deleted

### Requirement: Error Handling

The web application SHALL gracefully handle authentication and API errors during write operations.

#### Scenario: Session expired (401)
- **WHEN** API returns 401 during write operation
- **THEN** stored API key is cleared
- **AND** admin mode is deactivated
- **AND** user is prompted to re-authenticate

#### Scenario: Network error
- **WHEN** network request fails during write operation
- **THEN** error message is displayed
- **AND** form data is preserved
- **AND** user can retry

#### Scenario: Server error (500)
- **WHEN** API returns 500 during write operation
- **THEN** generic error message is displayed
- **AND** form data is preserved
- **AND** user can retry

### Requirement: Data Consistency

The web application SHALL maintain data consistency between local state and server after write operations.

#### Scenario: Refresh after create
- **WHEN** species/taxon/source is created successfully
- **THEN** local data is refreshed from API
- **AND** new entity appears in relevant lists

#### Scenario: Refresh after update
- **WHEN** entity is updated successfully
- **THEN** detail view shows updated data
- **AND** list views reflect changes

#### Scenario: Refresh after delete
- **WHEN** entity is deleted successfully
- **THEN** entity is removed from all views
- **AND** user is navigated away from deleted entity

### Requirement: Offline Behavior

The web application SHALL disable editing when offline and handle connection changes gracefully.

#### Scenario: Edit buttons hidden when offline
- **WHEN** user is not connected to network
- **AND** user is authenticated
- **THEN** edit/create/delete buttons are hidden or disabled
- **AND** tooltip indicates "Editing requires internet connection"

#### Scenario: Connection lost during edit
- **WHEN** user has edit form open
- **AND** network connection is lost
- **THEN** submit button is disabled
- **AND** warning message appears "Connection lost. Your changes are preserved."
- **AND** form data is retained

#### Scenario: Connection restored during edit
- **WHEN** user has edit form open with preserved data
- **AND** network connection is restored
- **THEN** submit button is re-enabled
- **AND** warning message is cleared
- **AND** user can submit the form

#### Scenario: API unavailable while online
- **WHEN** user is connected to network
- **AND** API health check fails
- **THEN** edit buttons are disabled
- **AND** message indicates "API server unavailable"

### Requirement: Rate Limit Handling

The web application SHALL handle API rate limiting gracefully.

#### Scenario: Rate limit exceeded
- **WHEN** API returns 429 Too Many Requests
- **THEN** error message displays "Too many requests. Please wait a moment and try again."
- **AND** submit button is disabled
- **AND** form data is preserved
- **AND** button re-enables after Retry-After duration

### Requirement: Success Feedback

The web application SHALL provide clear feedback when operations succeed.

#### Scenario: Edit success notification
- **WHEN** species/taxon/source is updated successfully
- **THEN** toast notification appears "Species updated successfully"
- **AND** notification auto-dismisses after 3 seconds

#### Scenario: Create success notification
- **WHEN** species/taxon/source is created successfully
- **THEN** toast notification appears "[Entity] created successfully"
- **AND** notification auto-dismisses after 3 seconds

#### Scenario: Delete success notification
- **WHEN** species/taxon/source is deleted successfully
- **THEN** toast notification appears "[Entity] deleted"
- **AND** notification auto-dismisses after 3 seconds

### Requirement: Validation Error Display

The web application SHALL display validation errors clearly to help users correct their input.

#### Scenario: Single field validation error
- **WHEN** API returns validation error for one field
- **THEN** error message appears below the field
- **AND** field is highlighted with error styling

#### Scenario: Multiple field validation errors
- **WHEN** API returns validation errors for multiple fields
- **THEN** error summary appears at top of form
- **AND** each field shows its specific error below the input
- **AND** form scrolls to first error
