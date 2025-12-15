# Quercus Database

A comprehensive database and query tool for Quercus (oak) species and their hybrids, scraped from [Oaks of the World](https://oaksoftheworld.fr).

## Features

- **Scraper**: Python script to extract all oak species and hybrid data
- **Query Tool**: Static webpage for searching and exploring species relationships
- **Comprehensive Data**: Includes taxonomy, morphology, distribution, and hybrid parentage
- **Resume Support**: Scraper automatically resumes from interruptions

## Quick Start

### 1. Scrape the Data

```bash
# Navigate to the scraper directory
cd scrapers/oaksoftheworld

# Install dependencies
pip install -r requirements.txt

# Run the scraper
python3 scraper.py

# Output: ../../quercus_data.json (in root directory)
```

The scraper will:
- Fetch all species from the main list
- Extract detailed information from each species page
- Build bidirectional hybrid relationships
- Save progress automatically (resume on restart)

See [scrapers/oaksoftheworld/README.md](scrapers/oaksoftheworld/README.md) for detailed scraper documentation.

### 2. Browse the Data

Open `browse.html` in your browser to:
- Search for species by name (case-insensitive, partial matching)
- View all hybrids for a given species with their other parent
- See parent species for each hybrid
- Explore detailed species information

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