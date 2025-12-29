#!/usr/bin/env python3
"""
Parser functions for the Quercus scraper
Handles parsing of HTML pages and data extraction
"""

from bs4 import BeautifulSoup
import re
from urllib.parse import urljoin
from utils import log_inconsistency


def normalize_species_name(name, has_hybrid_marker=False):
    """Normalize species name, handling (x) hybrid markers"""
    # Remove (x) marker if present
    name = name.replace('(x)', '').strip()

    # If this is a hybrid, ensure it uses × symbol
    if has_hybrid_marker and '×' not in name and ' x ' not in name.lower():
        # Insert × after "Quercus" if present, or at start
        if name.startswith('Quercus '):
            name = name.replace('Quercus ', 'Quercus × ', 1)
        else:
            name = '× ' + name

    return name


def parse_species_list(html, base_url):
    """Parse the main list page to build synonym map and species list"""
    soup = BeautifulSoup(html, 'html.parser')

    # Data structures to build
    synonym_map = {}  # Maps synonym -> accepted name
    species_info = {}  # Maps species name -> {url, author, is_hybrid, synonyms: []}

    print("\nParsing species list...")

    # Get all text content and split into lines
    body_text = soup.get_text()
    lines = [line.strip() for line in body_text.split('\n') if line.strip()]

    # Parse the HTML to find accepted species (marked with font size="4")
    # These are the only names that should appear as species in the final output
    accepted_species_set = set()  # Set of names that are truly accepted species
    links_map = {}  # Maps species name -> URL (includes both accepted and synonym names with links)

    for link in soup.find_all('a', href=True):
        href = link.get('href', '')
        if 'quercus' in href.lower() and '.htm' in href:
            # Check if this link has a font size="4" child (accepted species marker)
            has_font_4 = link.find('font', size="4") is not None
            text = link.get_text(strip=True)

            if text:
                # Check if this is marked as a hybrid
                has_hybrid_marker = '(x)' in text or '×' in text

                # Remove "Quercus " prefix and (x) marker for mapping
                clean_name = text.replace('Quercus ', '').replace('(x)', '').replace('×', '').strip().split()[0]  # Take first word only

                links_map[clean_name] = {
                    'url': urljoin(base_url, href),
                    'is_hybrid': has_hybrid_marker
                }

                # If this has font size="4", it's an accepted species
                if has_font_4:
                    accepted_species_set.add(clean_name.lower())

    print(f"Found {len(links_map)} linked names")
    print(f"Found {len(accepted_species_set)} accepted species (with font size=4)")

    # Now parse the text content line by line
    i = 0
    while i < len(lines):
        line = lines[i]

        # Skip headers and navigation
        if any(skip in line.lower() for skip in ['list of species', 'accepted names', 'warning', 'names of hybrids']):
            i += 1
            continue

        # Skip single letter navigation (A, B, C, etc.)
        if len(line) <= 3 and line.upper() == line:
            i += 1
            continue

        # Check if line contains (x) marker
        has_hybrid_marker = '(x)' in line
        line_no_marker = line.replace('(x)', '').strip()

        # Case 1: synonym = accepted (e.g., "aaata = corrugata")
        if '=' in line_no_marker:
            parts = line_no_marker.split('=')
            if len(parts) == 2:
                synonym = parts[0].strip()
                accepted = parts[1].strip()

                # Check if the accepted name's link points to a different species name
                # This indicates the accepted name is itself a synonym (synonym chain)
                if accepted in links_map:
                    accepted_url = links_map[accepted]['url']
                    # Extract species name from the URL
                    # URL format: .../quercus_SPECIES.htm
                    url_match = re.search(r'quercus_(\w+)\.htm', accepted_url)
                    species_from_url = url_match.group(1) if url_match else None

                    if species_from_url and species_from_url.lower() != accepted.lower():
                        log_inconsistency(f"Synonym chain: '{synonym} = {accepted}' but '{accepted}' links to quercus_{species_from_url}.htm. This means '{accepted}' is also a synonym of '{species_from_url}'.")
                        # Add the intermediate synonym to the synonym_map
                        synonym_map[accepted] = species_from_url

                # Check for synonym chains: does the synonym itself have a different page?
                if synonym in links_map and accepted in links_map:
                    synonym_url = links_map[synonym]['url']
                    accepted_url = links_map[accepted]['url']

                    if synonym_url != accepted_url:
                        log_inconsistency(f"Synonym chain: '{synonym}' has its own page but is a synonym of '{accepted}'. This indicates '{synonym}' was formerly an accepted name.")

                # Use the accepted name AS-IS from the source
                synonym_map[synonym] = accepted

                # Make sure accepted species exists in our tracking
                if accepted not in species_info:
                    link_info = links_map.get(accepted, {})
                    species_info[accepted] = {
                        'url': link_info.get('url'),
                        'author': None,
                        'is_hybrid': link_info.get('is_hybrid', False) or '×' in accepted or ' x ' in accepted,
                        'synonyms': []
                    }

                species_info[accepted]['synonyms'].append(synonym)

        # Case 2: "name1, name2 : see accepted" (e.g., "margaretta, margarettiae : see stellata")
        elif ': see ' in line_no_marker.lower() or ':see ' in line_no_marker.lower():
            parts = re.split(r':\s*see\s+', line_no_marker, flags=re.IGNORECASE)
            if len(parts) == 2:
                synonyms_part = parts[0].strip()
                accepted = parts[1].strip()

                # Check if the accepted name is itself a synonym (synonym chain)
                if accepted in links_map:
                    accepted_url = links_map[accepted]['url']
                    url_match = re.search(r'quercus_(\w+)\.htm', accepted_url)
                    species_from_url = url_match.group(1) if url_match else None

                    if species_from_url and species_from_url.lower() != accepted.lower():
                        log_inconsistency(f"Synonym chain: ': see {accepted}' but '{accepted}' links to quercus_{species_from_url}.htm. This means '{accepted}' is also a synonym of '{species_from_url}'.")
                        # Add the intermediate synonym to the synonym_map
                        synonym_map[accepted] = species_from_url

                # Split multiple synonyms by comma
                synonyms = [s.strip() for s in synonyms_part.split(',')]

                for synonym in synonyms:
                    if synonym:
                        synonym_map[synonym] = accepted

                        if accepted not in species_info:
                            link_info = links_map.get(accepted, {})
                            species_info[accepted] = {
                                'url': link_info.get('url'),
                                'author': None,
                                'is_hybrid': link_info.get('is_hybrid', False) or '×' in accepted or ' x ' in accepted,
                                'synonyms': []
                            }

                        species_info[accepted]['synonyms'].append(synonym)

        # Case 3: "name (x) Author" or "name Author" (accepted name with optional hybrid marker and author)
        elif line_no_marker and not any(c in line_no_marker for c in '=:'):
            # This could be a species name
            # Check if it's in our links_map
            name_parts = line_no_marker.split()
            if name_parts:
                species_name = name_parts[0]

                if species_name in links_map:
                    # This is an accepted species
                    author = ' '.join(name_parts[1:]) if len(name_parts) > 1 else None
                    link_info = links_map[species_name]

                    # Use (x) marker from the line, not just from the link
                    is_hybrid = has_hybrid_marker or link_info.get('is_hybrid', False) or '×' in species_name or ' x ' in species_name

                    if species_name not in species_info:
                        species_info[species_name] = {
                            'url': link_info['url'],
                            'author': author,
                            'is_hybrid': is_hybrid,
                            'synonyms': []
                        }
                    else:
                        # Update existing entry
                        if author and not species_info[species_name]['author']:
                            species_info[species_name]['author'] = author
                        if is_hybrid:
                            species_info[species_name]['is_hybrid'] = True

        i += 1

    # Resolve synonym chains: if a synonym points to another synonym, resolve to the final name
    def resolve_synonym(name, synonym_map, visited=None):
        """Resolve a synonym chain to the final accepted name"""
        if visited is None:
            visited = set()
        if name in visited:
            # Circular reference, return as-is
            return name
        if name not in synonym_map:
            # This is the final accepted name
            return name
        visited.add(name)
        return resolve_synonym(synonym_map[name], synonym_map, visited)

    # Build final species list (only accepted names with URLs)
    species_list = []
    for name, info in species_info.items():
        if info['url']:  # Only include if we have a URL
            # Only include if this name is in the accepted_species_set
            # (marked with font size="4" in the source HTML)
            if name.lower() in accepted_species_set:
                # Collect all synonyms, including those that pointed to intermediate names
                all_synonyms = []

                # Direct synonyms
                all_synonyms.extend(info['synonyms'])

                # Find synonyms that resolve to this name through chains
                for syn, accepted in synonym_map.items():
                    final_name = resolve_synonym(syn, synonym_map)
                    if final_name.lower() == name.lower() and syn not in all_synonyms:
                        all_synonyms.append(syn)

                # Normalize the name (add × for hybrids)
                full_name = normalize_species_name(f"Quercus {name}", info['is_hybrid'])

                species_list.append({
                    'name': full_name,
                    'url': info['url'],
                    'is_hybrid': info['is_hybrid'],
                    'author': info['author'],
                    'synonyms': [f"Quercus {syn}" for syn in sorted(set(all_synonyms))]
                })

    # Also add the synonym map to help during processing
    print(f"\nParsing complete:")
    print(f"  Accepted species: {len(species_list)}")
    print(f"  Total synonyms: {len(synonym_map)}")
    print(f"  Total entries in source: {len(links_map)}")

    return species_list, synonym_map


