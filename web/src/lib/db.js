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
  // Main species table - stores full denormalized objects including sources array
  species: 'name, is_hybrid',

  // Metadata table for tracking data version
  metadata: 'key'
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
 *       bark_twigs_buds, hardiness_habitat, miscellaneous
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
  const { metadata, species } = jsonData;

  // Check if we need to update
  const currentVersion = await db.metadata.get('dataVersion');
  if (currentVersion?.value === metadata?.version) {
    console.log('Database already up to date');
    return 0;
  }

  // Clear and repopulate (full replacement strategy)
  await db.transaction('rw', db.species, db.metadata, async () => {
    await db.species.clear();
    await db.species.bulkAdd(species);

    // Store metadata
    await db.metadata.put({ key: 'dataVersion', value: metadata?.version || '1.0' });
    await db.metadata.put({ key: 'lastUpdated', value: metadata?.exported_at || new Date().toISOString() });
    await db.metadata.put({ key: 'speciesCount', value: species.length });
  });

  console.log(`Populated database with ${species.length} species`);
  return species.length;
}

/**
 * Get all species sorted by name
 * @returns {Promise<Array>} All species sorted alphabetically
 */
export async function getAllSpecies() {
  return db.species.orderBy('name').toArray();
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
    'fruits', 'bark_twigs_buds', 'hardiness_habitat', 'miscellaneous', 'url'
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
 *   1. Source with is_preferred === true
 *   2. Source with most populated fields
 *   3. First source in array
 * @param {Object} species - Species object
 * @returns {Object|null} Selected source or null if no sources
 */
export function getPrimarySource(species) {
  if (!species?.sources?.length) return null;

  // Priority 1: Check for is_preferred flag
  const preferred = species.sources.find(s => s.is_preferred);
  if (preferred) return preferred;

  // Priority 2: Select source with most populated fields
  const sorted = [...species.sources].sort((a, b) =>
    countPopulatedFields(b) - countPopulatedFields(a)
  );

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
