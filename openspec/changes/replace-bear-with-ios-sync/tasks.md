## 1. API Notes Endpoints (builds on oaks-doc9)

- [ ] 1.1 Add notes routes to API server (`/api/notes`)
- [ ] 1.2 Implement GET /api/notes (list with filters)
- [ ] 1.3 Implement GET /api/notes/:id (single note)
- [ ] 1.4 Implement POST /api/notes (create)
- [ ] 1.5 Implement PUT /api/notes/:id (update)
- [ ] 1.6 Implement DELETE /api/notes/:id (delete)
- [ ] 1.7 Add field mapping layer (API fields ↔ DB columns)
- [ ] 1.8 Write API tests for notes endpoints

## 2. iOS API Integration (builds on oaks-0ps1)

- [ ] 2.1 Create `APIService.swift` with base networking
- [ ] 2.2 Implement notes API client methods
- [ ] 2.3 Add API key storage in Keychain
- [ ] 2.4 Create `SyncService.swift` for background sync
- [ ] 2.5 Implement offline queue for pending writes
- [ ] 2.6 Update `NotesViewModel` to use APIService
- [ ] 2.7 Add network status monitoring
- [ ] 2.8 Add sync status UI indicator

## 3. iOS Offline Caching

- [ ] 3.1 Modify `StorageService` to act as cache layer
- [ ] 3.2 Implement cache invalidation strategy
- [ ] 3.3 Add background sync on app foreground
- [ ] 3.4 Handle conflict resolution (last-write-wins)
- [ ] 3.5 Test offline → online transitions

## 4. Remove Bear Integration

- [ ] 4.1 Delete `cmd/import_bear.go`
- [ ] 4.2 Delete `cmd/generate_bear_notes.go`
- [ ] 4.3 Remove Bear-related metadata key from database
- [ ] 4.4 Remove Bear references from root.go init

## 5. Documentation Updates

- [ ] 5.1 Update CLAUDE.md data flow diagram
- [ ] 5.2 Remove Bear workflow documentation
- [ ] 5.3 Add API-based sync workflow documentation
- [ ] 5.4 Update project.md with new architecture
- [ ] 5.5 Add migration guide for Bear users
- [ ] 5.6 Document API endpoints in cli/docs/

## 6. Testing

- [ ] 6.1 Integration tests for notes API
- [ ] 6.2 iOS unit tests for APIService
- [ ] 6.3 iOS unit tests for SyncService
- [ ] 6.4 End-to-end sync scenario tests
