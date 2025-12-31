import { describe, it, expect } from 'vitest';
import {
  speciesToApiFormat,
  taxonToApiFormat,
  sourceToApiFormat,
  ApiError
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
