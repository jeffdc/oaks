# Design: Content Expansion

## Context

The Oak Compendium needs to evolve from a species-only database to a comprehensive reference. Users should be able to:
1. Read curated content about higher taxonomy levels (what makes white oaks distinct?)
2. Browse standalone articles (how to document an oak, recommended books)
3. Navigate easily between related content via automatic linking

### Stakeholders
- Site owner (content author)
- End users (botanists, naturalists, researchers)

### Constraints
- Must work offline (PWA/IndexedDB)
- No user-generated content (single author)
- Markdown rendering is new capability for the project

## Goals / Non-Goals

### Goals
- Support markdown content at any taxonomy level
- Provide a dedicated articles section with tagging
- Automatically link species mentions to species pages
- Display backlinks on species pages

### Non-Goals
- Image management (future work)
- Full-text search across articles (use existing search)
- Version history or drafts
- Multiple content sources for taxa (unlike species)

## Decisions

### Decision: Single Content Field per Taxon

Taxa get a single `content` markdown field rather than structured fields like species have.

**Rationale**: Taxa content is editorial/curated, not data aggregation from multiple sources. A single markdown field provides maximum flexibility for the author.

**Alternatives considered**:
- Structured fields (leaves, habitat, etc.) - rejected, too rigid for higher-level descriptions
- Multi-source content like species - rejected, only Oak Compendium produces taxa content

### Decision: Articles as Separate Entity

Articles are stored in their own table, not attached to taxonomy.

**Rationale**: Articles like "How to document an oak" or "Recommended books" don't belong to any taxon. Keeping them separate provides a clean data model.

**Alternatives considered**:
- Attach articles to taxa as "general content" - rejected, clutters taxa model
- Use a generic "content" table for both - rejected, different metadata requirements

### Decision: Tag-Based Categorization

Articles use simple string tags for categorization, not a separate tags table.

**Rationale**: Small number of categories expected (guides, book-reviews, identification). JSON array of strings is simpler than normalized tags table.

**Alternatives considered**:
- Normalized tags table - rejected, over-engineering for expected scale
- Fixed enum of categories - rejected, too rigid

### Decision: Backlinks Computed at Load Time

Backlinks shown on species pages are computed when the page loads by scanning content.

**Rationale**: With small content volume, scanning is fast enough. Avoids maintaining bidirectional link tables.

**Alternatives considered**:
- Store backlinks table - rejected, complexity for marginal benefit
- Skip backlinks entirely - rejected, valuable navigation feature

### Decision: Markdown Library

Use `marked` for markdown rendering in the web app, with `DOMPurify` for HTML sanitization.

**Rationale**: Small bundle size (~40KB), no dependencies, well-maintained, supports custom renderers for auto-linking.

**Alternatives considered**:
- `remark` - rejected, larger ecosystem complexity
- `markdown-it` - viable alternative, slightly larger

### Decision: HTML Sanitization

All rendered markdown MUST be sanitized with DOMPurify before insertion into the DOM.

**Rationale**: Even with a single trusted author, sanitization prevents accidents (copy-pasted content with scripts) and establishes good security hygiene. Defense in depth.

**Implementation**:
```javascript
import { marked } from 'marked';
import DOMPurify from 'dompurify';

function renderMarkdown(content) {
  const rawHtml = marked.parse(content);
  return DOMPurify.sanitize(rawHtml);
}
```

**Alternatives considered**:
- `marked` built-in sanitize option - deprecated, less thorough
- Trust content without sanitization - rejected, poor security practice

## Database Schema

### Taxa Table Modification

Rename existing unused `notes` column to `content`, add timestamp:
```sql
-- SQLite doesn't support RENAME COLUMN directly in older versions
-- Use table rebuild approach:
ALTER TABLE taxa RENAME TO taxa_old;
CREATE TABLE taxa (
    name TEXT NOT NULL,
    level TEXT NOT NULL CHECK(level IN ('subgenus', 'section', 'subsection', 'complex')),
    parent TEXT,
    author TEXT,
    content TEXT,              -- renamed from 'notes'
    content_updated_at TEXT,   -- new
    links TEXT,
    PRIMARY KEY (name, level)
);
INSERT INTO taxa (name, level, parent, author, content, links)
    SELECT name, level, parent, author, notes, links FROM taxa_old;
DROP TABLE taxa_old;
```

