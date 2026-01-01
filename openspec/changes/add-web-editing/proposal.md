# Change: Add Web Editing with API Key Authentication

## Why

The web app is currently read-only. All data editing requires either the CLI tool, direct API calls, or the in-development iOS app. Adding edit capabilities to the web app would:

- Enable quick corrections when browsing species data
- Provide a full CRUD interface accessible from any browser
- Reduce friction for data maintenance tasks
- Complement the iOS app (which focuses on field notes)

The API already supports full CRUD operations with API key auth. This change adds the web UI layer on top.

## What Changes

### Web Application (`web/`)

**Authentication:**
- **ADDED**: Settings page (`/settings/`) with API key input
- **ADDED**: Auth store to manage API key state and persistence
- **ADDED**: Authenticated API client wrapper for write operations
- **ADDED**: "Admin mode" indicator in header when authenticated

**Species Editing:**
- **ADDED**: Edit button on species detail page (visible when authenticated)
- **ADDED**: Species edit form (modal or dedicated page)
- **ADDED**: Delete species with confirmation dialog
- **ADDED**: Create new species form

**Taxa Editing:**
- **ADDED**: Edit/create/delete taxa in taxonomy browser

**Sources Editing:**
- **ADDED**: Edit/create/delete sources in sources page

**Error Handling:**
- **ADDED**: Graceful handling of 401 responses (clear auth, show message)
- **ADDED**: Optimistic updates with rollback on error
- **ADDED**: Loading states for write operations

### API Server (`api/`)
- No changes required - existing API key auth works as-is

## Impact

- **Affected specs**: web-editing (new capability)
- **Affected code**:
  - `web/src/lib/stores/authStore.js` (new)
  - `web/src/lib/apiClient.js` (modify for auth headers)
  - `web/src/routes/settings/+page.svelte` (new)
  - `web/src/lib/components/SpeciesDetail.svelte` (add edit UI)
  - `web/src/lib/components/SpeciesEditForm.svelte` (new)
  - `web/src/lib/components/Header.svelte` (admin indicator)
  - Plus similar changes for taxa and sources
- **Breaking changes**: None - purely additive
- **Security considerations**:
  - API key stored in localStorage (standard for SPAs)
  - Key visible in browser devtools (acceptable for single-user scenario)
  - All writes go over HTTPS to api.oakcompendium.com

## Scope

**All decisions resolved:**
1. ✅ Data model: Option C - minimal fixes + write mapping (no schema changes)
2. ✅ IndexedDB refresh: Full refresh after each edit
3. ✅ Offline editing: Disable when offline
4. ✅ Species-source editing: Edit ANY source's data (per-source Edit buttons)
5. ✅ Array field UI: Tag input for simple arrays
6. ✅ Taxonomy fields: Dropdown for subgenus, autocomplete for others

**Estimated effort:**
- Data model fixes: ~0.5 days (synonym search fix + toApiFormat utility)
- Core editing features: ~7-9 days
- Polish & accessibility: ~2-3 days
- Total: ~10-12 days

**Priority:** After consolidate-db-code and other pending changes

## Requirements Summary

The spec includes 12 requirements:
1. API Key Authentication
2. Species Editing
3. Species-Source Editing
4. Taxa Editing
5. Sources Editing
6. Delete Confirmation (all deletes require explicit confirmation)
7. Error Handling
8. Data Consistency
9. Offline Behavior
10. Rate Limit Handling
11. Success Feedback
12. Validation Error Display

## Review Findings

### Critical Issues (Must Address)

**1. No Optimistic Concurrency Control**
No mechanism to detect if data was modified between opening an edit form and submitting. If you open species "alba", someone (or you on another device) edits it, then you submit, you silently overwrite their work. Standard practice is to include a version/ETag and return 409 Conflict if mismatched.

**2. Race Condition in Full Refresh Strategy**
Full refresh after edits can cause problems if edit modal is open when refresh occurs, or if user navigates to another record during refresh. The mental model of data becomes stale.

**3. Session Timeout Missing**
API keys in localStorage persist indefinitely. If someone uses a shared computer and forgets to logout, the key remains accessible. Should add configurable session timeout.

### Security Concerns

**4. XSS Attack Vector**
API key in localStorage is vulnerable to any XSS on the same origin. While "single-user scenario" is cited, this should be clearly documented as a known risk.

**5. No Input Sanitization Specified**
No discussion of HTML escaping on display, maximum field lengths, or character restrictions for species names.

### Missing Requirements

**6. No Undo/Edit History**
No way to revert changes or see what was modified. A single accidental save could corrupt data with no recovery path except database backups.

**7. No Unsaved Changes Warning**
If user has form changes and accidentally navigates away, closes the tab, or clicks Cancel, there's no confirmation dialog to prevent data loss.

**8. Draft/Autosave Missing**
Spec mentions "form data is preserved" on connection loss, but if the browser crashes, form data is lost. No autosave to localStorage for long forms.

### Technical Gaps

**9. Confirmed Bug: Synonym Search**
`dataStore.js:101-103` expects `{name: "..."}` objects but export format (`api/internal/export/types.go:54`) sends `[]string`. This is a legitimate bug to fix.

**10. Concurrent Tab Handling Undefined**
If user has the same species open in two tabs and saves in one (triggering refresh), the other tab has stale data.

**11. API Health Check Frequency Unspecified**
Task 3.6 mentions "Periodic API health check" but frequency, false positive handling, and mid-session behavior aren't defined.

**12. Delete Cascade Semantics Unclear**
What happens when deleting a taxon with assigned species? Can you delete a source with species_sources records? API behavior not specified.

### UX Gaps

**13. Large Form Handling**
Species have many fields. Modal approach may be cramped. Need to specify: scroll behavior, field grouping, mobile layout.

**14. Keyboard Accessibility**
Forms need: tab order, Enter to submit, Escape to close, ARIA labels for screen readers.

### Estimation & Planning

**15. Optimistic Estimate**
6-8 days for ~70 sub-tasks is aggressive (<1 hour/task). More realistic: 12-15 days with testing.

**16. Task Dependencies Not Explicit**
Section 5 (UI Components) should block 6-9; Section 2 (Auth) should block Section 4 (API Write Operations).

### Minor Issues

**17. Taxonomy Validation**
When editing species, user can enter any section/subsection/complex via autocomplete. Can invalid (non-existent) values be submitted?

### Disposition

| Issue | Disposition |
|-------|-------------|
| 1. Concurrency control | Defer to v2 - single user, low risk |
| 2. Refresh race condition | Add: disable form submit during refresh |
| 3. Session timeout | Add to scope - 24 hour default |
| 4. XSS risk | Document in security notes |
| 5. Input sanitization | Add to scope - max lengths, escaping |
| 6. Undo/history | Defer to v2 |
| 7. Unsaved changes warning | Add to scope |
| 8. Draft autosave | Defer to v2 |
| 9. Synonym bug | Already in scope (Task 1.1) |
| 10. Concurrent tabs | Document as known limitation |
| 11. Health check frequency | Specify: 60 seconds, with debounce |
| 12. Delete cascade | Document API behavior in spec |
| 13. Form layout | Add to design: scrollable modal, field sections |
| 14. Keyboard a11y | Add to scope |
| 15. Estimate | Revise to 10-12 days |
| 16. Dependencies | Add to tasks.md |
| 17. Taxonomy validation | API rejects invalid; show error |
