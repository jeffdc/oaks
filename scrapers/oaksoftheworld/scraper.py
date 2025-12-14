#!/usr/bin/env python3
"""
Scraper for Oaks of the World website
Extracts all Quercus species and hybrid data into JSON format
"""

import os
import sys
from urllib.parse import urljoin

# Import utility functions
from name_parser import parse_species_list_html
from utils import (
    fetch_page,
    load_progress,
    save_progress,
    save_final_output,
    clear_progress,
    get_cache_count,
    get_inconsistency_count,
    CACHE_DIR,
    INCONSISTENCY_LOG,
    OUTPUT_FILE
)

# Import parser functions
from parser import (
    parse_species_list,
    parse_species_page,
    build_hybrid_relationships
)

# Base URL for the Oaks of the World website (HTTPS enabled)
BASE_URL = "https://oaksoftheworld.fr/"
LIST_URL = urljoin(BASE_URL, "liste.htm")

def main():
    # Check for command line arguments
    force_restart = '--restart' in sys.argv
    test_mode = '--test' in sys.argv
    no_cache = '--no-cache' in sys.argv
    no_ssl_verify = '--no-ssl-verify' in sys.argv
    limit = None

    # Check for --limit=N argument
    for arg in sys.argv:
        if arg.startswith('--limit='):
            try:
                limit = int(arg.split('=')[1])
                print(f"Limit mode: Processing only {limit} species")
            except ValueError:
                print("Invalid limit value, ignoring")

    # If --test flag is used, default to 50 species
    if test_mode and limit is None:
        limit = 50
        print(f"Test mode: Processing only {limit} species")

    if no_cache:
        print("Cache disabled: Fetching fresh data from server")
        use_cache = False
    else:
        use_cache = True
        cache_count = get_cache_count()
        if cache_count > 0:
            print(f"Cache enabled: {cache_count} pages cached")

    # SSL verification settings
    verify_ssl = not no_ssl_verify
    if no_ssl_verify:
        print("WARNING: SSL certificate verification disabled")
        import urllib3
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    
    if force_restart:
        print("Force restart requested, ignoring previous progress...")
        clear_progress()
        progress = {
            'species_links': [],
            'synonym_map': {},
            'completed': [],
            'failed': [],
            'species_data': []
        }
    else:
        progress = load_progress()
    
    # Fetch species list if we don't have it yet
    if not progress['species_links']:
        print("Fetching species list...")
        list_html = fetch_page(LIST_URL, use_cache=use_cache, verify_ssl=verify_ssl)
        if not list_html:
            print("Failed to fetch species list")
            return
        
        species_list, synonym_map = parse_species_list_html(list_html, BASE_URL)
        # species_list, synonym_map = parse_species_list(list_html, BASE_URL)
        progress['species_links'] = species_list
        progress['synonym_map'] = synonym_map
        save_progress(progress)
        print(f"Found {len(progress['species_links'])} accepted species")
        print(f"Found {len(progress['synonym_map'])} synonyms")
    else:
        print(f"Using cached species list: {len(progress['species_links'])} accepted species")
        print(f"Using cached synonym map: {len(progress.get('synonym_map', {}))} synonyms")
    
    species_links = progress['species_links']
    completed = set(progress['completed'])
    failed_urls = set(progress['failed'])
    
    # Apply limit if specified
    if limit:
        species_links = species_links[:limit]
        print(f"Limited to first {len(species_links)} species")
    
    # Resume from where we left off
    total = len(species_links)
    remaining = [item for item in species_links if item['url'] not in completed]
    
    if not remaining:
        print("All species already processed!")
    else:
        print(f"\nProgress: {len(completed)}/{total} completed, {len(remaining)} remaining")
        
        # Ask if user wants to retry failed URLs
        if failed_urls:
            print(f"\nFound {len(failed_urls)} previously failed URLs")
            retry = input("Retry failed URLs? (y/n, default=n): ").strip().lower()
            if retry == 'y':
                failed_urls.clear()
                progress['failed'] = []
                remaining = [item for item in species_links if item['url'] not in completed]
    
    # Process remaining species
    for i, item in enumerate(remaining, 1):
        # Skip if previously failed (unless we're retrying)
        if item['url'] in failed_urls:
            continue
        
        current_num = len(completed) + i
        print(f"\nProcessing {current_num}/{total}: {item['name']}")
        
        try:
            page_html = fetch_page(item['url'], use_cache=use_cache, verify_ssl=verify_ssl)
            if not page_html:
                print(f"  Failed to fetch page")
                progress['failed'].append(item['url'])
                save_progress(progress)
                continue
            
            species_data = parse_species_page(
                page_html, 
                item['name'], 
                item['is_hybrid'],
                stored_author=item.get('author'),
                stored_synonyms=item.get('synonyms', [])
            )
            species_data['url'] = item['url']
            
            # Add to progress
            progress['species_data'].append(species_data)
            progress['completed'].append(item['url'])
            
            # Save progress every 10 species
            if len(progress['completed']) % 10 == 0:
                save_progress(progress)
                print(f"  Progress saved ({len(progress['completed'])}/{total})")
            
        except Exception as e:
            print(f"  Error processing {item['name']}: {e}")
            progress['failed'].append(item['url'])
            save_progress(progress)
            continue
    
    # Final save
    save_progress(progress)
    
    # Build hybrid relationships
    print("\nBuilding hybrid relationships...")
    all_species = build_hybrid_relationships(progress['species_data'])
    
    # Sort by name
    all_species.sort(key=lambda x: x['name'])
    
    # Save final output
    save_final_output(all_species)
    
    print(f"\n✓ Saved {len(all_species)} species to {OUTPUT_FILE}")
    
    # Print statistics
    num_hybrids = sum(1 for s in all_species if s['is_hybrid'])
    print(f"  Species: {len(all_species) - num_hybrids}")
    print(f"  Hybrids: {num_hybrids}")
    
    if progress['failed']:
        print(f"\n⚠ Warning: {len(progress['failed'])} URLs failed to process")
        print("  Run again to retry, or use --restart to start fresh")
    else:
        print("\n✓ All species processed successfully!")
    
    print(f"\nUsage:")
    print(f"  python {sys.argv[0]}                 # Continue from last position")
    print(f"  python {sys.argv[0]} --restart       # Start fresh")
    print(f"  python {sys.argv[0]} --test          # Process only first 50 species")
    print(f"  python {sys.argv[0]} --limit=N       # Process only first N species")
    print(f"  python {sys.argv[0]} --no-cache      # Ignore cache, fetch fresh data")
    print(f"  python {sys.argv[0]} --no-ssl-verify # Disable SSL certificate verification")
    print(f"\nCache directory: {CACHE_DIR}/ ({get_cache_count()} files)")
    print(f"  To clear cache: rm -rf {CACHE_DIR}/")

    inconsistency_count = get_inconsistency_count()
    if inconsistency_count > 0:
        print(f"\nTaxonomic notes (synonym chains, etc.): {inconsistency_count} (see {INCONSISTENCY_LOG})")

if __name__ == '__main__':
    main()