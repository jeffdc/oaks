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
