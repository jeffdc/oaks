# Quercus Compendium - Web Application

A modern, responsive web application for browsing and exploring oak (Quercus) species data. Built as a Progressive Web App (PWA) with offline support.

## Tech Stack

- **Framework**: SvelteKit with Svelte 5 (runes syntax)
- **Build Tool**: Vite 6
- **Static Adapter**: @sveltejs/adapter-static for GitHub Pages deployment
- **Styling**: Tailwind CSS 4 + Custom CSS Variables
- **Testing**: Vitest + @testing-library/svelte
- **Offline Support**: IndexedDB caching via Dexie.js (no service worker)
- **Data Source**: Static JSON (`static/quercus_data.json`, committed to repo)

## Project Structure

```
web/
├── src/
│   ├── app.html             # HTML template
│   ├── app.css              # Global styles & CSS custom properties
│   ├── routes/              # SvelteKit file-based routing
│   │   ├── +layout.svelte   # Root layout with Header and data loading
│   │   ├── +layout.js       # Prerender configuration
│   │   ├── +page.svelte     # Home page (LandingPage)
│   │   ├── list/+page.svelte           # Species list view
│   │   ├── about/+page.svelte          # About page
│   │   ├── taxonomy/+page.svelte       # Taxonomy browser (genus-level view)
│   │   ├── taxonomy/[...path]/         # Dynamic taxon view
│   │   └── species/[name]/             # Dynamic species detail
│   └── lib/
│       ├── components/      # Svelte components
│       │   ├── Header.svelte
│       │   ├── Search.svelte
│       │   ├── LandingPage.svelte
│       │   ├── SearchResults.svelte
│       │   ├── SpeciesDetail.svelte
│       │   ├── TaxonView.svelte
│       │   └── AboutPage.svelte
│       ├── stores/
│       │   ├── dataStore.js  # Svelte stores for species/taxa data
│       │   └── authStore.js  # Authentication state (API key, session)
│       ├── db.js             # IndexedDB wrapper (Dexie.js)
│       ├── apiClient.js      # HTTP client for API requests (editing)
│       └── tests/            # Test files
│           ├── setup.js      # Vitest setup
│           ├── dataStore.test.js
│           └── db.test.js
├── static/                   # Static assets (icons, data file)
├── svelte.config.js          # SvelteKit config with static adapter
├── vite.config.js            # Vite config + PWA settings
└── package.json              # Dependencies
```

## Architecture & Patterns

### State Management (dataStore.js)

Uses Svelte stores for reactive state:

- **Writable Stores**:
  - `allSpecies`: All loaded species data
  - `isLoading`: Loading state flag
  - `error`: Error state
  - `searchQuery`: Current search text
  - `selectedSpecies`: Currently selected species for detail view

- **Derived Stores**:
  - `filteredSpecies`: Species filtered by search query (searches name, author, synonyms, local_names, range)
  - `speciesCounts`: Calculates species count, hybrid count, and total from filtered results

### Routing & Navigation

- **SvelteKit file-based routing** with path URLs (no hash routing)
- Routes:
  - `/` - Home (LandingPage)
  - `/list/` - Species list view
  - `/about/` - About page
  - `/taxonomy/` - Taxonomy tree view
  - `/taxonomy/[...path]/` - Dynamic taxon view (e.g., `/taxonomy/Quercus/Quercus/`)
  - `/species/[name]/` - Species detail (e.g., `/species/alba/`)
- Base path: `/` (custom domain: oakcompendium.org)
- Navigation: Standard `<a href>` links with `$app/paths` base import
- Browser back/forward buttons work correctly

### Data Flow

1. App loads → `loadSpeciesData()` fetches `/quercus_data.json`
2. Data stored in `allSpecies` store
3. Search input updates `searchQuery` store
4. `filteredSpecies` automatically recomputes via derived store
5. Components reactively update via Svelte subscriptions (`$filteredSpecies`)

### Offline Support

The app provides offline read access through IndexedDB caching:

- **Data Persistence**: Species data cached in IndexedDB via Dexie.js
- **Offline Reads**: Cached data available without network connection
- **Online Edits Only**: CRUD operations require API connectivity
- **Offline Indicator**: Header shows status when network unavailable

Note: This is not a full PWA - there is no service worker or install-to-homescreen capability.

## Styling System

