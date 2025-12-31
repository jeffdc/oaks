# Oak Compendium Web Application

A web application for browsing and managing Quercus (oak) species data. Connects to the Oak Compendium API for data access with offline data caching via IndexedDB.

## Technology Stack

- **Framework**: SvelteKit with Svelte 5 (runes syntax)
- **Styling**: Tailwind CSS v4
- **Build Tool**: Vite 6
- **Adapter**: @sveltejs/adapter-static (GitHub Pages)
- **Testing**: Vitest + @testing-library/svelte, Playwright (E2E)
- **Offline Storage**: IndexedDB via Dexie.js

## Prerequisites

- Node.js 18+
- npm 9+

## Development

```bash
npm install
npm run dev          # Dev server, uses production API
npm run dev:local    # Dev server, uses local API at localhost:8080
```

**Tip**: Use `make dev` from the project root to start both API and web dev server together.

## Building

```bash
npm run build      # Output to dist/
npm run preview    # Preview production build
```

## Testing

```bash
npm run test           # Run tests once
npm run test:watch     # Watch mode
npm run test:coverage  # With coverage report
npm run test:e2e       # Playwright E2E tests
```

## Project Structure

```
web/
├── src/
│   ├── app.html             # HTML template
│   ├── app.css              # Global styles & CSS custom properties
│   ├── routes/              # SvelteKit file-based routing
│   │   ├── +layout.svelte   # Root layout with Header
│   │   ├── +page.svelte     # Home page
│   │   ├── list/            # Species list view
│   │   ├── about/           # About page
│   │   ├── taxonomy/        # Taxonomy tree + dynamic taxon views
│   │   ├── species/[name]/  # Species detail pages
│   │   ├── sources/         # Sources list and detail views
│   │   └── compare/[name]/  # Source comparison view
│   └── lib/
│       ├── apiClient.js     # HTTP client for API
│       ├── components/      # Svelte components
│       │   ├── Header.svelte
│       │   ├── Search.svelte
│       │   ├── SearchResults.svelte
│       │   ├── LandingPage.svelte
│       │   ├── SpeciesDetail.svelte
│       │   ├── TaxonView.svelte
│       │   ├── AboutPage.svelte
│       │   ├── SourceDetail.svelte
│       │   ├── SourceComparison.svelte
│       │   ├── EditModal.svelte
│       │   ├── DeleteConfirmDialog.svelte
│       │   ├── FormField.svelte
│       │   ├── TagInput.svelte
│       │   ├── TaxonSelect.svelte
│       │   ├── Toast.svelte
│       │   └── LoadingSpinner.svelte
│       ├── stores/
│       │   ├── dataStore.js   # Species/taxa state
│       │   ├── authStore.js   # Authentication state
│       │   └── toastStore.js  # Toast notifications
│       └── icons/           # SVG icons
├── static/                  # Static assets (icons, quercus_data.json)
├── svelte.config.js         # SvelteKit config
├── vite.config.js           # Vite config
└── package.json
```

## Routes

| Path | Description |
|------|-------------|
| `/` | Home / Landing page |
| `/list/` | Species list with search |
| `/species/[name]/` | Species detail (e.g., `/species/alba/`) |
| `/taxonomy/` | Taxonomy tree view |
| `/taxonomy/[...path]/` | Taxon detail (e.g., `/taxonomy/Quercus/Quercus/`) |
| `/sources/` | Data sources list |
| `/sources/[id]/` | Source detail |
| `/compare/[name]/` | Compare sources for a species |
| `/about/` | About page |

## Data Source

The app loads species data from `static/quercus_data.json`, which is:
- Exported from the CLI: `oak export ../web/static/quercus_data.json`
- Committed to the repo

For editing operations, the app connects to the API server (production or local).

## Offline Support

- **IndexedDB Caching**: Species data cached locally for offline reads
- **Network Required for Edits**: CRUD operations require API connectivity
- **Offline Indicator**: Header shows status when network unavailable

Note: This is not a full PWA - there is no service worker or install-to-homescreen capability.

## Deployment

GitHub Actions auto-deploys to GitHub Pages on push to main.

Custom domain: oakcompendium.org (base path `/`)

## Detailed Documentation

See [CLAUDE.md](CLAUDE.md) for comprehensive architecture documentation including:
- State management patterns
- Component details
- Styling system
- Data structures
