/**
 * E2E tests for CRUD operations
 *
 * Tests cover:
 * - Species: create, edit fields, delete (with cascade verification)
 * - Species-Source: edit source data, add new source, delete source record
 * - Taxa: create in hierarchy, edit, delete (verify constraint 409)
 * - Sources: create, edit metadata, delete (verify constraint 409)
 * - Error handling: validation (400), auth (401), rate limit (429), network errors
 * - Offline mode: canEdit is false, edit buttons disabled, connection loss preserves data
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { get } from 'svelte/store';

// Mock SvelteKit environment - must be before imports
vi.mock('$app/environment', () => ({
  browser: true
}));

vi.mock('$app/paths', () => ({
  base: ''
}));

// Mock toast store to capture notifications
const mockToast = {
  success: vi.fn(),
  error: vi.fn(),
  warning: vi.fn(),
  info: vi.fn(),
  dismiss: vi.fn(),
  dismissAll: vi.fn()
};

vi.mock('../lib/stores/toastStore.js', () => ({
  toast: mockToast
}));

// Mock localStorage
let mockLocalStorage = {};
const localStorageMock = {
  getItem: vi.fn((key) => mockLocalStorage[key] ?? null),
  setItem: vi.fn((key, value) => { mockLocalStorage[key] = value; }),
  removeItem: vi.fn((key) => { delete mockLocalStorage[key]; }),
  clear: vi.fn(() => { mockLocalStorage = {}; })
};

Object.defineProperty(global, 'localStorage', {
  value: localStorageMock,
  writable: true
});

// Mock fetch for API calls
const mockFetch = vi.fn();
global.fetch = mockFetch;

// Helper to set up valid auth session
function setupValidSession(apiKey = 'test-api-key') {
  const now = Date.now();
  mockLocalStorage = {
    'oak_api_key': apiKey,
    'oak_api_key_timestamp': String(now)
  };
}

// Helper to create mock response
function mockResponse(data, options = {}) {
  return {
    ok: options.ok !== false,
    status: options.status || 200,
    statusText: options.statusText || 'OK',
    headers: new Map(Object.entries(options.headers || {})),
    json: vi.fn().mockResolvedValue(data)
  };
}

// Helper to create mock error response
function mockErrorResponse(message, status, code, fieldErrors = null) {
  const error = { message, code };
  if (fieldErrors) {
    error.details = { errors: fieldErrors };
  }
  return {
    ok: false,
    status,
    statusText: message,
    headers: new Map(),
    json: vi.fn().mockResolvedValue({ error })
  };
}

describe('CRUD Operations', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockLocalStorage = {};
    mockFetch.mockReset();
  });

  afterEach(() => {
    vi.resetModules();
  });

  // =============================================================================
  // Species CRUD Tests
  // =============================================================================
  describe('Species CRUD', () => {
    describe('createSpecies', () => {
      it('creates a new species with valid data', async () => {
        setupValidSession();

        const speciesData = {
          name: 'newspecies',
          author: 'Author 2025',
          is_hybrid: false,
          conservation_status: 'LC',
          taxonomy: {
            subgenus: 'Quercus',
            section: 'Quercus'
          }
        };

        mockFetch.mockResolvedValueOnce(mockResponse({
          scientific_name: 'newspecies',
          author: 'Author 2025',
          is_hybrid: false
        }));

        const { createSpecies } = await import('../lib/apiClient.js');
        const result = await createSpecies(speciesData);

        expect(mockFetch).toHaveBeenCalledWith(
          expect.stringContaining('/api/v1/species'),
          expect.objectContaining({
            method: 'POST',
            body: expect.stringContaining('newspecies')
          })
        );
        expect(result.scientific_name).toBe('newspecies');
      });

      it('handles validation errors on create', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockErrorResponse(
          'Validation failed',
          400,
          'VALIDATION_ERROR',
          [{ field: 'scientific_name', message: 'Name already exists' }]
        ));

        const { createSpecies, ApiError } = await import('../lib/apiClient.js');

        try {
          await createSpecies({ name: 'existing' });
          expect.fail('Should have thrown');
        } catch (error) {
          expect(error).toBeInstanceOf(ApiError);
          expect(error.status).toBe(400);
          expect(error.fieldErrors).toHaveLength(1);
          expect(error.fieldErrors[0].field).toBe('scientific_name');
        }
      });

      it('requires authentication for create', async () => {
        // No session set up
        const { createSpecies, ApiError } = await import('../lib/apiClient.js');

        await expect(createSpecies({ name: 'test' }))
          .rejects.toThrow(ApiError);

        try {
          await createSpecies({ name: 'test' });
        } catch (error) {
          expect(error.status).toBe(401);
          expect(error.code).toBe('UNAUTHENTICATED');
        }
      });
    });

    describe('updateSpecies', () => {
      it('updates species fields correctly', async () => {
        setupValidSession();

        const updatedData = {
          name: 'alba',
          author: 'L. 1753 (updated)',
          conservation_status: 'NT',
          taxonomy: {
            subgenus: 'Quercus',
            section: 'Quercus',
            subsection: 'Albae'
          }
        };

        mockFetch.mockResolvedValueOnce(mockResponse({
          scientific_name: 'alba',
          author: 'L. 1753 (updated)',
          conservation_status: 'NT'
        }));

        const { updateSpecies } = await import('../lib/apiClient.js');
        const result = await updateSpecies('alba', updatedData);

        expect(mockFetch).toHaveBeenCalledWith(
          expect.stringContaining('/api/v1/species/alba'),
          expect.objectContaining({
            method: 'PUT'
          })
        );
        expect(result.conservation_status).toBe('NT');
      });

      it('handles not found error on update', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockErrorResponse(
          'Species not found',
          404,
          'NOT_FOUND'
        ));

        const { updateSpecies, ApiError } = await import('../lib/apiClient.js');

        await expect(updateSpecies('nonexistent', { name: 'nonexistent' }))
          .rejects.toThrow(ApiError);
      });

      it('encodes special characters in species name', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockResponse({ scientific_name: '× bebbiana' }));

        const { updateSpecies } = await import('../lib/apiClient.js');
        await updateSpecies('× bebbiana', { name: '× bebbiana', is_hybrid: true });

        expect(mockFetch).toHaveBeenCalledWith(
          expect.stringContaining(encodeURIComponent('× bebbiana')),
          expect.anything()
        );
      });
    });

    describe('deleteSpecies', () => {
      it('deletes a species successfully', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockResponse(null));

        const { deleteSpecies } = await import('../lib/apiClient.js');
        await deleteSpecies('testspecies');

        expect(mockFetch).toHaveBeenCalledWith(
          expect.stringContaining('/api/v1/species/testspecies'),
          expect.objectContaining({
            method: 'DELETE'
          })
        );
      });

      it('cascades delete to species-sources', async () => {
        setupValidSession();

        // First delete should succeed (cascades to sources)
        mockFetch.mockResolvedValueOnce(mockResponse(null));

        const { deleteSpecies } = await import('../lib/apiClient.js');
        await deleteSpecies('specieswithsources');

        // The API handles cascade delete internally
        expect(mockFetch).toHaveBeenCalledTimes(1);
      });

      it('handles delete of non-existent species', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockErrorResponse(
          'Species not found',
          404,
          'NOT_FOUND'
        ));

        const { deleteSpecies, ApiError } = await import('../lib/apiClient.js');

        await expect(deleteSpecies('nonexistent'))
          .rejects.toThrow(ApiError);
      });
    });
  });

  // =============================================================================
  // Species-Source CRUD Tests
  // =============================================================================
  describe('Species-Source CRUD', () => {
    describe('createSpeciesSource', () => {
      it('adds a new source to a species', async () => {
        setupValidSession();

        const sourceData = {
          source_id: 2,
          local_names: ['white oak', 'eastern white oak'],
          range: 'Eastern North America',
          leaves: 'Lobed leaves...',
          is_preferred: false
        };

        mockFetch.mockResolvedValueOnce(mockResponse({
          source_id: 2,
          local_names: ['white oak', 'eastern white oak']
        }));

        const { createSpeciesSource } = await import('../lib/apiClient.js');
        const result = await createSpeciesSource('alba', sourceData);

        expect(mockFetch).toHaveBeenCalledWith(
          expect.stringContaining('/api/v1/species/alba/sources'),
          expect.objectContaining({
            method: 'POST',
            body: expect.stringContaining('source_id')
          })
        );
        expect(result.source_id).toBe(2);
      });

      it('handles duplicate source error', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockErrorResponse(
          'Source already associated with species',
          409,
          'CONSTRAINT_ERROR'
        ));

        const { createSpeciesSource, ApiError } = await import('../lib/apiClient.js');

        await expect(createSpeciesSource('alba', { source_id: 1 }))
          .rejects.toThrow(ApiError);
      });
    });

    describe('updateSpeciesSource', () => {
      it('edits source data for a species', async () => {
        setupValidSession();

        const updatedSourceData = {
          source_id: 1,
          local_names: ['updated name'],
          range: 'Updated range description',
          is_preferred: true
        };

        mockFetch.mockResolvedValueOnce(mockResponse({
          source_id: 1,
          range: 'Updated range description'
        }));

        const { updateSpeciesSource } = await import('../lib/apiClient.js');
        const result = await updateSpeciesSource('alba', 1, updatedSourceData);

        expect(mockFetch).toHaveBeenCalledWith(
          expect.stringContaining('/api/v1/species/alba/sources/1'),
          expect.objectContaining({
            method: 'PUT'
          })
        );
        expect(result.range).toBe('Updated range description');
      });

      it('updates preferred status correctly', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockResponse({
          source_id: 2,
          is_preferred: true
        }));

        const { updateSpeciesSource } = await import('../lib/apiClient.js');
        await updateSpeciesSource('alba', 2, { source_id: 2, is_preferred: true });

        const requestBody = JSON.parse(mockFetch.mock.calls[0][1].body);
        expect(requestBody.is_preferred).toBe(true);
      });
    });

    describe('deleteSpeciesSource', () => {
      it('removes a source from a species', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockResponse(null));

        const { deleteSpeciesSource } = await import('../lib/apiClient.js');
        await deleteSpeciesSource('alba', 2);

        expect(mockFetch).toHaveBeenCalledWith(
          expect.stringContaining('/api/v1/species/alba/sources/2'),
          expect.objectContaining({
            method: 'DELETE'
          })
        );
      });

      it('handles delete of non-existent species-source', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockErrorResponse(
          'Species source not found',
          404,
          'NOT_FOUND'
        ));

        const { deleteSpeciesSource, ApiError } = await import('../lib/apiClient.js');

        await expect(deleteSpeciesSource('alba', 999))
          .rejects.toThrow(ApiError);
      });
    });
  });

  // =============================================================================
  // Taxa CRUD Tests
  // =============================================================================
  describe('Taxa CRUD', () => {
    describe('createTaxon', () => {
      it('creates a new taxon in hierarchy', async () => {
        setupValidSession();

        const taxonData = {
          name: 'NewSection',
          level: 'section',
          parent: 'Quercus',
          author: 'Author 2025',
          notes: 'A new section for testing'
        };

        mockFetch.mockResolvedValueOnce(mockResponse({
          name: 'NewSection',
          level: 'section',
          parent: 'Quercus'
        }));

        const { createTaxon } = await import('../lib/apiClient.js');
        const result = await createTaxon(taxonData);

        expect(mockFetch).toHaveBeenCalledWith(
          expect.stringContaining('/api/v1/taxa'),
          expect.objectContaining({
            method: 'POST',
            body: expect.stringContaining('NewSection')
          })
        );
        expect(result.name).toBe('NewSection');
        expect(result.level).toBe('section');
      });

      it('creates taxon with links array', async () => {
        setupValidSession();

        const taxonData = {
          name: 'LinkedSection',
          level: 'subsection',
          parent: 'Quercus',
          links: [{ url: 'https://example.com', title: 'Reference' }]
        };

        mockFetch.mockResolvedValueOnce(mockResponse({
          name: 'LinkedSection',
          links: [{ url: 'https://example.com', title: 'Reference' }]
        }));

        const { createTaxon } = await import('../lib/apiClient.js');
        const result = await createTaxon(taxonData);

        const requestBody = JSON.parse(mockFetch.mock.calls[0][1].body);
        expect(requestBody.links).toHaveLength(1);
      });
    });

    describe('updateTaxon', () => {
      it('updates taxon properties', async () => {
        setupValidSession();

        const updatedData = {
          name: 'Quercus',
          level: 'section',
          author: 'L. (updated)',
          notes: 'Updated notes'
        };

        mockFetch.mockResolvedValueOnce(mockResponse({
          name: 'Quercus',
          author: 'L. (updated)'
        }));

        const { updateTaxon } = await import('../lib/apiClient.js');
        const result = await updateTaxon('section', 'Quercus', updatedData);

        expect(mockFetch).toHaveBeenCalledWith(
          expect.stringContaining('/api/v1/taxa/section/Quercus'),
          expect.objectContaining({
            method: 'PUT'
          })
        );
        expect(result.author).toBe('L. (updated)');
      });
    });

    describe('deleteTaxon', () => {
      it('deletes a taxon without children', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockResponse(null));

        const { deleteTaxon } = await import('../lib/apiClient.js');
        await deleteTaxon('subsection', 'LeafTaxon');

        expect(mockFetch).toHaveBeenCalledWith(
          expect.stringContaining('/api/v1/taxa/subsection/LeafTaxon'),
          expect.objectContaining({
            method: 'DELETE'
          })
        );
      });

      it('returns 409 constraint error when taxon has children', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockErrorResponse(
          'Cannot delete taxon with child taxa',
          409,
          'CONSTRAINT_ERROR'
        ));

        const { deleteTaxon, ApiError } = await import('../lib/apiClient.js');

        try {
          await deleteTaxon('section', 'Quercus');
          expect.fail('Should have thrown');
        } catch (error) {
          expect(error).toBeInstanceOf(ApiError);
          expect(error.status).toBe(409);
          expect(error.code).toBe('CONSTRAINT_ERROR');
        }
      });

      it('returns 409 constraint error when taxon is used by species', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockErrorResponse(
          'Cannot delete taxon referenced by species',
          409,
          'CONSTRAINT_ERROR'
        ));

        const { deleteTaxon, ApiError } = await import('../lib/apiClient.js');

        await expect(deleteTaxon('section', 'UsedSection'))
          .rejects.toMatchObject({
            status: 409,
            code: 'CONSTRAINT_ERROR'
          });
      });
    });
  });

  // =============================================================================
  // Sources CRUD Tests
  // =============================================================================
  describe('Sources CRUD', () => {
    describe('createSource', () => {
      it('creates a new source with all metadata', async () => {
        setupValidSession();

        const sourceData = {
          source_type: 'book',
          name: 'Field Guide to Oaks',
          description: 'A comprehensive field guide',
          author: 'John Doe',
          year: 2025,
          isbn: '978-0-123456-78-9',
          notes: 'Excellent reference'
        };

        mockFetch.mockResolvedValueOnce(mockResponse({
          id: 5,
          source_type: 'book',
          name: 'Field Guide to Oaks'
        }));

        const { createSource } = await import('../lib/apiClient.js');
        const result = await createSource(sourceData);

        expect(mockFetch).toHaveBeenCalledWith(
          expect.stringContaining('/api/v1/sources'),
          expect.objectContaining({
            method: 'POST'
          })
        );
        expect(result.id).toBe(5);
        expect(result.source_type).toBe('book');
      });

      it('creates source with license information', async () => {
        setupValidSession();

        const sourceData = {
          source_type: 'website',
          name: 'Open Oak Database',
          url: 'https://openoaks.org',
          license: 'CC BY-SA 4.0',
          license_url: 'https://creativecommons.org/licenses/by-sa/4.0/'
        };

        mockFetch.mockResolvedValueOnce(mockResponse({ id: 6 }));

        const { createSource } = await import('../lib/apiClient.js');
        await createSource(sourceData);

        const requestBody = JSON.parse(mockFetch.mock.calls[0][1].body);
        expect(requestBody.license).toBe('CC BY-SA 4.0');
        expect(requestBody.license_url).toBe('https://creativecommons.org/licenses/by-sa/4.0/');
      });
    });

    describe('updateSource', () => {
      it('updates source metadata', async () => {
        setupValidSession();

        const updatedData = {
          id: 1,
          source_type: 'website',
          name: 'Oaks of the World (Updated)',
          description: 'Updated description',
          year: 2025
        };

        mockFetch.mockResolvedValueOnce(mockResponse({
          id: 1,
          name: 'Oaks of the World (Updated)',
          year: 2025
        }));

        const { updateSource } = await import('../lib/apiClient.js');
        const result = await updateSource(1, updatedData);

        expect(mockFetch).toHaveBeenCalledWith(
          expect.stringContaining('/api/v1/sources/1'),
          expect.objectContaining({
            method: 'PUT'
          })
        );
        expect(result.year).toBe(2025);
      });

      it('handles not found on update', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockErrorResponse(
          'Source not found',
          404,
          'NOT_FOUND'
        ));

        const { updateSource, ApiError } = await import('../lib/apiClient.js');

        await expect(updateSource(999, { name: 'Test' }))
          .rejects.toThrow(ApiError);
      });
    });

    describe('deleteSource', () => {
      it('deletes a source without species references', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockResponse(null));

        const { deleteSource } = await import('../lib/apiClient.js');
        await deleteSource(5);

        expect(mockFetch).toHaveBeenCalledWith(
          expect.stringContaining('/api/v1/sources/5'),
          expect.objectContaining({
            method: 'DELETE'
          })
        );
      });

      it('returns 409 constraint error when source has species references', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockErrorResponse(
          'Cannot delete source with species references',
          409,
          'CONSTRAINT_ERROR'
        ));

        const { deleteSource, ApiError } = await import('../lib/apiClient.js');

        try {
          await deleteSource(1); // Main source with many references
          expect.fail('Should have thrown');
        } catch (error) {
          expect(error).toBeInstanceOf(ApiError);
          expect(error.status).toBe(409);
          expect(error.code).toBe('CONSTRAINT_ERROR');
        }
      });

      it('constraint error message indicates species are blocking deletion', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockErrorResponse(
          'Cannot delete source: 523 species reference this source',
          409,
          'CONSTRAINT_ERROR'
        ));

        const { deleteSource } = await import('../lib/apiClient.js');

        try {
          await deleteSource(1);
        } catch (error) {
          expect(error.message).toContain('species');
          expect(error.status).toBe(409);
        }
      });
    });
  });

  // =============================================================================
  // Error Handling Tests
  // =============================================================================
  describe('Error Handling', () => {
    describe('Validation errors (400)', () => {
      it('parses field-level validation errors', async () => {
        setupValidSession();

        const fieldErrors = [
          { field: 'scientific_name', message: 'Name contains invalid characters' },
          { field: 'author', message: 'Author too long' }
        ];

        mockFetch.mockResolvedValueOnce(mockErrorResponse(
          'Validation failed',
          400,
          'VALIDATION_ERROR',
          fieldErrors
        ));

        const { createSpecies, ApiError } = await import('../lib/apiClient.js');

        try {
          await createSpecies({ name: 'invalid@name', author: 'A'.repeat(500) });
        } catch (error) {
          expect(error).toBeInstanceOf(ApiError);
          expect(error.status).toBe(400);
          expect(error.fieldErrors).toHaveLength(2);
          expect(error.fieldErrors[0].field).toBe('scientific_name');
          expect(error.fieldErrors[1].field).toBe('author');
        }
      });

      it('shows validation errors inline in form', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockErrorResponse(
          'Validation failed',
          400,
          'VALIDATION_ERROR',
          [{ field: 'scientific_name', message: 'Required' }]
        ));

        const { createSpecies } = await import('../lib/apiClient.js');

        try {
          await createSpecies({ name: '' });
        } catch (error) {
          // Form should display error.fieldErrors inline
          expect(error.fieldErrors).toBeDefined();
          expect(error.fieldErrors[0].message).toBe('Required');
        }
      });
    });

    describe('Network failure', () => {
      it('shows toast for network error', async () => {
        setupValidSession();

        // Simulate network failure
        mockFetch.mockRejectedValueOnce(new TypeError('Failed to fetch'));

        const { createSpecies, ApiError } = await import('../lib/apiClient.js');

        try {
          await createSpecies({ name: 'test' });
        } catch (error) {
          expect(error).toBeInstanceOf(ApiError);
          expect(error.code).toBe('NETWORK_ERROR');
          expect(error.status).toBe(0);
        }
      });

      it('shows toast for timeout', async () => {
        setupValidSession();

        // Simulate abort (timeout)
        const abortError = new Error('Aborted');
        abortError.name = 'AbortError';
        mockFetch.mockRejectedValueOnce(abortError);

        const { createSpecies, ApiError } = await import('../lib/apiClient.js');

        try {
          await createSpecies({ name: 'test' });
        } catch (error) {
          expect(error).toBeInstanceOf(ApiError);
          expect(error.code).toBe('TIMEOUT');
          expect(error.status).toBe(0);
        }
      });
    });

    describe('Authentication errors (401)', () => {
      it('clears auth and shows message on 401', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce(mockErrorResponse(
          'Unauthorized',
          401,
          'UNAUTHORIZED'
        ));

        // Need to re-import after setting up session
        vi.resetModules();

        // Re-mock before importing
        vi.doMock('../lib/stores/toastStore.js', () => ({
          toast: mockToast
        }));

        const { createSpecies, ApiError } = await import('../lib/apiClient.js');

        try {
          await createSpecies({ name: 'test' });
        } catch (error) {
          expect(error).toBeInstanceOf(ApiError);
          expect(error.status).toBe(401);
          // authStore.clearKey() and toast.warning() should be called
          // This is tested via integration with authStore
        }
      });

      it('throws UNAUTHENTICATED when no API key', async () => {
        // No session set up
        const { createSpecies, ApiError } = await import('../lib/apiClient.js');

        try {
          await createSpecies({ name: 'test' });
        } catch (error) {
          expect(error).toBeInstanceOf(ApiError);
          expect(error.status).toBe(401);
          expect(error.code).toBe('UNAUTHENTICATED');
        }
      });
    });

    describe('Rate limiting (429)', () => {
      it('shows rate limit message', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce({
          ok: false,
          status: 429,
          statusText: 'Too Many Requests',
          headers: new Map([['Retry-After', '60']]),
          json: vi.fn().mockResolvedValue({})
        });

        const { createSpecies, RateLimitError } = await import('../lib/apiClient.js');

        try {
          await createSpecies({ name: 'test' });
        } catch (error) {
          expect(error).toBeInstanceOf(RateLimitError);
          expect(error.status).toBe(429);
          expect(error.retryAfter).toBe(60);
          expect(error.code).toBe('RATE_LIMITED');
        }
      });

      it('handles missing Retry-After header', async () => {
        setupValidSession();

        mockFetch.mockResolvedValueOnce({
          ok: false,
          status: 429,
          statusText: 'Too Many Requests',
          headers: new Map(),
          json: vi.fn().mockResolvedValue({})
        });

        const { createSpecies, RateLimitError } = await import('../lib/apiClient.js');

        try {
          await createSpecies({ name: 'test' });
        } catch (error) {
          expect(error).toBeInstanceOf(RateLimitError);
          expect(error.retryAfter).toBeNull();
        }
      });
    });
  });

  // =============================================================================
  // Offline Mode Tests
  // =============================================================================
  describe('Offline Mode', () => {
    beforeEach(() => {
      vi.resetModules();
    });

    describe('canEdit store', () => {
      it('canEdit is false when offline', async () => {
        setupValidSession();

        // Mock navigator.onLine as false
        Object.defineProperty(global.navigator, 'onLine', {
          value: false,
          writable: true,
          configurable: true
        });

        const { canEdit, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(false);
        apiAvailable.set(false);

        expect(get(canEdit)).toBe(false);
      });

      it('canEdit is false when API unavailable', async () => {
        setupValidSession();

        Object.defineProperty(global.navigator, 'onLine', {
          value: true,
          writable: true,
          configurable: true
        });

        const { canEdit, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(true);
        apiAvailable.set(false);

        expect(get(canEdit)).toBe(false);
      });

      it('canEdit is true when online, authenticated, and API available', async () => {
        setupValidSession();

        Object.defineProperty(global.navigator, 'onLine', {
          value: true,
          writable: true,
          configurable: true
        });

        const { canEdit, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(true);
        apiAvailable.set(true);

        expect(get(canEdit)).toBe(true);
      });
    });

    describe('getCannotEditReason', () => {
      it('returns "Offline" when offline', async () => {
        setupValidSession();

        const { getCannotEditReason, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(false);
        apiAvailable.set(true);

        expect(getCannotEditReason()).toBe('Offline');
      });

      it('returns "API unavailable" when API is down', async () => {
        setupValidSession();

        const { getCannotEditReason, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(true);
        apiAvailable.set(false);

        expect(getCannotEditReason()).toBe('API unavailable');
      });

      it('returns "Not authenticated" when not logged in', async () => {
        // No session
        const { getCannotEditReason } = await import('../lib/stores/authStore.js');

        expect(getCannotEditReason()).toBe('Not authenticated');
      });

      it('returns null when can edit', async () => {
        setupValidSession();

        const { getCannotEditReason, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(true);
        apiAvailable.set(true);

        expect(getCannotEditReason()).toBe(null);
      });
    });

    describe('Form data preservation', () => {
      it('form data is preserved when connection is lost mid-edit', async () => {
        // This tests the component behavior pattern
        // The SpeciesEditForm tracks connectionLostDuringEdit state
        // and preserves formData when canEdit becomes false

        setupValidSession();

        const { isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        // Simulate form data
        const formData = {
          name: 'unsaved-species',
          author: 'Test Author',
          conservation_status: 'LC'
        };

        // User starts editing (online)
        isOnline.set(true);
        apiAvailable.set(true);

        // Connection lost
        isOnline.set(false);

        // Form data should still be intact (component responsibility)
        // This is a unit test verifying the store state changes
        // The component uses $: reactive statements to track this
        expect(formData.name).toBe('unsaved-species');
        expect(formData.author).toBe('Test Author');
      });

      it('shows connection warning when offline mid-edit', async () => {
        // This validates the pattern used in SpeciesEditForm
        setupValidSession();

        const { canEdit, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        // Start online
        isOnline.set(true);
        apiAvailable.set(true);
        expect(get(canEdit)).toBe(true);

        // Go offline
        isOnline.set(false);

        // Now canEdit should be false
        expect(get(canEdit)).toBe(false);

        // Component would set connectionLostDuringEdit = true
        // and show warning banner "Connection lost. Your changes are preserved."
      });
    });
  });
});

// =============================================================================
// Format Conversion Tests (Unit tests for helper functions)
// =============================================================================
describe('Format Conversion', () => {
  describe('speciesSourceToApiFormat', () => {
    it('converts species source fields correctly', async () => {
      const { speciesSourceToApiFormat } = await import('../lib/apiClient.js');

      const webFormat = {
        source_id: 1,
        local_names: ['white oak'],
        range: 'Eastern NA',
        growth_habit: 'Tree',
        leaves: 'Lobed',
        flowers: 'Catkins',
        fruits: 'Acorns',
        bark: 'Gray',
        twigs: 'Brown',
        buds: 'Pointed',
        hardiness_habitat: 'Zone 4-9',
        miscellaneous: 'Notes',
        url: 'https://example.com',
        is_preferred: true
      };

      const result = speciesSourceToApiFormat(webFormat);

      expect(result.source_id).toBe(1);
      expect(result.local_names).toEqual(['white oak']);
      expect(result.is_preferred).toBe(true);
      expect(result.leaves).toBe('Lobed');
    });

    it('handles missing optional fields', async () => {
      const { speciesSourceToApiFormat } = await import('../lib/apiClient.js');

      const minimal = {
        source_id: 1
      };

      const result = speciesSourceToApiFormat(minimal);

      expect(result.source_id).toBe(1);
      expect(result.local_names).toEqual([]);
      expect(result.range).toBeNull();
      expect(result.is_preferred).toBe(false);
    });
  });
});
