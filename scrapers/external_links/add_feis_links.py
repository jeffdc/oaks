#!/usr/bin/env python3
"""
Add FEIS (Fire Effects Information System) links to oak species.

FEIS is maintained by the USDA Forest Service and provides detailed
fire ecology information for North American species.

Usage:
    python3 add_feis_links.py
    python3 add_feis_links.py --dry-run
"""

import argparse
import json
import sqlite3
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent
DB_PATH = PROJECT_ROOT / "cli" / "oak_compendium.db"

# FEIS URL pattern - uses first 3 letters of species name
FEIS_URL_PATTERN = "https://www.fs.usda.gov/database/feis/plants/tree/que{code}/all.html"

# Species with confirmed FEIS pages (verified via HTTP 200 response)
# Code is first 3 letters of species epithet
FEIS_SPECIES = {
    # Species name -> URL code (usually first 3 letters)
    "agrifolia": "agr",
    "alba": "alb",
    "arizonica": "ari",
    "bicolor": "bic",
    "chrysolepis": "chr",
    "coccinea": "coc",
    "douglasii": "dou",
    "ellipsoidalis": "ell",
    "emoryi": "emo",
    "falcata": "fal",
    "gambelii": "gam",
    "garryana": "gar",
    "grisea": "gri",
    "incana": "inc",
    "kelloggii": "kel",
    "laevis": "lae",
    "lobata": "lob",
    "lyrata": "lyr",
    "macrocarpa": "mac",
    "marilandica": "mar",
    "muehlenbergii": "mue",
    "nigra": "nig",
    "oblongifolia": "obl",
    "palustris": "pal",
    "phellos": "phe",
    "rubra": "rub",
    "shumardii": "shu",
    "stellata": "ste",
    "turbinella": "tur",
    "velutina": "vel",
    "virginiana": "vir",
    "wislizeni": "wis",
}


def get_feis_url(species_name):
    """Generate FEIS URL for a species."""
    code = FEIS_SPECIES.get(species_name)
    if not code:
        return None
    return FEIS_URL_PATTERN.format(code=code)


def update_external_links(scientific_name, new_link, dry_run=False):
    """Add a link to the external_links JSON array."""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Get current external_links
    cursor.execute(
        "SELECT external_links FROM oak_entries WHERE scientific_name = ?",
        (scientific_name,),
    )
    row = cursor.fetchone()

    if not row:
        print(f"  WARNING: Species '{scientific_name}' not found in database")
        conn.close()
        return False

    current_links = row[0]
    if current_links:
        try:
            links = json.loads(current_links)
        except json.JSONDecodeError:
            links = []
    else:
        links = []

    # Check if FEIS link already exists
    for link in links:
        if link.get("source") == "FEIS":
            print(f"  Already has FEIS link")
            conn.close()
            return False

    # Add new link
    links.append(new_link)

    if not dry_run:
        cursor.execute(
            "UPDATE oak_entries SET external_links = ? WHERE scientific_name = ?",
            (json.dumps(links), scientific_name),
        )
        conn.commit()

    conn.close()
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Add FEIS (Fire Effects Information System) links to oak species"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Don't update database, just show what would be done",
    )
    args = parser.parse_args()

    if args.dry_run:
        print("DRY RUN MODE - No database changes will be made\n")

    # Get all species from database
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT scientific_name FROM oak_entries")
    db_species = {row[0] for row in cursor.fetchall()}
    conn.close()

    print(f"Database has {len(db_species)} species")
    print(f"FEIS covers {len(FEIS_SPECIES)} species\n")

    added = 0
    skipped = 0
    not_found = 0

    for species, code in sorted(FEIS_SPECIES.items()):
        if species not in db_species:
            print(f"  {species}: NOT IN DATABASE")
            not_found += 1
            continue

        url = get_feis_url(species)
        link = {
            "source": "FEIS",
            "name": "Fire Effects Information System",
            "url": url,
        }

        print(f"  {species}: ", end="")
        if update_external_links(species, link, args.dry_run):
            print(f"ADDED - {url}")
            added += 1
        else:
            skipped += 1

    print(f"\n{'=' * 60}")
    print("SUMMARY")
    print(f"{'=' * 60}")
    print(f"Added: {added}")
    print(f"Skipped (already had FEIS): {skipped}")
    print(f"Not in database: {not_found}")


if __name__ == "__main__":
    main()
