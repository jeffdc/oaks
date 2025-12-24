#!/usr/bin/env python3
"""
Add Flora of North America (FNA) links to oak species.

FNA covers 90 North American oak species. This script adds FNA links
to the external_links field for species that have FNA treatments.

Usage:
    python3 add_fna_links.py
    python3 add_fna_links.py --dry-run
"""

import argparse
import json
import sqlite3
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent
DB_PATH = PROJECT_ROOT / "cli" / "oak_compendium.db"

# FNA URL pattern - species name with underscores
FNA_URL_PATTERN = "https://floranorthamerica.org/Quercus_{name}"

# Species covered by FNA (from efloras.org browse page)
# These are the 90 species with treatments in FNA Volume 3
FNA_SPECIES = [
    "acerifolia",
    "agrifolia",
    "ajoensis",
    "alba",
    "arizonica",
    "arkansana",
    "austrina",
    "berberidifolia",
    "bicolor",
    "boyntonii",
    "buckleyi",
    "carmenensis",
    "chapmanii",
    "chihuahuensis",
    "chrysolepis",
    "coccinea",
    "cornelius-mulleri",
    "depressipes",
    "douglasii",
    "dumosa",
    "durata",
    "ellipsoidalis",
    "emoryi",
    "engelmannii",
    "falcata",
    "fusiformis",
    "gambelii",
    "garryana",
    "geminata",
    "georgiana",
    "graciliformis",
    "gravesii",
    "grisea",
    "havardii",
    "hemisphaerica",
    "hinckleyi",
    "hypoleucoides",
    "ilicifolia",
    "imbricaria",
    "incana",
    "inopina",
    "intricata",
    "john-tuckeri",
    "kelloggii",
    "laceyi",
    "laevis",
    "laurifolia",
    "lobata",
    "lyrata",
    "macrocarpa",
    "margarettae",
    "marilandica",
    "michauxii",
    "minima",
    "mohriana",
    "montana",
    "muehlenbergii",
    "myrtifolia",
    "nigra",
    "oblongifolia",
    "oglethorpensis",
    "pacifica",
    "pagoda",
    "palmeri",
    "palustris",
    "phellos",
    "polymorpha",
    "prinoides",
    "pumila",
    "pungens",
    "robur",
    "robusta",
    "rubra",
    "rugosa",
    "sadleriana",
    "shumardii",
    "similis",
    "sinuata",
    "stellata",
    "tardifolia",
    "texana",
    "tomentella",
    "toumeyi",
    "turbinella",
    "vacciniifolia",
    "vaseyana",
    "velutina",
    "viminea",
    "virginiana",
    "wislizeni",
]


def get_fna_url(species_name):
    """Generate FNA URL for a species."""
    # FNA uses underscores in URLs
    url_name = species_name.replace(" ", "_")
    return FNA_URL_PATTERN.format(name=url_name)


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

    # Check if FNA link already exists
    for link in links:
        if link.get("source") == "FNA":
            print(f"  Already has FNA link")
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
        description="Add Flora of North America links to oak species"
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
    print(f"FNA covers {len(FNA_SPECIES)} species\n")

    added = 0
    skipped = 0
    not_found = 0

    for species in FNA_SPECIES:
        # Try to match with database (handle naming differences)
        if species in db_species:
            db_name = species
        elif species.replace("-", " ") in db_species:
            # Handle hyphenated names like "cornelius-mulleri" -> "cornelius mulleri"
            db_name = species.replace("-", " ")
        else:
            print(f"  {species}: NOT IN DATABASE")
            not_found += 1
            continue

        url = get_fna_url(species)
        link = {
            "source": "FNA",
            "name": "Flora of North America",
            "url": url,
        }

        print(f"  {db_name}: ", end="")
        if update_external_links(db_name, link, args.dry_run):
            print(f"ADDED - {url}")
            added += 1
        else:
            skipped += 1

    print(f"\n{'=' * 60}")
    print("SUMMARY")
    print(f"{'=' * 60}")
    print(f"Added: {added}")
    print(f"Skipped (already had FNA): {skipped}")
    print(f"Not in database: {not_found}")


if __name__ == "__main__":
    main()
