# Oak Browser Web Application

A Progressive Web App (PWA) for browsing Quercus (oak) species data with offline support.

## Technology Stack

- **Framework**: SvelteKit with Svelte 5 (runes syntax)
- **Styling**: Tailwind CSS v4
- **Build Tool**: Vite 6
- **Adapter**: @sveltejs/adapter-static (GitHub Pages)
- **PWA**: @vite-pwa/sveltekit

## Prerequisites

- Node.js 18+
- npm 9+

## Development

```bash
npm install
npm run dev        # Dev server at http://localhost:5173
```

## Building

```bash
npm run build      # Output to dist/
npm run preview    # Preview production build
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
│   │   └── species/[name]/  # Species detail pages
│   └── lib/
│       ├── components/      # Svelte components
│       ├── stores/          # State management (dataStore.js)
│       └── db.js            # IndexedDB wrapper (Dexie.js)
├── static/                  # Static assets (icons, quercus_data.json)
├── svelte.config.js         # SvelteKit config
├── vite.config.js           # Vite + PWA config
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
| `/about/` | About page |

## Data Source

The app loads species data from `static/quercus_data.json`, which is:
- Exported from the CLI: `oak export ../web/public/quercus_data.json`
- Committed to the repo
- Loaded into IndexedDB on first load for offline queries

## PWA Features

- **Offline Support**: Works without internet after initial load
- **Installable**: Can be added to home screen on mobile/desktop
- **Auto-Update**: Prompts user when new version is available

## Deployment

GitHub Actions auto-deploys to GitHub Pages on push to main.

Base path is `/oaks` (configured in `svelte.config.js`).

## Detailed Documentation

See [CLAUDE.md](CLAUDE.md) for comprehensive architecture documentation including:
- State management patterns
- Component details
- Styling system
- Data structures
