# Oak Browser Web Application

A modern, performant Progressive Web App (PWA) for browsing Quercus (oak) species data.

## Technology Stack

- **Framework**: Svelte (compiler-based, zero runtime)
- **Styling**: Tailwind CSS v4 (utility-first, optimized CSS)
- **Build Tool**: Vite (fast builds and HMR)
- **PWA**: vite-plugin-pwa (offline support)

## Prerequisites

- Node.js 18+
- npm 9+

## Development

```bash
# Install dependencies
npm install

# Start development server (with hot reload)
npm run dev
```

The dev server will run at `http://localhost:5173`

## Building for Production

```bash
# Build optimized production bundle
npm run build

# Preview production build locally
npm run preview
```

The build output will be in the `dist/` directory.

## Data Source

The application loads species data from `../quercus_data.json`. During the build process, this file is automatically copied to the `public/` directory.

To update the data:
1. Run the scraper in `../scrapers/oaksoftheworld/`
2. The build process will automatically pick up the updated `quercus_data.json`

## PWA Features

- **Offline Support**: Works without internet after initial load
- **Update Notifications**: Users are notified when new versions are available
- **App-like Experience**: Can be installed on mobile/desktop

## Project Structure

```
web/
├── src/
│   ├── App.svelte          # Main app component
│   ├── app.css             # Tailwind CSS import
│   ├── main.js             # App entry point
│   └── lib/                # Reusable components
│       ├── dataStore.js    # Svelte stores for state management
│       ├── Search.svelte   # Search component
│       ├── SpeciesList.svelte  # Species list view
│       ├── SpeciesDetail.svelte # Species detail view
│       └── UpdatePrompt.svelte # PWA update notification
├── public/                 # Static assets
├── index.html              # HTML entry point
├── vite.config.js          # Vite configuration (includes PWA setup)
├── postcss.config.js       # PostCSS configuration
└── package.json            # Dependencies and scripts
```

## Development Notes

- The app is fully client-side (no backend required)
- All data is loaded from a static JSON file
- Service Worker handles caching for offline use
- Using Tailwind CSS v4 with `@tailwindcss/postcss` plugin
- Vite's custom plugin automatically copies `quercus_data.json` during build
