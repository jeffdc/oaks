#!/usr/bin/env python3
"""
Name parser for Quercus species list
Parses liste.htm according to rules in docs/parsing_rules.txt
"""

import re
import html
from urllib.parse import urljoin
from utils import log_inconsistency


def extract_links_from_line(line):
    """
    Extract all quercus links from a line.
    Returns list of (href, link_text) tuples.
    """
    links = []
    # Pattern uses non-greedy match to get content between <a> and </a>
    pattern = r'<a\s+href="(quercus_[^"]+\.htm)"[^>]*>(.*?)</a>'

    for match in re.finditer(pattern, line, re.IGNORECASE):
        href = match.group(1)
        link_html = match.group(2)
        # Strip HTML tags from link text and decode HTML entities
        link_text = re.sub(r'<[^>]+>', '', link_html).strip()
        link_text = html.unescape(link_text)
        links.append((href, link_text))

    return links


def extract_species_from_url(url):
    """
    Extract species name from URL like 'quercus_alba.htm' -> 'alba'
    """
    match = re.search(r'quercus_([^.]+)\.htm', url, re.IGNORECASE)
    return match.group(1) if match else None


def strip_html_tags(text):
    """Remove all HTML tags from text and decode HTML entities"""
    text = re.sub(r'<[^>]+>', '', text).strip()
    return html.unescape(text)


def is_hybrid(text):
    """
    Check if text contains hybrid markers: (x) or x.
    Note: Don't rely on whitespace around markers
    """
    return bool(re.search(r'\(x\)|×|x\.', text, re.IGNORECASE))


def parse_line(line, base_url):
    """
    Parse a single line from liste.htm according to parsing_rules.txt

    Returns dict with:
    - entry_type: 'ACCEPTED_SPECIES', 'ACCEPTED_HYBRID', 'SYNONYM_EQUALS', 'SYNONYM_SEE', 'OTHER'
    - species_name: extracted species name
    - author: author string (if present)
    - url: the quercus URL
    - synonyms: list of synonym dicts (for SYNONYM_* types)
    - is_hybrid: boolean
    - raw_line: original line for debugging
    """
    line = line.strip()

    # Extract all links
    links = extract_links_from_line(line)

    if not links:
        # Every line MUST contain at least one link per rules otherwise it is not something we care about
        return None

    # Check if all links match
    unique_hrefs = set(href for href, _ in links)
    if len(unique_hrefs) > 1:
        log_inconsistency(f"Multiple different links in line: {unique_hrefs} - Line: {strip_html_tags(line)}")

    # Use the link (first one if multiple)
    main_href = links[0][0]
    main_url = urljoin(base_url, main_href)

    # Extract species name from URL (this is the source of truth per rules)
    species_from_url = extract_species_from_url(main_href)
    if not species_from_url:
        log_inconsistency(f"Could not extract a species name for Line: {strip_html_tags(line)}")
        return None

    # Get visible text (strip all HTML)
    visible_text = strip_html_tags(line)

    # Determine entry type and parse accordingly

    # Check for SYNONYM_SEE (contains ': see' or ':see' with possible :)
    if re.search(r':\s*see:?\s+', visible_text, re.IGNORECASE):
        return parse_synonym_see(visible_text, main_url, species_from_url, line)

    # Check for SYNONYM_EQUALS (contains '=' with optional spaces before it)
    if re.search(r'\s*=\s+', visible_text):
        return parse_synonym_equals(visible_text, main_url, species_from_url, line)

    # Check if line starts with a link (ACCEPTED_SPECIES or ACCEPTED_HYBRID)
    # Allow optional tags (like <font>) before the link
    if re.match(r'^\s*(?:<[^>]+>)*\s*<a\s+href="quercus_', line, re.IGNORECASE):
        # Check for hybrid markers
        if is_hybrid(visible_text):
            return parse_accepted_hybrid(visible_text, main_url, species_from_url, line)
        else:
            return parse_accepted_species(visible_text, main_url, species_from_url, line)

    # OTHER_LINK - link in middle of line
    return parse_other_link(visible_text, main_url, species_from_url, line)


def parse_accepted_species(visible_text, url, species_from_url, raw_line):
    """
    Parse ACCEPTED_SPECIES: everything after species name is author
    """
    # Extract first word as species name from text
    words = visible_text.split()
    if not words:
        return None

    species_from_text = words[0].strip()
    author = ' '.join(words[1:]).strip() if len(words) > 1 else None

    # Ensure author is None if it's empty
    if author and not author.strip():
        author = None

    # Check if text name matches URL name
    if species_from_text.lower() != species_from_url.lower():
        log_inconsistency(f"Species name mismatch: text='{species_from_text}' vs URL='{species_from_url}'. Using URL name.")

    return {
        'entry_type': 'ACCEPTED_SPECIES',
        'species_name': species_from_url,
        'author': author,
        'url': url,
        'is_hybrid': False,
        'synonyms': [],
        'raw_line': raw_line
    }


