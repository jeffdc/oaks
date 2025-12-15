#!/usr/bin/env python3
"""
Import Quercus species from iNaturalist CSV export.

Reads the extracted quercus-inat.csv file and generates a YAML file
suitable for `oak import-bulk`.

Usage:
    python3 scripts/import_inat_species.py [input.csv] [output.yaml]

    Defaults: data/quercus-inat.csv -> data/species-inat.yaml
"""

import csv
import sys
from pathlib import Path
from collections import defaultdict


def parse_inat_csv(csv_path):
    """Parse iNaturalist CSV and build taxa hierarchy."""
    taxa_by_id = {}
    species_entries = []

    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            taxon_id = row['id']
            rank = row['taxonRank']
            name = row['scientificName']
            parent_url = row['parentNameUsageID']
            taxon_url = row['taxonID']

            # Extract parent ID from URL
            parent_id = None
            if parent_url:
                parent_id = parent_url.split('/')[-1]

            taxa_by_id[taxon_id] = {
                'id': taxon_id,
                'name': name,
                'rank': rank,
                'parent_id': parent_id,
                'url': taxon_url,
                'specific_epithet': row.get('specificEpithet', ''),
                'infraspecific_epithet': row.get('infraspecificEpithet', ''),
            }

            # Collect species-level entries
            if rank in ('species', 'hybrid', 'subspecies', 'variety', 'infrahybrid'):
                species_entries.append(taxa_by_id[taxon_id])

    return taxa_by_id, species_entries


def get_taxonomy_chain(taxon, taxa_by_id):
    """Walk up the taxonomy tree to find subgenus, section, subsection, complex."""
    taxonomy = {
        'subgenus': None,
        'section': None,
        'subsection': None,
        'complex': None,
    }

    current = taxon
    visited = set()

    while current and current['id'] not in visited:
        visited.add(current['id'])
        rank = current['rank']

        if rank == 'subgenus':
            # Extract name from "Quercus subg. Cerris" -> "Cerris"
            name = extract_taxon_name(current['name'], rank)
            taxonomy['subgenus'] = name
        elif rank == 'section':
            name = extract_taxon_name(current['name'], rank)
            taxonomy['section'] = name
        elif rank == 'subsection':
            name = extract_taxon_name(current['name'], rank)
            taxonomy['subsection'] = name
        elif rank == 'complex':
            name = extract_taxon_name(current['name'], rank)
            taxonomy['complex'] = name

        # Move to parent
        parent_id = current.get('parent_id')
        if parent_id and parent_id in taxa_by_id:
            current = taxa_by_id[parent_id]
        else:
            break

    return taxonomy


def extract_taxon_name(full_name, rank):
    """Extract just the taxon name from the full scientific name."""
    parts = full_name.split()

    if rank == 'subgenus':
        if 'subg.' in parts:
            idx = parts.index('subg.')
            if idx + 1 < len(parts):
                return parts[idx + 1]
        return parts[-1]

    if rank == 'section':
        if 'sect.' in parts:
            idx = parts.index('sect.')
            if idx + 1 < len(parts):
                return parts[idx + 1]
        return parts[-1]

    if rank == 'subsection':
        if 'subsect.' in parts:
            idx = parts.index('subsect.')
            if idx + 1 < len(parts):
                return parts[idx + 1]
        return parts[-1]

    if rank == 'complex':
        # Return the whole thing minus "Quercus" prefix
        if parts[0] == 'Quercus':
            return ' '.join(parts[1:])
        return full_name

    return parts[-1] if parts else full_name


def extract_species_name(full_name, rank):
    """Extract species name from full scientific name.

    For species: "Quercus alba" -> "alba"
    For hybrids: "Quercus × acutidens" -> "× acutidens"
    For subspecies: "Quercus alba var. latiloba" -> "alba var. latiloba"
    """
    parts = full_name.split()

    if len(parts) < 2:
        return full_name

    # Remove "Quercus" prefix
    if parts[0] == 'Quercus':
        return ' '.join(parts[1:])

    return full_name


def is_hybrid(name, rank):
    """Check if this is a hybrid entry."""
    return rank in ('hybrid', 'infrahybrid') or '×' in name


def generate_yaml(taxa_by_id, species_entries, output_path):
    """Generate YAML output file for oak import-bulk."""

    lines = [
        "# Quercus Species from iNaturalist",
        "# Generated from iNaturalist taxonomy export",
        "#",
        "# Import with: oak import-bulk data/species-inat.yaml --source-id inat",
        "",
    ]

    for entry in sorted(species_entries, key=lambda x: x['name']):
        name = entry['name']
        rank = entry['rank']

        # Get species name (without Quercus prefix)
        species_name = extract_species_name(name, rank)

        # Get taxonomy chain
        taxonomy = get_taxonomy_chain(entry, taxa_by_id)

        # Determine if hybrid
        hybrid = is_hybrid(name, rank)

        lines.append(f"- scientific_name: \"{species_name}\"")
        lines.append(f"  is_hybrid: {str(hybrid).lower()}")

        # Add taxonomy if available
        if taxonomy['subgenus']:
            lines.append(f"  subgenus: {taxonomy['subgenus']}")
        if taxonomy['section']:
            lines.append(f"  section: {taxonomy['section']}")
        if taxonomy['subsection']:
            lines.append(f"  subsection: {taxonomy['subsection']}")
        if taxonomy['complex']:
            lines.append(f"  complex: \"{taxonomy['complex']}\"")

        lines.append("")

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

    return len(species_entries)


def main():
    script_dir = Path(__file__).parent
    project_root = script_dir.parent

    input_path = Path(sys.argv[1]) if len(sys.argv) > 1 else project_root / 'data' / 'quercus-inat.csv'
    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else project_root / 'data' / 'species-inat.yaml'

    print(f"Reading from: {input_path}")

    taxa_by_id, species_entries = parse_inat_csv(input_path)

    # Count by rank
    by_rank = defaultdict(int)
    for entry in species_entries:
        by_rank[entry['rank']] += 1

    print(f"\nFound species-level entries:")
    for rank in ['species', 'hybrid', 'subspecies', 'variety', 'infrahybrid']:
        count = by_rank.get(rank, 0)
        if count > 0:
            print(f"  {rank}: {count}")

    print(f"\nGenerating: {output_path}")
    count = generate_yaml(taxa_by_id, species_entries, output_path)

    print(f"\nDone! Generated {count} species entries.")
    print(f"\nTo import:")
    print(f"  1. Create source: oak source new")
    print(f"     (use source_id: inat, name: iNaturalist)")
    print(f"  2. Import: oak import-bulk {output_path} --source-id inat")


if __name__ == '__main__':
    main()