### CSS Custom Properties (app.css)

All colors, shadows, and typography defined as CSS variables:

```css
--color-forest-{50-900}  /* Green palette */
--color-oak-brown        /* Accent colors */
--color-background       /* Semantic colors */
--shadow-{sm,md,lg,xl}   /* Elevation system */
--font-serif             /* Typography */
```

### Styling Approach

- **Global styles**: `app.css` (Tailwind import + custom properties + component utilities)
- **Component styles**: Scoped `<style>` blocks in `.svelte` files
- **Hybrid approach**: Tailwind utilities for layout, custom properties for colors
- **Consistency**: All components reference CSS variables for colors/shadows

### Global Component Utilities (app.css)

Shared utility classes for common patterns used across multiple components:

```css
/* Content rendering */
.prose-content              /* Markdown/rich text styling */
.prose-content-compact      /* Tighter spacing for tables */

/* Cards */
.card                       /* Base card with border, shadow, rounded corners */
.card-sm                    /* Smaller border radius */
.card-interactive           /* Hover/focus states for clickable cards */
.card-forest                /* Forest-tinted background variant */

/* Navigation */
.taxonomy-nav               /* Taxonomy breadcrumb container */
.taxonomy-nav .taxonomy-link, .taxonomy-name, .taxonomy-level-label, .taxonomy-separator

/* Badges/Pills */
.badge                      /* Base badge styling */
.badge-uppercase            /* Uppercase with letter-spacing */
.badge-forest               /* Green background */
.badge-forest-light         /* Light green background */
.badge-forest-dark          /* Dark green background */
.badge-muted                /* Gray/muted background */

/* Typography */
.section-title              /* Section headings (1.25rem, serif) */
.section-title-sm           /* Smaller variant (1rem) */

/* Feedback */
.loading-spinner            /* Animated spinner */
```

**When to use global utilities vs component styles:**
- Use global utilities for patterns that appear in 2+ components
- Keep component-specific styles in scoped `<style>` blocks
- Prefer composition (multiple utility classes) over new one-off utilities

### Color Palette

- **Primary**: Forest green (`--color-forest-*`) - used for headers, accents
- **Neutrals**: Stone tones for text and backgrounds
- **Theme**: Nature-inspired with rich greens and earth tones

## Key Components

### +layout.svelte (Root Layout)

- Contains Header component
- Handles initial data loading via `onMount`
- Shows loading and error states
- Wraps all page content with consistent styling

### Header.svelte

- Navigation links using `<a href>` with base path
- Search component integration
- Consistent across all pages

### SearchResults.svelte

- Displays search results for species and sources
- Shows count bar at top: "X species | Y hybrids | Z total"
- When searching, groups results by type (Sources first, then Species)
- Each species shows: name (with × for hybrids), author, common names
- Empty state when no results

### SpeciesDetail.svelte

- Comprehensive species information display
- Shows all available fields (taxonomy, morphology, distribution, etc.)
- For hybrids: shows parent formula and links to parents
- Navigation between related species

### Search.svelte

- Real-time search with clear button
- Searches across: name, author, synonyms, local_names, range
- Shows result count below input
- Styled with glassmorphism effect in header


## Development Workflow

### Running Locally

```bash
npm install
npm run dev          # Dev server, uses production API
npm run dev:local    # Dev server, uses local API at localhost:8080
```

**Tip**: Use `make dev` from the project root to start both the API server and web dev server together.

### Building

```bash
npm run build      # Outputs to dist/
npm run preview    # Preview production build
```

### Testing

```bash
npm run test           # Run tests once
npm run test:watch     # Watch mode for development
npm run test:coverage  # Run with coverage report
```

Tests are located in `src/tests/`. The test infrastructure uses:
- **Vitest**: Test runner (integrates with Vite)
- **@testing-library/svelte**: Component testing
- **jsdom**: DOM environment simulation

Current test coverage includes:
- `dataStore.test.js`: Store filtering, counts, helper functions
- `db.test.js`: Source selection and completeness helpers

### Data Updates

The data file `public/quercus_data.json` is committed to the repo. The CLI exports directly to this location. If data structure changes, no code changes needed unless new fields should be displayed. GitHub Actions auto-deploys on push to main.

## Important Conventions

### File Naming