def parse_accepted_hybrid(visible_text, url, species_from_url, raw_line):
    """
    Parse ACCEPTED_HYBRID: everything after species name + (x) is author
    Note: hybrid marker may not be separated by whitespace
    """
    # Remove hybrid markers to extract name and author
    # Pattern: species_name (x) author OR species_name(x) author OR × species_name author

    # First, check if it starts with × or x
    if visible_text.startswith('×') or visible_text.lower().startswith('x '):
        # Format: × name author
        text_after_x = re.sub(r'^[×x]\s*', '', visible_text, flags=re.IGNORECASE).strip()
        words = text_after_x.split()
        species_from_text = words[0].strip() if words else None
        author = ' '.join(words[1:]).strip() if len(words) > 1 else None
    else:
        # Format: name (x) author or name(x)author
        # Remove (x) and x. markers
        text_no_marker = re.sub(r'\(x\)|x\.', '', visible_text, flags=re.IGNORECASE).strip()
        words = text_no_marker.split()
        species_from_text = words[0].strip() if words else None
        author = ' '.join(words[1:]).strip() if len(words) > 1 else None

    # Ensure author is None if it's empty or just whitespace
    if author and not author.strip():
        author = None
    elif author:
        author = author.strip()

    # Check if text name matches URL name
    if species_from_text and species_from_text.lower() != species_from_url.lower():
        log_inconsistency(f"Hybrid name mismatch: text='{species_from_text}' vs URL='{species_from_url}'. Using URL name.")

    return {
        'entry_type': 'ACCEPTED_HYBRID',
        'species_name': species_from_url,
        'author': author,
        'url': url,
        'is_hybrid': True,
        'synonyms': [],
        'raw_line': raw_line
    }


def parse_synonym_equals(visible_text, url, species_from_url, raw_line):
    """
    Parse SYNONYM_EQUALS: left = right or left= right
    Left side is synonym (with optional author), right side is accepted name
    Track author for synonym separately
    Handles cases like:
    - "aaata = corrugata"
    - "castaneifolia Morrison, non C.A.Mey.= acutissima"
    """
    # Split on = with optional space before and required space after
    parts = re.split(r'\s*=\s+', visible_text, maxsplit=1)
    if len(parts) != 2:
        return None

    synonym_part = parts[0].strip()
    accepted_part = parts[1].strip()

    # Extract synonym name and author (first word is name, rest is author)
    synonym_words = synonym_part.split()
    synonym_name = synonym_words[0].strip() if synonym_words else None
    synonym_author = ' '.join(synonym_words[1:]).strip() if len(synonym_words) > 1 else None

    # Ensure synonym author is None if empty
    if synonym_author and not synonym_author.strip():
        synonym_author = None

    # Extract accepted name and author from right side - we might have an x signifying a hybrid, ignore that
    accepted_words = accepted_part.split()

    if accepted_words and accepted_words[0].strip().lower() == "x" and len(accepted_words) > 1:
        # Case 1: First word is "x" and there's a second word.
        # The name is the second word (accepted_words[1]).
        accepted_name_text = accepted_words[1].strip()
        # The remaining words for the author start from index 2.
        author_words = accepted_words[2:]
    elif accepted_words:
        # Case 2: accepted_words is not empty, but Case 1 is false.
        # The name is the first word (accepted_words[0]).
        accepted_name_text = accepted_words[0].strip()
        # The remaining words for the author start from index 1.
        author_words = accepted_words[1:]
    else:
        # Case 3: accepted_words is empty.
        accepted_name_text = None
        author_words = []

    # Join the determined remaining author_words
    accepted_author = ' '.join(author_words).strip() if author_words else None

    # Ensure accepted author is None if empty
    if accepted_author and not accepted_author.strip():
        accepted_author = None

    # Check if accepted name from text matches URL
    if accepted_name_text and accepted_name_text.lower() != species_from_url.lower():
        log_inconsistency(f"Synonym target mismatch: text='{accepted_name_text}' vs URL='{species_from_url}'. Using URL name. Line: {raw_line}")

    # Check for hybrid markers in the accepted part
    hybrid = is_hybrid(accepted_part)

    return {
        'entry_type': 'SYNONYM_EQUALS',
        'species_name': species_from_url,
        'author': accepted_author,
        'url': url,
        'is_hybrid': hybrid,
        'synonyms': [{
            'name': synonym_name,
            'author': synonym_author
        }],
        'raw_line': raw_line
    }