Note: The `notes` column is currently unused (0 rows have data), so this is a safe rename.

### New Articles Table
```sql
CREATE TABLE articles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slug TEXT NOT NULL UNIQUE,          -- URL-friendly identifier
    title TEXT NOT NULL,
    author TEXT NOT NULL DEFAULT 'Jeff Clark',
    published_at TEXT NOT NULL,         -- ISO 8601 date
    updated_at TEXT,
    tags TEXT,                          -- JSON array of strings
    content TEXT NOT NULL,              -- Markdown content
    is_published INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX idx_articles_slug ON articles(slug);
CREATE INDEX idx_articles_published ON articles(published_at);
```

## API Endpoints

### Taxa Content
- `GET /api/v1/taxa/:level/:name` - existing, now includes content
- `PUT /api/v1/taxa/:level/:name` - existing, now accepts content field

### Articles
- `GET /api/v1/articles` - list articles (filterable by tag)
- `GET /api/v1/articles/:slug` - get article by slug
- `POST /api/v1/articles` - create article (authenticated)
- `PUT /api/v1/articles/:slug` - update article (authenticated)
- `DELETE /api/v1/articles/:slug` - delete article (authenticated)

## JSON Export Format

### Updated Taxa
```json
{
  "taxa": [
    {
      "name": "Quercus",
      "level": "section",
      "parent": "Quercus",
      "content": "# Section Quercus\n\nThe white oaks...",
      "content_updated_at": "2025-01-15T10:30:00Z"
    }
  ]
}
```

### New Articles Section
```json
{
  "articles": [
    {
      "slug": "documenting-oaks",
      "title": "How to Document an Oak for Identification",
      "author": "Jeff Clark",
      "published_at": "2025-01-15",
      "updated_at": "2025-01-20",
      "tags": ["guides"],
      "content": "# How to Document an Oak\n\nWhen you encounter..."
    }
  ]
}
```

## Web App Components

**Note**: This proposal assumes `refactor-web-data-layer` has completed. The web app uses direct API calls, not IndexedDB.

### New Components
- `TaxonContent.svelte` - renders taxon markdown with auto-linking
- `ArticleList.svelte` - displays article list with tag filtering
- `ArticleView.svelte` - single article view
- `SpeciesBacklinks.svelte` - shows content referencing this species
- `MarkdownRenderer.svelte` - shared component with species auto-linking

### New API Client Methods
```javascript
// Articles
fetchArticles(tag?: string): Promise<Article[]>
fetchArticle(slug: string): Promise<Article>
fetchArticleTags(): Promise<string[]>

// Taxa content included in existing fetchTaxon() response
```

## Auto-Linking Architecture

**DEPENDENCY**: Requires `species-name-parser` capability (bead `oaks-lqfj`), implemented in Go.

### Design Decision: Server-Side Linking

Species auto-linking happens at **save time** on the API server, not at render time in the browser.

**Rationale**:
- Content is processed once, not on every page view
- Parser complexity stays in Go, web app just renders standard markdown
- Stored content is self-contained with resolved links
- Backlinks can be computed with simple pattern matching on stored content

**Implementation**:
- Parser lives at `api/internal/parser/` (separate spec: `add-species-name-parser`)
- When taxa content or articles are created/updated via API, content is processed
- Species mentions are converted to markdown links: `[Quercus alba](/species/alba)`
- Original author text is preserved in the link text

### Auto-Linking Flow

```
Author writes:          "The white oaks include Q. alba and Q. macrocarpa."
                                    ↓
API receives content:   POST /api/v1/articles { content: "..." }
                                    ↓
Parser processes:       Finds "Q. alba" at pos 27, "Q. macrocarpa" at pos 40
                                    ↓
Links resolved:         "The white oaks include [Q. alba](/species/alba) and [Q. macrocarpa](/species/macrocarpa)."
                                    ↓
Stored in DB:           Content with resolved links
                                    ↓
Web renders:            Standard markdown → HTML (no species detection)
```

### Backlinks Computation

Since stored content contains resolved links like `/species/alba`, backlinks are computed by pattern matching:

