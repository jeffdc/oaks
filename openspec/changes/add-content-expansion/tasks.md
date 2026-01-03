# Tasks: Content Expansion

## Prerequisites

**All phases require**: `refactor-web-data-layer` complete (web app uses direct API calls, no IndexedDB)

**Phase 1 & 2**: Can proceed in parallel after prerequisite
**Phase 3**: Also requires `species-name-parser` (bead `oaks-lqfj`) complete

---

## Phase 1: Taxa Content (Priority 1)

### 1.1 Database & API Layer
- [ ] 1.1.1 Rename taxa `notes` column to `content`, add `content_updated_at`
- [ ] 1.1.2 Write migration script (table rebuild for SQLite)
- [ ] 1.1.3 Update taxa model in API server
- [ ] 1.1.4 Update taxa handlers to accept/return content field
- [ ] 1.1.5 Update export to include taxa content
- [ ] 1.1.6 Write tests for taxa content operations

### 1.2 Web App - Taxa Content Display
- [ ] 1.2.1 Add markdown rendering library (marked + DOMPurify)
- [ ] 1.2.2 Create MarkdownRenderer component with sanitization
- [ ] 1.2.3 Update TaxonView to display content
- [ ] 1.2.4 Write tests for taxa content display

### 1.3 Web App - Taxa Content Editing
- [ ] 1.3.1 Add authentication state management (API key storage)
- [ ] 1.3.2 Create MarkdownEditor component with preview
- [ ] 1.3.3 Add Edit/Add Content button to TaxonView (when authenticated)
- [ ] 1.3.4 Create TaxonContentEditor page/modal
- [ ] 1.3.5 Implement save functionality via API
- [ ] 1.3.6 Write tests for taxa content editing

## Phase 2: Reference Articles (Priority 2)

### 2.1 Database & API Layer
- [ ] 2.1.1 Create articles table schema
- [ ] 2.1.2 Write migration script
- [ ] 2.1.3 Create article model in API server
- [ ] 2.1.4 Implement article CRUD handlers
- [ ] 2.1.5 Implement tags endpoint
- [ ] 2.1.6 Add slug generation utility
- [ ] 2.1.7 Update export to include articles
- [ ] 2.1.8 Write tests for article operations

### 2.2 Web App - Articles Display
- [ ] 2.2.1 Add article API client methods (list, get, tags, create, update, delete)
- [ ] 2.2.2 Create ArticleList component (shows drafts when authenticated)
- [ ] 2.2.3 Create ArticleView component
- [ ] 2.2.4 Add articles section to landing page
- [ ] 2.2.5 Add articles link to navigation
- [ ] 2.2.6 Implement tag filtering
- [ ] 2.2.7 Add SvelteKit routes for articles (/articles, /articles/[slug])
- [ ] 2.2.8 Write tests for article display components

### 2.3 Web App - Article Authoring
- [ ] 2.3.1 Create ArticleEditor component with markdown preview
- [ ] 2.3.2 Add New Article button (when authenticated)
- [ ] 2.3.3 Add Edit button to ArticleView (when authenticated)
- [ ] 2.3.4 Create article editor route (/articles/[slug]/edit, /articles/new)
- [ ] 2.3.5 Implement publish/unpublish toggle
- [ ] 2.3.6 Implement article deletion with confirmation
- [ ] 2.3.7 Write tests for article authoring

## Phase 3: Species Auto-Linking (Priority 3)

**BLOCKED BY**: `species-name-parser` (bead `oaks-lqfj`) - Go implementation

### 3.1 API - Auto-Linking at Save Time
- [ ] 3.1.1 Integrate species-name-parser into taxa content handler
- [ ] 3.1.2 Integrate species-name-parser into article handlers
- [ ] 3.1.3 Process content on create and update operations
- [ ] 3.1.4 Write tests for auto-linking during save

### 3.2 API - Backlinks Endpoint
- [ ] 3.2.1 Add `GET /api/v1/species/:name/backlinks` endpoint
- [ ] 3.2.2 Implement content pattern matching for `/species/{name}`
- [ ] 3.2.3 Write tests for backlinks endpoint

### 3.3 Web App - Backlinks Display
- [ ] 3.3.1 Add backlinks API client method
- [ ] 3.3.2 Create SpeciesBacklinks component
- [ ] 3.3.3 Add backlinks section to SpeciesDetail page
- [ ] 3.3.4 Write tests for backlinks display

## Phase 4: Integration & Polish

### 4.1 Documentation
- [ ] 4.1.1 Update CLAUDE.md with new data structures
- [ ] 4.1.2 Update API documentation

### 4.2 Testing & Deployment
- [ ] 4.2.1 End-to-end testing of content flow
- [ ] 4.2.2 Performance testing with sample content
- [ ] 4.2.3 Deploy API changes
- [ ] 4.2.4 Deploy web app changes
