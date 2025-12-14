# iNaturalist Hybrid Oak Scraper

This scraper searches iNaturalist for hybrid oaks based on a parent species and extracts hybrid information.

## Installation

```bash
pip install -r requirements.txt
```

## Usage

```bash
python scrape_hybrids.py <parent_name> [-o OUTPUT_FILE]
```

### Examples

Search for hybrids of Quercus falcata:
```bash
python scrape_hybrids.py falcata
```

Search for hybrids and save to a custom file:
```bash
python scrape_hybrids.py falcata -o falcata_hybrids.json
```

### Arguments

- `parent_name`: The parent species name without "Quercus" prefix (e.g., "falcata", "alba", "robur")
- `-o, --output`: Output JSON file path (default: inat_hybrids.json)

## Output Format

The script outputs data in the same JSON format as `quercus_data.json`, with the following fields:

- `name`: Hybrid species name (without "Quercus" prefix)
- `is_hybrid`: Always `true`
- `local_names`: Array containing the common name if found (e.g., ["Willdenow's Oak"])
- `parent1`, `parent2`: Parent species names if found
- `parent_formula`: Formula showing the cross (e.g., "Quercus falcata × Quercus phellos")
- `url`: Link to iNaturalist search for the hybrid

## How It Works

1. Constructs a search URL like `https://www.inaturalist.org/search?q=quercus%20falcata%20x`
2. Scrapes the search results page
3. Extracts hybrid names (e.g., "Quercus × subfalcata")
4. Extracts common names if present (e.g., "Quercus × willdenowiana (Willdenow's Oak)")
5. Looks for parent formulas in the "Other Names" section (e.g., "Quercus falcata × phellos")
6. Converts data to the quercus_data.json format

## Notes

- The scraper may need adjustments if iNaturalist changes their HTML structure
- Not all hybrids will have complete parent information
- Results depend on what's available in iNaturalist's database
