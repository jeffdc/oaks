#!/usr/bin/env python3
"""
Fetch IUCN Red List conservation status for oak species.

Queries the IUCN Red List API v4 for each species in the database
and updates the conservation_status field.

Usage:
    python3 fetch_status.py --token YOUR_API_TOKEN
    python3 fetch_status.py --token YOUR_API_TOKEN --dry-run
    python3 fetch_status.py --token YOUR_API_TOKEN --restart

Get an API token at: https://api.iucnredlist.org/users/sign_up
"""

import argparse
import json
import os
import sqlite3
import sys
import time
from datetime import datetime
from pathlib import Path

import requests

# Configuration
PROJECT_ROOT = Path(__file__).parent.parent.parent
TMP_DIR = PROJECT_ROOT / "tmp" / "iucn"
DB_PATH = PROJECT_ROOT / "cli" / "oak_compendium.db"

PROGRESS_FILE = TMP_DIR / "iucn_progress.json"
DISCREPANCY_LOG = TMP_DIR / "conservation_discrepancies.log"
ERROR_LOG = TMP_DIR / "iucn_errors.log"

API_BASE = "https://api.iucnredlist.org/api/v4"
DELAY_SECONDS = 2.0  # Be polite to the server

# IUCN conservation status codes
VALID_STATUSES = {
    "NE": "Not Evaluated",
    "DD": "Data Deficient",
    "LC": "Least Concern",
    "NT": "Near Threatened",
    "VU": "Vulnerable",
    "EN": "Endangered",
    "CR": "Critically Endangered",
    "EW": "Extinct in the Wild",
    "EX": "Extinct",
}


def setup_directories():
    """Create necessary directories"""
    TMP_DIR.mkdir(parents=True, exist_ok=True)


def load_progress():
    """Load progress from previous run"""
    if PROGRESS_FILE.exists():
        try:
            with open(PROGRESS_FILE, "r") as f:
                progress = json.load(f)
                print(f"Loaded progress: {len(progress.get('completed', []))} species already processed")
                return progress
        except json.JSONDecodeError:
            print("Warning: Progress file corrupted, starting fresh")

    return {
        "completed": [],
        "failed": [],
        "not_found": [],
        "updated": [],
        "discrepancies": [],
    }


def save_progress(progress):
    """Save current progress to disk"""
    with open(PROGRESS_FILE, "w") as f:
        json.dump(progress, f, indent=2)


def clear_progress():
    """Clear progress file"""
    if PROGRESS_FILE.exists():
        PROGRESS_FILE.unlink()
    if DISCREPANCY_LOG.exists():
        DISCREPANCY_LOG.unlink()
    if ERROR_LOG.exists():
        ERROR_LOG.unlink()


def log_discrepancy(message):
    """Log conservation status discrepancy"""
    timestamp = datetime.now().isoformat()
    with open(DISCREPANCY_LOG, "a") as f:
        f.write(f"[{timestamp}] {message}\n")
    print(f"  [DISCREPANCY] {message}")


def log_error(message):
    """Log API errors"""
    timestamp = datetime.now().isoformat()
    with open(ERROR_LOG, "a") as f:
        f.write(f"[{timestamp}] {message}\n")


def get_species_from_db():
    """Get all species from the database"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "SELECT scientific_name, conservation_status, is_hybrid FROM oak_entries ORDER BY scientific_name"
    )
    species = cursor.fetchall()
    conn.close()
    return species


def update_conservation_status(scientific_name, status):
    """Update conservation status in the database"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE oak_entries SET conservation_status = ? WHERE scientific_name = ?",
        (status, scientific_name),
    )
    conn.commit()
    conn.close()


