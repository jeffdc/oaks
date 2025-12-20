import { writable, derived } from 'svelte/store';
import {
  db,
  getAllSpecies,
  populateFromJson,
  hasData,
  getMetadata,
  getPrimarySource,
  getAllSources,
  getSourceById,
  getSourceCompleteness
} from '../db.js';

// Re-export source helpers for component use
export { getPrimarySource, getAllSources, getSourceById, getSourceCompleteness };

// Store for all species data
export const allSpecies = writable([]);

// Store for loading state
export const isLoading = writable(true);

// Store for error state
export const error = writable(null);

// Store for search query
export const searchQuery = writable('');

// Store for selected species (for detail view)
export const selectedSpecies = writable(null);

// Store for data source info
export const dataSource = writable({ from: null, version: null });

// Derived store: filtered species based on search
export const filteredSpecies = derived(
  [allSpecies, searchQuery],
  ([$allSpecies, $searchQuery]) => {
    if (!$searchQuery) return $allSpecies;

    const query = $searchQuery.toLowerCase();
    return $allSpecies.filter(species => {
      // Search in species name
      if (species.name.toLowerCase().includes(query)) return true;

      // Search in author
      if (species.author && species.author.toLowerCase().includes(query)) return true;

      // Search in synonyms
      if (species.synonyms && species.synonyms.some(syn =>
        syn.name && syn.name.toLowerCase().includes(query)
      )) return true;

      // Search in local names (common names) from all sources
      if (species.sources && species.sources.some(source =>
        source.local_names && source.local_names.some(name =>
          name.toLowerCase().includes(query)
        )
      )) return true;

      // Search in range from primary source
      const primarySource = getPrimarySource(species);
      if (primarySource?.range && primarySource.range.toLowerCase().includes(query)) return true;

      return false;
    });
  }
);

// Derived store: species counts
export const speciesCounts = derived(
  filteredSpecies,
  ($filteredSpecies) => {
    const speciesCount = $filteredSpecies.filter(s => !s.is_hybrid).length;
    const hybridCount = $filteredSpecies.filter(s => s.is_hybrid).length;
    const total = $filteredSpecies.length;
    return { speciesCount, hybridCount, total };
  }
);

// Helper: format species display name
// Options: { abbreviated: true } returns "Q. alba", otherwise "Quercus alba"
// Note: hybrid names already include × in the name (e.g., "× beadlei")
export function formatSpeciesName(species, options = {}) {
  const genus = options.abbreviated ? 'Q.' : 'Quercus';
  return `${genus} ${species.name}`;
}

/**
 * Load species data with IndexedDB caching
 * Strategy:
 * 1. If IndexedDB has data, load from there immediately (fast, offline-capable)
 * 2. Then check JSON for updates in background
 * 3. If IndexedDB is empty, fetch JSON and populate
 */
export async function loadSpeciesData() {
  try {
    isLoading.set(true);
    error.set(null);

    // Check if we have cached data in IndexedDB
    const hasCachedData = await hasData();

    if (hasCachedData) {
      // Load from IndexedDB immediately (fast path)
      const species = await getAllSpecies();
      allSpecies.set(species);

      const metadata = await getMetadata();
      dataSource.set({ from: 'indexeddb', version: metadata.dataVersion });
      isLoading.set(false);

      // Check for updates in background (non-blocking)
      checkForUpdates().catch(err => {
        console.warn('Background update check failed:', err);
      });

      return species;
    }

    // No cached data - fetch from JSON
    return await fetchAndCacheData();
  } catch (err) {
    console.error('Error loading species data:', err);
    error.set(err.message);
    isLoading.set(false);
    throw err;
  }
}

/**
 * Fetch JSON and populate IndexedDB
 */
async function fetchAndCacheData() {
  const response = await fetch(`${import.meta.env.BASE_URL}quercus_data.json`);
  if (!response.ok) {
    throw new Error(`Failed to load data: ${response.statusText}`);
  }

  const data = await response.json();

  // Normalize data format (handle both old flat format and new format with metadata)
  const normalizedData = normalizeJsonData(data);

  // Populate IndexedDB
  await populateFromJson(normalizedData);

  // Load from IndexedDB (ensures consistent data format)
  const species = await getAllSpecies();
  allSpecies.set(species);

  const metadata = await getMetadata();
  dataSource.set({ from: 'json', version: metadata.dataVersion });
  isLoading.set(false);

  return species;
}

/**
 * Check if JSON has newer data than IndexedDB
 */
async function checkForUpdates() {
  try {
    // Bypass browser cache to get fresh data from server
    const response = await fetch(`${import.meta.env.BASE_URL}quercus_data.json`, {
      cache: 'no-store'
    });
    if (!response.ok) return;

    const data = await response.json();
    const normalizedData = normalizeJsonData(data);

    // populateFromJson checks version and only updates if newer
    const count = await populateFromJson(normalizedData);

    if (count > 0) {
      // Data was updated - reload stores
      const species = await getAllSpecies();
      allSpecies.set(species);

      const metadata = await getMetadata();
      dataSource.set({ from: 'json-update', version: metadata.dataVersion });

    }
  } catch (err) {
    // Non-fatal - we already have data
    console.warn('Update check failed:', err);
  }
}

/**
 * Normalize JSON data to match expected format
 * Handles both old flat format and new format with metadata/sources
 */
function normalizeJsonData(data) {
  // If already has metadata, assume it's new format
  if (data.metadata) {
    return data;
  }

  // Old format: { species: [...] } with flat species objects
  // Convert to new format with synthetic metadata
  const species = data.species || data;

  return {
    metadata: {
      version: '1.0-legacy',
      exported_at: new Date().toISOString(),
      species_count: species.length
    },
    species: species.map(s => ({
      ...s,
      // If no sources array, the flat fields are treated as primary source data
      // The UI will handle both formats via getPrimarySource helper
    }))
  };
}

// Helper to find species by name
export function findSpeciesByName(name) {
  let result = null;
  const unsubscribe = allSpecies.subscribe(species => {
    result = species.find(s => s.name === name);
  });
  unsubscribe();
  return result;
}
