/**
 * IndexedDB Schema for Quercus Database
 *
 * Uses Dexie.js for cleaner IndexedDB API.
 *
 * Design Decisions:
 * - Single 'species' table stores denormalized species data with sources array
 * - Primary key is 'name' (species epithet, unique)
 * - Minimal indexes (name, is_hybrid) - complex filtering done in-memory
 * - Each species has a sources[] array; source with is_primary=true is canonical
 * - Data populated from JSON export on first load or updates
 */

import Dexie from 'dexie';

// Database instance
export const db = new Dexie('QuercusDB');

// Schema definition
// Syntax: 'primaryKey, index1, index2, ...'
// Keep indexes minimal - use in-memory filtering for complex queries (~670 species)
db.version(1).stores({
  species: 'name, is_hybrid',
  metadata: 'key'
});

// Version 2: Add sources table for full source metadata
db.version(2).stores({
  species: 'name, is_hybrid',
  metadata: 'key',
  sources: 'id'
});

/**
 * Schema Documentation:
 *
 * species table:
 *   - name (primary key): Species epithet, e.g., 'alba'
 *   - is_hybrid (indexed): Boolean for filtering hybrids vs species
 *
 *   Species-level fields (same across all sources):
 *   - author, taxonomy, conservation_status, parent1, parent2,
 *     hybrids, closely_related_to, subspecies_varieties
 *
 *   Source-attributed fields (in sources array, may vary by source):
 *   - sources[]: Array of source objects, each containing:
 *     - source_id, source_name, source_url, is_primary
 *     - range, growth_habit, leaves, flowers, fruits,
 *       bark, twigs, buds, hardiness_habitat, miscellaneous
 *     - synonyms, local_names
 *
 *   The source with is_primary=true is the canonical/synthesized source
 *   displayed by default. Users can switch sources in detail view.
 *
 * metadata table:
 *   - key (primary key): 'dataVersion', 'lastUpdated', etc.
 *   - value: The metadata value
 *
 * Query Strategy:
 *   - Indexed queries: by name (primary key), is_hybrid
 *   - All other filtering done in-memory after loading all species
 *   - This is fast enough for ~670 species dataset
 */

/**
 * Populate database from JSON export
 * @param {Object} jsonData - Parsed JSON from export file
 * @returns {Promise<number>} Number of species inserted
 */
export async function populateFromJson(jsonData) {
  const { metadata, species, sources } = jsonData;

  // Check if we need to update
  const currentVersion = await db.metadata.get('dataVersion');
  if (currentVersion?.value === metadata?.version) {
    return 0;
  }

  // Clear and repopulate (full replacement strategy)
  await db.transaction('rw', db.species, db.metadata, db.sources, async () => {
    await db.species.clear();
    await db.species.bulkAdd(species);

    // Store sources metadata if provided
    if (sources?.length) {
      await db.sources.clear();
      await db.sources.bulkAdd(sources);
    }

    // Store metadata
    await db.metadata.put({ key: 'dataVersion', value: metadata?.version || '1.0' });
    await db.metadata.put({ key: 'lastUpdated', value: metadata?.exported_at || new Date().toISOString() });
    await db.metadata.put({ key: 'speciesCount', value: species.length });
  });

  return species.length;
}

/**
 * Get all species sorted by name (species before hybrids)
 * @returns {Promise<Array>} All species sorted: non-hybrids first, then hybrids, alphabetically within each group
 */
export async function getAllSpecies() {
  const all = await db.species.toArray();
  return all.sort((a, b) => {
    // Species before hybrids
    if (a.is_hybrid !== b.is_hybrid) {
      return a.is_hybrid ? 1 : -1;
    }
    // Alphabetically within group
    return a.name.localeCompare(b.name);
  });
}

/**
 * Get a single species by name
 * @param {string} name - Species epithet
 * @returns {Promise<Object|undefined>} Species object or undefined
 */
export async function getSpeciesByName(name) {
  return db.species.get(name);
}

/**
 * Get species counts
 * @returns {Promise<Object>} Counts object with speciesCount, hybridCount, total
 */
export async function getSpeciesCounts() {
  const [speciesCount, hybridCount] = await Promise.all([
    db.species.where('is_hybrid').equals(false).count(),
    db.species.where('is_hybrid').equals(true).count()
  ]);
  return {
    speciesCount,
    hybridCount,
    total: speciesCount + hybridCount
  };
}

/**
 * Count populated (non-null, non-empty) fields in a source object
 * Used for selecting the most complete source when no preferred flag is set
 * @param {Object} source - Source object
 * @returns {number} Count of populated fields
 */
function countPopulatedFields(source) {
  if (!source) return 0;

  const fieldsToCheck = [
    'local_names', 'range', 'growth_habit', 'leaves', 'flowers',
    'fruits', 'bark', 'twigs', 'buds', 'hardiness_habitat', 'miscellaneous', 'url'
  ];

  return fieldsToCheck.reduce((count, field) => {
    const value = source[field];
    if (value === null || value === undefined) return count;
    if (Array.isArray(value) && value.length === 0) return count;
    if (typeof value === 'string' && value.trim() === '') return count;
    return count + 1;
  }, 0);
}

/**
 * Get the default/primary source for a species
 * Selection priority:
 *   1. Source with is_preferred === true AND has substantive content
 *   2. Source with most populated fields
 *   3. First source in array
 * @param {Object} species - Species object
 * @returns {Object|null} Selected source or null if no sources
 */
