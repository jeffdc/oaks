#!/usr/bin/env python3
"""
Utility functions for the Quercus scraper
Handles caching, file I/O, progress tracking, and HTTP requests
"""

import os
import json
import time
import requests
from pathlib import Path
from urllib.parse import urlparse

# Configuration - use project-root-relative paths
PROJECT_ROOT = Path(__file__).parent.parent.parent
TMP_SCRAPER_DIR = PROJECT_ROOT / "tmp" / "scraper"

CACHE_DIR = str(TMP_SCRAPER_DIR / "html_cache")
PROGRESS_FILE = str(TMP_SCRAPER_DIR / "scraper_progress.json")
OUTPUT_FILE = str(TMP_SCRAPER_DIR / "oaksoftheworld.json")
INCONSISTENCY_LOG = str(TMP_SCRAPER_DIR / "data_inconsistencies.log")
DELAY_SECONDS = 0.25


def get_cache_path(url):
    """Generate a cache file path for a URL"""
    os.makedirs(CACHE_DIR, exist_ok=True)
    
    # Use URL path as filename (more readable than hash)
    parsed = urlparse(url)
    filename = parsed.path.split('/')[-1]
    if not filename or filename == '':
        filename = 'index.html'
    
    return os.path.join(CACHE_DIR, filename)


def fetch_page(url, use_cache=True, verify_ssl=True):
    """Fetch a page with error handling, rate limiting, and caching

    Args:
        url: The URL to fetch
        use_cache: Whether to use cached version if available
        verify_ssl: Whether to verify SSL certificates (default: True)
    """
    cache_path = get_cache_path(url)

    # Check cache first
    if use_cache and os.path.exists(cache_path):
        try:
            with open(cache_path, 'r', encoding='utf-8') as f:
                print(f"  [CACHE] Using cached version")
                return f.read()
        except Exception as e:
            print(f"  [CACHE] Error reading cache: {e}, fetching fresh")

    # Fetch from web
    try:
        time.sleep(DELAY_SECONDS)
        response = requests.get(url, timeout=10, verify=verify_ssl)
        response.raise_for_status()
        html = response.text

        # Save to cache
        try:
            with open(cache_path, 'w', encoding='utf-8') as f:
                f.write(html)
        except Exception as e:
            print(f"  [CACHE] Warning: Could not save to cache: {e}")

        return html
    except requests.exceptions.SSLError as e:
        print(f"SSL Error fetching {url}: {e}")
        print("  Hint: If the SSL certificate is problematic, you may need to verify the site's security")
        return None
    except requests.RequestException as e:
        print(f"Error fetching {url}: {e}")
        return None


def load_progress():
    """Load progress from previous run"""
    if os.path.exists(PROGRESS_FILE):
        try:
            with open(PROGRESS_FILE, 'r', encoding='utf-8') as f:
                progress = json.load(f)
                print(f"Loaded progress: {len(progress.get('completed', []))} species already processed")
                return progress
        except json.JSONDecodeError:
            print("Warning: Progress file corrupted, starting fresh")
    
    return {
        'species_links': [],
        'synonym_map': {},
        'completed': [],
        'failed': [],
        'species_data': []
    }


def save_progress(progress):
    """Save current progress to disk"""
    with open(PROGRESS_FILE, 'w', encoding='utf-8') as f:
        json.dump(progress, f, indent=2, ensure_ascii=False)


def save_final_output(all_species):
    """Save final JSON output"""
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump({'species': all_species}, f, indent=2, ensure_ascii=False)


def log_inconsistency(message):
    """Log taxonomic notes and synonym chains to a file"""
    with open(INCONSISTENCY_LOG, 'a', encoding='utf-8') as f:
        f.write(f"{message}\n")
    print(f"  [TAXONOMIC NOTE] {message}")


def clear_progress():
    """Clear all progress and cache files"""
    if os.path.exists(PROGRESS_FILE):
        os.remove(PROGRESS_FILE)
    if os.path.exists(INCONSISTENCY_LOG):
        os.remove(INCONSISTENCY_LOG)


def get_cache_count():
    """Get number of cached HTML files"""
    if not os.path.exists(CACHE_DIR):
        return 0
    return len([f for f in os.listdir(CACHE_DIR) if f.endswith('.htm')])


def get_inconsistency_count():
    """Get number of logged inconsistencies"""
    if not os.path.exists(INCONSISTENCY_LOG):
        return 0
    with open(INCONSISTENCY_LOG, 'r') as f:
        return len(f.readlines())