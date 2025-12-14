#!/usr/bin/env python3
"""
Scraper for iNaturalist to find hybrid oaks
Searches for hybrids of a given parent species and extracts hybrid names and parent formulas
"""

import sys
import json
import argparse
import re
from urllib.parse import urlencode, quote
import requests
from bs4 import BeautifulSoup


def fetch_page(url, headers=None):
    """Fetch a web page and return its content"""
    if headers is None:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }

    try:
        response = requests.get(url, headers=headers, timeout=30)
        response.raise_for_status()
        return response.text
    except requests.RequestException as e:
        print(f"Error fetching {url}: {e}")
        return None


def parse_hybrid_name(name_text):
    """
    Parse hybrid name from iNaturalist result
    Returns tuple of (species_name, common_name)
    E.g., "Quercus × willdenowiana (Willdenow's Oak)" -> ("willdenowiana", "Willdenow's Oak")
    """
    # Remove "Quercus" prefix and clean up
    name_text = name_text.strip()

    # Extract common name if present (in parentheses)
    common_name = None
    common_match = re.search(r'\(([^)]+)\)', name_text)
    if common_match:
        common_name = common_match.group(1).strip()
        # Remove the common name part from the text
        name_text = re.sub(r'\s*\([^)]+\)', '', name_text)

    # Match patterns like "Quercus × subfalcata" or "Quercus x subfalcata"
    match = re.search(r'Quercus\s*[×x]\s*(\w+)', name_text, re.IGNORECASE)
    if match:
        return match.group(1), common_name

    # Fallback: just remove Quercus and any × or x
    name_text = re.sub(r'Quercus\s*', '', name_text, flags=re.IGNORECASE)
    name_text = re.sub(r'^[×x]\s*', '', name_text)
    return name_text.strip(), common_name


def extract_parent_formula(other_names_text):
    """
    Extract parent formula from "Other Names" section
    E.g., "Quercus falcata × phellos" or "Quercus falcata x phellos"
    """
    if not other_names_text:
        return None

    # Look for patterns like "Quercus species1 × species2"
    match = re.search(r'Quercus\s+(\w+)\s*[×x]\s*(\w+)', other_names_text, re.IGNORECASE)
    if match:
        parent1 = match.group(1).lower()
        parent2 = match.group(2).lower()
        return f"Quercus {parent1} × Quercus {parent2}"

    return None


def search_hybrids(parent_name):
    """
    Search iNaturalist for hybrids of the given parent species
    parent_name: e.g., "falcata" (without "Quercus x" prefix)
    """
    # Construct search URL
    search_query = f"quercus {parent_name} x"
    url = f"https://www.inaturalist.org/search?q={quote(search_query)}"

    print(f"Searching: {url}")

    html = fetch_page(url)
    if not html:
        print("Failed to fetch search results")
        return []

    soup = BeautifulSoup(html, 'html.parser')
    hybrids = []

    # Find all taxon results - everything in div.media.taxon-result is a hybrid
    results = soup.find_all('div', class_='taxon-result')

    print(f"Found {len(results)} taxon results")

    for idx, result in enumerate(results, 1):
        try:
            print(f"\nProcessing result #{idx}...")

            # Get the media-body
            media_body = result.find('div', class_='media-body')
            if not media_body:
                print("  ERROR: no media-body found")
                continue

            # Get the heading with the link
            heading = media_body.find('h4', class_='media-heading')
            if not heading:
                print("  ERROR: no media-heading found")
                continue

            # Find the span.taxon wrapper which contains the scientific name
            taxon_span = heading.find('span', class_='taxon')
            if not taxon_span:
                print("  ERROR: no taxon span found")
                continue

            # Find the <a> tag within the taxon span that contains the sciname
            # There might be multiple links, we need the one with span.sciname
            links = taxon_span.find_all('a')
            link_element = None
            sciname_span = None

            print(f"  Found {len(links)} links in taxon span")
            for idx_link, link in enumerate(links):
                print(f"    Link {idx_link+1}: {link.get('href', 'NO HREF')}")
                print(f"    Link HTML: {str(link)[:150]}")
                sciname = link.find('span', class_='sciname')
                print(f"    Has sciname span: {sciname is not None}")
                if sciname:
                    link_element = link
                    sciname_span = sciname
                    break

            if not link_element or not sciname_span:
                print(f"  ERROR: no link with sciname found")
                # Try a different approach - maybe sciname is adjacent to the link
                sciname_span = taxon_span.find('span', class_='sciname')
                if sciname_span:
                    print(f"  Found sciname span elsewhere in taxon: {str(sciname_span)[:100]}")
                    # Get any link in the taxon span
                    link_element = taxon_span.find('a')
                    if link_element:
                        print(f"  Using first link found: {link_element.get('href')}")
                    else:
                        continue
                else:
                    continue

            print(f"{link_element}")

            # Get the URL (prepend base URL)
            taxon_url = link_element.get('href', '')
            if taxon_url:
                taxon_url = f"https://www.inaturalist.org{taxon_url}"

            # Get the scientific name with spaces between <mark> tags preserved
            # Use separator=' ' to add space between elements
            name_text = sciname_span.get_text(separator=' ', strip=True)

            print(f"  Name: {name_text}")
            print(f"  URL: {taxon_url}")

            # Keep the full Latin name (e.g., "Quercus × subfalcata")
            # Clean up whitespace and ensure proper spacing around ×
            full_latin_name = ' '.join(name_text.split())
            # Ensure space around × or x
            full_latin_name = re.sub(r'\s*×\s*', ' × ', full_latin_name)
            full_latin_name = re.sub(r'\s+x\s+', ' × ', full_latin_name, flags=re.IGNORECASE)

            # Fix word fragments that were split by <mark> tags
            # e.g., "sub falcata" -> "subfalcata"
            # Pattern: lowercase letters, space, lowercase letters (after the × symbol)
            full_latin_name = re.sub(r'(×\s+)([a-z]+)\s+([a-z]+)', r'\1\2\3', full_latin_name)

            print(f"  Cleaned name: {full_latin_name}")

            # Get common name from span.othernames > span.comname
            # This is inside the taxon_span, not the general heading
            common_name = None
            othernames_span = taxon_span.find('span', class_='othernames')
            print(f"  Found othernames span: {othernames_span is not None}")
            if othernames_span:
                comname_span = othernames_span.find('span', class_='comname')
                print(f"  Found comname span: {comname_span is not None}")
                if comname_span:
                    common_name = comname_span.get_text(separator=' ', strip=True)
                    print(f"  Raw common name: '{common_name}'")
                    # Remove parentheses
                    common_name = re.sub(r'^\s*\(?\s*', '', common_name)
                    common_name = re.sub(r'\s*\)?\s*$', '', common_name)

            print(f"  Extracted common name: {common_name}")

            # Get parent formula from "Other Names:" section
            other_names = None
            parent_formula = None

            # Find all p.text-muted and look for "Other Names:"
            muted_paragraphs = media_body.find_all('p', class_='text-muted')
            print(f"  Found {len(muted_paragraphs)} muted paragraphs")
            for p in muted_paragraphs:
                # Use separator=' ' to preserve spaces between <mark> tags
                p_text = p.get_text(separator=' ', strip=True)
                print(f"    Paragraph text: {p_text[:100]}...")
                if 'Other Names:' in p_text or 'Other names:' in p_text:
                    # Extract just the parent formula part (after "Other Names:")
                    other_names = re.sub(r'^.*?Other Names:\s*', '', p_text, flags=re.IGNORECASE)
                    print(f"    Extracted other names: {other_names}")
                    parent_formula = extract_parent_formula(other_names)
                    print(f"    Parent formula from extraction: {parent_formula}")
                    break

            hybrid_data = {
                'name': full_latin_name,
                'common_name': common_name,
                'parent_formula': parent_formula,
                'other_names': other_names,
                'url': taxon_url
            }

            hybrids.append(hybrid_data)
            print(f"  ✓ ADDED hybrid: {full_latin_name}")
            if common_name:
                print(f"    Common name: {common_name}")
            if parent_formula:
                print(f"    Parent formula: {parent_formula}")
            else:
                print(f"    Parent formula: Not found")

        except Exception as e:
            print(f"  ERROR parsing result: {e}")
            import traceback
            traceback.print_exc()
            continue

    return hybrids


