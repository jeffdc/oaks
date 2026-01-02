import { writable, get } from 'svelte/store';
import { unifiedSearch } from '$lib/apiClient.js';

// Store for search query
export const searchQuery = writable('');

// Store for loading state (used by components during API calls)
export const isLoading = writable(false);

// Store for error state (used by components during API calls)
export const error = writable(null);

// =============================================================================
// Search State
// =============================================================================

// Empty unified search results structure
const emptySearchResults = {
  species: [],
  taxa: [],
  sources: [],
  counts: { species: 0, taxa: 0, sources: 0, total: 0 }
};

// Store for search results (unified: species, taxa, sources)
export const searchResults = writable(emptySearchResults);

// Store for search loading state
export const searchLoading = writable(false);

// Store for search error state
export const searchError = writable(null);

// AbortController for cancelling pending search requests
let searchAbortController = null;

/**
 * Perform a unified search using the API
 * Searches across species, taxa, and sources
 * Cancels any pending search request before starting a new one
 * @param {string} query - Search query
 */
export async function performSearch(query) {
  // Cancel any existing search
  if (searchAbortController) {
    searchAbortController.abort();
  }

  // Create new abort controller for this request
  searchAbortController = new AbortController();

  // Clear previous results and set loading state
  searchLoading.set(true);
  searchError.set(null);

  try {
    const results = await unifiedSearch(query);
    // Only update if this request wasn't aborted
    if (!searchAbortController.signal.aborted) {
      searchResults.set(results);
      searchLoading.set(false);
    }
  } catch (err) {
    // Ignore abort errors - they're expected when cancelling
    if (err.name === 'AbortError' || err.code === 'ABORT') {
      return;
    }
    // Only update error if this request wasn't aborted
    if (!searchAbortController.signal.aborted) {
      searchError.set(err.message || 'Search failed');
      searchResults.set(emptySearchResults);
      searchLoading.set(false);
    }
  }
}

/**
 * Cancel any pending search request
 */
export function cancelSearch() {
  if (searchAbortController) {
    searchAbortController.abort();
    searchAbortController = null;
  }
  searchLoading.set(false);
}

/**
 * Clear search state (query, results, error)
 */
export function clearSearch() {
  cancelSearch();
  searchQuery.set('');
  searchResults.set(emptySearchResults);
  searchError.set(null);
}

// =============================================================================
// Helper Functions
// =============================================================================
// These are pure functions that operate on in-memory species/source objects

/**
 * Helper: format species display name
 * Options: { abbreviated: true } returns "Q. alba", otherwise "Quercus alba"
 * Note: hybrid names already include × in the name (e.g., "× beadlei")
 * Supports both API format (scientific_name) and legacy format (name)
 * @param {Object} species - Species object with name or scientific_name property
 * @param {Object} options - Formatting options
 * @returns {string} Formatted species name
 */
export function formatSpeciesName(species, options = {}) {
  const genus = options.abbreviated ? 'Q.' : 'Quercus';
  const name = species.scientific_name || species.name;
  return `${genus} ${name}`;
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
 * @param {Object} species - Species object with sources array
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
 * @param {Object} species - Species object with sources array
 * @returns {Array} Array of source objects
 */
export function getAllSources(species) {
  return species?.sources || [];
}

/**
 * Get a specific source by ID
 * @param {Object} species - Species object with sources array
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
 * @returns {number} Number of populated fields (0-12)
 */
export function getSourceCompleteness(source) {
  return countPopulatedFields(source);
}