def extract_table_data(soup):
    """Extract data from the species page table"""
    data = {}

    # Find the main table
    tables = soup.find_all('table')
    if not tables:
        return data

    # The data is in a table with rows containing labels and values
    for table in tables:
        rows = table.find_all('tr')
        for row in rows:
            cells = row.find_all('td')
            if len(cells) >= 2:
                label = cells[0].get_text(strip=True).lower()
                # Use separator to preserve spaces between elements
                value = cells[1].get_text(separator=' ', strip=True)

                if value and value != '---':
                    data[label] = value

    return data


def parse_taxonomy(misc_text):
    """Extract taxonomy information from miscellaneous field"""
    taxonomy = {}

    if not misc_text:
        return None

    # Look for patterns like "Sub-genus Quercus, Section Quercus, Series Albae"
    subgenus_match = re.search(r'Sub-genus\s+(\w+)', misc_text, re.IGNORECASE)
    section_match = re.search(r'Section\s+(\w+)', misc_text, re.IGNORECASE)
    series_match = re.search(r'Series\s+(\w+)', misc_text, re.IGNORECASE)
    subsection_match = re.search(r'subsection\s+(\w+)', misc_text, re.IGNORECASE)

    if subgenus_match:
        taxonomy['subgenus'] = subgenus_match.group(1)
    if section_match:
        taxonomy['section'] = section_match.group(1)
    if subsection_match:
        taxonomy['subsection'] = subsection_match.group(1)
    if series_match:
        taxonomy['series'] = series_match.group(1)

    return taxonomy if taxonomy else None


