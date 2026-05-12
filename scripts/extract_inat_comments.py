#!/usr/bin/env python3
"""
Extract and clean Quercus-related comments from iNaturalist data.

Reads my_inat_comments.json (raw export), filters to Quercus-related comments,
fetches the user's actual identifications from the iNat API, deduplicates,
removes noise, and outputs clean per-species datasets.

Usage:
    # Full pipeline (requires API access)
    python3 scripts/extract_inat_comments.py --user jeffdc

    # With API token for faster rate limits
    python3 scripts/extract_inat_comments.py --user jeffdc --token YOUR_TOKEN

    # Skip API fetch, use cached identifications
    python3 scripts/extract_inat_comments.py --user jeffdc --skip-fetch

    # Filter only (no API fetch, no ID enrichment)
    python3 scripts/extract_inat_comments.py --filter-only

Output:
    data/quercus_comments.json          - All Quercus-related comments (minimal fields)
    data/quercus_mentions_comments.json  - Non-Quercus taxa that mention Quercus in text
    data/inat_identifications.json       - Cached user identifications from API
    data/comments_enriched.json          - Comments enriched with user's ID taxon
    data/comments_cleaned.json           - Final cleaned dataset
    data/comments_by_species.json        - Grouped by user's ID taxon
"""

import argparse
import json
import re
import sqlite3
import sys
import time
import urllib.request
import urllib.parse
from collections import Counter, defaultdict
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DB_PATH = PROJECT_ROOT / "oaks.db"
INPUT_PATH = PROJECT_ROOT / "my_inat_comments.json"
DATA_DIR = PROJECT_ROOT / "data"

INAT_API_BASE = "https://api.inaturalist.org/v1"
PUBLIC_RATE_LIMIT_DELAY = 1.1  # seconds between requests (public API: 60/min)
TOKEN_RATE_LIMIT_DELAY = 0.2   # seconds with token (higher limits)


def load_quercus_taxonomy(db_path):
    """Load all Quercus-related taxonomic names from the oaks database."""
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    names = set()

    cur.execute("SELECT DISTINCT scientific_name FROM species")
    for (name,) in cur.fetchall():
        names.add(name)

    for col in ("section", "subsection", "complex", "subgenus"):
        cur.execute(
            f"SELECT DISTINCT {col} FROM species "
            f"WHERE {col} IS NOT NULL AND {col} != ''"
        )
        for (name,) in cur.fetchall():
            names.add(name)

    conn.close()

    # Also build a regex for detecting Quercus mentions in comment text
    epithets = set()
    for name in names:
        parts = name.split()
        if len(parts) >= 2 and parts[0] == "Quercus":
            epithets.add(parts[1])

    mention_pattern = re.compile(
        r"\bQuercus\b|"
        r"\bQ\.\s*("
        + "|".join(re.escape(e) for e in sorted(epithets, key=len, reverse=True))
        + r")\b|"
        r"\bQ\s+("
        + "|".join(re.escape(e) for e in sorted(epithets, key=len, reverse=True))
        + r")\b",
        re.IGNORECASE,
    )

    print(f"Loaded {len(names)} Quercus-related names from DB")
    return names, mention_pattern


def filter_to_quercus(comments, quercus_names, mention_pattern):
    """Split comments into Quercus-taxon and Quercus-mention datasets."""
    quercus_taxon = []
    quercus_mention = []

    for c in comments:
        taxon = c.get("taxon") or ""
        body = c.get("comment_body") or ""

        is_quercus = taxon.startswith("Quercus") or taxon in quercus_names

        minimal = {
            "observation_id": c["observation_id"],
            "comment_id": c["comment_id"],
            "taxon": c["taxon"],
            "comment_body": c["comment_body"],
        }

        if is_quercus:
            quercus_taxon.append(minimal)
        elif mention_pattern.search(body):
            quercus_mention.append(minimal)

    print(f"Quercus-taxon comments: {len(quercus_taxon)}")
    print(f"Quercus-mention comments: {len(quercus_mention)}")
    return quercus_taxon, quercus_mention


