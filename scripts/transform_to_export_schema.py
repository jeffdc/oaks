#!/usr/bin/env python3
"""
Transform scraper output to export schema format.

Converts flat species objects from the scraper into the multi-source
format defined in cli/schema/export_schema.json.

Usage:
    python3 transform_to_export_schema.py [input.json] [output.json]

    Defaults: quercus_data.json -> quercus_export.json
"""

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

# Fields that belong at species level (same regardless of source)
SPECIES_LEVEL_FIELDS = {
    'name',
    'author',
    'is_hybrid',
    'conservation_status',
    'taxonomy',
    'parent1',
    'parent2',
    'parent_formula',
    'hybrids',
    'closely_related_to',
    'subspecies_varieties',
}

# Fields that belong at source level (may vary by source)
SOURCE_LEVEL_FIELDS = {
    'range',
    'growth_habit',
    'leaves',
    'flowers',
    'fruits',
    'bark_twigs_buds',
    'hardiness_habitat',
    'miscellaneous',
    'synonyms',
    'local_names',
    'url',  # becomes source_url
}

SOURCE_ID = 'oaksoftheworld'
SOURCE_NAME = 'Oaks of the World'


def normalize_synonyms(synonyms):
    """Ensure synonyms are in {name, author} format."""
    if not synonyms:
        return []

    normalized = []
    for syn in synonyms:
        if isinstance(syn, str):
            # Parse "name author" format if possible
            normalized.append({'name': syn, 'author': None})
        elif isinstance(syn, dict):
            normalized.append({
                'name': syn.get('name', ''),
                'author': syn.get('author')
            })
    return normalized


def normalize_taxonomy(taxonomy):
    """Ensure taxonomy has all expected fields."""
    if not taxonomy:
        return {
            'genus': 'Quercus',
            'subgenus': None,
            'section': None,
            'subsection': None,
        }

    return {
        'genus': 'Quercus',
        'subgenus': taxonomy.get('subgenus'),
        'section': taxonomy.get('section'),
        'subsection': taxonomy.get('subsection'),
    }


def transform_species(species_data):
    """Transform a single species from flat format to multi-source format."""
    # Extract species-level fields
    transformed = {
        'name': species_data.get('name'),
        'author': species_data.get('author'),
        'is_hybrid': species_data.get('is_hybrid', False),
        'conservation_status': species_data.get('conservation_status'),
        'taxonomy': normalize_taxonomy(species_data.get('taxonomy')),
        'parent1': species_data.get('parent1'),
        'parent2': species_data.get('parent2'),
        'hybrids': species_data.get('hybrids', []),
        'closely_related_to': species_data.get('closely_related_to', []),
        'subspecies_varieties': species_data.get('subspecies_varieties', []),
    }

    # Build source object with source-level fields
    source = {
        'source_id': SOURCE_ID,
        'source_name': SOURCE_NAME,
        'source_url': species_data.get('url'),
        'is_primary': True,
        'range': species_data.get('range'),
        'growth_habit': species_data.get('growth_habit'),
        'leaves': species_data.get('leaves'),
        'flowers': species_data.get('flowers'),
        'fruits': species_data.get('fruits'),
        'bark_twigs_buds': species_data.get('bark_twigs_buds'),
        'hardiness_habitat': species_data.get('hardiness_habitat'),
        'miscellaneous': species_data.get('miscellaneous'),
        'synonyms': normalize_synonyms(species_data.get('synonyms')),
        'local_names': species_data.get('local_names', []),
    }

    transformed['sources'] = [source]

    return transformed


def transform_data(input_data):
    """Transform entire dataset to export schema format."""
    species_list = input_data.get('species', input_data)
    if isinstance(species_list, dict):
        # Handle case where input is already wrapped
        species_list = species_list.get('species', [])

    transformed_species = [transform_species(s) for s in species_list]

    return {
        'metadata': {
            'version': '1.0',
            'exported_at': datetime.now(timezone.utc).isoformat(),
            'species_count': len(transformed_species),
        },
        'species': transformed_species,
    }


def main():
    # Determine input/output paths
    script_dir = Path(__file__).parent
    project_root = script_dir.parent

    input_path = Path(sys.argv[1]) if len(sys.argv) > 1 else project_root / 'quercus_data.json'
    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else project_root / 'quercus_export.json'

    print(f"Reading from: {input_path}")

    with open(input_path, 'r', encoding='utf-8') as f:
        input_data = json.load(f)

    print(f"Transforming {len(input_data.get('species', []))} species...")

    output_data = transform_data(input_data)

    print(f"Writing to: {output_path}")

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)

    print(f"Done! Transformed {output_data['metadata']['species_count']} species.")


if __name__ == '__main__':
    main()