def parse_conservation_status(misc_text):
    """Extract conservation status from miscellaneous field"""
    if not misc_text:
        return None

    # Look for IUCN categories
    match = re.search(r'IUCN.*?:\s*([A-Z]{2})', misc_text, re.IGNORECASE)
    if match:
        return match.group(1)

    return None


def parse_hybrid_parents(synonym_text, species_name):
    """Parse hybrid parent formula like 'alba x macrocarpa'

    The parent formula is typically at the end of the synonym text in formats like:
    - "cerris x suber"
    - "alba X macrocarpa" (case insensitive)

    We validate that both parent names:
    - Are at least 3 characters long
    - Contain only letters (no numbers, which would indicate years)
    - Look like plausible species names
    """
    if not synonym_text:
        return None, None, None

    # Look for pattern: "species1 x species2" or "species1 X species2"
    # Prefer matches near the end of the text (more likely to be correct)
    # Species names must be alphabetic and at least 3 chars
    pattern = r'([a-zA-Z]{3,})\s*[xX×]\s*([a-zA-Z]{3,})'

    # Find all matches and use the last one (most likely the actual hybrid formula)
    matches = list(re.finditer(pattern, synonym_text))

    if matches:
        # Use the last match (usually the actual formula at end of text)
        match = matches[-1]
        parent1_name = match.group(1).lower()
        parent2_name = match.group(2).lower()

        # Additional validation: reject common non-species words
        invalid_words = {'var', 'subsp', 'nom', 'non', 'nec', 'illeg', 'inval'}
        if parent1_name in invalid_words or parent2_name in invalid_words:
            return None, None, None

        parent1 = f"Quercus {parent1_name}"
        parent2 = f"Quercus {parent2_name}"
        return synonym_text.strip(), parent1, parent2

    return None, None, None


