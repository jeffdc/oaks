/**
 * API Client for Oak Compendium API
 *
 * Provides methods to fetch data from the API server with automatic
 * error handling and timeout support.
 *
 * API Base URL is configured via environment variable VITE_API_URL
 * or defaults to api.oakcompendium.com in production.
 */

// API configuration
const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://api.oakcompendium.com';
const API_TIMEOUT = 10000; // 10 seconds

/**
 * Custom error class for API errors
 */
export class ApiError extends Error {
  constructor(message, status, code) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
  }
}

/**
 * Fetch wrapper with timeout and error handling
 * @param {string} endpoint - API endpoint (without base URL)
 * @param {Object} options - Fetch options
 * @returns {Promise<any>} Parsed JSON response
 */
async function fetchApi(endpoint, options = {}) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT);

  try {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      ...options,
      signal: controller.signal,
      headers: {
        'Accept': 'application/json',
        ...options.headers
      }
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      const errorBody = await response.json().catch(() => ({}));
      throw new ApiError(
        errorBody.error || `API request failed: ${response.statusText}`,
        response.status,
        errorBody.code
      );
    }

    return response.json();
  } catch (err) {
    clearTimeout(timeoutId);

    if (err.name === 'AbortError') {
      throw new ApiError('Request timed out', 0, 'TIMEOUT');
    }

    if (err instanceof ApiError) {
      throw err;
    }

    // Network error (offline, DNS failure, etc.)
    throw new ApiError(
      err.message || 'Network error',
      0,
      'NETWORK_ERROR'
    );
  }
}

/**
 * Check if the API is reachable
 * @returns {Promise<boolean>} True if API is reachable
 */
export async function checkApiHealth() {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 3000); // 3 second timeout for health check

    const response = await fetch(`${API_BASE_URL}/health`, {
      signal: controller.signal
    });

    clearTimeout(timeoutId);
    return response.ok;
  } catch {
    return false;
  }
}

/**
 * Fetch full export data from API
 * This returns the same format as quercus_data.json
 * @returns {Promise<Object>} Export data with metadata, species, and sources
 */
export async function fetchExport() {
  return fetchApi('/api/v1/export');
}

/**
 * Fetch all species from API
 * @returns {Promise<Array>} Array of species objects
 */
export async function fetchSpecies() {
  const response = await fetchApi('/api/v1/species');
  return response.species || response;
}

/**
 * Fetch a single species by name
 * @param {string} name - Species name (epithet)
 * @returns {Promise<Object>} Species object
 */
export async function fetchSpeciesByName(name) {
  return fetchApi(`/api/v1/species/${encodeURIComponent(name)}`);
}

/**
 * Search species by query
 * @param {string} query - Search query
 * @returns {Promise<Array>} Matching species
 */
export async function searchSpecies(query) {
  const response = await fetchApi(`/api/v1/species/search?q=${encodeURIComponent(query)}`);
  return response.species || response;
}

/**
 * Fetch all taxa from API
 * @returns {Promise<Array>} Array of taxa objects
 */
export async function fetchTaxa() {
  const response = await fetchApi('/api/v1/taxa');
  return response.taxa || response;
}

/**
 * Fetch a single taxon
 * @param {string} level - Taxon level (subgenus, section, etc.)
 * @param {string} name - Taxon name
 * @returns {Promise<Object>} Taxon object
 */
export async function fetchTaxon(level, name) {
  return fetchApi(`/api/v1/taxa/${encodeURIComponent(level)}/${encodeURIComponent(name)}`);
}

/**
 * Fetch all sources from API
 * @returns {Promise<Array>} Array of source objects
 */
export async function fetchSources() {
  const response = await fetchApi('/api/v1/sources');
  return response.sources || response;
}

/**
 * Fetch a single source by ID
 * @param {number} id - Source ID
 * @returns {Promise<Object>} Source object
 */
export async function fetchSourceById(id) {
  return fetchApi(`/api/v1/sources/${id}`);
}

/**
 * Get the configured API base URL (for debugging)
 * @returns {string} API base URL
 */
export function getApiBaseUrl() {
  return API_BASE_URL;
}

// =============================================================================
// Format Conversion Functions
// =============================================================================
// These convert from web format (export/display format) to API format (database format)

/**
 * Convert species from web format to API format
 * Web format uses nested taxonomy object and 'name' field
 * API format uses flat taxonomy fields and 'scientific_name'
 * @param {Object} species - Species in web/export format
 * @returns {Object} Species in API format (OakEntry)
 */
export function speciesToApiFormat(species) {
  return {
    scientific_name: species.name,
    author: species.author || null,
    is_hybrid: species.is_hybrid || false,
    conservation_status: species.conservation_status || null,
    // Flatten taxonomy object to top-level fields
    subgenus: species.taxonomy?.subgenus || null,
    section: species.taxonomy?.section || null,
    subsection: species.taxonomy?.subsection || null,
    complex: species.taxonomy?.complex || null,
    // Hybrid parents
    parent1: species.parent1 || null,
    parent2: species.parent2 || null,
    // Related species arrays
    hybrids: species.hybrids || [],
    closely_related_to: species.closely_related_to || [],
    subspecies_varieties: species.subspecies_varieties || [],
    // Synonyms: web format may have objects with {name, author}, API expects strings
    synonyms: (species.synonyms || []).map(s => typeof s === 'string' ? s : s.name),
    // External links (same format)
    external_links: species.external_links || [],
  };
}

/**
 * Convert taxon from web format to API format
 * Currently 1:1 mapping, but provides consistency and future flexibility
 * @param {Object} taxon - Taxon in web format
 * @returns {Object} Taxon in API format
 */
export function taxonToApiFormat(taxon) {
  return {
    name: taxon.name,
    level: taxon.level,
    parent: taxon.parent || null,
    author: taxon.author || null,
    notes: taxon.notes || null,
    links: taxon.links || [],
  };
}

/**
 * Convert source from web format to API format
 * Currently 1:1 mapping, but provides consistency and future flexibility
 * @param {Object} source - Source in web format
 * @returns {Object} Source in API format
 */
export function sourceToApiFormat(source) {
  return {
    id: source.id,
    source_type: source.source_type,
    name: source.name,
    description: source.description || null,
    author: source.author || null,
    year: source.year || null,
    url: source.url || null,
    isbn: source.isbn || null,
    doi: source.doi || null,
    notes: source.notes || null,
    license: source.license || null,
    license_url: source.license_url || null,
  };
}