export function getPrimarySource(species) {
  if (!species?.sources?.length) return null;

  // Sort all sources by completeness
  const sorted = [...species.sources].sort((a, b) =>
    countPopulatedFields(b) - countPopulatedFields(a)
  );

  // Priority 1: Check for is_preferred flag with substantive content
  const preferred = species.sources.find(s => s.is_preferred);
  if (preferred) {
    const preferredCount = countPopulatedFields(preferred);
    const bestCount = countPopulatedFields(sorted[0]);
    // Use preferred source if it has at least 2 fields OR is the most complete
    if (preferredCount >= 2 || preferredCount >= bestCount) {
      return preferred;
    }
    // Fall through to most complete source if preferred is too sparse
  }

  // Priority 2: Select source with most populated fields
  return sorted[0];
}

/**
 * Get all sources for a species
 * @param {Object} species - Species object
 * @returns {Array} Array of source objects
 */
export function getAllSources(species) {
  return species?.sources || [];
}

/**
 * Get a specific source by ID
 * @param {Object} species - Species object
 * @param {number} sourceId - Source ID to find
 * @returns {Object|null} Source object or null if not found
 */
export function getSourceById(species, sourceId) {
  if (!species?.sources?.length) return null;
  return species.sources.find(s => s.source_id === sourceId) || null;
}

/**
 * Get source completeness score (for display purposes)
 * @param {Object} source - Source object
 * @returns {number} Number of populated fields (0-10)
 */
export function getSourceCompleteness(source) {
  return countPopulatedFields(source);
}

/**
 * Get all unique sources with full metadata and coverage statistics
 * Merges stored source metadata with derived coverage stats from species
 * @returns {Promise<Array>} Array of source objects with:
 *   - Full metadata: id, name, source_type, description, author, year, url, isbn, doi, notes, license, license_url
 *   - Coverage stats: species_count, coverage_percent, species_names
 */
export async function getAllSourcesInfo() {
  const allSpecies = await db.species.toArray();
  const totalSpecies = allSpecies.length;

  // Try to get stored source metadata
  let storedSources = [];
  try {
    storedSources = await db.sources.toArray();
  } catch (e) {
    // Table might not exist yet
  }

  // Build map of stored source metadata by ID
  const sourceMetaMap = new Map();
  for (const s of storedSources) {
    sourceMetaMap.set(s.id, s);
  }

  // Map to accumulate coverage and fallback info: source_id -> { species_names[], fallback }
  const coverageMap = new Map();

  for (const species of allSpecies) {
    if (!species.sources?.length) continue;

    for (const source of species.sources) {
      const id = source.source_id;
      if (!coverageMap.has(id)) {
        // Store fallback info from species source data
        coverageMap.set(id, {
          species_names: [],
          fallback: {
            source_name: source.source_name,
            source_url: source.source_url,
            license: source.license,
            license_url: source.license_url
          }
        });
      }
      coverageMap.get(id).species_names.push(species.name);
    }
  }

  // Merge metadata with coverage stats
  const sources = [];
  for (const [id, data] of coverageMap) {
    const meta = sourceMetaMap.get(id);
    const fallback = data.fallback;
    const speciesNames = data.species_names;

    sources.push({
      // Full metadata from sources table, with fallback to species source data
      source_id: id,
      source_name: meta?.name || fallback.source_name || `Source ${id}`,
      source_type: meta?.source_type || null,
      description: meta?.description || null,
      author: meta?.author || null,
      year: meta?.year || null,
      source_url: meta?.url || fallback.source_url || null,
      isbn: meta?.isbn || null,
      doi: meta?.doi || null,
      notes: meta?.notes || null,
      license: meta?.license || fallback.license || null,
      license_url: meta?.license_url || fallback.license_url || null,
      // Coverage stats
      species_names: speciesNames,
      species_count: speciesNames.length,
      coverage_percent: totalSpecies > 0
        ? Math.round((speciesNames.length / totalSpecies) * 100)
        : 0
    });
  }

  // Sort: species before hybrids, then by count descending
  sources.sort((a, b) => b.species_count - a.species_count);

  return sources;
}

/**
 * Get detailed info for a single source by ID
 * @param {number} sourceId - Source ID to look up
 * @returns {Promise<Object|null>} Source info with full metadata and stats, or null if not found
 */
export async function getSourceInfo(sourceId) {
  const allSources = await getAllSourcesInfo();
  return allSources.find(s => s.source_id === sourceId) || null;
}

/**
 * Get all species that have data from a specific source
 * @param {number} sourceId - Source ID to filter by
 * @returns {Promise<Array>} Array of species objects (species before hybrids, then alphabetically)
 */
export async function getSpeciesBySource(sourceId) {
  const allSpecies = await db.species.toArray();
  return allSpecies
    .filter(species => species.sources?.some(s => s.source_id === sourceId))
    .sort((a, b) => {
      // Species before hybrids
      if (a.is_hybrid !== b.is_hybrid) {
        return a.is_hybrid ? 1 : -1;
      }
      // Alphabetically within group
      return a.name.localeCompare(b.name);
    });
}

/**
 * Check if database has data
 * @returns {Promise<boolean>} True if species table has records
 */
export async function hasData() {
  const count = await db.species.count();
  return count > 0;
}

/**
 * Get database metadata
 * @returns {Promise<Object>} Metadata object
 */
export async function getMetadata() {
  const records = await db.metadata.toArray();
  return Object.fromEntries(records.map(r => [r.key, r.value]));
}
