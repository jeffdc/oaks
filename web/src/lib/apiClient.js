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
 * @property {number} status - HTTP status code (0 for network errors)
 * @property {string} code - Error code (e.g., 'CONFLICT', 'NOT_FOUND', 'NETWORK_ERROR')
 * @property {Object} details - Additional error details (e.g., blocking_hybrids for 409)
 */
export class ApiError extends Error {
  constructor(message, status, code, details = null) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    this.details = details;
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
      // Extract error info from response body
      // API returns { error: { message, code, details } } format
      const errorInfo = errorBody.error || errorBody;
      throw new ApiError(
        errorInfo.message || errorBody.error || `API request failed: ${response.statusText}`,
        response.status,
        errorInfo.code || (response.status === 409 ? 'CONFLICT' : undefined),
        errorInfo.details || null
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
 * Retry helper with exponential backoff
 * Delays: 1s, 2s, 4s between retries (default)
 * @param {Function} fn - Async function to retry
 * @param {Object} options - Retry options
 * @param {number} options.maxRetries - Maximum number of retries (default: 3)
 * @param {number} options.baseDelay - Base delay in ms (default: 1000)
 * @returns {Promise<any>} Result from fn
 */
export async function fetchWithRetry(fn, { maxRetries = 3, baseDelay = 1000 } = {}) {
  let lastError;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;

      // Don't retry on 4xx errors (client errors) except 408 (timeout) and 429 (rate limit)
      if (err instanceof ApiError && err.status >= 400 && err.status < 500 &&
          err.status !== 408 && err.status !== 429) {
        throw err;
      }

      // If we've exhausted retries, throw the last error
      if (attempt === maxRetries) {
        throw err;
      }

      // Wait with exponential backoff before next retry
      const delay = baseDelay * Math.pow(2, attempt);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  throw lastError;
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
 * Fetch all species from API
 * @returns {Promise<Array>} Array of species objects
 */
export async function fetchSpecies() {
  const response = await fetchApi('/api/v1/species');
  return response.species || response;
}

/**
 * Fetch a single species by name (basic info)
 * @param {string} name - Species name (epithet)
 * @returns {Promise<Object>} Species object
 */
export async function fetchSpeciesByName(name) {
  return fetchApi(`/api/v1/species/${encodeURIComponent(name)}`);
}

/**
 * Fetch a single species with all source data embedded
 * @param {string} name - Species name (epithet)
 * @returns {Promise<Object>} Species object with sources array
 */
export async function fetchSpeciesFull(name) {
  return fetchApi(`/api/v1/species/${encodeURIComponent(name)}/full`);
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
// Species Mutations
// =============================================================================

/**
 * Create a new species
 * @param {Object} species - Species data in API format
 * @returns {Promise<Object>} Created species
 */
export async function createSpecies(species) {
  return fetchApi('/api/v1/species', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(species)
  });
}

/**
 * Update an existing species
 * @param {string} name - Current species name
 * @param {Object} species - Updated species data in API format
 * @returns {Promise<Object>} Updated species
 */
export async function updateSpecies(name, species) {
  return fetchApi(`/api/v1/species/${encodeURIComponent(name)}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(species)
  });
}

/**
 * Delete a species
 * Returns 409 Conflict with blocking hybrids list if species is a parent
 * @param {string} name - Species name to delete
 * @returns {Promise<void>}
 * @throws {ApiError} With status 409 and details.blocking_hybrids if blocked
 */
export async function deleteSpecies(name) {
  return fetchApi(`/api/v1/species/${encodeURIComponent(name)}`, {
    method: 'DELETE'
  });
}

// =============================================================================
// Species-Source Mutations
// =============================================================================

/**
 * Fetch species-source entries for a species
 * @param {string} speciesName - Species name
 * @returns {Promise<Array>} Array of species-source objects
 */
export async function fetchSpeciesSources(speciesName) {
  const response = await fetchApi(`/api/v1/species/${encodeURIComponent(speciesName)}/sources`);
  return response.sources || response;
}

/**
 * Create a new species-source entry
 * @param {string} speciesName - Species name
 * @param {Object} speciesSource - Species-source data
 * @returns {Promise<Object>} Created species-source
 */
export async function createSpeciesSource(speciesName, speciesSource) {
  return fetchApi(`/api/v1/species/${encodeURIComponent(speciesName)}/sources`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(speciesSource)
  });
}

/**
 * Update a species-source entry
 * @param {string} speciesName - Species name
 * @param {number} sourceId - Source ID
 * @param {Object} speciesSource - Updated species-source data
 * @returns {Promise<Object>} Updated species-source
 */
export async function updateSpeciesSource(speciesName, sourceId, speciesSource) {
  return fetchApi(`/api/v1/species/${encodeURIComponent(speciesName)}/sources/${sourceId}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(speciesSource)
  });
}

/**
 * Delete a species-source entry
 * @param {string} speciesName - Species name
 * @param {number} sourceId - Source ID
 * @returns {Promise<void>}
 */
export async function deleteSpeciesSource(speciesName, sourceId) {
  return fetchApi(`/api/v1/species/${encodeURIComponent(speciesName)}/sources/${sourceId}`, {
    method: 'DELETE'
  });
}

// =============================================================================
// Taxa Mutations
// =============================================================================

/**
 * Create a new taxon
 * @param {Object} taxon - Taxon data in API format
 * @returns {Promise<Object>} Created taxon
 */
export async function createTaxon(taxon) {
  return fetchApi('/api/v1/taxa', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(taxon)
  });
}

/**
 * Update an existing taxon
 * @param {string} level - Taxon level
 * @param {string} name - Taxon name
 * @param {Object} taxon - Updated taxon data in API format
 * @returns {Promise<Object>} Updated taxon
 */
export async function updateTaxon(level, name, taxon) {
  return fetchApi(`/api/v1/taxa/${encodeURIComponent(level)}/${encodeURIComponent(name)}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(taxon)
  });
}

/**
 * Delete a taxon
 * @param {string} level - Taxon level
 * @param {string} name - Taxon name
 * @returns {Promise<void>}
 */
export async function deleteTaxon(level, name) {
  return fetchApi(`/api/v1/taxa/${encodeURIComponent(level)}/${encodeURIComponent(name)}`, {
    method: 'DELETE'
  });
}

// =============================================================================
// Source Mutations
// =============================================================================

/**
 * Create a new source
 * @param {Object} source - Source data in API format
 * @returns {Promise<Object>} Created source
 */
export async function createSource(source) {
  return fetchApi('/api/v1/sources', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(source)
  });
}

/**
 * Update an existing source
 * @param {number} id - Source ID
 * @param {Object} source - Updated source data in API format
 * @returns {Promise<Object>} Updated source
 */
export async function updateSource(id, source) {
  return fetchApi(`/api/v1/sources/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(source)
  });
}

/**
 * Delete a source
 * @param {number} id - Source ID
 * @returns {Promise<void>}
 */
export async function deleteSource(id) {
  return fetchApi(`/api/v1/sources/${id}`, {
    method: 'DELETE'
  });
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
