# Scrapers TODO

## Refactor: Use API instead of direct DB access

The Python scrapers currently access the SQLite database directly instead of using the API. This creates coupling to the database location and bypasses the API layer.

Files affected:
- `external_links/add_feis_links.py`
- `external_links/add_fna_links.py`
- `iucn/fetch_status.py`
- `usda_symbols.py`

Each uses: `DB_PATH = PROJECT_ROOT / 'cli' / 'oak_compendium.db'`

Options:
- Update paths to point at correct DB location
- Refactor to use Phoenix API endpoints