def split_list_field(text):
    """Split a text field into a list, handling various separators"""
    if not text or text == '---':
        return []

    # Split by semicolon or comma
    items = re.split(r'[;,]', text)
    items = [item.strip() for item in items if item.strip()]
    return items if items else []


def parse_species_page(html, species_name, is_hybrid, stored_author=None, stored_synonyms=None):
    """Parse individual species page"""
    soup = BeautifulSoup(html, 'html.parser')
    table_data = extract_table_data(soup)

    species_data = {
        'name': species_name,
        'is_hybrid': is_hybrid,
        'author': stored_author or table_data.get('author'),  # Prefer author from list page
        'synonyms': stored_synonyms or split_list_field(table_data.get('synonyms', '')),  # Prefer synonyms from list page
        'local_names': split_list_field(table_data.get('local names', '')),
        'range': table_data.get('range'),
        'growth_habit': table_data.get('growth habit'),
        'leaves': table_data.get('leaves'),
        'flowers': table_data.get('flowers'),
        'fruits': table_data.get('fruits'),
        'bark_twigs_buds': table_data.get('bark, twigs and'),
        'hardiness_habitat': table_data.get('hardiness zone, habitat'),
        'miscellaneous': table_data.get('miscellaneous'),
        'subspecies_varieties': split_list_field(table_data.get('subspecies and varieties', ''))
    }

    # Parse taxonomy and conservation status
    misc = species_data.get('miscellaneous', '')
    species_data['taxonomy'] = parse_taxonomy(misc)
    species_data['conservation_status'] = parse_conservation_status(misc)

    # For hybrids, parse parent information
    if is_hybrid:
        synonym_text = table_data.get('synonyms', '')
        formula, parent1, parent2 = parse_hybrid_parents(synonym_text, species_name)
        species_data['parent_formula'] = formula
        species_data['parent1'] = parent1
        species_data['parent2'] = parent2
    else:
        species_data['hybrids'] = []
        species_data['closely_related_to'] = []

    # Clean up None values for optional fields
    cleaned_data = {}
    for key, value in species_data.items():
        if value == '' or value == '---':
            cleaned_data[key] = None
        elif isinstance(value, list) and not value:
            cleaned_data[key] = []
        else:
            cleaned_data[key] = value

    return cleaned_data


def build_hybrid_relationships(species_list):
    """Build bidirectional relationships between species and their hybrids"""
    # Create lookup dictionaries
    species_by_name = {s['name']: s for s in species_list}

    # For each hybrid, add it to its parents' hybrid lists
    for species in species_list:
        if species['is_hybrid']:
            parent1 = species.get('parent1')
            parent2 = species.get('parent2')

            # Extract species name from "Quercus alba" format
            if parent1:
                parent1_name = re.sub(r'^Quercus\s+', '', parent1, flags=re.IGNORECASE).strip()
                if parent1_name in species_by_name:
                    if 'hybrids' not in species_by_name[parent1_name]:
                        species_by_name[parent1_name]['hybrids'] = []
                    if species['name'] not in species_by_name[parent1_name]['hybrids']:
                        species_by_name[parent1_name]['hybrids'].append(species['name'])

            if parent2:
                parent2_name = re.sub(r'^Quercus\s+', '', parent2, flags=re.IGNORECASE).strip()
                if parent2_name in species_by_name:
                    if 'hybrids' not in species_by_name[parent2_name]:
                        species_by_name[parent2_name]['hybrids'] = []
                    if species['name'] not in species_by_name[parent2_name]['hybrids']:
                        species_by_name[parent2_name]['hybrids'].append(species['name'])

    return list(species_by_name.values())