- Components: PascalCase (e.g., `SearchResults.svelte`)
- Utilities: camelCase (e.g., `dataStore.js`)
- Styles: kebab-case for CSS classes

### Code Style

- **Indentation**: 2 spaces
- **Imports**: Group by type (Svelte imports, then local components/stores)
- **Props**: Use `export let propName` in components
- **Events**: Custom events passed as function props (e.g., `onSelectSpecies`)

### Component Communication

- **Parent → Child**: Props
- **Navigation**: Standard `<a href>` links (no callback props for navigation)
- **Global State**: Svelte stores (imported from `$lib/stores/dataStore.js`)

### Accessibility

- Semantic HTML (buttons, proper headings)
- Focus states on interactive elements
- ARIA labels where needed (e.g., clear button)

## Data Structure

Species object shape:
```javascript
{
  name: "alba",           // Species name (without "Quercus")
  is_hybrid: false,
  author: "L. 1753",
  synonyms: [{name: "...", author: "..."}],
  local_names: ["white oak"],
  range: "Eastern North America; 0 to 1600 m",
  growth_habit: "...",
  leaves: "...",
  flowers: "...",
  fruits: "...",
  bark_twigs_buds: "...",
  hardiness_habitat: "...",
  taxonomy: {
    subgenus: "Quercus",
    section: "Quercus",
    subsection: null,
    complex: null
  },
  conservation_status: "...",
  subspecies_varieties: [{...}],
  hybrids: ["Quercus × bebbiana"],  // List of hybrid names
  url: "https://...",

  // Hybrid-specific fields:
  parent_formula: "alba x macrocarpa",
  parent1: "Quercus alba",
  parent2: "Quercus macrocarpa"
}
```

## Common Tasks

### Adding a New Component

1. Create `.svelte` file in `src/lib/components/`
2. Import stores from `$lib/stores/dataStore.js` as needed
3. Use CSS variables for styling consistency
4. For navigation, use `<a href>` with `import { base } from '$app/paths'`
5. Import and use in parent component or route page

### Modifying Search Behavior

Edit the `filteredSpecies` derived store in `dataStore.js:19-48`

### Changing Theme Colors

Modify CSS variables in `app.css:4-38`

### Adding New Data Fields

1. Data comes from scrapers - update scraper if needed
2. Display in `SpeciesDetail.svelte`
3. Optionally add to search in `dataStore.js` filteredSpecies


## Performance Considerations

- **Data Loading**: Single JSON fetch on app load (all species ~2-3MB)
- **Search**: Client-side filtering (fast enough for ~500 species)
- **Caching**: IndexedDB caches species data for offline reads
- **Images**: SVG icons only (no species photos currently)
- **Lazy Loading**: Not needed - single page app with minimal bundle

## Browser Support

- Modern browsers with ES6+ support
- IndexedDB required for offline data caching
- CSS custom properties required

## Deployment

Static site - can be deployed to:
- GitHub Pages
- Netlify
- Vercel
- Any static hosting

Build output in `dist/` is fully self-contained.

## Web Editing

The web application supports full CRUD operations for species, taxa, and sources directly from the browser. This allows data management without needing CLI access.

### Overview

- **Create, Read, Update, Delete** for species, species sources, taxa, and sources
- Requires API key authentication (same key format as CLI/iOS)
- Changes persist to the SQLite database via the API server
- Works in both local development (`make dev`) and production modes

### Authentication

**authStore** (`src/lib/stores/authStore.js`) manages authentication state:

- API key stored in `localStorage` (persists across sessions)
- 24-hour session timeout (auto-logout after inactivity)
- `canEdit` derived store gates all edit UI elements
- Session validated on app load and before each API call

```javascript
// Key exports from authStore
export const apiKey = writable(null);      // Current API key
export const canEdit = derived(...);        // Whether editing is enabled
export function setApiKey(key) {...}        // Store key and start session
export function clearApiKey() {...}         // Logout
```

### Edit Components

**Modal and Form Infrastructure:**

| Component | Purpose |
|-----------|---------|
| `EditModal.svelte` | Reusable modal wrapper with save/cancel/delete actions |
| `SpeciesEditForm.svelte` | Edit core species fields (name, author, taxonomy, conservation) |
| `SpeciesSourceEditForm.svelte` | Edit source-attributed data (leaves, range, etc.) |
| `TaxonEditForm.svelte` | Edit taxa (subgenera, sections, subsections, complexes) |
| `SourceEditForm.svelte` | Edit data sources (books, websites, etc.) |

