# Change: Add Content Expansion (Taxa Pages, Articles, Auto-Linking)

## Dependencies

### Required Before Starting (All Phases)
- **BLOCKED BY**: `refactor-web-data-layer` - This proposal assumes the web app uses direct API calls (no IndexedDB). Must complete first.

### Required Before Phase 3 Only
- **BLOCKED BY**: `add-wasm-species-linker` - Phase 3 (auto-linking) requires the species name parser. Uses Rust/WASM for client-side linking at render time (supersedes `add-species-name-parser`).

### Implementation Order
1. **Phase 1 (Taxa Content)** and **Phase 2 (Articles)** can proceed in parallel once `refactor-web-data-layer` is complete
2. **Phase 3 (Species Auto-Linking)** requires both earlier phases AND `add-wasm-species-linker` to be complete
3. **Phase 4 (Integration)** depends on all prior phases

## Why

The Oak Compendium currently only supports content at the species level. Information about higher taxonomy levels (e.g., "characteristics of white oaks" for Section Quercus) and general reference material (guides, book reviews, identification essays) has no home. This limits the site's potential to become a comprehensive oak reference.

## What Changes

### Priority 1: Taxa-Level Content
- Add freeform markdown content field to taxa table (subgenus, section, subsection, complex)
- Content authored by site owner, attributed to Oak Compendium source (no multi-source tracking)
- Users navigate to taxa pages via existing taxonomy browser and breadcrumbs
- Taxa content does NOT inherit to child taxa or species
- **BREAKING**: Adds new column to `taxa` table; requires migration

### Priority 2: Reference Articles
- New `articles` table storing standalone markdown documents
- Article metadata: title, publication date, author (all required)
- Simple tagging system for categorization (guides, book reviews, identification)
- Dedicated "Articles" section accessible from front page and navigation
- Articles in flat list, filtered by tags

### Priority 3: Species Auto-Linking
- Automatic detection of species mentions in markdown content
- Pattern matching for "Quercus alba" and "Q. alba" forms
- Convert mentions to links to species pages
- Add backlinks on species pages showing referencing content
- Applies to taxa content and article content

## Impact

- **Affected specs**: api-server (new endpoints), plus new specs taxa-content, reference-articles, species-linking
- **Affected code**:
  - `api/internal/db/` - new tables and queries
  - `api/internal/handlers/` - new endpoints
  - `api/internal/models/` - new types
  - `api/internal/export/` - updated JSON export format
  - `web/src/lib/` - new components, stores, and API client methods
  - `web/src/routes/` - new article routes

## Out of Scope

- Image support (future enhancement)
- Content above Quercus genus level
- Multiple authors or user-contributed content
- Structured data fields for taxa (freeform only)
- Search within articles (use existing infrastructure)
