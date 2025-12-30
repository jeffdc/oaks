# Tasks: Consolidate Database Code

## 1. Fix Critical Bug First
- [ ] 1.1 Port bidirectional relationship management from CLI to API's `SaveOakEntry()`
- [ ] 1.2 Add transaction support to API's `SaveOakEntry()`
- [ ] 1.3 Port `getOakEntryTx()`, `addHybridToParentTx()`, `removeHybridFromParentTx()` to API
- [ ] 1.4 Add tests for bidirectional relationship management in API
- [ ] 1.5 Verify existing hybrids have correct parent references (data audit)

## 2. Implement Embedded API Mode
- [ ] 2.1 Create `cli/internal/embedded/` package
- [ ] 2.2 Implement embedded API server startup (localhost-only)
- [ ] 2.3 Add `--local` flag behavior: start embedded API, use client, shutdown
- [ ] 2.4 Ensure embedded mode uses same auth bypass as current local mode
- [ ] 2.5 Test embedded mode with all CLI commands

## 3. Enhance CLI Client
- [ ] 3.1 Add retry logic for transient failures
- [ ] 3.2 Test client with mock server

## 4. Migrate CLI Commands to Client-Only
- [ ] 4.1 Update `oak new` to use client
- [ ] 4.2 Update `oak edit` to use client
- [ ] 4.3 Update `oak delete` to use client
- [ ] 4.4 Update `oak find` to use client
- [ ] 4.5 Update `oak export` to use client
- [ ] 4.6 Update `oak source` commands to use client
- [ ] 4.7 Update remaining non-bulk commands to use client

## 5. Remove Duplicate Code (Non-Bulk)
- [ ] 5.1 Identify which db functions are only used by bulk commands
- [ ] 5.2 Delete duplicated non-bulk functions from `cli/internal/db/`
- [ ] 5.3 Delete `cli/internal/models/` (use API's models via client responses)
- [ ] 5.4 Update CLI imports
- [ ] 5.5 Run `go mod tidy` in cli/
- [ ] 5.6 Verify CLI builds and tests pass

## 6. Testing
- [ ] 6.1 Add integration tests for embedded API mode
- [ ] 6.2 Add integration tests for remote API mode
- [ ] 6.3 Test bidirectional relationship consistency
- [ ] 6.4 Run full test suite

## 7. Documentation
- [ ] 7.1 Update CLAUDE.md architecture diagram
- [ ] 7.2 Update CLI README with embedded vs remote modes
- [ ] 7.3 Remove references to CLI's internal db package (where applicable)

## 8. Cleanup
- [ ] 8.1 Review for any remaining duplication
- [ ] 8.2 Final code review
- [ ] 8.3 Verify all tests pass

---

## Deferred: Bulk Operations (Low Priority)

These tasks enable full removal of `cli/internal/db/` but are deferred since bulk imports are rare.

### D1. Add Bulk API Endpoints
- [ ] D1.1 Add bulk species import endpoint (`POST /api/v1/species/bulk`)
- [ ] D1.2 Add bulk taxa import endpoint (`POST /api/v1/taxa/bulk`)
- [ ] D1.3 Add transaction support to bulk endpoints
- [ ] D1.4 Test bulk endpoints with large datasets

### D2. Migrate Bulk CLI Commands
- [ ] D2.1 Add bulk import methods to `cli/internal/client/`
- [ ] D2.2 Implement progress reporting for bulk operations
- [ ] D2.3 Update `oak import-bulk` to use client with bulk endpoint
- [ ] D2.4 Update `oak taxa import` to use client with bulk endpoint
- [ ] D2.5 Test bulk import performance (compare to old direct DB)

### D3. Complete Code Removal
- [ ] D3.1 Delete remaining `cli/internal/db/` code
- [ ] D3.2 Document bulk import endpoints in API docs
- [ ] D3.3 Final verification all CLI commands work via client
