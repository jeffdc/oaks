# Oaks of the World Scraper

This scraper extracts data from [Oaks of the World](https://oaksoftheworld.fr/) website and generates a comprehensive JSON dataset of Quercus (oak) species.

## Overview

The scraper parses the main species list and individual species pages to extract:
- Species names and author information
- Hybrid status and parent species
- Synonyms and taxonomic relationships
- Morphological characteristics (leaves, bark, fruits, etc.)
- Geographic range and habitat information
- Conservation status and taxonomy

## Output

The scraper outputs `quercus_data.json` to the root directory (`../../quercus_data.json` relative to this directory) so that `browse.html` can load it.

## Usage

Run from this directory:

```bash
cd scrapers/oaksoftheworld

# Continue from last position
python3 scraper.py

# Start fresh (clears progress)
python3 scraper.py --restart

# Process only first N species (for testing)
python3 scraper.py --limit=10

# Disable caching (fetch fresh data)
python3 scraper.py --no-cache
```

## Files

- `scraper.py` - Main scraper script
- `name_parser.py` - Parses the main species list (liste.htm) according to parsing rules
- `parser.py` - Parses individual species pages
- `utils.py` - Utility functions for caching, progress tracking, and HTTP requests
- `test_name_parser.py` - Test script for the name parser
- `parsing_rules.txt` - Documentation of parsing rules for the species list
- `requirements.txt` - Python dependencies

## Data Files (in tmp/scraper/)

All temporary/cache files are stored in `tmp/scraper/` at the project root:
- `html_cache/` - Cached HTML pages from the website
- `data_inconsistencies.log` - Log of taxonomic notes and name mismatches
- `scraper_progress.json` - Progress file (created during scraping)

## Requirements

```bash
pip install -r requirements.txt
```

Main dependencies:
- requests - HTTP requests
- beautifulsoup4 - HTML parsing
- lxml - XML/HTML parsing backend

## How It Works

1. **Fetch Species List**: Downloads `liste.htm` from the website
2. **Parse Species Names**: Extracts species names, synonyms, and hybrid markers using rules from `parsing_rules.txt`
3. **Fetch Species Pages**: Downloads individual species pages (e.g., `quercus_alba.htm`)
4. **Extract Data**: Parses each page to extract morphological and taxonomic data
5. **Build Relationships**: Creates bidirectional relationships between species and their hybrids
6. **Output JSON**: Saves all data to `../../quercus_data.json`

## Recent Fixes

- **Hybrid Detection**: Fixed issue where hybrids like Quercus × richteri were not properly marked due to the (x) marker appearing outside the link text
- **Synonym Handling**: Improved parsing of complex synonym patterns (equals, see, and chain references)
- **Parent Detection**: Correctly identifies both parent species for hybrid oaks
