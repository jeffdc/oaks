## ADDED Requirements

### Requirement: Notes API Endpoints

The API server SHALL provide CRUD endpoints for managing species notes.

#### Scenario: List all notes
- **WHEN** client sends GET /api/v1/notes
- **THEN** server returns array of all notes with 200 status
- **AND** each note includes id, scientificName, taxonomy, fields, sourceId, createdAt, updatedAt

#### Scenario: List notes with species filter
- **WHEN** client sends GET /api/v1/notes?species=alba
- **THEN** server returns only notes matching the species name

#### Scenario: Get single note
- **WHEN** client sends GET /api/v1/notes/:id with valid UUID
- **THEN** server returns the note with 200 status

#### Scenario: Get non-existent note
- **WHEN** client sends GET /api/v1/notes/:id with unknown UUID
- **THEN** server returns 404 status with error message

#### Scenario: Create note
- **WHEN** client sends POST /api/v1/notes with valid note payload
- **THEN** server creates the note in species_sources table
- **AND** returns the created note with assigned ID and 201 status

#### Scenario: Create note for unknown species
- **WHEN** client sends POST /api/v1/notes with species not in oak_entries
- **THEN** server returns 400 status with error message

#### Scenario: Update note
- **WHEN** client sends PUT /api/v1/notes/:id with updated fields
- **THEN** server updates the note and returns 200 status
- **AND** updatedAt timestamp is set to current time

#### Scenario: Delete note
- **WHEN** client sends DELETE /api/v1/notes/:id
- **THEN** server removes the note and returns 204 status

---

### Requirement: iOS API Service

The iOS app SHALL communicate with the API server via a dedicated APIService.

#### Scenario: Fetch notes from server
- **WHEN** app needs to display notes list
- **THEN** APIService fetches from GET /api/v1/notes
- **AND** results are cached locally for offline access

#### Scenario: Create note via API
- **WHEN** user creates a new note in the app
- **THEN** APIService sends POST /api/v1/notes
- **AND** local cache is updated with server response

#### Scenario: Update note via API
- **WHEN** user edits an existing note
- **THEN** APIService sends PUT /api/v1/notes/:id
- **AND** local cache is updated with server response

#### Scenario: Delete note via API
- **WHEN** user deletes a note
- **THEN** APIService sends DELETE /api/v1/notes/:id
- **AND** note is removed from local cache

---

### Requirement: iOS Offline Support

The iOS app SHALL support offline usage with automatic sync when connectivity is restored.

#### Scenario: Read while offline
- **WHEN** device is offline
- **AND** user views notes list
- **THEN** app displays notes from local cache

#### Scenario: Create while offline
- **WHEN** device is offline
- **AND** user creates a new note
- **THEN** note is saved to local cache
- **AND** note is queued for sync

#### Scenario: Sync on connectivity restore
- **WHEN** device regains connectivity
- **AND** there are pending changes in queue
- **THEN** app syncs pending changes to server in background
- **AND** local cache is updated with server responses

#### Scenario: Conflict resolution
- **WHEN** same note is modified locally and on server
- **THEN** most recent updatedAt timestamp wins (last-write-wins)

---

### Requirement: API Authentication for Notes

The notes API SHALL follow the authentication model defined by the CRUD API (see `add-crud-api-server` spec):
- Read operations (GET) are public
- Write operations (POST, PUT, DELETE) require API key authentication

#### Scenario: Read notes without authentication
- **WHEN** client sends GET /api/v1/notes without Authorization header
- **THEN** request is processed normally
- **AND** notes data is returned

#### Scenario: Write note with valid API key
- **WHEN** client sends POST/PUT/DELETE to /api/v1/notes with valid `Authorization: Bearer <key>` header
- **THEN** request is processed normally

#### Scenario: Write note without API key
- **WHEN** client sends POST/PUT/DELETE to /api/v1/notes without Authorization header
- **THEN** server returns 401 Unauthorized

#### Scenario: Write note with invalid API key
- **WHEN** client sends POST/PUT/DELETE to /api/v1/notes with invalid API key
- **THEN** server returns 401 Unauthorized

---

### Requirement: Field Mapping

The API SHALL map iOS note fields to database columns consistently.

#### Scenario: Field mapping on create/update
- **WHEN** a note is created or updated via API
- **THEN** fields are mapped as follows:
  | API Field | DB Column |
  |-----------|-----------|
  | commonNames | local_names |
  | leaf | leaves |
  | acorn | fruits |
  | bark | bark |
  | twigs | twigs |
  | buds | buds |
  | form | growth_habit |
  | rangeHabitat | range |
  | fieldNotes | miscellaneous |
  | resources | url |

#### Scenario: Source attribution
- **WHEN** a note is created via API
- **THEN** sourceId from request is used (default 3 for personal observation)
- **AND** is_preferred is set to true for source_id 3

---

## REMOVED Requirements

### Requirement: Bear App Import

**Reason**: Replaced by API-based sync with iOS app. The API provides real-time sync without manual import steps, and the iOS app provides better structured data capture than Bear's markdown format.

**Migration**: Users should run `oak import-bear --full` one final time before this removal to ensure all existing notes are in the database.

---

### Requirement: Bear Note Template Generation

**Reason**: No longer needed since iOS app provides structured note entry UI with taxonomy pickers and dedicated field editors.

**Migration**: N/A - this was a helper for creating Bear notes, not needed with iOS app.
