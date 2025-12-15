# Quercus Database

A comprehensive database and query tool for Quercus (oak) species and their hybrids.

## Features

- **682 Species**: Complete iNaturalist Quercus taxonomy with species data
- **Web Application**: Modern Svelte 5 PWA with offline support
- **CLI Tool**: Go-based tool for managing taxonomic data
- **Multi-Source**: Combines data from iNaturalist and Oaks of the World
- **Offline-First**: Works without internet after initial load

## Quick Start

### Browse Species (Web App)

```bash
cd web
npm install
npm run dev
# Open http://localhost:5173
```

### Manage Data (CLI)

```bash
cd cli
go build -o oak .

# View taxonomy tree
./oak taxa list

# Search for species
./oak find alba

# Export to JSON for web app
./oak export ../quercus_data.json
```

### Initialize Database from Seed Files

```bash
cd cli

# Import iNaturalist taxonomy and species
./oak taxa import --clear data/quercus-taxonomy.yaml
./oak import-bulk data/quercus-species.yaml --source-id 1
```

## Data Pipeline

```
Data Sources                    CLI Tool                      Web App
─────────────                   ────────                      ───────
iNaturalist ──────┐
  (taxonomy)      │
                  ├──▶ oak_compendium.db ──▶ quercus_data.json ──▶ IndexedDB
Oaks of the World │         (SQLite)            (JSON export)      (browser)
  (descriptions) ─┘
```

1. **Seed Files** (`cli/data/`): iNaturalist taxonomy and species list
2. **CLI Database**: SQLite database managed by `oak` CLI tool
3. **JSON Export**: `oak export` generates denormalized JSON for web
4. **Web App**: Loads JSON into IndexedDB for offline-capable queries

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.

## Scraper Usage

### Basic Usage
```bash
cd scrapers/oaksoftheworld

# First run (or resume from last position)
python3 scraper.py

# Force restart from beginning
python3 scraper.py --restart

# Test mode (first 50 species)
python3 scraper.py --test

# Process specific number of species
python3 scraper.py --limit=10
```

### Features
- **Auto-resume**: Automatically continues from where it left off
- **Progress tracking**: Saves state every 10 species
- **Error handling**: Continues past failures, tracks failed URLs
- **Rate limiting**: 0.5 second delay between requests

### Output Files
- `quercus_data.json` - Final structured data (in root directory)
- `tmp/scraper/scraper_progress.json` - Progress state (can be deleted to restart)
- `tmp/scraper/data_inconsistencies.log` - Taxonomic notes and name mismatches
- `tmp/scraper/html_cache/` - Cached HTML pages

## Data Structure

```json
{
  "species": [
    {
      "name": "Quercus alba",
      "is_hybrid": false,
      "author": "L. 1753",
      "synonyms": [...],
      "local_names": ["white oak", "eastern white oak"],
      "range": "Eastern North America; 0 to 1600 m",
      "growth_habit": "reaches 25 m high...",
      "leaves": "8-20 cm long, 5-10 cm wide...",
      "taxonomy": {
        "subgenus": "Quercus",
        "section": "Quercus",
        "series": "Albae"
      },
      "hybrids": ["Quercus × bebbiana", ...],
      "url": "http://..."
    },
    {
      "name": "Quercus × bebbiana",
      "is_hybrid": true,
      "parent_formula": "alba x macrocarpa",
      "parent1": "Quercus alba",
      "parent2": "Quercus macrocarpa",
      ...
    }
  ]
}
```

## Data Fields

All species include (when available):
- **name**: Scientific name
- **is_hybrid**: Boolean flag
- **author**: Taxonomic authority
- **synonyms**: List of alternative names
- **local_names**: Common names
- **range**: Geographic distribution
- **growth_habit**: Size and form description
- **leaves**: Leaf morphology
- **flowers**: Flower description
- **fruits**: Acorn characteristics
- **bark_twigs_buds**: Bark and twig features
- **hardiness_habitat**: Growing conditions
- **taxonomy**: Subgenus, section, series classification
- **conservation_status**: IUCN status if applicable
- **subspecies_varieties**: Infraspecific taxa
- **url**: Link to source page

Hybrids additionally include:
- **parent_formula**: Original hybrid formula (e.g., "alba x macrocarpa")
- **parent1**: First parent species
- **parent2**: Second parent species

## Requirements

- Python 3.7+
- requests
- beautifulsoup4
- lxml

See `scrapers/oaksoftheworld/requirements.txt` for the complete list.

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## Data Source

Data scraped from [Oaks of the World](https://oaksoftheworld.fr) with respect to their rate limits.

## License

MIT License - See LICENSE file for details

## Future Enhancements

- [ ] Geographic filtering
- [ ] Taxonomy visualization
- [ ] Export functionality (CSV, PDF)
- [ ] Image gallery integration
- [ ] Mobile-responsive design

## Acknowledgments

Thanks to the maintainers of [Oaks of the World](https://oaksoftheworld.fr) for compiling this comprehensive resource.