def parse_synonym_see(visible_text, url, species_from_url, raw_line):
    """
    Parse SYNONYM_SEE: synonyms : see accepted
    Before ':' may have comma-separated list of synonyms
    Possibly could have see or see:
    """
    parts = re.split(r':\s*see:?\s+', visible_text, maxsplit=1, flags=re.IGNORECASE)
    if len(parts) != 2:
        return None

    synonyms_part = parts[0].strip()
    accepted_part = parts[1].strip()

    # Parse comma-separated synonyms
    synonym_entries = []
    for syn in synonyms_part.split(','):
        syn = syn.strip()
        if syn:
            # Extract name and author
            syn_words = syn.split()
            syn_name = syn_words[0].strip() if syn_words else None
            syn_author = ' '.join(syn_words[1:]).strip() if len(syn_words) > 1 else None

            # Ensure author is None if empty
            if syn_author and not syn_author.strip():
                syn_author = None

            if syn_name:
                synonym_entries.append({
                    'name': syn_name,
                    'author': syn_author
                })

    # Extract accepted name and author
    accepted_words = accepted_part.split()
    accepted_name_text = accepted_words[0].strip() if accepted_words else None
    accepted_author = ' '.join(accepted_words[1:]).strip() if len(accepted_words) > 1 else None

    # Ensure author is None if empty
    if accepted_author and not accepted_author.strip():
        accepted_author = None

    # Check if accepted name matches URL
    if accepted_name_text and accepted_name_text.lower() != species_from_url.lower():
        log_inconsistency(f"Synonym target mismatch: text='{accepted_name_text}' vs URL='{species_from_url}'. Using URL name.")

    # Check for hybrid markers
    hybrid = is_hybrid(accepted_part)

    return {
        'entry_type': 'SYNONYM_SEE',
        'species_name': species_from_url,
        'author': accepted_author,
        'url': url,
        'is_hybrid': hybrid,
        'synonyms': synonym_entries,
        'raw_line': raw_line
    }


def parse_other_link(visible_text, url, species_from_url, raw_line):
    """
    Parse OTHER_LINK: link appears in middle of line
    Apply general rules
    """
    # This is an edge case - try to extract what we can
    # Look for species name pattern in text
    words = visible_text.split()

    # Try to find the species name in the text
    species_from_text = None
    author = None

    for i, word in enumerate(words):
        if word.lower() == species_from_url.lower():
            species_from_text = word
            # Everything after is author
            author = ' '.join(words[i+1:]).strip() if i+1 < len(words) else None
            break

    # Ensure author is None if empty
    if author and not author.strip():
        author = None

    if not species_from_text:
        # Couldn't find species name in text, use URL
        log_inconsistency(f"OTHER_LINK: Could not find species name '{species_from_url}' in text: {visible_text}")

    hybrid = is_hybrid(visible_text)

    return {
        'entry_type': 'OTHER_LINK',
        'species_name': species_from_url,
        'author': author,
        'url': url,
        'is_hybrid': hybrid,
        'synonyms': [],
        'raw_line': raw_line
    }


def parse_species_list_html(html, base_url):
    """
    Parse the entire liste.htm file

    Returns:
    - accepted_species: list of accepted species dicts
    - synonym_map: dict mapping synonym names to accepted names
    """
    lines = html.split('\n')

    accepted_species = {}  # key: species_name, value: species dict
    synonym_map = {}  # key: synonym_name, value: accepted_name

    print("\nParsing species list with new parser...")

    parsed_count = 0
    for line_num, line in enumerate(lines, 1):
        parsed = parse_line(line, base_url)

        if not parsed:
            continue

        parsed_count += 1
        entry_type = parsed['entry_type']
        species_name = parsed['species_name']

        # Handle based on entry type
        if entry_type in ['ACCEPTED_SPECIES', 'ACCEPTED_HYBRID']:
            # This is an accepted species
            if species_name not in accepted_species:
                accepted_species[species_name] = {
                    'name': species_name,
                    'author': parsed['author'],
                    'url': parsed['url'],
                    'is_hybrid': parsed['is_hybrid'],
                    'synonyms': []
                }
            else:
                # Already exists, update if we have better info
                if parsed['author'] and not accepted_species[species_name]['author']:
                    accepted_species[species_name]['author'] = parsed['author']
                # Update is_hybrid if this entry says it's a hybrid
                if parsed['is_hybrid']:
                    accepted_species[species_name]['is_hybrid'] = True

        elif entry_type in ['SYNONYM_EQUALS', 'SYNONYM_SEE', 'OTHER_LINK']:
            # This entry represents synonyms
            for syn in parsed['synonyms']:
                syn_name = syn['name']
                if syn_name:
                    # Support multiple mappings per synonym name
                    if syn_name not in synonym_map:
                        synonym_map[syn_name] = []
                    synonym_map[syn_name].append({
                        'accepted_name': species_name,
                        'synonym_author': syn['author']
                    })

            # Make sure the accepted species exists
            if species_name not in accepted_species:
                accepted_species[species_name] = {
                    'name': species_name,
                    'author': parsed['author'],
                    'url': parsed['url'],
                    'is_hybrid': parsed['is_hybrid'],
                    'synonyms': []
                }

    # Build synonym lists for each accepted species
    for syn_name, syn_mappings in synonym_map.items():
        # syn_mappings is now a list of dicts
        for syn_info in syn_mappings:
            accepted_name = syn_info['accepted_name']
            if accepted_name in accepted_species:
                accepted_species[accepted_name]['synonyms'].append({
                    'name': syn_name,
                    'author': syn_info['synonym_author']
                })

    # Calculate synonym statistics
    total_synonym_mappings = sum(len(mappings) for mappings in synonym_map.values())

    print(f"Parsed {parsed_count} lines")
    print(f"Found {len(accepted_species)} accepted species")
    print(f"Found {len(synonym_map)} unique synonym names ({total_synonym_mappings} total mappings)")

    return list(accepted_species.values()), synonym_map
