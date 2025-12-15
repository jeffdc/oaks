#!/usr/bin/env python3
"""
Import Quercus taxonomy from iNaturalist CSV export.

Reads the extracted quercus-inat.csv file and generates a taxa.yaml file
with proper hierarchy and iNaturalist links.

Usage:
    python3 scripts/import_inat_taxa.py [input.csv] [output.yaml]

    Defaults: data/quercus-inat.csv -> data/taxa-inat.yaml
"""

import csv
import sys
from pathlib import Path
from collections import defaultdict


def parse_inat_csv(csv_path):
    """Parse iNaturalist CSV and extract taxa by rank."""
    taxa_by_id = {}
    taxa_by_rank = defaultdict(list)

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
            taxa_by_rank[rank].append(taxa_by_id[taxon_id])

    return taxa_by_id, taxa_by_rank


def get_parent_name(taxon, taxa_by_id):
    """Get the name of the parent taxon."""
    if not taxon.get('parent_id'):
        return None
    parent = taxa_by_id.get(taxon['parent_id'])
    if parent:
        # For ranks below genus, use just the last part of the name
        name = parent['name']
        # If it's a multi-word name (like "Quercus sect. Lobatae"), extract the last word
        if ' ' in name:
            parts = name.split()
            # Handle "sect.", "subsect.", etc.
            for i, part in enumerate(parts):
                if part.lower() in ('sect.', 'subsect.', 'subg.'):
                    if i + 1 < len(parts):
                        return parts[i + 1]
            return parts[-1]
        return name
    return None


def extract_taxon_name(full_name, rank):
    """Extract just the taxon name from the full scientific name."""
    # Full names like "Quercus subg. Cerris" -> "Cerris"
    # Or "Quercus sect. Lobatae" -> "Lobatae"
    # Or species "Quercus alba" -> "alba"

    parts = full_name.split()

    if rank == 'genus':
        return full_name

    if rank == 'subgenus':
        # Format: "Quercus subg. Name" or just "Name"
        if 'subg.' in parts:
            idx = parts.index('subg.')
            if idx + 1 < len(parts):
                return parts[idx + 1]
        return parts[-1]

    if rank == 'section':
        # Format: "Quercus sect. Name"
        if 'sect.' in parts:
            idx = parts.index('sect.')
            if idx + 1 < len(parts):
                return parts[idx + 1]
        return parts[-1]

    if rank == 'subsection':
        # Format: "Quercus subsect. Name"
        if 'subsect.' in parts:
            idx = parts.index('subsect.')
            if idx + 1 < len(parts):
                return parts[idx + 1]
        return parts[-1]

    if rank == 'complex':
        # Format: varies, often "Q. name complex" or just the name
        # Return the whole thing minus "Quercus" prefix
        if parts[0] == 'Quercus':
            return ' '.join(parts[1:])
        return full_name

    if rank == 'species':
        # Format: "Quercus alba"
        if len(parts) >= 2:
            return parts[1]  # specific epithet
        return full_name

    if rank == 'hybrid':
        # Format: "Quercus × name" or "Quercus name × name"
        if len(parts) >= 2:
            # Return everything after "Quercus"
            return ' '.join(parts[1:])
        return full_name

    if rank in ('subspecies', 'variety'):
        # Format: "Quercus alba var. name"
        return ' '.join(parts[1:])  # Everything after genus

    return parts[-1] if parts else full_name


def generate_yaml(taxa_by_id, taxa_by_rank, output_path):
    """Generate YAML output file."""

    lines = [
        "# Quercus Taxonomy from iNaturalist",
        "# Generated from iNaturalist taxonomy export",
        "#",
        "# Links format:",
        "#   links:",
        "#     - label: iNaturalist",
        "#       url: https://www.inaturalist.org/taxa/...",
        "",
        "subgenera:"
    ]

    # Process subgenera
    for taxon in sorted(taxa_by_rank.get('subgenus', []), key=lambda x: x['name']):
        name = extract_taxon_name(taxon['name'], 'subgenus')
        lines.append(f"  - name: {name}")
        lines.append(f"    author: null")
        lines.append(f"    notes: null")
        lines.append(f"    links:")
        lines.append(f"      - label: iNaturalist")
        lines.append(f"        url: {taxon['url']}")
        lines.append("")

    # Process sections
    lines.append("sections:")
    for taxon in sorted(taxa_by_rank.get('section', []), key=lambda x: x['name']):
        name = extract_taxon_name(taxon['name'], 'section')
        parent = get_parent_name(taxon, taxa_by_id)
        lines.append(f"  - name: {name}")
        if parent:
            lines.append(f"    parent: {parent}")
        lines.append(f"    author: null")
        lines.append(f"    notes: null")
        lines.append(f"    links:")
        lines.append(f"      - label: iNaturalist")
        lines.append(f"        url: {taxon['url']}")
        lines.append("")

    # Process subsections
    lines.append("subsections:")
    for taxon in sorted(taxa_by_rank.get('subsection', []), key=lambda x: x['name']):
        name = extract_taxon_name(taxon['name'], 'subsection')
        parent = get_parent_name(taxon, taxa_by_id)
        lines.append(f"  - name: {name}")
        if parent:
            lines.append(f"    parent: {parent}")
        lines.append(f"    author: null")
        lines.append(f"    notes: null")
        lines.append(f"    links:")
        lines.append(f"      - label: iNaturalist")
        lines.append(f"        url: {taxon['url']}")
        lines.append("")

    # Process complexes
    lines.append("complexes:")
    for taxon in sorted(taxa_by_rank.get('complex', []), key=lambda x: x['name']):
        name = extract_taxon_name(taxon['name'], 'complex')
        parent = get_parent_name(taxon, taxa_by_id)
        lines.append(f"  - name: \"{name}\"")
        if parent:
            lines.append(f"    parent: {parent}")
        lines.append(f"    author: null")
        lines.append(f"    notes: null")
        lines.append(f"    links:")
        lines.append(f"      - label: iNaturalist")
        lines.append(f"        url: {taxon['url']}")
        lines.append("")

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

    return taxa_by_rank


def main():
    script_dir = Path(__file__).parent
    project_root = script_dir.parent

    input_path = Path(sys.argv[1]) if len(sys.argv) > 1 else project_root / 'data' / 'quercus-inat.csv'
    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else project_root / 'data' / 'taxa-inat.yaml'

    print(f"Reading from: {input_path}")

    taxa_by_id, taxa_by_rank = parse_inat_csv(input_path)

    print(f"\nFound taxa by rank:")
    for rank in ['genus', 'subgenus', 'section', 'subsection', 'complex', 'species', 'hybrid', 'subspecies', 'variety', 'infrahybrid']:
        count = len(taxa_by_rank.get(rank, []))
        if count > 0:
            print(f"  {rank}: {count}")

    print(f"\nGenerating: {output_path}")
    generate_yaml(taxa_by_id, taxa_by_rank, output_path)

    print(f"\nDone! Taxa YAML file generated.")
    print(f"  Subgenera: {len(taxa_by_rank.get('subgenus', []))}")
    print(f"  Sections: {len(taxa_by_rank.get('section', []))}")
    print(f"  Subsections: {len(taxa_by_rank.get('subsection', []))}")
    print(f"  Complexes: {len(taxa_by_rank.get('complex', []))}")
    print(f"\nNote: Species ({len(taxa_by_rank.get('species', []))}) and hybrids ({len(taxa_by_rank.get('hybrid', []))}) are not included in taxa.yaml")
    print(f"      They will be imported separately into oak_entries.")


if __name__ == '__main__':
    main()
