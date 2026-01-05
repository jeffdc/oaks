# Tasks: Consolidate Database Code

## 1. Fix Critical Bug First
- [x] 1.1 Port bidirectional relationship management from CLI to API's `SaveOakEntry()`
- [x] 1.2 Add transaction support to API's `SaveOakEntry()`
- [x] 1.3 Port `getOakEntryTx()`, `addHybridToParentTx()`, `removeHybridFromParentTx()` to API
- [x] 1.4 Add tests for bidirectional relationship management in API
- [x] 1.5 Verify existing hybrids have correct parent references (data audit)

## 2. Implement Embedded API Mode
- [x] 2.1 Create `cli/internal/embedded/` package
- [x] 2.2 Implement embedded API server startup (localhost-only)
- [x] 2.3 Add `--local` flag behavior: start embedded API, use client, shutdown
- [x] 2.4 Ensure embedded mode uses same auth bypass as current local mode
- [x] 2.5 Test embedded mode with all CLI commands

## 3. Enhance CLI Client
- [x] 3.1 Add retry logic for transient failures
- [x] 3.2 Test client with mock server

## 4. Migrate CLI Commands to Client-Only
- [x] 4.1 Update `oak new` to use client
- [x] 4.2 Update `oak edit` to use client
- [x] 4.3 Update `oak delete` to use client
- [x] 4.4 Update `oak find` to use client
- [x] 4.5 Update `oak export` to use client
- [x] 4.6 Update `oak source` commands to use client
- [x] 4.7 Update remaining non-bulk commands to use client

## 5. Remove Duplicate Code (Non-Bulk)
- [x] 5.1 Identify which db functions are only used by bulk commands
- [x] 5.2 Delete duplicated non-bulk functions from `cli/internal/db/`
- [x] 5.3 Delete `cli/internal/models/` (use API's models via client responses)
- [x] 5.4 Update CLI imports
- [x] 5.5 Run `go mod tidy` in cli/
- [x] 5.6 Verify CLI builds and tests pass

## 6. Testing
- [x] 6.1 Add integration tests for embedded API mode
- [x] 6.2 Add integration tests for remote API mode
- [x] 6.3 Test bidirectional relationship consistency
- [x] 6.4 Run full test suite

## 7. Documentation
- [x] 7.1 Update CLAUDE.md architecture diagram
- [x] 7.2 Update CLI README with embedded vs remote modes
- [x] 7.3 Remove references to CLI's internal db package (where applicable)

## 8. Cleanup
- [x] 8.1 Review for any remaining duplication
- [x] 8.2 Final code review
- [x] 8.3 Verify all tests pass

---

## Deferred: Bulk Operations (Low Priority)

These tasks enable full removal of `cli/internal/db/` but are deferred since bulk imports are rare.

### D1. Add Bulk API Endpoints
- [x] D1.1 Add bulk species import endpoint (`POST /api/v1/species/bulk`)
- [x] D1.2 Add bulk taxa import endpoint (`POST /api/v1/taxa/bulk`)
- [x] D1.3 Add transaction support to bulk endpoints
- [x] D1.4 Test bulk endpoints with large datasets

### D2. Migrate Bulk CLI Commands
- [x] D2.1 Add bulk import methods to `cli/internal/client/`
- [x] D2.2 Implement progress reporting for bulk operations
- [x] D2.3 Update `oak import-bulk` to use client with bulk endpoint
- [x] D2.4 Update `oak taxa import` to use client with bulk endpoint
- [x] D2.5 Test bulk import performance (compare to old direct DB)

### D3. Complete Code Removal
- [x] D3.1 Delete remaining `cli/internal/db/` code
- [x] D3.2 Document bulk import endpoints in API docs
- [x] D3.3 Final verification all CLI commands work via client
