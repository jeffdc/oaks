/**
 * API Client for Oak Compendium API
 *
 * Provides methods to fetch data from the API server with automatic
 * error handling and timeout support.
 *
 * API Base URL is configured via environment variable VITE_API_URL
 * or defaults to api.oakcompendium.com in production.
 */

import { get } from 'svelte/store';
import { authStore } from './stores/authStore.js';
import { toast } from './stores/toastStore.js';

// API configuration
const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://api.oakcompendium.com';
const API_TIMEOUT = 10000; // 10 seconds

/**
 * Custom error class for API errors
 * @property {number} status - HTTP status code (0 for network errors)
 * @property {string} code - Error code (e.g., 'CONFLICT', 'NOT_FOUND', 'NETWORK_ERROR')
 * @property {Object} details - Additional error details (e.g., blocking_hybrids for 409)
 * @property {Array<{field: string, message: string}>|null} fieldErrors - Validation errors by field
 */
export class ApiError extends Error {
  constructor(message, status, code, details = null, fieldErrors = null) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    this.details = details;
    this.fieldErrors = fieldErrors;
  }
}

/**
 * Custom error class for rate limiting (429 responses)
 * @property {number|null} retryAfter - Seconds until retry is allowed (from Retry-After header)
 */
export class RateLimitError extends ApiError {
  constructor(message, retryAfter = null) {
    super(message, 429, 'RATE_LIMITED');
    this.name = 'RateLimitError';
    this.retryAfter = retryAfter;
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
      cache: 'no-store',  // Prevent browser caching for API requests
      signal: controller.signal,
      headers: {
        'Accept': 'application/json',
        ...options.headers
      }
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      // Handle rate limiting specially
      if (response.status === 429) {
        const retryAfter = response.headers.get('Retry-After');
        const retrySeconds = retryAfter ? parseInt(retryAfter, 10) : null;
        throw new RateLimitError('Rate limit exceeded', retrySeconds);
      }

      // Handle 401 Unauthorized - clear stale API key and notify user
      if (response.status === 401) {
        authStore.clearKey();
        toast.warning('Session expired. Please re-enter your API key.');
        throw new ApiError('Unauthorized', 401, 'UNAUTHORIZED');
      }

      const errorBody = await response.json().catch(() => ({}));

      // Handle validation errors (400 with field-level errors)
      if (response.status === 400 && errorBody.error?.details?.errors) {
        const fieldErrors = errorBody.error.details.errors;
        throw new ApiError(
          errorBody.error.message || 'Validation failed',
          response.status,
          errorBody.error.code || 'VALIDATION_ERROR',
          null,
          fieldErrors
        );
      }

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
 * Authenticated fetch wrapper - adds Authorization header from authStore
 * @param {string} endpoint - API endpoint (without base URL)
 * @param {Object} options - Fetch options
 * @returns {Promise<any>} Parsed JSON response
 * @throws {ApiError} If not authenticated or request fails
 */
async function fetchApiAuthenticated(endpoint, options = {}) {
  const apiKey = get(authStore);
  if (!apiKey) {
    throw new ApiError('Not authenticated', 401, 'UNAUTHENTICATED');
  }

  return fetchApi(endpoint, {
    ...options,
    headers: {
      ...options.headers,
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    }
  });
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
 * Fetch database stats (counts)
 * @returns {Promise<Object>} Stats object with species_count, hybrid_count, taxa_count, source_count
 */
export async function fetchStats() {
  return fetchApi('/api/v1/stats');
}

/**
 * Fetch all species from API
 * @returns {Promise<Array>} Array of species objects
 */
export async function fetchSpecies() {
  const response = await fetchApi('/api/v1/species');
  return response.data || response.species || response;
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
 * Fetch species that have data from a specific source
 * @param {number} sourceId - Source ID
 * @returns {Promise<Array>} Array of species objects
 */
export async function fetchSpeciesBySource(sourceId) {
  const response = await fetchApi(`/api/v1/species?source_id=${sourceId}&limit=1000`);
  return response.data || response.species || response;
}

/**
 * Search species by query (species-only search)
 * @param {string} query - Search query
 * @returns {Promise<Array>} Matching species
 */
export async function searchSpecies(query) {
  const response = await fetchApi(`/api/v1/species/search?q=${encodeURIComponent(query)}`);
  return response.data || response.species || response;
}

/**
 * Unified search across species, taxa, and sources
 * @param {string} query - Search query
 * @returns {Promise<Object>} Search results with species, taxa, sources arrays and counts
 */
export async function unifiedSearch(query) {
  return fetchApi(`/api/v1/search?q=${encodeURIComponent(query)}`);
}

/**
 * Fetch all taxa from API
 * @returns {Promise<Array>} Array of taxa objects
 */
export async function fetchTaxa() {
  const response = await fetchApi('/api/v1/taxa');
  return response.data || response.taxa || response;
}

/**
 * Fetch taxa by level with optional parent filtering
 * @param {string} level - Taxon level (subgenus, section, subsection, complex)
 * @param {Array<string>} parentPath - Parent taxon path for filtering
 * @returns {Promise<Array>} Array of taxa objects with species_count
 */
export async function fetchTaxaByLevel(level, parentPath = []) {
  let url = `/api/v1/taxa?level=${encodeURIComponent(level)}`;

  // Filter by the immediate parent (last element in path)
  if (parentPath.length > 0) {
    const parent = parentPath[parentPath.length - 1];
    if (parent) {
      url += `&parent=${encodeURIComponent(parent)}`;
    }
  }

  const response = await fetchApi(url);
  return response.data || response.taxa || response;
}

/**
 * Fetch species belonging to a specific taxon path
 * @param {Array<string>} taxonPath - Taxon path (e.g., ['Quercus', 'Quercus', 'Albae'])
 * @returns {Promise<Array>} Array of species objects
 */
export async function fetchSpeciesByTaxon(taxonPath = []) {
  let url = '/api/v1/species?limit=1000'; // Get all species, not just 50

  // Add taxon filters based on path
  if (taxonPath.length >= 1 && taxonPath[0]) {
    url += `&subgenus=${encodeURIComponent(taxonPath[0])}`;
  }
  if (taxonPath.length >= 2 && taxonPath[1]) {
    url += `&section=${encodeURIComponent(taxonPath[1])}`;
  }
  if (taxonPath.length >= 3 && taxonPath[2]) {
    url += `&subsection=${encodeURIComponent(taxonPath[2])}`;
  }
  if (taxonPath.length >= 4 && taxonPath[3]) {
    url += `&complex=${encodeURIComponent(taxonPath[3])}`;
  }

  const response = await fetchApi(url);
  return response.data || response.species || response;
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
  // Sources endpoint returns array directly
  return Array.isArray(response) ? response : (response.data || response.sources || response);
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

/**
 * Verify an API key is valid
 * @param {string} apiKey - The API key to verify
 * @returns {Promise<boolean>} True if valid
 * @throws {ApiError} If verification fails
 */
export async function verifyApiKey(apiKey) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT);

  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/auth/verify`, {
      signal: controller.signal,
      headers: {
        'Accept': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      }
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      if (response.status === 401) {
        return false;
      }
      const errorBody = await response.json().catch(() => ({}));
      throw new ApiError(
        errorBody.error || `Verification failed: ${response.statusText}`,
        response.status,
        errorBody.code
      );
    }

    return true;
  } catch (err) {
    clearTimeout(timeoutId);

    if (err.name === 'AbortError') {
      throw new ApiError('Request timed out', 0, 'TIMEOUT');
    }

    if (err instanceof ApiError) {
      throw err;
    }

    throw new ApiError(
      err.message || 'Network error',
      0,
      'NETWORK_ERROR'
    );
  }
}

// =============================================================================
// Species-Source Read Operations
// =============================================================================

/**
 * Fetch species-source entries for a species
 * @param {string} speciesName - Species name
 * @returns {Promise<Array>} Array of species-source objects
 */
export async function fetchSpeciesSources(speciesName) {
  const response = await fetchApi(`/api/v1/species/${encodeURIComponent(speciesName)}/sources`);
  return Array.isArray(response) ? response : (response.data || response.sources || response);
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

/**
 * Convert species source from web format to API format
 * @param {Object} speciesSource - Species source in web format
 * @returns {Object} Species source in API format
 */
export function speciesSourceToApiFormat(speciesSource) {
  return {
    source_id: speciesSource.source_id,
    local_names: speciesSource.local_names || [],
    range: speciesSource.range || null,
    growth_habit: speciesSource.growth_habit || null,
    leaves: speciesSource.leaves || null,
    flowers: speciesSource.flowers || null,
    fruits: speciesSource.fruits || null,
    bark: speciesSource.bark || null,
    twigs: speciesSource.twigs || null,
    buds: speciesSource.buds || null,
    hardiness_habitat: speciesSource.hardiness_habitat || null,
    miscellaneous: speciesSource.miscellaneous || null,
    url: speciesSource.url || null,
    is_preferred: speciesSource.is_preferred || false,
  };
}

// =============================================================================
// Authenticated Write Operations
// =============================================================================
// These methods require authentication via authStore API key

// -----------------------------------------------------------------------------
// Species Write Operations
// -----------------------------------------------------------------------------

/**
 * Create a new species
 * @param {Object} species - Species data in web format
 * @returns {Promise<Object>} Created species
 * @throws {ApiError} On validation or auth errors
 */
export async function createSpecies(species) {
  const data = speciesToApiFormat(species);
  return fetchApiAuthenticated('/api/v1/species', {
    method: 'POST',
    body: JSON.stringify(data)
  });
}

/**
 * Update an existing species
 * @param {string} name - Species name (epithet)
 * @param {Object} species - Species data in web format
 * @returns {Promise<Object>} Updated species
 * @throws {ApiError} On validation, auth, or not found errors
 */
export async function updateSpecies(name, species) {
  const data = speciesToApiFormat(species);
  return fetchApiAuthenticated(`/api/v1/species/${encodeURIComponent(name)}`, {
    method: 'PUT',
    body: JSON.stringify(data)
  });
}

/**
 * Delete a species
 * @param {string} name - Species name (epithet)
 * @returns {Promise<void>}
 * @throws {ApiError} On auth or not found errors
 */
export async function deleteSpecies(name) {
  await fetchApiAuthenticated(`/api/v1/species/${encodeURIComponent(name)}`, {
    method: 'DELETE'
  });
}

// -----------------------------------------------------------------------------
// Taxa Write Operations
// -----------------------------------------------------------------------------

/**
 * Create a new taxon
 * @param {Object} taxon - Taxon data in web format
 * @returns {Promise<Object>} Created taxon
 * @throws {ApiError} On validation or auth errors
 */
export async function createTaxon(taxon) {
  const data = taxonToApiFormat(taxon);
  return fetchApiAuthenticated('/api/v1/taxa', {
    method: 'POST',
    body: JSON.stringify(data)
  });
}

/**
 * Update an existing taxon
 * @param {string} level - Taxon level (subgenus, section, subsection, complex)
 * @param {string} name - Taxon name
 * @param {Object} taxon - Taxon data in web format
 * @returns {Promise<Object>} Updated taxon
 * @throws {ApiError} On validation, auth, or not found errors
 */
export async function updateTaxon(level, name, taxon) {
  const data = taxonToApiFormat(taxon);
  return fetchApiAuthenticated(`/api/v1/taxa/${encodeURIComponent(level)}/${encodeURIComponent(name)}`, {
    method: 'PUT',
    body: JSON.stringify(data)
  });
}

/**
 * Delete a taxon
 * @param {string} level - Taxon level (subgenus, section, subsection, complex)
 * @param {string} name - Taxon name
 * @returns {Promise<void>}
 * @throws {ApiError} On auth or not found errors
 */
export async function deleteTaxon(level, name) {
  await fetchApiAuthenticated(`/api/v1/taxa/${encodeURIComponent(level)}/${encodeURIComponent(name)}`, {
    method: 'DELETE'
  });
}

// -----------------------------------------------------------------------------
// Source Write Operations
// -----------------------------------------------------------------------------

/**
 * Create a new source
 * @param {Object} source - Source data in web format
 * @returns {Promise<Object>} Created source with ID
 * @throws {ApiError} On validation or auth errors
 */
export async function createSource(source) {
  const data = sourceToApiFormat(source);
  return fetchApiAuthenticated('/api/v1/sources', {
    method: 'POST',
    body: JSON.stringify(data)
  });
}

/**
 * Update an existing source
 * @param {number} id - Source ID
 * @param {Object} source - Source data in web format
 * @returns {Promise<Object>} Updated source
 * @throws {ApiError} On validation, auth, or not found errors
 */
export async function updateSource(id, source) {
  const data = sourceToApiFormat(source);
  return fetchApiAuthenticated(`/api/v1/sources/${id}`, {
    method: 'PUT',
    body: JSON.stringify(data)
  });
}

/**
 * Delete a source
 * @param {number} id - Source ID
 * @returns {Promise<void>}
 * @throws {ApiError} On auth or not found errors
 */
export async function deleteSource(id) {
  await fetchApiAuthenticated(`/api/v1/sources/${id}`, {
    method: 'DELETE'
  });
}

// -----------------------------------------------------------------------------
// Species Source Write Operations
// -----------------------------------------------------------------------------

/**
 * Create a new species-source association
 * @param {string} speciesName - Species name (epithet)
 * @param {Object} speciesSource - Species source data in web format
 * @returns {Promise<Object>} Created species source
 * @throws {ApiError} On validation or auth errors
 */
export async function createSpeciesSource(speciesName, speciesSource) {
  const data = speciesSourceToApiFormat(speciesSource);
  return fetchApiAuthenticated(`/api/v1/species/${encodeURIComponent(speciesName)}/sources`, {
    method: 'POST',
    body: JSON.stringify(data)
  });
}

/**
 * Update an existing species-source association
 * @param {string} speciesName - Species name (epithet)
 * @param {number} sourceId - Source ID
 * @param {Object} speciesSource - Species source data in web format
 * @returns {Promise<Object>} Updated species source
 * @throws {ApiError} On validation, auth, or not found errors
 */
export async function updateSpeciesSource(speciesName, sourceId, speciesSource) {
  const data = speciesSourceToApiFormat(speciesSource);
  return fetchApiAuthenticated(`/api/v1/species/${encodeURIComponent(speciesName)}/sources/${sourceId}`, {
    method: 'PUT',
    body: JSON.stringify(data)
  });
}

/**
 * Delete a species-source association
 * @param {string} speciesName - Species name (epithet)
 * @param {number} sourceId - Source ID
 * @returns {Promise<void>}
 * @throws {ApiError} On auth or not found errors
 */
export async function deleteSpeciesSource(speciesName, sourceId) {
  await fetchApiAuthenticated(`/api/v1/species/${encodeURIComponent(speciesName)}/sources/${sourceId}`, {
    method: 'DELETE'
  });
}