def convert_to_quercus_format(hybrids, parent_name):
    """
    Convert hybrid data to the quercus_data.json format
    """
    species_list = []

    for hybrid in hybrids:
        # Parse parent names from formula if available
        parent1 = None
        parent2 = None

        print(f"\nConverting hybrid: {hybrid['name']}")
        print(f"  Parent formula: {hybrid.get('parent_formula')}")

        if hybrid.get('parent_formula'):
            formula = hybrid['parent_formula']
            # Try to match "Quercus species1 × Quercus species2" or "Quercus species1 × species2"
            match = re.search(r'Quercus\s+(\w+)\s*[×xX]\s*(?:Quercus\s+)?(\w+)', formula, re.IGNORECASE)
            if match:
                parent1 = f"Quercus {match.group(1)}"
                parent2 = f"Quercus {match.group(2)}"
                print(f"  ✓ Extracted parents: {parent1}, {parent2}")
            else:
                print(f"  ✗ Could not extract parents from: {formula}")

        # Add common name to local_names if present
        local_names = []
        if hybrid.get('common_name'):
            local_names.append(hybrid['common_name'])

        species_entry = {
            "name": hybrid['name'],
            "is_hybrid": True,
            "author": None,
            "parent1": parent1,
            "parent2": parent2,
            "parent_formula": hybrid.get('parent_formula'),
            "synonyms": [],
            "local_names": local_names,
            "range": None,
            "growth_habit": None,
            "leaves": None,
            "flowers": None,
            "fruits": None,
            "bark_twigs_buds": None,
            "hardiness_habitat": None,
            "miscellaneous": f"Hybrid found via iNaturalist search for Quercus {parent_name}",
            "subspecies_varieties": [],
            "taxonomy": {},
            "conservation_status": None,
            "hybrids": [],
            "closely_related_to": [],
            "url": hybrid.get('url', '')
        }

        print(f"  Final entry parent1: {species_entry['parent1']}")
        print(f"  Final entry parent2: {species_entry['parent2']}")

        species_list.append(species_entry)

    return {
        "species": species_list
    }


def main():
    parser = argparse.ArgumentParser(description='Scrape hybrid oak data from iNaturalist')
    parser.add_argument('parent_name', help='Parent species name (without Quercus prefix), e.g., "falcata"')
    parser.add_argument('-o', '--output', default='inat_hybrids.json', help='Output JSON file (default: inat_hybrids.json)')

    args = parser.parse_args()

    print(f"Searching for hybrids of Quercus {args.parent_name}")

    hybrids = search_hybrids(args.parent_name)

    if not hybrids:
        print("No hybrids found")
        return

    print(f"\nFound {len(hybrids)} hybrid(s)")

    # Convert to quercus_data.json format
    output_data = convert_to_quercus_format(hybrids, args.parent_name)

    # Save to file
    output_file = args.output
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)

    print(f"\nData saved to {output_file}")
    print(f"Total hybrids: {len(output_data['species'])}")


if __name__ == '__main__':
    main()
