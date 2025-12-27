import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/svelte';

// Test the helper functions used in SpeciesDetail
// Note: Full component rendering requires mocking $app/paths, $app/navigation, and marked

describe('SpeciesDetail helper functions', () => {
  // Test conservation status mapping (extracted from component logic)
  describe('conservation status helpers', () => {
    const getConservationStatusLabel = (status) => {
      const labels = {
        'LC': 'Least Concern',
        'NT': 'Near Threatened',
        'VU': 'Vulnerable',
        'EN': 'Endangered',
        'CR': 'Critically Endangered',
        'EW': 'Extinct in the Wild',
        'EX': 'Extinct',
        'DD': 'Data Deficient',
        'NE': 'Not Evaluated'
      };
      return labels[status] || status;
    };

    const getConservationStatusColors = (status) => {
      const colors = {
        'EX': { bg: '#000000', text: '#FFFFFF' },
        'EW': { bg: '#542344', text: '#FFFFFF' },
        'CR': { bg: '#D81E05', text: '#FFFFFF' },
        'EN': { bg: '#FC7F3F', text: '#000000' },
        'VU': { bg: '#F9E814', text: '#000000' },
        'NT': { bg: '#CCE226', text: '#000000' },
        'LC': { bg: '#60C659', text: '#000000' },
        'DD': { bg: '#D1D1C6', text: '#000000' },
        'NE': { bg: '#FFFFFF', text: '#000000', border: '#D1D1C6' }
      };
      return colors[status] || { bg: '#D1D1C6', text: '#000000' };
    };

    it('maps LC to Least Concern', () => {
      expect(getConservationStatusLabel('LC')).toBe('Least Concern');
    });

    it('maps CR to Critically Endangered', () => {
      expect(getConservationStatusLabel('CR')).toBe('Critically Endangered');
    });

    it('returns original status for unknown codes', () => {
      expect(getConservationStatusLabel('XX')).toBe('XX');
    });

    it('returns correct colors for LC status', () => {
      const colors = getConservationStatusColors('LC');
      expect(colors.bg).toBe('#60C659');
      expect(colors.text).toBe('#000000');
    });

    it('returns correct colors for CR status', () => {
      const colors = getConservationStatusColors('CR');
      expect(colors.bg).toBe('#D81E05');
      expect(colors.text).toBe('#FFFFFF');
    });

    it('returns NE status with border', () => {
      const colors = getConservationStatusColors('NE');
      expect(colors.border).toBe('#D1D1C6');
    });

    it('returns default colors for unknown status', () => {
      const colors = getConservationStatusColors('XX');
      expect(colors.bg).toBe('#D1D1C6');
    });
  });

  // Test hybrid name handling
  describe('hybrid name helpers', () => {
    const needsHybridSymbol = (s) => {
      return s.is_hybrid && !s.name.startsWith('×');
    };

    it('returns true for hybrid without × prefix', () => {
      expect(needsHybridSymbol({ is_hybrid: true, name: 'bebbiana' })).toBe(true);
    });

    it('returns false for hybrid with × prefix', () => {
      expect(needsHybridSymbol({ is_hybrid: true, name: '× bebbiana' })).toBe(false);
    });

    it('returns false for non-hybrid', () => {
      expect(needsHybridSymbol({ is_hybrid: false, name: 'alba' })).toBe(false);
    });
  });

  // Test parent extraction logic
  describe('getOtherParent', () => {
    const cleanName = (name) => name?.replace(/^Quercus\s+/, '').replace(/^×\s*/, '').trim();

    const getOtherParent = (hybrid, currentSpecies) => {
      const parent1 = cleanName(hybrid.parent1);
      const parent2 = cleanName(hybrid.parent2);
      const current = cleanName(currentSpecies);

      if (parent1 && parent1.toLowerCase() !== current.toLowerCase()) {
        return parent1;
      } else if (parent2 && parent2.toLowerCase() !== current.toLowerCase()) {
        return parent2;
      }
      return null;
    };

    it('returns parent1 when current species is parent2', () => {
      const hybrid = { parent1: 'Quercus alba', parent2: 'Quercus macrocarpa' };
      expect(getOtherParent(hybrid, 'macrocarpa')).toBe('alba');
    });

    it('returns parent2 when current species is parent1', () => {
      const hybrid = { parent1: 'Quercus alba', parent2: 'Quercus macrocarpa' };
      expect(getOtherParent(hybrid, 'alba')).toBe('macrocarpa');
    });

    it('handles Quercus prefix in parent names', () => {
      const hybrid = { parent1: 'Quercus alba', parent2: 'Quercus rubra' };
      expect(getOtherParent(hybrid, 'Quercus alba')).toBe('rubra');
    });

    it('returns null when no other parent found', () => {
      const hybrid = { parent1: null, parent2: null };
      expect(getOtherParent(hybrid, 'alba')).toBeNull();
    });
  });

  // Test external links sorting
  describe('external links helpers', () => {
    it('sorts links alphabetically by name', () => {
      const links = [
        { name: 'Wikipedia', url: 'http://example.com' },
        { name: 'iNaturalist', url: 'http://example.com' },
        { name: 'GBIF', url: 'http://example.com' }
      ];

      links.sort((a, b) => a.name.localeCompare(b.name));

      expect(links[0].name).toBe('GBIF');
      expect(links[1].name).toBe('iNaturalist');
      expect(links[2].name).toBe('Wikipedia');
    });
  });
});