**Helper Components:**

| Component | Purpose |
|-----------|---------|
| `FormField.svelte` | Labeled input/textarea with consistent styling |
| `TagInput.svelte` | Multi-value input for arrays (synonyms, local names) |
| `TaxonSelect.svelte` | Dropdown for taxonomy selection with hierarchy |
| `DeleteConfirmDialog.svelte` | Confirmation dialog for destructive actions |
| `Toast.svelte` | Feedback notifications (success/error messages) |
| `LoadingSpinner.svelte` | Loading indicator for async operations |

### Data Flow

Edit operations follow this pattern:

```
User edits form → Submit → API call (POST/PUT/DELETE)
                              ↓
                    API updates SQLite database
                              ↓
                    refreshData() called
                              ↓
                    Fetch fresh quercus_data.json
                              ↓
                    Repopulate IndexedDB
                              ↓
                    UI reactively updates via stores
```

Key functions in `dataStore.js`:
- `refreshData()`: Re-fetches JSON and repopulates IndexedDB
- `loadSpeciesData()`: Initial data load (also used for refresh)

### API Integration

Edit operations use `apiClient.js` for HTTP requests:

```javascript
// Example API calls
await apiClient.updateSpecies(name, speciesData);
await apiClient.createSource(sourceData);
await apiClient.deleteSpeciesSource(speciesName, sourceId);
```

All requests include the API key in the `X-API-Key` header.

### Delete Cascade Behavior

Understanding how deletions propagate is important for maintaining data integrity:

| Entity | On Delete | Constraint |
|--------|-----------|------------|
| Species | Auto-deletes all species_sources | Cascades |
| Taxon | Blocked if species reference it | 409 Conflict |
| Source | Blocked if species_sources exist | 409 Conflict |
| Species-Source | No dependents | Always allowed |

**API Response Handling:**
- `200/204`: Success, refresh data
- `409 Conflict`: Show constraint error to user

**Error Messages (from DeleteConfirmDialog):**
- Species: "This will also remove data from X source(s)." (cascade warning)
- Taxon: "Cannot delete: X species use this taxon." (blocked)
- Taxon: "Cannot delete: this taxon has X child taxa." (blocked by children)
- Source: "Cannot delete: X species have data from this source." (blocked)

**UI Behavior:**
- Species delete shows cascade warning with source count, allows proceeding
- Taxon/Source delete blocks with clear error message and OK button only
- All errors display in styled error box with red accent
- Dialog title changes to "Cannot delete [entity type]" for blocked operations

### Security Notes

**Considerations for the current implementation:**

1. **localStorage for API key**: The API key is stored in browser localStorage. This is acceptable for the single-user scenario but would be vulnerable to XSS attacks in a multi-user environment.

2. **Single-user design**: The editing feature is designed for the project maintainer, not general public editing.

3. **Concurrent tab limitations**: Multiple browser tabs may show stale data after edits. The `refreshData()` call only updates the current tab.

4. **No offline editing**: Edits require an active connection to the API server. Offline mode is read-only.

### Testing Locally

1. **Start the development servers:**
   ```bash
   # From project root
   make dev
   # This starts API on :8080 and web on :5173
   ```

2. **Get a test API key:**
   ```bash
   cat ~/.oak/config.yaml
   # Look for the 'key' field under your profile
   ```

3. **Enable editing in the app:**
   - Navigate to Settings (gear icon in header)
   - Enter the API key
   - Click "Save"
   - Edit buttons will appear throughout the UI

4. **Verify connection:**
   - Settings page shows "Connected" status when API key is valid
   - Toast notifications confirm successful edits

### Adding New Editable Fields

To add a new field to an edit form:

1. Add the field to the appropriate form component (e.g., `SpeciesEditForm.svelte`)
2. Ensure the API endpoint handles the field
3. Update the JSON export if the field should appear in the web view
4. No changes needed to IndexedDB schema (dynamic structure)

## Future Enhancements

See main README.md for planned features. Web-specific ideas:
- Image gallery integration
- Geographic filtering with map view
- Taxonomy tree visualization
- Advanced search filters (by section, range, etc.)
- Dark mode toggle
- Print-friendly species pages
