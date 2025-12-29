## ADDED Requirements

### Requirement: Notes API Endpoints

The API server SHALL provide CRUD endpoints for managing species notes.

#### Scenario: List all notes
- **WHEN** client sends GET /api/notes
- **THEN** server returns array of all notes with 200 status
- **AND** each note includes id, scientificName, taxonomy, fields, sourceId, createdAt, updatedAt

#### Scenario: List notes with species filter
- **WHEN** client sends GET /api/notes?species=alba
- **THEN** server returns only notes matching the species name

#### Scenario: Get single note
- **WHEN** client sends GET /api/notes/:id with valid UUID
- **THEN** server returns the note with 200 status

#### Scenario: Get non-existent note
- **WHEN** client sends GET /api/notes/:id with unknown UUID
- **THEN** server returns 404 status with error message

#### Scenario: Create note
- **WHEN** client sends POST /api/notes with valid note payload
- **THEN** server creates the note in species_sources table
- **AND** returns the created note with assigned ID and 201 status

#### Scenario: Create note for unknown species
- **WHEN** client sends POST /api/notes with species not in oak_entries
- **THEN** server returns 400 status with error message

#### Scenario: Update note
- **WHEN** client sends PUT /api/notes/:id with updated fields
- **THEN** server updates the note and returns 200 status
- **AND** updatedAt timestamp is set to current time

#### Scenario: Delete note
- **WHEN** client sends DELETE /api/notes/:id
- **THEN** server removes the note and returns 204 status

---

### Requirement: iOS API Service

The iOS app SHALL communicate with the API server via a dedicated APIService.

#### Scenario: Fetch notes from server
- **WHEN** app needs to display notes list
- **THEN** APIService fetches from GET /api/notes
- **AND** results are cached locally for offline access

#### Scenario: Create note via API
- **WHEN** user creates a new note in the app
- **THEN** APIService sends POST /api/notes
- **AND** local cache is updated with server response

#### Scenario: Update note via API
- **WHEN** user edits an existing note
- **THEN** APIService sends PUT /api/notes/:id
- **AND** local cache is updated with server response

#### Scenario: Delete note via API
- **WHEN** user deletes a note
- **THEN** APIService sends DELETE /api/notes/:id
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

### Requirement: API Authentication

The API server SHALL require authentication for all endpoints except health check.

#### Scenario: Valid API key
- **WHEN** request includes valid Authorization: Bearer header
- **THEN** request is processed normally

#### Scenario: Missing API key
- **WHEN** request is missing Authorization header
- **THEN** server returns 401 Unauthorized

#### Scenario: Invalid API key
- **WHEN** request includes invalid Authorization header
- **THEN** server returns 401 Unauthorized

#### Scenario: Health check without auth
- **WHEN** client sends GET /api/health without Authorization
- **THEN** server returns 200 status (health check is public)

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
  | bark | bark_twigs_buds |
  | buds | bark_twigs_buds |
  | form | growth_habit |
  | rangeHabitat | range |
  | fieldNotes | miscellaneous |
  | resources | miscellaneous (appended) |

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