describe('SourceComparison helper functions', () => {
  describe('renderValue', () => {
    const renderValue = (source, field) => {
      const value = source[field.key];
      if (!value) return null;

      if (field.type === 'array' && Array.isArray(value)) {
        return value.join(', ');
      }
      return value;
    };

    it('returns null for missing values', () => {
      const source = {};
      const field = { key: 'range', type: 'markdown' };
      expect(renderValue(source, field)).toBeNull();
    });

    it('returns string value for markdown fields', () => {
      const source = { range: 'Eastern North America' };
      const field = { key: 'range', type: 'markdown' };
      expect(renderValue(source, field)).toBe('Eastern North America');
    });

    it('joins array values with comma', () => {
      const source = { local_names: ['white oak', 'eastern white oak'] };
      const field = { key: 'local_names', type: 'array' };
      expect(renderValue(source, field)).toBe('white oak, eastern white oak');
    });
  });

  describe('fieldHasData', () => {
    const fieldHasData = (field, selectedSources) => {
      return selectedSources.some(s => {
        const val = s[field.key];
        if (Array.isArray(val)) return val.length > 0;
        return val && val.trim && val.trim().length > 0;
      });
    };

    it('returns true when at least one source has data', () => {
      const field = { key: 'range' };
      const sources = [
        { range: null },
        { range: 'Eastern North America' }
      ];
      expect(fieldHasData(field, sources)).toBe(true);
    });

    it('returns false when no sources have data', () => {
      const field = { key: 'range' };
      const sources = [
        { range: null },
        { range: '' }
      ];
      expect(fieldHasData(field, sources)).toBe(false);
    });

    it('handles array fields correctly', () => {
      const field = { key: 'local_names' };
      const sources = [
        { local_names: [] },
        { local_names: ['white oak'] }
      ];
      expect(fieldHasData(field, sources)).toBe(true);
    });

    it('returns false for empty arrays', () => {
      const field = { key: 'local_names' };
      const sources = [
        { local_names: [] }
      ];
      expect(fieldHasData(field, sources)).toBe(false);
    });
  });

  describe('toggleSource', () => {
    it('adds source when not selected', () => {
      let selectedSourceIds = [1, 2];
      const sourceId = 3;

      if (!selectedSourceIds.includes(sourceId) && selectedSourceIds.length < 4) {
        selectedSourceIds = [...selectedSourceIds, sourceId];
      }

      expect(selectedSourceIds).toContain(3);
      expect(selectedSourceIds).toHaveLength(3);
    });

    it('removes source when selected and more than one', () => {
      let selectedSourceIds = [1, 2, 3];
      const sourceId = 2;

      if (selectedSourceIds.includes(sourceId) && selectedSourceIds.length > 1) {
        selectedSourceIds = selectedSourceIds.filter(id => id !== sourceId);
      }

      expect(selectedSourceIds).not.toContain(2);
      expect(selectedSourceIds).toHaveLength(2);
    });

    it('does not remove last selected source', () => {
      let selectedSourceIds = [1];
      const sourceId = 1;

      if (selectedSourceIds.includes(sourceId) && selectedSourceIds.length > 1) {
        selectedSourceIds = selectedSourceIds.filter(id => id !== sourceId);
      }

      // Should still have the source since it's the last one
      expect(selectedSourceIds).toContain(1);
    });

    it('limits selection to 4 sources', () => {
      let selectedSourceIds = [1, 2, 3, 4];
      const sourceId = 5;

      if (!selectedSourceIds.includes(sourceId) && selectedSourceIds.length < 4) {
        selectedSourceIds = [...selectedSourceIds, sourceId];
      }

      // Should not add 5th source
      expect(selectedSourceIds).not.toContain(5);
      expect(selectedSourceIds).toHaveLength(4);
    });
  });
});
