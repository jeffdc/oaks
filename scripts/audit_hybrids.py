#!/usr/bin/env python3
"""
Audit hybrid naming between OOTW source data and the database.

This script:
1. Checks the 'hybrids' arrays in each species to find references that
   don't match known hybrid species in the database
2. Uses fuzzy matching to find close matches (likely typos/variants)
3. Generates a report and a mapping file for fixing the data
"""

import json
import re
from collections import defaultdict
from difflib import SequenceMatcher
from pathlib import Path

# Paths
PROJECT_ROOT = Path(__file__).parent.parent
HTML_CACHE = PROJECT_ROOT / "tmp" / "scraper" / "html_cache"
DB_EXPORT = PROJECT_ROOT / "web" / "public" / "quercus_data.json"
REPORT_OUTPUT = PROJECT_ROOT / "tmp" / "hybrid_audit_report.txt"
MAPPING_OUTPUT = PROJECT_ROOT / "tmp" / "hybrid_name_mapping.json"


def similarity(a: str, b: str) -> float:
    """Calculate string similarity ratio."""
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()


def parse_hybrids_from_html(html_content: str) -> dict:
    """
    Parse hybrid references from HTML.
    Returns dict with 'link_names' and 'text_names' lists.
    """
    result = {'link_names': [], 'text_names': []}

    # Find the hybrids section pattern
    # Pattern: --- and numerous hybrids = <links>
    hybrid_pattern = r'---\s*and\s+(?:numerous\s+)?hybrids?\s*=\s*(.+?)(?:---|;|$)'
    match = re.search(hybrid_pattern, html_content, re.IGNORECASE | re.DOTALL)

    if not match:
        return result

    hybrid_section = match.group(1)

    # Extract link targets (href="quercus_NAME.htm")
    link_pattern = r'href="quercus_([^"]+)\.htm"'
    for m in re.finditer(link_pattern, hybrid_section, re.IGNORECASE):
        name = m.group(1).strip()
        # Clean up: remove 'x_' prefix if present, handle underscores
        name = re.sub(r'^x_?', '', name)
        name = name.replace('_', ' ')
        result['link_names'].append(name)

    # Extract display text (x NAME pattern, possibly in italics)
    # Matches: x bebbiana, x <i>bebbiana</i>, etc.
    text_pattern = r'x\s*(?:</?i>)?\s*([a-z]+)'
    for m in re.finditer(text_pattern, hybrid_section, re.IGNORECASE):
        name = m.group(1).strip()
        result['text_names'].append(name)

    return result


def load_db_hybrids() -> dict:
    """Load all hybrid species from the database export."""
    with open(DB_EXPORT) as f:
        data = json.load(f)

    # Build lookup: name -> species object
    # Also build a set of all hybrid names (with × prefix stripped)
    all_species = {s['name']: s for s in data['species']}

    hybrid_names = set()
    for s in data['species']:
        if s.get('is_hybrid'):
            # Normalize name: strip × prefix
            name = s['name']
            if name.startswith('× '):
                name = name[2:]
            hybrid_names.add(name.lower())

    return {
        'all_species': all_species,
        'hybrid_names': hybrid_names,
        'hybrid_names_original': {s['name'] for s in data['species'] if s.get('is_hybrid')}
    }


def find_close_matches(name: str, hybrid_names: set, threshold: float = 0.7) -> list:
    """Find hybrid names that are close matches to the given name."""
    matches = []
    name_lower = name.lower()

    for h in hybrid_names:
        if h == name_lower:
            continue  # Skip exact matches
        sim = similarity(name_lower, h)
        if sim >= threshold:
            matches.append((h, sim))

    return sorted(matches, key=lambda x: -x[1])