def fetch_identifications(observation_ids, username, token=None):
    """Fetch user's identifications from iNat API for given observation IDs."""
    delay = TOKEN_RATE_LIMIT_DELAY if token else PUBLIC_RATE_LIMIT_DELAY
    headers = {"User-Agent": "OakCompendium/1.0"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    all_identifications = []
    batch_size = 30
    total_batches = (len(observation_ids) + batch_size - 1) // batch_size

    print(f"Fetching IDs for {len(observation_ids)} observations "
          f"({total_batches} batches, ~{delay}s between requests)...")

    est_minutes = (total_batches * delay) / 60
    print(f"Estimated time: {est_minutes:.1f} minutes")

    for i in range(0, len(observation_ids), batch_size):
        batch = observation_ids[i : i + batch_size]
        batch_num = i // batch_size + 1
        obs_id_str = ",".join(str(x) for x in batch)

        page = 1
        while True:
            params = urllib.parse.urlencode(
                {
                    "user_id": username,
                    "observation_id": obs_id_str,
                    "per_page": 200,
                    "page": page,
                }
            )
            url = f"{INAT_API_BASE}/identifications?{params}"
            req = urllib.request.Request(url, headers=headers)

            try:
                with urllib.request.urlopen(req) as resp:
                    result = json.loads(resp.read())
            except urllib.error.HTTPError as e:
                print(f"  ERROR batch {batch_num}: HTTP {e.code}")
                if e.code == 429:
                    print("  Rate limited, waiting 60s...")
                    time.sleep(60)
                    continue
                break

            ids_in_page = result.get("results", [])
            all_identifications.extend(ids_in_page)

            total = result.get("total_results", 0)
            fetched = (page - 1) * 200 + len(ids_in_page)
            if fetched >= total:
                break
            page += 1

        if batch_num % 10 == 0 or batch_num == total_batches:
            print(f"  Batch {batch_num}/{total_batches} "
                  f"({len(all_identifications)} IDs so far)")

        time.sleep(delay)

    print(f"Fetched {len(all_identifications)} total identifications")
    return all_identifications


def resolve_taxon_names(identifications, token=None):
    """Resolve taxon IDs to names for any identifications missing taxon.name."""
    delay = TOKEN_RATE_LIMIT_DELAY if token else PUBLIC_RATE_LIMIT_DELAY
    headers = {"User-Agent": "OakCompendium/1.0"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    missing_ids = set()
    for ident in identifications:
        taxon = ident.get("taxon", {})
        if "name" not in taxon and "id" in taxon:
            missing_ids.add(taxon["id"])

    if not missing_ids:
        return {}

    print(f"Resolving {len(missing_ids)} taxon names...")
    taxon_names = {}

    for i in range(0, len(list(missing_ids)), 30):
        batch = list(missing_ids)[i : i + 30]
        id_str = ",".join(str(x) for x in batch)
        url = f"{INAT_API_BASE}/taxa/{id_str}"
        req = urllib.request.Request(url, headers=headers)

        try:
            with urllib.request.urlopen(req) as resp:
                result = json.loads(resp.read())
            for t in result.get("results", []):
                taxon_names[t["id"]] = t["name"]
        except urllib.error.HTTPError as e:
            print(f"  ERROR resolving taxa: HTTP {e.code}")

        time.sleep(delay)

    print(f"Resolved {len(taxon_names)} taxon names")
    return taxon_names


def build_id_mapping(identifications, taxon_names):
    """Build observation_id -> user's most recent ID mapping."""
    my_ids = {}
    for ident in identifications:
        obs_id = ident["observation"]["id"]
        taxon = ident.get("taxon", {})
        taxon_id = taxon.get("id")
        taxon_name = (
            taxon.get("name")
            or taxon_names.get(taxon_id)
            or f"taxon_{taxon_id}"
        )
        category = ident.get("category", "unknown")
        created = ident["created_at"]

        if obs_id not in my_ids or created > my_ids[obs_id]["created_at"]:
            my_ids[obs_id] = {
                "taxon": taxon_name,
                "category": category,
                "created_at": created,
            }

    return my_ids


def enrich_comments(comments, id_mapping):
    """Add user's ID taxon to each comment."""
    enriched = []
    for c in comments:
        my_id = id_mapping.get(c["observation_id"])
        enriched.append(
            {
                "observation_id": c["observation_id"],
                "comment_id": c["comment_id"],
                "consensus_taxon": c["taxon"],
                "my_id_taxon": my_id["taxon"] if my_id else None,
                "my_id_category": my_id["category"] if my_id else None,
                "comment_body": c["comment_body"],
            }
        )
    return enriched


def deduplicate(comments):
    """Remove duplicate comments by comment_id."""
    seen = set()
    result = []
    for c in comments:
        if c["comment_id"] not in seen:
            seen.add(c["comment_id"])
            result.append(c)
    dupes = len(comments) - len(result)
    if dupes:
        print(f"Removed {dupes} duplicate comments")
    return result


# --- Noise filtering ---

_SIGNAL_KEYWORDS = re.compile(
    r"leaf|leaves|lobe|sinus|sinuses|"
    r"bark|trunk|"
    r"twig|stem|petiole|branch|"
    r"bud|terminal bud|lateral bud|"
    r"acorn|cap\s*scale|peduncle|fruit|nut|"
    r"flower|catkin|"
    r"pubescent|glabrous|glaucous|toment|hair|"
    r"crown\s*lea|shade\s*lea|sapling|sprout|resprout|marcescent|"
    r"growth\s*form|growth\s*habit|canopy|height|"
    r"habitat|soil|calcareous|dry|moist|swamp|upland|ridge|bottomland|"
    r"range|distribution|planted|cultivat|arboretum|"
    r"hybrid|Q\s*[x\u00d7]|"
    r"lobe.{0,10}per\s*side|lobe\s*count|vein|"
    r"variable|plastic|variation|atypical|"
    r"auricul|rhomboid|sessile|coppice|"
    r"section\s|Lobatae|Albae|Cerris|"
    r"Q\.\s*\w+|Q\s+[a-z]{3,}|Quercus",
    re.IGNORECASE,
)

_INAT_HOUSEKEEPING = re.compile(
    r"can you (split|move|remove|crop|separate)|"
    r"move it to a new observation|"
    r"split it out into a separate|"
    r"combine them into a single|"
    r"could you crop it and upload|"
    r"you can split this out|"
    r"should be moved into a separ|"
    r"if these are all from the same tree.*(combine|single)|"
    r"^duplicate$",
    re.IGNORECASE,
)

_CONVERSATIONAL_NOISE = re.compile(
    r"derecho|power\s*line|power\s*outage|"
    r"alaska.*heat|heat.*no power|"
    r"buried here.*difference|frequency of power|"
    r"photos never do these.*justice|feel their majesty|"
    r"tree company made bank|"
    r"just when you think you have it figured out.*curve ball|"
    r"drawings and description are spot on|"
    r"was made a synonym|"
    r"taxonomical nomenclature lacks|"
    r"out of date names|"
    r"oak stumps in his time|"
    r"@\w+this reminded me|"
    r"updated some of the taxon photos|"
    r"^you are welcome\b(?!.*leaf|.*bark|.*bud|.*twig)",
    re.IGNORECASE,
)

_PURE_GALL = re.compile(
    r"gall|wasp|mite|Aceria|gallformers|Callirhytis|"
    r"Andricus|Acraspis|Disholcaspis|Cynipid|Dryocosmus|"
    r"Neuroterus|Amphibolips|Philonix|Druon",
    re.IGNORECASE,
)

_OAK_MORPHOLOGY = re.compile(
    r"leaf|leaves|bark|twig|bud|acorn|stem|branch|"
    r"lobe|sinus|petiole|glabrous|pubescent|glaucous|"
    r"habitat|soil|range|growth|crown|shade",
    re.IGNORECASE,
)


def is_signal(comment):
    """Determine if a comment contains extractable oak facts."""
    body = comment["comment_body"].strip()

    # Very short with no signal keywords
    if len(body) < 30:
        return False

    # iNat observation management
    if _INAT_HOUSEKEEPING.search(body):
        return False

    # Conversational noise without morphological content
    if _CONVERSATIONAL_NOISE.search(body) and not _OAK_MORPHOLOGY.search(body):
        return False

    # Pure gall/insect discussion with no oak morphology
    if _PURE_GALL.search(body) and not _OAK_MORPHOLOGY.search(body):
        return False

    # Short comments without signal keywords
    if len(body) < 80 and not _SIGNAL_KEYWORDS.search(body):
        return False

    return True


def filter_noise(comments):
    """Remove noise comments, keeping only those with extractable oak facts."""
    kept = [c for c in comments if is_signal(c)]
    removed = len(comments) - len(kept)
    print(f"Noise filter: {len(comments)} -> {len(kept)} (removed {removed})")
    return kept


def group_by_species(comments):
    """Group comments by user's ID taxon."""
    groups = defaultdict(list)
    for c in comments:
        key = c.get("my_id_taxon") or c.get("consensus_taxon") or "(unknown)"
        groups[key].append(c)

    # Sort by count descending
    sorted_groups = dict(
        sorted(groups.items(), key=lambda x: -len(x[1]))
    )
    return sorted_groups


def print_summary(grouped):
    """Print a summary of the grouped data."""
    print(f"\n{'='*60}")
    print(f"  Species summary: {len(grouped)} taxa, "
          f"{sum(len(v) for v in grouped.values())} comments")
    print(f"{'='*60}")
    for taxon, comments in grouped.items():
        print(f"  {taxon}: {len(comments)} comments")


def write_json(data, path):
    """Write data to JSON file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    print(f"Wrote {path}")


def main():
    parser = argparse.ArgumentParser(
        description="Extract and clean Quercus comments from iNaturalist data"
    )
    parser.add_argument(
        "--user", default="jeffdc", help="iNaturalist username (default: jeffdc)"
    )
    parser.add_argument(
        "--token", help="iNaturalist API token for higher rate limits"
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=INPUT_PATH,
        help=f"Input JSON file (default: {INPUT_PATH})",
    )
    parser.add_argument(
        "--db",
        type=Path,
        default=DB_PATH,
        help=f"Oaks SQLite database (default: {DB_PATH})",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DATA_DIR,
        help=f"Output directory (default: {DATA_DIR})",
    )
    parser.add_argument(
        "--skip-fetch",
        action="store_true",
        help="Skip API fetch, use cached identifications",
    )
    parser.add_argument(
        "--filter-only",
        action="store_true",
        help="Only filter to Quercus comments, skip API enrichment",
    )
    args = parser.parse_args()

    # Step 1: Load raw comments
    print(f"Loading comments from {args.input}...")
    with open(args.input) as f:
        raw_comments = json.load(f)
    print(f"Loaded {len(raw_comments)} comments")

    # Step 2: Load taxonomy and filter to Quercus
    quercus_names, mention_pattern = load_quercus_taxonomy(args.db)
    quercus_taxon, quercus_mention = filter_to_quercus(
        raw_comments, quercus_names, mention_pattern
    )

    write_json(quercus_taxon, args.output_dir / "quercus_comments.json")
    write_json(quercus_mention, args.output_dir / "quercus_mentions_comments.json")

    if args.filter_only:
        print("\n--filter-only: stopping after Quercus filtering")
        return

    # Step 3: Collect unique observation IDs
    all_quercus = quercus_taxon + quercus_mention
    obs_ids = sorted(set(c["observation_id"] for c in all_quercus))
    print(f"\nUnique observation IDs: {len(obs_ids)}")

    # Step 4: Fetch or load identifications
    id_cache_path = args.output_dir / "inat_identifications.json"

    if args.skip_fetch:
        if id_cache_path.exists():
            print(f"Loading cached identifications from {id_cache_path}...")
            with open(id_cache_path) as f:
                raw_identifications = json.load(f)
            print(f"Loaded {len(raw_identifications)} cached identifications")
        else:
            print(f"ERROR: --skip-fetch but no cache at {id_cache_path}")
            sys.exit(1)
    else:
        raw_identifications = fetch_identifications(
            obs_ids, args.user, args.token
        )
        write_json(raw_identifications, id_cache_path)

    # Step 5: Resolve taxon names and build mapping
    taxon_names = resolve_taxon_names(raw_identifications, args.token)
    id_mapping = build_id_mapping(raw_identifications, taxon_names)
    print(f"ID mapping: {len(id_mapping)} observations with user IDs")

    # Step 6: Enrich, deduplicate, and filter
    enriched = enrich_comments(all_quercus, id_mapping)
    enriched = deduplicate(enriched)
    write_json(enriched, args.output_dir / "comments_enriched.json")

    cleaned = filter_noise(enriched)
    write_json(cleaned, args.output_dir / "comments_cleaned.json")

    # Step 7: Group by species
    grouped = group_by_species(cleaned)
    write_json(grouped, args.output_dir / "comments_by_species.json")

    print_summary(grouped)

    # Stats
    with_id = sum(1 for c in cleaned if c.get("my_id_taxon"))
    without_id = sum(1 for c in cleaned if not c.get("my_id_taxon"))
    print(f"\nComments with user ID: {with_id}")
    print(f"Comments without user ID (comment-only): {without_id}")
    print("\nDone!")


if __name__ == "__main__":
    main()
