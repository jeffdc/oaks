#!/usr/bin/env python3
"""
USDA Plants Database Symbol Lookup

Queries the USDA Plants API to find symbols for Quercus species
and updates the oak_compendium.db external_links field.

Usage:
    python3 usda_symbols.py [--dry-run] [--limit N]
"""

import argparse
import json
import re
import sqlite3
import time
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

# USDA Plants API endpoint
API_URL = "https://plantsservices.sc.egov.usda.gov/api/PlantProfile"
PLANTS_URL = "https://plants.usda.gov/plant-profile/"

# Rate limiting
REQUEST_DELAY = 0.3  # seconds between requests

DB_PATH = Path(__file__).parent.parent / "cli" / "oak_compendium.db"


def generate_candidate_symbols(species_name: str) -> list[str]:
    """
    Generate candidate USDA symbols for a species.

    Pattern: QU + first 2 letters of epithet + optional numeric suffix
    For hybrids (starting with ×), use the hybrid name after ×
    """
    name = species_name.strip()

    # Handle hybrids - they start with × or x
    if name.startswith("×") or name.startswith("x"):
        name = name[1:].strip()

    # For subspecies/varieties like "acutissima acutissima", use only the first part
    name = name.split()[0] if " " in name else name

    # Get first 2 letters of the species epithet
    if len(name) < 2:
        return []

    base = "QU" + name[:2].upper()

    # Generate candidates: QUXX, QUXX2, QUXX3, ... QUXX9
    candidates = [base]
    for i in range(2, 10):
        candidates.append(f"{base}{i}")

    return candidates


def check_usda_symbol(symbol: str, expected_species: str) -> dict | None:
    """
    Check if a symbol exists in USDA and matches our species.

    Returns the API response if valid, None otherwise.
    """
    url = f"{API_URL}?symbol={symbol}"

    try:
        req = Request(url, headers={"User-Agent": "OakCompendium/1.0"})
        with urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode())

            # API returns null for invalid symbols
            if data is None:
                return None

            # Check if the response has valid data
            if not data.get("Symbol") or not data.get("ScientificName"):
                return None

            # Extract the species name from the scientific name
            # Format: "<i>Quercus alba</i> L." -> "alba"
            sci_name = data.get("ScientificName", "")
            # Remove HTML tags
            sci_name = re.sub(r"<[^>]+>", "", sci_name)
            # Extract species epithet (second word, handling hybrids)
            parts = sci_name.split()

            if len(parts) < 2:
                return None

            # Handle "Quercus ×hybrid" or "Quercus hybrid"
            epithet = parts[1].lower()
            if epithet.startswith("×"):
                epithet = epithet[1:]

            # Normalize expected species for comparison
            expected = expected_species.lower()
            if expected.startswith("×"):
                expected = expected[1:]

            # Check if it matches
            if epithet == expected:
                return data

            return None

    except HTTPError as e:
        if e.code == 404:
            return None
        print(f"  HTTP error {e.code} for {symbol}")
        return None
    except URLError as e:
        print(f"  URL error for {symbol}: {e}")
        return None
    except json.JSONDecodeError:
        return None


def find_usda_symbol(species_name: str) -> tuple[str | None, dict | None]:
    """
    Find the USDA symbol for a species by trying candidate symbols.

    Returns (symbol, api_data) or (None, None) if not found.
    """
    candidates = generate_candidate_symbols(species_name)

    for symbol in candidates:
        time.sleep(REQUEST_DELAY)
        result = check_usda_symbol(symbol, species_name)
        if result:
            return symbol, result

    return None, None


def update_external_links(conn: sqlite3.Connection, species_name: str,
                          symbol: str, common_name: str | None, dry_run: bool) -> bool:
    """
    Add USDA link to the species' external_links field.
    """
    cursor = conn.cursor()

    # Get current external_links
    cursor.execute(
        "SELECT external_links FROM oak_entries WHERE scientific_name = ?",
        (species_name,)
    )
    row = cursor.fetchone()
    if not row:
        return False

    # Parse existing links
    existing = row[0]
    if existing:
        try:
            links = json.loads(existing)
        except json.JSONDecodeError:
            links = []
    else:
        links = []

    # Check if USDA link already exists
    for link in links:
        if link.get("logo") == "usda" or link.get("source") == "USDA":
            return False  # Already has USDA link

    # Add USDA link
    # Note: Go model uses "logo" as identifier, not "source"
    usda_link = {
        "name": "USDA Plants Database",
        "url": f"{PLANTS_URL}{symbol}",
        "logo": "usda"
    }

    links.append(usda_link)

    if not dry_run:
        cursor.execute(
            "UPDATE oak_entries SET external_links = ? WHERE scientific_name = ?",
            (json.dumps(links), species_name)
        )
        conn.commit()

    return True


def main():
    parser = argparse.ArgumentParser(description="Look up USDA symbols for oak species")
    parser.add_argument("--dry-run", action="store_true", help="Don't update database")
    parser.add_argument("--limit", type=int, help="Limit number of species to process")
    parser.add_argument("--skip-existing", action="store_true", default=True,
                        help="Skip species that already have USDA links")
    args = parser.parse_args()

    if not DB_PATH.exists():
        print(f"Database not found: {DB_PATH}")
        return 1

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Get all species
    cursor.execute("SELECT scientific_name, external_links FROM oak_entries ORDER BY scientific_name")
    all_species = cursor.fetchall()

    # Filter out species that already have USDA links if requested
    species_to_process = []
    for name, links_json in all_species:
        if args.skip_existing and links_json:
            try:
                links = json.loads(links_json)
                if any(l.get("source") == "USDA" for l in links):
                    continue
            except json.JSONDecodeError:
                pass
        species_to_process.append(name)

    if args.limit:
        species_to_process = species_to_process[:args.limit]

    print(f"Processing {len(species_to_process)} species...")
    if args.dry_run:
        print("(dry run - no changes will be made)")
    print()

    found = 0
    not_found = 0
    errors = 0

    for i, species_name in enumerate(species_to_process):
        print(f"[{i+1}/{len(species_to_process)}] {species_name}...", end=" ", flush=True)

        try:
            symbol, data = find_usda_symbol(species_name)

            if symbol:
                common_name = data.get("CommonName") if data else None
                updated = update_external_links(conn, species_name, symbol, common_name, args.dry_run)
                if updated:
                    print(f"-> {symbol}" + (f" ({common_name})" if common_name else ""))
                    found += 1
                else:
                    print(f"-> {symbol} (already exists)")
            else:
                print("not found")
                not_found += 1

        except Exception as e:
            print(f"error: {e}")
            errors += 1

    print()
    print(f"Summary: {found} found, {not_found} not found, {errors} errors")

    conn.close()
    return 0


if __name__ == "__main__":
    exit(main())
