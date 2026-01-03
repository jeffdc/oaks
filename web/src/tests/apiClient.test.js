import { describe, it, expect, vi } from 'vitest';
import {
  speciesToApiFormat,
  taxonToApiFormat,
  sourceToApiFormat,
  ApiError,
  fetchWithRetry,
  createSpecies,
  updateSpecies,
  deleteSpecies,
  createSpeciesSource,
  updateSpeciesSource,
  deleteSpeciesSource,
  createTaxon,
  updateTaxon,
  deleteTaxon,
  createSource,
  updateSource,
  deleteSource
} from '../lib/apiClient.js';

describe('apiClient format conversion functions', () => {
  describe('speciesToApiFormat', () => {
    it('converts species name to scientific_name', () => {
      const species = { name: 'alba' };
      const result = speciesToApiFormat(species);
      expect(result.scientific_name).toBe('alba');
    });

    it('preserves author field', () => {
      const species = { name: 'alba', author: 'L. 1753' };
      const result = speciesToApiFormat(species);
      expect(result.author).toBe('L. 1753');
    });

    it('defaults author to null when missing', () => {
      const species = { name: 'alba' };
      const result = speciesToApiFormat(species);
      expect(result.author).toBeNull();
    });

    it('preserves is_hybrid field', () => {
      const species = { name: 'bebbiana', is_hybrid: true };
      const result = speciesToApiFormat(species);
      expect(result.is_hybrid).toBe(true);
    });

    it('defaults is_hybrid to false when missing', () => {
      const species = { name: 'alba' };
      const result = speciesToApiFormat(species);
      expect(result.is_hybrid).toBe(false);
    });

    it('preserves conservation_status', () => {
      const species = { name: 'alba', conservation_status: 'LC' };
      const result = speciesToApiFormat(species);
      expect(result.conservation_status).toBe('LC');
    });

    it('flattens nested taxonomy object', () => {
      const species = {
        name: 'alba',
        taxonomy: {
          subgenus: 'Quercus',
          section: 'Quercus',
          subsection: 'Albae',
          complex: null
        }
      };
      const result = speciesToApiFormat(species);
      expect(result.subgenus).toBe('Quercus');
      expect(result.section).toBe('Quercus');
      expect(result.subsection).toBe('Albae');
      expect(result.complex).toBeNull();
    });

    it('handles missing taxonomy object', () => {
      const species = { name: 'alba' };
      const result = speciesToApiFormat(species);
      expect(result.subgenus).toBeNull();
      expect(result.section).toBeNull();
      expect(result.subsection).toBeNull();
      expect(result.complex).toBeNull();
    });

    it('preserves hybrid parents', () => {
      const species = {
        name: 'bebbiana',
        is_hybrid: true,
        parent1: 'alba',
        parent2: 'macrocarpa'
      };
      const result = speciesToApiFormat(species);
      expect(result.parent1).toBe('alba');
      expect(result.parent2).toBe('macrocarpa');
    });

    it('defaults parent fields to null when missing', () => {
      const species = { name: 'alba' };
      const result = speciesToApiFormat(species);
      expect(result.parent1).toBeNull();
      expect(result.parent2).toBeNull();
    });

    it('preserves related species arrays', () => {
      const species = {
        name: 'alba',
        hybrids: ['bebbiana', 'jackiana'],
        closely_related_to: ['stellata', 'montana'],
        subspecies_varieties: ['alba var. latiloba']
      };
      const result = speciesToApiFormat(species);
      expect(result.hybrids).toEqual(['bebbiana', 'jackiana']);
      expect(result.closely_related_to).toEqual(['stellata', 'montana']);
      expect(result.subspecies_varieties).toEqual(['alba var. latiloba']);
    });

    it('defaults related species arrays to empty when missing', () => {
      const species = { name: 'alba' };
      const result = speciesToApiFormat(species);
      expect(result.hybrids).toEqual([]);
      expect(result.closely_related_to).toEqual([]);
      expect(result.subspecies_varieties).toEqual([]);
    });

    it('converts synonym objects to strings', () => {
      const species = {
        name: 'alba',
        synonyms: [
          { name: 'alba var. repanda', author: 'L.' },
          { name: 'alba var. latifolia' }
        ]
      };
      const result = speciesToApiFormat(species);
      expect(result.synonyms).toEqual(['alba var. repanda', 'alba var. latifolia']);
    });

    it('preserves string synonyms as-is', () => {
      const species = {
        name: 'alba',
        synonyms: ['alba var. repanda', 'alba var. latifolia']
      };
      const result = speciesToApiFormat(species);
      expect(result.synonyms).toEqual(['alba var. repanda', 'alba var. latifolia']);
    });

    it('handles mixed synonym formats', () => {
      const species = {
        name: 'alba',
        synonyms: [
          'alba var. repanda',
          { name: 'alba var. latifolia', author: 'DC.' }
        ]
      };
      const result = speciesToApiFormat(species);
      expect(result.synonyms).toEqual(['alba var. repanda', 'alba var. latifolia']);
    });

    it('defaults synonyms to empty array when missing', () => {
      const species = { name: 'alba' };
      const result = speciesToApiFormat(species);
      expect(result.synonyms).toEqual([]);
    });

    it('preserves external_links', () => {
      const species = {
        name: 'alba',
        external_links: [
          { title: 'Wikipedia', url: 'https://en.wikipedia.org/wiki/Quercus_alba' }
        ]
      };
      const result = speciesToApiFormat(species);
      expect(result.external_links).toEqual([
        { title: 'Wikipedia', url: 'https://en.wikipedia.org/wiki/Quercus_alba' }
      ]);
    });

    it('defaults external_links to empty array when missing', () => {
      const species = { name: 'alba' };
      const result = speciesToApiFormat(species);
      expect(result.external_links).toEqual([]);
    });

    it('converts complete species object', () => {
      const species = {
        name: 'alba',
        author: 'L. 1753',
        is_hybrid: false,
        conservation_status: 'LC',
        taxonomy: {
          subgenus: 'Quercus',
          section: 'Quercus',
          subsection: 'Albae',
          complex: null
        },
        parent1: null,
        parent2: null,
        hybrids: ['bebbiana'],
        closely_related_to: ['stellata'],
        subspecies_varieties: ['alba var. latiloba'],
        synonyms: [{ name: 'alba var. repanda' }],
        external_links: []
      };

      const result = speciesToApiFormat(species);

      expect(result).toEqual({
        scientific_name: 'alba',
        author: 'L. 1753',
        is_hybrid: false,
        conservation_status: 'LC',
        subgenus: 'Quercus',
        section: 'Quercus',
        subsection: 'Albae',
        complex: null,
        parent1: null,
        parent2: null,
        hybrids: ['bebbiana'],
        closely_related_to: ['stellata'],
        subspecies_varieties: ['alba var. latiloba'],
        synonyms: ['alba var. repanda'],
        external_links: []
      });
    });
  });

  describe('taxonToApiFormat', () => {
    it('preserves all taxon fields', () => {
      const taxon = {
        name: 'Quercus',
        level: 'section',
        parent: 'Quercus',
        author: 'L.',
        notes: 'White oaks',
        links: [{ url: 'https://example.com' }]
      };

      const result = taxonToApiFormat(taxon);

      expect(result).toEqual({
        name: 'Quercus',
        level: 'section',
        parent: 'Quercus',
        author: 'L.',
        notes: 'White oaks',
        links: [{ url: 'https://example.com' }]
      });
    });

    it('defaults optional fields to null/empty', () => {
      const taxon = {
        name: 'Cerris',
        level: 'subgenus'
      };

      const result = taxonToApiFormat(taxon);

      expect(result.parent).toBeNull();
      expect(result.author).toBeNull();
      expect(result.notes).toBeNull();
      expect(result.links).toEqual([]);
    });
  });

  describe('sourceToApiFormat', () => {
    it('preserves all source fields', () => {
      const source = {
        id: 1,
        source_type: 'website',
        name: 'Oaks of the World',
        description: 'Comprehensive oak database',
        author: 'Antoine Le Hardy de Beaulieu',
        year: 2020,
        url: 'https://oaksoftheworld.fr',
        isbn: null,
        doi: null,
        notes: 'Primary reference',
        license: 'CC BY-SA',
        license_url: 'https://creativecommons.org/licenses/by-sa/4.0/'
      };

      const result = sourceToApiFormat(source);

      expect(result).toEqual({
        id: 1,
        source_type: 'website',
        name: 'Oaks of the World',
        description: 'Comprehensive oak database',
        author: 'Antoine Le Hardy de Beaulieu',
        year: 2020,
        url: 'https://oaksoftheworld.fr',
        isbn: null,
        doi: null,
        notes: 'Primary reference',
        license: 'CC BY-SA',
        license_url: 'https://creativecommons.org/licenses/by-sa/4.0/'
      });
    });

    it('defaults optional fields to null', () => {
      const source = {
        id: 1,
        source_type: 'book',
        name: 'Field Guide to Oaks'
      };

      const result = sourceToApiFormat(source);

      expect(result.description).toBeNull();
      expect(result.author).toBeNull();
      expect(result.year).toBeNull();
      expect(result.url).toBeNull();
      expect(result.isbn).toBeNull();
      expect(result.doi).toBeNull();
      expect(result.notes).toBeNull();
      expect(result.license).toBeNull();
      expect(result.license_url).toBeNull();
    });
  });

  describe('ApiError', () => {
    it('creates error with message, status, and code', () => {
      const error = new ApiError('Not found', 404, 'NOT_FOUND');

      expect(error.message).toBe('Not found');
      expect(error.status).toBe(404);
      expect(error.code).toBe('NOT_FOUND');
      expect(error.name).toBe('ApiError');
    });

    it('creates error with details object', () => {
      const error = new ApiError('Cannot delete', 409, 'CONFLICT', {
        blocking_hybrids: ['bebbiana', 'jackiana']
      });

      expect(error.status).toBe(409);
      expect(error.code).toBe('CONFLICT');
      expect(error.details).toEqual({ blocking_hybrids: ['bebbiana', 'jackiana'] });
    });

    it('defaults details to null when not provided', () => {
      const error = new ApiError('Not found', 404, 'NOT_FOUND');
      expect(error.details).toBeNull();
    });

    it('is instanceof Error', () => {
      const error = new ApiError('Test error', 500, 'INTERNAL_ERROR');
      expect(error).toBeInstanceOf(Error);
    });

    it('is instanceof ApiError', () => {
      const error = new ApiError('Test error', 500, 'INTERNAL_ERROR');
      expect(error).toBeInstanceOf(ApiError);
    });

    it('can be thrown and caught', () => {
      expect(() => {
        throw new ApiError('Unauthorized', 401, 'UNAUTHORIZED');
      }).toThrow(ApiError);
    });

    it('includes stack trace', () => {
      const error = new ApiError('Test', 500, 'TEST');
      expect(error.stack).toBeDefined();
    });
  });
});

