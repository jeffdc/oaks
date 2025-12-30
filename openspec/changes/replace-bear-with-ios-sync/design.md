## Context

The Oak Compendium project uses a multi-source data model where species information comes from iNaturalist (taxonomy), Oaks of the World (descriptions), and personal observations (field notes). Personal observations currently flow through Bear app, which is suboptimal for structured data capture.

The iOS app is being developed to provide a native field note experience. This change defines how the iOS app syncs with the central database via the API server (see OpenSpec change `add-crud-api-server`).

### Stakeholders
- Primary user (Jeff): Field note capture on iOS, data management on macOS CLI
- Future users: Multi-client access via API

### Constraints
- Single-user system (no multi-tenancy initially)
- API server runs locally or on simple hosting (Fly.io, Railway, etc.)
- iOS app must work offline with sync when online
- Source attribution must be preserved (source_id 3 = personal observation)

## Goals / Non-Goals

### Goals
- Real-time sync between iOS app and database via API
- iOS app can browse full species data from API
- iOS app can create/edit/delete notes with server persistence
- Offline support with automatic background sync
- Simple authentication (API key initially)

### Non-Goals
- Multi-user support (single user, single API key)
- Complex auth (OAuth, social login)
- Real-time WebSocket updates
- Photo sync to server (photos stay on device initially)

## Decisions

### Decision 1: API-based sync over file-based sync

**What**: iOS app communicates with `oak serve` API server instead of file export/import.

**Why**:
- Real-time sync without manual export/import steps
- Central database is always authoritative
- Enables future web app migration from static JSON
- Builds on `add-crud-api-server` OpenSpec change

**Alternatives considered**:
- File-based JSON export/import: Simpler but requires manual sync steps
- iCloud CloudKit: Apple-specific, complex bidirectional sync
- Direct SQLite file sharing: Conflict-prone, requires file transfer

### Decision 2: Notes API endpoints

**Relationship to species-sources**: The notes API is a convenience layer over the `species_sources` table, specifically for personal observations (source_id 3). While the CRUD API provides generic `/api/v1/species/:name/sources/:sourceId` endpoints, the notes API provides:
- UUID-based access (better for iOS sync)
- Simplified field names matching the iOS UI
- Automatic source_id 3 assignment
- Filters for quick access to personal notes only

Under the hood, `/api/notes` operations map to `species_sources` table rows with `source_id = 3`.

**Endpoints** (building on `add-crud-api-server` spec):

```
GET    /api/v1/notes              # List all notes (with optional filters)
GET    /api/v1/notes/:id          # Get single note by ID
POST   /api/v1/notes              # Create new note
PUT    /api/v1/notes/:id          # Update existing note
DELETE /api/v1/notes/:id          # Delete note
```

**Note payload**:
```json
{
  "id": "uuid",
  "scientificName": "alba",
  "taxonomy": {
    "subgenus": "Quercus",
    "section": "Quercus",
    "subsection": null,
    "complex": null
  },
  "fields": {
    "commonNames": "White oak",
    "leaf": "5-9 rounded lobes...",
    "acorn": "Shallow cup...",
    "bark": "Light gray, scaly...",
    "twigs": "Stout, reddish-brown...",
    "buds": "Clustered at twig tips...",
    "form": "Large spreading crown...",
    "rangeHabitat": "Eastern North America...",
    "fieldNotes": "Observed at...",
    "resources": "..."
  },
  "sourceId": 3,
  "createdAt": "2025-01-10T14:20:00Z",
  "updatedAt": "2025-01-15T09:00:00Z"
}
```

### Decision 3: iOS offline support

**Strategy**: Cache-first with background sync

1. **Read path**:
   - Check local cache first
   - Fetch from API if cache miss or stale
   - Update cache with API response

2. **Write path**:
   - Write to local cache immediately
   - Queue API request
   - Sync in background when online
   - Retry failed requests with exponential backoff

3. **Conflict resolution**: Last-write-wins (acceptable for single user)

**Implementation**:
- `StorageService` becomes cache layer
- New `APIService` handles network requests
- New `SyncService` manages queue and background sync

### Decision 4: Authentication

**What**: API key authentication for write operations only (consistent with CRUD API spec)

**Implementation**:
- Server generates API key on first run, stores in config
- iOS app stores API key in Keychain
- Write requests (POST, PUT, DELETE) include `Authorization: Bearer <api-key>` header
- Read requests (GET) do not require authentication
- Server validates key on write operations only

**Why this model**:
- Consistent with `add-crud-api-server` design decisions
- Read operations are public (species data is not sensitive)
- Write protection prevents unauthorized data modification
- Single user, no need for complex user management
- Can upgrade to proper auth later if needed

### Decision 5: Field mapping (iOS ↔ API ↔ Database)

| iOS Field | API Field | DB Column (species_sources) |
|-----------|-----------|----------------------------|
| commonNames | commonNames | local_names |
| leaf | leaf | leaves |
| acorn | acorn | fruits |
| bark | bark | bark |
| twigs | twigs | twigs |
| buds | buds | buds |
| form | form | growth_habit |
| rangeHabitat | rangeHabitat | range |
| fieldNotes | fieldNotes | miscellaneous |
| resources | resources | url |

**Note**: API uses iOS field names for consistency. Server maps to DB columns internally. The database has separate columns for `bark`, `twigs`, and `buds` (as well as legacy `bark_twigs_buds` which is deprecated).

### Decision 6: Photo handling

**What**: Photos remain on iOS device, not synced to API.

**Why**:
- Simplifies initial implementation
- Photos are primarily useful on mobile
- Can add photo upload endpoint later

**Future**: Add `POST /api/notes/:id/photos` for photo upload with cloud storage.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| API server unavailable | Offline mode with local cache, sync when back online |
| Data loss during Bear→iOS migration | Document migration steps, keep Bear import temporarily |
| Network latency affects UX | Optimistic UI updates, background sync |
| API key compromise | Can regenerate key, single user limits blast radius |

## Migration Plan

1. **Phase 1**: Implement API server (`add-crud-api-server` OpenSpec change)
2. **Phase 2**: Update iOS app to use API (this change)
3. **Phase 3**: Run `oak import-bear --full` one final time
4. **Phase 4**: Remove Bear commands from CLI
5. **Rollback**: Bear commands can be restored from git if needed

### Migration steps for Bear users
1. Deploy API server
2. Run `oak import-bear --full` to ensure all Bear notes are in database
3. iOS app now reads from API
4. Recreate any in-progress Bear notes in iOS app
5. Bear commands are removed in subsequent release

## Open Questions

_All questions resolved._

**Resolved: Where to host API server?**
- **Decision**: Fly.io (as specified in `add-crud-api-server` design)
- **Rationale**: Simple deployment, free tier, persistent volumes for SQLite, automatic TLS

**Resolved: Should we add sync status indicator in iOS app?**
- **Decision**: Yes
- **Rationale**: Users need visibility into sync state, especially for offline scenarios
- **Action**: Task 2.8 covers implementing sync status UI indicator

**Resolved: Do we want conflict detection (vs pure last-write-wins)?**
- **Decision**: Last-write-wins with no conflict detection (initially)
- **Rationale**: Single user system - conflicts are unlikely. Simpler implementation. Can add conflict detection later if needed.
