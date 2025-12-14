#!/usr/bin/env python3
"""
Test script for the new name parser
Parses liste.htm and outputs results to a text file for manual inspection
"""

import sys
from name_parser import parse_species_list_html

# Configuration
BASE_URL = "https://oaksoftheworld.fr/"
INPUT_FILE = "html_cache/liste.htm"
OUTPUT_FILE = "parser_test_results.txt"

def main():
    print("="*80)
    print("NAME PARSER TEST")
    print("="*80)
    print(f"\nReading from: {INPUT_FILE}")
    print(f"Writing to: {OUTPUT_FILE}")

    # Read the HTML file
    try:
        with open(INPUT_FILE, 'r', encoding='utf-8') as f:
            html = f.read()
    except FileNotFoundError:
        print(f"ERROR: Could not find {INPUT_FILE}")
        sys.exit(1)

    # Parse the species list
    accepted_species, synonym_map = parse_species_list_html(html, BASE_URL)

    # Sort species by name
    accepted_species.sort(key=lambda x: x['name'].lower())

    # Write results to file
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write("="*100 + "\n")
        f.write("NAME PARSER TEST RESULTS\n")
        f.write("="*100 + "\n\n")

        # Summary statistics
        f.write("SUMMARY STATISTICS\n")
        f.write("-"*100 + "\n\n")

        total_species = len(accepted_species)
        non_hybrids = [s for s in accepted_species if not s['is_hybrid']]
        hybrids = [s for s in accepted_species if s['is_hybrid']]
        species_with_author = [s for s in accepted_species if s['author']]
        species_with_synonyms = [s for s in accepted_species if s['synonyms']]
        total_synonyms = sum(len(s['synonyms']) for s in accepted_species)

        # Calculate total synonym mappings (some synonyms map to multiple species)
        total_synonym_mappings = sum(len(mappings) for mappings in synonym_map.values())
        synonyms_with_multiple_mappings = sum(1 for mappings in synonym_map.values() if len(mappings) > 1)

        f.write(f"Total accepted species:           {total_species}\n")
        f.write(f"  Non-hybrids:                    {len(non_hybrids)}\n")
        f.write(f"  Hybrids:                        {len(hybrids)}\n")
        f.write(f"  Species with authors:           {len(species_with_author)}\n")
        f.write(f"  Species with synonyms:          {len(species_with_synonyms)}\n")
        f.write(f"Total synonyms parsed:            {total_synonyms}\n")
        f.write(f"Unique synonym names:             {len(synonym_map)}\n")
        f.write(f"Total synonym mappings:           {total_synonym_mappings}\n")
        f.write(f"Synonyms with multiple mappings:  {synonyms_with_multiple_mappings}\n")

        # All accepted species
        f.write("\n" + "="*100 + "\n")
        f.write("ALL ACCEPTED SPECIES\n")
        f.write("="*100 + "\n\n")

        for i, species in enumerate(accepted_species, 1):
            f.write(f"{i}. Quercus {species['name']}\n")
            f.write(f"   Type:     {'HYBRID' if species['is_hybrid'] else 'SPECIES'}\n")
            f.write(f"   Author:   {species['author'] if species['author'] else '(none)'}\n")
            f.write(f"   URL:      {species['url']}\n")

            if species['synonyms']:
                f.write(f"   Synonyms: ({len(species['synonyms'])})\n")
                for syn in species['synonyms']:
                    syn_author = f" {syn['author']}" if syn['author'] else ""
                    f.write(f"             - {syn['name']}{syn_author}\n")
            else:
                f.write(f"   Synonyms: (none)\n")

            f.write(f"   {'-'*96}\n\n")

        # List of hybrids only
        f.write("\n" + "="*100 + "\n")
        f.write("HYBRID SPECIES ONLY\n")
        f.write("="*100 + "\n\n")

        if hybrids:
            for i, species in enumerate(hybrids, 1):
                f.write(f"{i}. Quercus × {species['name']}\n")
                f.write(f"   Author:   {species['author'] if species['author'] else '(none)'}\n")
                f.write(f"   URL:      {species['url']}\n")
                f.write(f"   Synonyms: {len(species['synonyms'])}\n")
                f.write(f"   {'-'*96}\n\n")
        else:
            f.write("No hybrids found.\n\n")

        # Synonym map sample
        f.write("\n" + "="*100 + "\n")
        f.write("SYNONYM MAP (first 50 entries)\n")
        f.write("="*100 + "\n\n")

        sorted_synonyms = sorted(synonym_map.items(), key=lambda x: x[0].lower())
        count = 0
        for syn_name, syn_mappings in sorted_synonyms:
            if count >= 50:
                break
            # syn_mappings is now a list of dicts
            if len(syn_mappings) == 1:
                # Single mapping - display on one line
                syn_info = syn_mappings[0]
                accepted = syn_info['accepted_name']
                syn_author = syn_info['synonym_author']
                author_str = f" [{syn_author}]" if syn_author else ""
                count += 1
                f.write(f"{count:3d}. {syn_name}{author_str} → {accepted}\n")
            else:
                # Multiple mappings - display with sub-items
                count += 1
                f.write(f"{count:3d}. {syn_name} → MULTIPLE MAPPINGS ({len(syn_mappings)})\n")
                for syn_info in syn_mappings:
                    accepted = syn_info['accepted_name']
                    syn_author = syn_info['synonym_author']
                    author_str = f" [{syn_author}]" if syn_author else ""
                    f.write(f"       {syn_name}{author_str} → {accepted}\n")

        if len(sorted_synonyms) > 50:
            f.write(f"\n... and {len(sorted_synonyms) - 50} more synonyms ...\n")

        # Synonyms with multiple mappings
        f.write("\n" + "="*100 + "\n")
        f.write("SYNONYMS WITH MULTIPLE MAPPINGS\n")
        f.write("="*100 + "\n\n")

        multi_mappings = [(syn_name, mappings) for syn_name, mappings in sorted_synonyms
                          if len(mappings) > 1]

        if multi_mappings:
            for i, (syn_name, mappings) in enumerate(multi_mappings, 1):
                f.write(f"{i:3d}. {syn_name} ({len(mappings)} mappings)\n")
                for mapping in mappings:
                    accepted = mapping['accepted_name']
                    syn_author = mapping['synonym_author']
                    author_str = f" [{syn_author}]" if syn_author else ""
                    f.write(f"       → {accepted} (as {syn_name}{author_str})\n")
                f.write("\n")
            f.write(f"Total synonyms with multiple mappings: {len(multi_mappings)}\n")
        else:
            f.write("No synonyms with multiple mappings found.\n")

        # Species without authors
        f.write("\n" + "="*100 + "\n")
        f.write("SPECIES WITHOUT AUTHORS (first 20)\n")
        f.write("="*100 + "\n\n")

        no_author = [s for s in accepted_species if not s['author']]
        for i, species in enumerate(no_author[:20], 1):
            type_str = "HYBRID" if species['is_hybrid'] else "SPECIES"
            f.write(f"{i:3d}. Quercus {species['name']} ({type_str})\n")

        if len(no_author) > 20:
            f.write(f"\n... and {len(no_author) - 20} more without authors ...\n")

        f.write(f"\nTotal species without authors: {len(no_author)}\n")

        # Species without synonyms
        f.write("\n" + "="*100 + "\n")
        f.write("SPECIES WITHOUT SYNONYMS (first 20)\n")
        f.write("="*100 + "\n\n")

        no_synonyms = [s for s in accepted_species if not s['synonyms']]
        for i, species in enumerate(no_synonyms[:20], 1):
            type_str = "HYBRID" if species['is_hybrid'] else "SPECIES"
            author_str = f" {species['author']}" if species['author'] else ""
            f.write(f"{i:3d}. Quercus {species['name']}{author_str} ({type_str})\n")

        if len(no_synonyms) > 20:
            f.write(f"\n... and {len(no_synonyms) - 20} more without synonyms ...\n")

        f.write(f"\nTotal species without synonyms: {len(no_synonyms)}\n")

        f.write("\n" + "="*100 + "\n")
        f.write("END OF REPORT\n")
        f.write("="*100 + "\n")

    # Print summary to console
    print("\n" + "="*80)
    print("PARSING COMPLETE")
    print("="*80)
    print(f"\nTotal accepted species:     {total_species}")
    print(f"  Non-hybrids:              {len(non_hybrids)}")
    print(f"  Hybrids:                  {len(hybrids)}")
    print(f"Unique synonym names:       {len(synonym_map)}")
    print(f"Total synonym mappings:     {total_synonym_mappings}")
    print(f"Multiple mappings:          {synonyms_with_multiple_mappings}")
    print(f"\nExpected from source:       374 (356 species + 18 hybrids)")
    print(f"Difference:                 {total_species - 374:+d}")
    print(f"\nResults written to: {OUTPUT_FILE}")
    print("\nPlease review the output file for detailed results.")
    print("="*80)

if __name__ == '__main__':
    main()