def main():
    print("Loading database...")
    db_data = load_db_hybrids()
    hybrid_names = db_data['hybrid_names']  # Set of normalized hybrid names (no × prefix)
    all_species = db_data['all_species']
    hybrid_names_original = db_data['hybrid_names_original']  # Original names with × prefix

    print(f"Found {len(hybrid_names)} hybrid species in database")

    # Results tracking
    exact_matches = 0
    close_matches = []  # (species, ref_name, db_name, similarity)
    no_matches = []  # (species, ref_name)
    name_mapping = {}  # OOTW name -> canonical DB name

    # Check every species' hybrids array
    species_with_hybrids = [(name, s) for name, s in all_species.items()
                            if s.get('hybrids') and len(s['hybrids']) > 0]
    print(f"Found {len(species_with_hybrids)} species with hybrid references")

    for species_name, species in species_with_hybrids:
        for ref_name in species['hybrids']:
            ref_lower = ref_name.lower()

            # Check for exact match (normalize: strip × prefix if present)
            ref_normalized = ref_lower.lstrip('× ').strip()

            if ref_normalized in hybrid_names:
                exact_matches += 1
            else:
                # Try to find close matches
                matches = find_close_matches(ref_normalized, hybrid_names)
                if matches:
                    best_match, sim = matches[0]
                    close_matches.append((species_name, ref_name, best_match, sim))
                    # Build mapping
                    if ref_name not in name_mapping:
                        name_mapping[ref_name] = best_match
                else:
                    no_matches.append((species_name, ref_name))

    # Also check HTML for internal OOTW inconsistencies
    text_vs_link_mismatches = []
    html_files = list(HTML_CACHE.glob("*.htm"))
    print(f"Scanning {len(html_files)} HTML files for internal inconsistencies...")

    for html_file in sorted(html_files):
        species_name = html_file.stem.replace('quercus_', '')
        try:
            with open(html_file, 'r', encoding='utf-8', errors='ignore') as f:
                html_content = f.read()
        except Exception:
            continue

        parsed = parse_hybrids_from_html(html_content)
        for i, link_name in enumerate(parsed['link_names']):
            if i < len(parsed['text_names']):
                text_name = parsed['text_names'][i]
                if link_name.lower() != text_name.lower():
                    text_vs_link_mismatches.append((species_name, text_name, link_name))

    # Generate report
    report_lines = []
    report_lines.append("=" * 70)
    report_lines.append("HYBRID NAMING AUDIT REPORT")
    report_lines.append("=" * 70)
    report_lines.append("")
    report_lines.append(f"Database hybrid species: {len(hybrid_names)}")
    report_lines.append(f"Species with hybrid references: {len(species_with_hybrids)}")
    report_lines.append(f"Hybrid references checked: {exact_matches + len(close_matches) + len(no_matches)}")
    report_lines.append(f"  - Exact matches: {exact_matches}")
    report_lines.append(f"  - Close matches (needs review): {len(close_matches)}")
    report_lines.append(f"  - No matches: {len(no_matches)}")
    report_lines.append(f"OOTW internal text/link mismatches: {len(text_vs_link_mismatches)}")
    report_lines.append("")

    # Text vs Link Mismatches (internal inconsistencies in OOTW)
    if text_vs_link_mismatches:
        report_lines.append("-" * 70)
        report_lines.append("OOTW INTERNAL INCONSISTENCIES (text differs from link)")
        report_lines.append("-" * 70)
        report_lines.append("")
        for species, text, link in sorted(set(text_vs_link_mismatches)):
            report_lines.append(f"  {species}: text='{text}' link='{link}'")
        report_lines.append("")

    # Close matches
    if close_matches:
        report_lines.append("-" * 70)
        report_lines.append("CLOSE MATCHES (likely typos - needs review)")
        report_lines.append("-" * 70)
        report_lines.append("These hybrid references in species.hybrids arrays don't exactly")
        report_lines.append("match any hybrid species in the database, but are close.")
        report_lines.append("")
        report_lines.append("Format:")
        report_lines.append("  OOTW: 'name' (parents from OOTW: species that list this hybrid)")
        report_lines.append("  DB:   '× name' (parents from DB: parent1 × parent2)")
        report_lines.append("")

        # Group by (OOTW name, DB name) pair
        by_pair = defaultdict(list)
        for species, ootw, db, sim in close_matches:
            by_pair[(ootw, db, sim)].append(species)

        for (ootw, db, sim), species_list in sorted(by_pair.items(), key=lambda x: -x[0][2]):
            # Get DB hybrid's actual parents
            db_hybrid_name = f"× {db}"
            db_hybrid = all_species.get(db_hybrid_name)
            if db_hybrid:
                db_p1 = db_hybrid.get('parent1', '?')
                db_p2 = db_hybrid.get('parent2', '?')
                db_parents = f"{db_p1} × {db_p2}"
            else:
                db_parents = "hybrid not found in DB"

            ootw_parents = ', '.join(sorted(set(species_list)))

            report_lines.append(f"  OOTW: '{ootw}' (parents: {ootw_parents})")
            report_lines.append(f"  DB:   '{db_hybrid_name}' (parents: {db_parents})")
            report_lines.append(f"  Similarity: {sim:.0%}")
            report_lines.append("")

    # No matches
    if no_matches:
        report_lines.append("-" * 70)
        report_lines.append("NO MATCHES (OOTW-only hybrids)")
        report_lines.append("-" * 70)
        report_lines.append("These hybrid references don't match any hybrid species in the DB")
        report_lines.append("and aren't close enough for fuzzy matching. These are OOTW-only")
        report_lines.append("hybrids that should be added to notes.")
        report_lines.append("")
        report_lines.append("Format: 'hybrid_name' (OOTW parents: species that list this hybrid)")
        report_lines.append("")

        # Group by hybrid name
        by_name = defaultdict(list)
        for species, name in no_matches:
            by_name[name].append(species)

        for name, species_list in sorted(by_name.items()):
            ootw_parents = ', '.join(sorted(set(species_list)))
            report_lines.append(f"  '{name}' (OOTW parents: {ootw_parents})")
        report_lines.append("")

    report = "\n".join(report_lines)

    # Write report
    with open(REPORT_OUTPUT, 'w') as f:
        f.write(report)

    # Read existing mapping file to preserve good_matches
    existing_good_matches = {}
    if MAPPING_OUTPUT.exists():
        try:
            with open(MAPPING_OUTPUT) as f:
                existing_data = json.load(f)
                existing_good_matches = existing_data.get("good_matches", {})
        except Exception:
            pass

    # Build detailed close_matches with parent info
    close_matches_detailed = {}
    by_pair = defaultdict(list)
    for species, ootw, db, sim in close_matches:
        by_pair[(ootw, db, sim)].append(species)

    for (ootw, db, sim), species_list in by_pair.items():
        # Get DB hybrid's actual parents
        db_hybrid_name = f"× {db}"
        db_hybrid = all_species.get(db_hybrid_name)
        if db_hybrid:
            db_p1 = db_hybrid.get('parent1') or '?'
            db_p2 = db_hybrid.get('parent2') or '?'
        else:
            db_p1 = '?'
            db_p2 = '?'

        close_matches_detailed[ootw] = {
            "db_name": db,
            "similarity": round(sim, 2),
            "ootw_parents": sorted(set(species_list)),
            "db_parents": [db_p1, db_p2]
        }

    # Build detailed no_matches with parent info
    no_matches_detailed = {}
    by_name = defaultdict(list)
    for species, name in no_matches:
        by_name[name].append(species)

    for name, species_list in by_name.items():
        no_matches_detailed[name] = {
            "ootw_parents": sorted(set(species_list))
        }

    # Write mapping file
    mapping_data = {
        "description": "Hybrid naming audit - OOTW names vs DB names",
        "good_matches": existing_good_matches,
        "close_matches": close_matches_detailed,
        "no_matches": no_matches_detailed
    }
    with open(MAPPING_OUTPUT, 'w') as f:
        json.dump(mapping_data, f, indent=2)

    print(report)
    print(f"\nReport written to: {REPORT_OUTPUT}")
    print(f"Mapping written to: {MAPPING_OUTPUT}")


if __name__ == "__main__":
    main()