describe('fetchWithRetry', () => {
  it('returns result on first success', async () => {
    const fn = vi.fn().mockResolvedValue('success');
    const result = await fetchWithRetry(fn, { baseDelay: 10 });
    expect(result).toBe('success');
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it('retries on failure and succeeds', async () => {
    const fn = vi.fn()
      .mockRejectedValueOnce(new ApiError('Server error', 500, 'INTERNAL'))
      .mockResolvedValueOnce('success');

    const result = await fetchWithRetry(fn, { baseDelay: 10 });
    expect(result).toBe('success');
    expect(fn).toHaveBeenCalledTimes(2);
  });

  it('retries up to maxRetries times', async () => {
    const fn = vi.fn().mockRejectedValue(new ApiError('Server error', 500, 'INTERNAL'));

    await expect(fetchWithRetry(fn, { maxRetries: 3, baseDelay: 10 }))
      .rejects.toThrow(ApiError);

    expect(fn).toHaveBeenCalledTimes(4); // initial + 3 retries
  });

  it('does not retry on 4xx errors (except 408, 429)', async () => {
    const fn = vi.fn().mockRejectedValue(new ApiError('Not found', 404, 'NOT_FOUND'));

    await expect(fetchWithRetry(fn, { maxRetries: 3, baseDelay: 10 }))
      .rejects.toThrow(ApiError);

    expect(fn).toHaveBeenCalledTimes(1); // no retries
  });

  it('does not retry on 400 Bad Request', async () => {
    const fn = vi.fn().mockRejectedValue(new ApiError('Bad request', 400, 'BAD_REQUEST'));

    await expect(fetchWithRetry(fn, { maxRetries: 3, baseDelay: 10 }))
      .rejects.toThrow(ApiError);

    expect(fn).toHaveBeenCalledTimes(1);
  });

  it('does not retry on 401 Unauthorized', async () => {
    const fn = vi.fn().mockRejectedValue(new ApiError('Unauthorized', 401, 'UNAUTHORIZED'));

    await expect(fetchWithRetry(fn, { maxRetries: 3, baseDelay: 10 }))
      .rejects.toThrow(ApiError);

    expect(fn).toHaveBeenCalledTimes(1);
  });

  it('does not retry on 403 Forbidden', async () => {
    const fn = vi.fn().mockRejectedValue(new ApiError('Forbidden', 403, 'FORBIDDEN'));

    await expect(fetchWithRetry(fn, { maxRetries: 3, baseDelay: 10 }))
      .rejects.toThrow(ApiError);

    expect(fn).toHaveBeenCalledTimes(1);
  });

  it('retries on 408 Request Timeout', async () => {
    const fn = vi.fn()
      .mockRejectedValueOnce(new ApiError('Timeout', 408, 'TIMEOUT'))
      .mockResolvedValueOnce('success');

    const result = await fetchWithRetry(fn, { baseDelay: 10 });
    expect(result).toBe('success');
    expect(fn).toHaveBeenCalledTimes(2);
  });

  it('retries on 429 Too Many Requests', async () => {
    const fn = vi.fn()
      .mockRejectedValueOnce(new ApiError('Rate limited', 429, 'RATE_LIMITED'))
      .mockResolvedValueOnce('success');

    const result = await fetchWithRetry(fn, { baseDelay: 10 });
    expect(result).toBe('success');
    expect(fn).toHaveBeenCalledTimes(2);
  });

  it('retries on 5xx server errors', async () => {
    const fn = vi.fn()
      .mockRejectedValueOnce(new ApiError('Bad gateway', 502, 'BAD_GATEWAY'))
      .mockRejectedValueOnce(new ApiError('Service unavailable', 503, 'SERVICE_UNAVAILABLE'))
      .mockResolvedValueOnce('success');

    const result = await fetchWithRetry(fn, { baseDelay: 10 });
    expect(result).toBe('success');
    expect(fn).toHaveBeenCalledTimes(3);
  });

  it('retries on network errors', async () => {
    const fn = vi.fn()
      .mockRejectedValueOnce(new ApiError('Network error', 0, 'NETWORK_ERROR'))
      .mockResolvedValueOnce('success');

    const result = await fetchWithRetry(fn, { baseDelay: 10 });
    expect(result).toBe('success');
    expect(fn).toHaveBeenCalledTimes(2);
  });

  it('uses exponential backoff', async () => {
    vi.useFakeTimers();
    const fn = vi.fn()
      .mockRejectedValueOnce(new ApiError('Error', 500, 'INTERNAL'))
      .mockRejectedValueOnce(new ApiError('Error', 500, 'INTERNAL'))
      .mockResolvedValueOnce('success');

    const promise = fetchWithRetry(fn, { baseDelay: 1000 });

    // First call happens immediately
    await vi.advanceTimersByTimeAsync(0);
    expect(fn).toHaveBeenCalledTimes(1);

    // First retry after 1s
    await vi.advanceTimersByTimeAsync(1000);
    expect(fn).toHaveBeenCalledTimes(2);

    // Second retry after 2s (exponential: 1000 * 2^1)
    await vi.advanceTimersByTimeAsync(2000);
    expect(fn).toHaveBeenCalledTimes(3);

    const result = await promise;
    expect(result).toBe('success');

    vi.useRealTimers();
  });

  it('uses default options when none provided', async () => {
    const fn = vi.fn().mockResolvedValue('success');
    const result = await fetchWithRetry(fn);
    expect(result).toBe('success');
    expect(fn).toHaveBeenCalledTimes(1);
  });
});

describe('mutation functions exist', () => {
  // These tests verify the mutation functions are exported
  // Full integration tests would require mocking fetch
  describe('species mutations', () => {
    it('exports createSpecies function', () => {
      expect(typeof createSpecies).toBe('function');
    });

    it('exports updateSpecies function', () => {
      expect(typeof updateSpecies).toBe('function');
    });

    it('exports deleteSpecies function', () => {
      expect(typeof deleteSpecies).toBe('function');
    });
  });

  describe('species-source mutations', () => {
    it('exports createSpeciesSource function', () => {
      expect(typeof createSpeciesSource).toBe('function');
    });

    it('exports updateSpeciesSource function', () => {
      expect(typeof updateSpeciesSource).toBe('function');
    });

    it('exports deleteSpeciesSource function', () => {
      expect(typeof deleteSpeciesSource).toBe('function');
    });
  });

  describe('taxon mutations', () => {
    it('exports createTaxon function', () => {
      expect(typeof createTaxon).toBe('function');
    });

    it('exports updateTaxon function', () => {
      expect(typeof updateTaxon).toBe('function');
    });

    it('exports deleteTaxon function', () => {
      expect(typeof deleteTaxon).toBe('function');
    });
  });

  describe('source mutations', () => {
    it('exports createSource function', () => {
      expect(typeof createSource).toBe('function');
    });

    it('exports updateSource function', () => {
      expect(typeof updateSource).toBe('function');
    });

    it('exports deleteSource function', () => {
      expect(typeof deleteSource).toBe('function');
    });
  });
});