def fetch_iucn_status(scientific_name, token):
    """
    Fetch conservation status from IUCN API v4.

    Returns tuple: (status_code, assessment_url) or (None, None) if not found
    """
    # IUCN expects genus and species separately
    # Our species names are like "alba" (without Quercus prefix)
    genus = "Quercus"
    species = scientific_name

    # Handle hybrids - they typically won't be in IUCN
    # The is_hybrid check is done in the main loop, but also check name patterns as fallback
    if "×" in species or " x " in species or species.startswith("x "):
        return None, None, "hybrid"

    url = f"{API_BASE}/taxa/scientific_name"
    params = {
        "genus_name": genus,
        "species_name": species,
    }
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    }

    try:
        time.sleep(DELAY_SECONDS)
        response = requests.get(url, params=params, headers=headers, timeout=30)

        if response.status_code == 401:
            print("ERROR: Invalid API token")
            sys.exit(1)
        elif response.status_code == 404:
            return None, None, "not_found"
        elif response.status_code == 429:
            print("  [RATE LIMITED] Waiting 60 seconds...")
            time.sleep(60)
            return fetch_iucn_status(scientific_name, token)
        elif response.status_code != 200:
            log_error(f"{scientific_name}: HTTP {response.status_code} - {response.text}")
            return None, None, f"http_{response.status_code}"

        data = response.json()

        # The API returns assessments for the species
        # We need to find the latest assessment and get its category
        if not data.get("assessments") or len(data["assessments"]) == 0:
            return None, None, "no_assessments"

        # Get the latest assessment (should be first, but let's be safe)
        latest = None
        for assessment in data["assessments"]:
            if assessment.get("latest", False):
                latest = assessment
                break

        if not latest:
            # If no "latest" flag, use the first one
            latest = data["assessments"][0]

        category = latest.get("red_list_category_code")
        assessment_url = latest.get("url", "")

        if category and category in VALID_STATUSES:
            return category, assessment_url, "success"
        else:
            log_error(f"{scientific_name}: Unknown category: {category}")
            return None, None, "unknown_category"

    except requests.exceptions.Timeout:
        log_error(f"{scientific_name}: Request timeout")
        return None, None, "timeout"
    except requests.exceptions.RequestException as e:
        log_error(f"{scientific_name}: Request error: {e}")
        return None, None, "request_error"
    except json.JSONDecodeError as e:
        log_error(f"{scientific_name}: JSON decode error: {e}")
        return None, None, "json_error"


def main():
    parser = argparse.ArgumentParser(
        description="Fetch IUCN Red List conservation status for oak species"
    )
    parser.add_argument(
        "--token",
        required=True,
        help="IUCN API token (get one at https://api.iucnredlist.org/users/sign_up)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Don't update database, just show what would be done",
    )
    parser.add_argument(
        "--restart",
        action="store_true",
        help="Start fresh, ignore previous progress",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limit number of species to process (0 = all)",
    )
    args = parser.parse_args()

    setup_directories()

    if args.restart:
        clear_progress()
        print("Cleared previous progress")

    progress = load_progress()
    species_list = get_species_from_db()

    print(f"\nFound {len(species_list)} species in database")
    print(f"Already processed: {len(progress['completed'])}")
    print(f"Rate limiting: {DELAY_SECONDS} seconds between requests")
    if args.dry_run:
        print("DRY RUN MODE - No database changes will be made")
    print()

    processed = 0
    for scientific_name, current_status, is_hybrid in species_list:
        if scientific_name in progress["completed"]:
            continue

        if args.limit > 0 and processed >= args.limit:
            print(f"\nReached limit of {args.limit} species")
            break

        processed += 1
        print(f"[{processed}/{len(species_list) - len(progress['completed'])}] Quercus {scientific_name}...", end=" ")

        # Skip hybrids - they aren't in IUCN Red List
        if is_hybrid:
            print("skipped (hybrid)")
            progress["completed"].append(scientific_name)
            continue

        iucn_status, url, result = fetch_iucn_status(scientific_name, args.token)

        if result == "hybrid":
            print("skipped (hybrid)")
            progress["completed"].append(scientific_name)
        elif result == "not_found" or result == "no_assessments":
            print("not in IUCN")
            progress["not_found"].append(scientific_name)
            progress["completed"].append(scientific_name)
        elif result != "success":
            print(f"error: {result}")
            progress["failed"].append(scientific_name)
        else:
            # Successfully got IUCN status
            status_name = VALID_STATUSES.get(iucn_status, iucn_status)

            if current_status and current_status != iucn_status:
                # Discrepancy between database and IUCN
                log_discrepancy(
                    f"Quercus {scientific_name}: DB={current_status}, IUCN={iucn_status} ({status_name})"
                )
                progress["discrepancies"].append({
                    "species": scientific_name,
                    "db_status": current_status,
                    "iucn_status": iucn_status,
                    "url": url,
                })
                print(f"DISCREPANCY: {current_status} → {iucn_status}")
            elif current_status == iucn_status:
                print(f"{iucn_status} (matches)")
            else:
                # No existing status, update it
                if not args.dry_run:
                    update_conservation_status(scientific_name, iucn_status)
                print(f"{iucn_status} ({status_name}) - UPDATED")
                progress["updated"].append(scientific_name)

            progress["completed"].append(scientific_name)

        # Save progress every 10 species
        if processed % 10 == 0:
            save_progress(progress)

    save_progress(progress)

    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Total processed: {len(progress['completed'])}")
    print(f"Updated: {len(progress['updated'])}")
    print(f"Not in IUCN: {len(progress['not_found'])}")
    print(f"Discrepancies: {len(progress['discrepancies'])}")
    print(f"Failed: {len(progress['failed'])}")

    if progress["discrepancies"]:
        print(f"\nDiscrepancy log: {DISCREPANCY_LOG}")
    if progress["failed"]:
        print(f"Error log: {ERROR_LOG}")


if __name__ == "__main__":
    main()