```go
// API endpoint: GET /api/v1/species/:name/backlinks
func findBacklinks(speciesName string, db *Database) []Backlink {
    pattern := fmt.Sprintf("/species/%s)", strings.ToLower(speciesName))

    var backlinks []Backlink

    // Search taxa content
    taxa := db.FindTaxaWithContentMatching(pattern)
    for _, t := range taxa {
        backlinks = append(backlinks, Backlink{Type: "taxon", Name: t.Name, Level: t.Level})
    }

    // Search articles
    articles := db.FindArticlesWithContentMatching(pattern)
    for _, a := range articles {
        backlinks = append(backlinks, Backlink{Type: "article", Slug: a.Slug, Title: a.Title})
    }

    return backlinks
}
```

### Edge Cases

All edge cases are handled by the Go parser (see `add-species-name-parser` spec, bead `oaks-lqfj`):

- **Unknown species**: If parser finds "Quercus unknownus" but species doesn't exist, text is left as-is (no link)
- **Already linked**: If content contains `[Quercus alba](/species/alba)`, parser skips it (no double-linking)
- **Code blocks**: Parser skips content inside markdown code blocks
- **Infraspecific taxa**: `Quercus alba var. latiloba` becomes `[Quercus alba var. latiloba](/species/alba)` - full text is link, target is species page
- **Species renamed/deleted**: Old links become dead; content search can find stale `/species/oldname` references

## Risks / Trade-offs

### Risk: Performance with Large Content
- **Risk**: Many articles + taxa could slow backlink computation
- **Mitigation**: At expected scale (<100 articles, <50 taxa with content), SQL `LIKE` queries on content columns are fast enough. No caching or indexing needed initially. If scale increases significantly, options include: in-memory caching, pre-computing on export, or full-text search index.

### Risk: Broken Links on Species Rename
- **Risk**: Render-time linking means old names won't link
- **Mitigation**: Maintain synonym awareness in linker; content search can find stale references

### Risk: Markdown Rendering Inconsistency
- **Risk**: Markdown may render differently than author expects
- **Mitigation**: Stick to CommonMark subset; provide clear authoring guidelines

## Migration Plan

1. Rename `notes` column to `content` in `taxa` table via table rebuild (see schema section)
   - No data migration needed: `notes` column is currently unused (0 rows have data)
   - Add `content_updated_at` column in same operation
2. Create `articles` table (new, no existing data)
3. Update export format (additive - old clients ignore new fields)
4. Deploy API changes
5. Update web app with new components

### Rollback Strategy

**Taxa table rollback** (if needed before any content is added):
```sql
-- Reverse the rename: content → notes
ALTER TABLE taxa RENAME TO taxa_old;
CREATE TABLE taxa (
    name TEXT NOT NULL,
    level TEXT NOT NULL CHECK(level IN ('subgenus', 'section', 'subsection', 'complex')),
    parent TEXT,
    author TEXT,
    notes TEXT,              -- restored original name
    links TEXT,
    PRIMARY KEY (name, level)
);
INSERT INTO taxa (name, level, parent, author, notes, links)
    SELECT name, level, parent, author, content, links FROM taxa_old;
DROP TABLE taxa_old;
```

**Taxa table rollback** (if content has been added):
- Content data will be preserved but column renamed back to `notes`
- Web app gracefully handles missing `content` field (shows no content section)
- Export format remains backward compatible (old clients ignore extra fields)

**Articles table rollback**:
- `DROP TABLE articles;` removes all article data
- Web app handles missing articles endpoint gracefully (shows empty list or hides section)
- No other tables depend on articles

**Web app rollback**:
- Deploy previous version without content/article components
- Components handle missing data gracefully (no errors, just empty states)

## Open Questions

1. ~~Should article slugs be auto-generated from title or manually specified?~~
   - **Resolved**: Auto-generated from title at creation, or explicitly provided. **Slugs are immutable after creation** - title changes don't affect slug, and slug field is ignored on PUT.
2. ~~Should unpublished articles be visible via API with auth?~~
   - **Resolved**: Yes. Drafts (is_published=false) are visible only with API key authentication. Web app supports authenticated editing with publish/unpublish workflow.
