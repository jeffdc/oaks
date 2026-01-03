import { describe, it, expect } from 'vitest';

// Test helper functions extracted from SearchResults.svelte
describe('SearchResults helper functions', () => {
  describe('needsHybridSymbol', () => {
    // Check if hybrid name already has the hybrid symbol
    const needsHybridSymbol = (species) => {
      const name = species.scientific_name || species.name;
      return species.is_hybrid && !name.startsWith('×');
    };

    it('returns true for hybrid without × prefix', () => {
      expect(needsHybridSymbol({ is_hybrid: true, name: 'bebbiana' })).toBe(true);
    });

    it('returns true for hybrid using scientific_name field', () => {
      expect(needsHybridSymbol({ is_hybrid: true, scientific_name: 'bebbiana' })).toBe(true);
    });

    it('returns false for hybrid with × prefix', () => {
      expect(needsHybridSymbol({ is_hybrid: true, name: '× bebbiana' })).toBe(false);
    });

    it('returns false for hybrid with × prefix (no space)', () => {
      expect(needsHybridSymbol({ is_hybrid: true, name: '×bebbiana' })).toBe(false);
    });

    it('returns false for non-hybrid', () => {
      expect(needsHybridSymbol({ is_hybrid: false, name: 'alba' })).toBe(false);
    });

    it('returns false for non-hybrid even with × in name', () => {
      // Edge case: non-hybrid shouldn't need symbol
      expect(needsHybridSymbol({ is_hybrid: false, name: '× test' })).toBe(false);
    });
  });

  describe('getSpeciesName', () => {
    // Get species name (supports both API formats)
    const getSpeciesName = (species) => {
      return species.scientific_name || species.name;
    };

    it('returns scientific_name when available', () => {
      const species = { scientific_name: 'alba', name: 'legacy_name' };
      expect(getSpeciesName(species)).toBe('alba');
    });

    it('returns name when scientific_name is missing', () => {
      const species = { name: 'alba' };
      expect(getSpeciesName(species)).toBe('alba');
    });

    it('returns scientific_name even when empty', () => {
      const species = { scientific_name: '', name: 'alba' };
      // Empty string is falsy, so should fall back to name
      expect(getSpeciesName(species)).toBe('alba');
    });

    it('returns undefined when neither field exists', () => {
      const species = {};
      expect(getSpeciesName(species)).toBeUndefined();
    });
  });

  describe('getCommonNames', () => {
    // Simple version without getPrimarySource dependency
    const getCommonNamesSimple = (species) => {
      if (species.local_names && species.local_names.length > 0) {
        return species.local_names;
      }
      return [];
    };

    it('returns local_names when available', () => {
      const species = { local_names: ['white oak', 'eastern white oak'] };
      expect(getCommonNamesSimple(species)).toEqual(['white oak', 'eastern white oak']);
    });

    it('returns empty array when local_names is empty', () => {
      const species = { local_names: [] };
      expect(getCommonNamesSimple(species)).toEqual([]);
    });

    it('returns empty array when local_names is missing', () => {
      const species = { name: 'alba' };
      expect(getCommonNamesSimple(species)).toEqual([]);
    });

    it('returns single common name', () => {
      const species = { local_names: ['white oak'] };
      expect(getCommonNamesSimple(species)).toEqual(['white oak']);
    });
  });

  describe('browse mode counts', () => {
    // Test count calculations for browse mode
    const calculateBrowseCounts = (species) => ({
      speciesCount: species.filter(s => !s.is_hybrid).length,
      hybridCount: species.filter(s => s.is_hybrid).length,
      total: species.length
    });

    it('calculates correct counts for mixed species list', () => {
      const species = [
        { name: 'alba', is_hybrid: false },
        { name: 'rubra', is_hybrid: false },
        { name: 'bebbiana', is_hybrid: true },
        { name: 'jackiana', is_hybrid: true },
        { name: 'macrocarpa', is_hybrid: false }
      ];
      const counts = calculateBrowseCounts(species);
      expect(counts.speciesCount).toBe(3);
      expect(counts.hybridCount).toBe(2);
      expect(counts.total).toBe(5);
    });

    it('handles all non-hybrids', () => {
      const species = [
        { name: 'alba', is_hybrid: false },
        { name: 'rubra', is_hybrid: false }
      ];
      const counts = calculateBrowseCounts(species);
      expect(counts.speciesCount).toBe(2);
      expect(counts.hybridCount).toBe(0);
      expect(counts.total).toBe(2);
    });

    it('handles all hybrids', () => {
      const species = [
        { name: 'bebbiana', is_hybrid: true },
        { name: 'jackiana', is_hybrid: true }
      ];
      const counts = calculateBrowseCounts(species);
      expect(counts.speciesCount).toBe(0);
      expect(counts.hybridCount).toBe(2);
      expect(counts.total).toBe(2);
    });

    it('handles empty list', () => {
      const counts = calculateBrowseCounts([]);
      expect(counts.speciesCount).toBe(0);
      expect(counts.hybridCount).toBe(0);
      expect(counts.total).toBe(0);
    });
  });

  describe('search results structure', () => {
    // Test extraction of search result components
    const extractSearchComponents = (searchResults) => ({
      species: searchResults.species || [],
      taxa: searchResults.taxa || [],
      sources: searchResults.sources || [],
      counts: searchResults.counts || { species: 0, taxa: 0, sources: 0, total: 0 }
    });

    it('extracts all components from complete results', () => {
      const results = {
        species: [{ name: 'alba' }],
        taxa: [{ name: 'Quercus', level: 'section' }],
        sources: [{ id: 1, name: 'Source 1' }],
        counts: { species: 1, taxa: 1, sources: 1, total: 3 }
      };
      const extracted = extractSearchComponents(results);
      expect(extracted.species).toHaveLength(1);
      expect(extracted.taxa).toHaveLength(1);
      expect(extracted.sources).toHaveLength(1);
      expect(extracted.counts.total).toBe(3);
    });

    it('handles missing components', () => {
      const results = { species: [{ name: 'alba' }] };
      const extracted = extractSearchComponents(results);
      expect(extracted.species).toHaveLength(1);
      expect(extracted.taxa).toEqual([]);
      expect(extracted.sources).toEqual([]);
      expect(extracted.counts.total).toBe(0);
    });

    it('handles empty results', () => {
      const extracted = extractSearchComponents({});
      expect(extracted.species).toEqual([]);
      expect(extracted.taxa).toEqual([]);
      expect(extracted.sources).toEqual([]);
      expect(extracted.counts.total).toBe(0);
    });
  });
});
