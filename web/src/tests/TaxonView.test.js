import { describe, it, expect } from 'vitest';

// Test helper functions extracted from TaxonView.svelte
describe('TaxonView helper functions', () => {
  describe('getTaxonLevel', () => {
    const getTaxonLevel = (depth) => {
      const levels = ['genus', 'subgenus', 'section', 'subsection', 'complex'];
      return levels[depth] || 'taxon';
    };

    it('returns genus for depth 0', () => {
      expect(getTaxonLevel(0)).toBe('genus');
    });

    it('returns subgenus for depth 1', () => {
      expect(getTaxonLevel(1)).toBe('subgenus');
    });

    it('returns section for depth 2', () => {
      expect(getTaxonLevel(2)).toBe('section');
    });

    it('returns subsection for depth 3', () => {
      expect(getTaxonLevel(3)).toBe('subsection');
    });

    it('returns complex for depth 4', () => {
      expect(getTaxonLevel(4)).toBe('complex');
    });

    it('returns taxon for depth beyond array bounds', () => {
      expect(getTaxonLevel(5)).toBe('taxon');
      expect(getTaxonLevel(10)).toBe('taxon');
    });

    it('returns taxon for negative depth', () => {
      expect(getTaxonLevel(-1)).toBe('taxon');
    });
  });

  describe('getTaxonLevelLabel', () => {
    const getTaxonLevelLabel = (depth) => {
      const labels = ['Genus', 'Subgenus', 'Section', 'Subsection', 'Complex'];
      return labels[depth] || 'Taxon';
    };

    it('returns Genus for depth 0', () => {
      expect(getTaxonLevelLabel(0)).toBe('Genus');
    });

    it('returns Subgenus for depth 1', () => {
      expect(getTaxonLevelLabel(1)).toBe('Subgenus');
    });

    it('returns Section for depth 2', () => {
      expect(getTaxonLevelLabel(2)).toBe('Section');
    });

    it('returns Subsection for depth 3', () => {
      expect(getTaxonLevelLabel(3)).toBe('Subsection');
    });

    it('returns Complex for depth 4', () => {
      expect(getTaxonLevelLabel(4)).toBe('Complex');
    });

    it('returns Taxon for unknown depths', () => {
      expect(getTaxonLevelLabel(5)).toBe('Taxon');
    });
  });

  describe('getTaxonLevelLabelPlural', () => {
    const getTaxonLevelLabelPlural = (depth) => {
      const labels = ['Genera', 'Subgenera', 'Sections', 'Subsections', 'Complexes'];
      return labels[depth] || 'Taxa';
    };

    it('returns Genera for depth 0', () => {
      expect(getTaxonLevelLabelPlural(0)).toBe('Genera');
    });

    it('returns Subgenera for depth 1', () => {
      expect(getTaxonLevelLabelPlural(1)).toBe('Subgenera');
    });

    it('returns Sections for depth 2', () => {
      expect(getTaxonLevelLabelPlural(2)).toBe('Sections');
    });

    it('returns Subsections for depth 3', () => {
      expect(getTaxonLevelLabelPlural(3)).toBe('Subsections');
    });

    it('returns Complexes for depth 4', () => {
      expect(getTaxonLevelLabelPlural(4)).toBe('Complexes');
    });

    it('returns Taxa for unknown depths', () => {
      expect(getTaxonLevelLabelPlural(5)).toBe('Taxa');
      expect(getTaxonLevelLabelPlural(-1)).toBe('Taxa');
    });
  });

  describe('getBreadcrumbLevelLabel', () => {
    // Get lowercase level label for breadcrumb items (path index → level)
    const getBreadcrumbLevelLabel = (pathIndex) => {
      const labels = ['subgenus', 'section', 'subsection', 'complex'];
      return labels[pathIndex] || '';
    };

    it('returns subgenus for index 0', () => {
      expect(getBreadcrumbLevelLabel(0)).toBe('subgenus');
    });

    it('returns section for index 1', () => {
      expect(getBreadcrumbLevelLabel(1)).toBe('section');
    });

    it('returns subsection for index 2', () => {
      expect(getBreadcrumbLevelLabel(2)).toBe('subsection');
    });

    it('returns complex for index 3', () => {
      expect(getBreadcrumbLevelLabel(3)).toBe('complex');
    });

    it('returns empty string for out of bounds index', () => {
      expect(getBreadcrumbLevelLabel(4)).toBe('');
      expect(getBreadcrumbLevelLabel(-1)).toBe('');
    });
  });

  describe('getSpeciesName', () => {
    // Helper to get species name (supports both API format and legacy format)
    const getSpeciesName = (s) => {
      return s.scientific_name || s.name;
    };

    it('returns scientific_name when available', () => {
      expect(getSpeciesName({ scientific_name: 'alba' })).toBe('alba');
    });

    it('falls back to name when scientific_name is missing', () => {
      expect(getSpeciesName({ name: 'rubra' })).toBe('rubra');
    });

    it('prefers scientific_name over name', () => {
      expect(getSpeciesName({ scientific_name: 'alba', name: 'different' })).toBe('alba');
    });
  });

  describe('getTaxonUrl', () => {
    // Build taxonomy path URL (without base path for testing)
    const getTaxonUrl = (path) => {
      if (path.length === 0) return '/taxonomy/';
      return `/taxonomy/${path.map(encodeURIComponent).join('/')}/`;
    };

    it('returns base taxonomy URL for empty path', () => {
      expect(getTaxonUrl([])).toBe('/taxonomy/');
    });

    it('builds URL for single path element', () => {
      expect(getTaxonUrl(['Quercus'])).toBe('/taxonomy/Quercus/');
    });

    it('builds URL for multiple path elements', () => {
      expect(getTaxonUrl(['Quercus', 'Quercus', 'Albae'])).toBe('/taxonomy/Quercus/Quercus/Albae/');
    });

    it('encodes special characters in path', () => {
      expect(getTaxonUrl(['Test Name'])).toBe('/taxonomy/Test%20Name/');
    });

    it('handles path with reserved characters', () => {
      expect(getTaxonUrl(['Quercus/Special'])).toBe('/taxonomy/Quercus%2FSpecial/');
    });
  });

  describe('child level mapping', () => {
    // Determine what child level to fetch based on current depth
    const getChildLevel = (depth) => {
      const childLevelMap = ['subgenus', 'section', 'subsection', 'complex'];
      return childLevelMap[depth];
    };

    it('returns subgenus for depth 0 (genus level)', () => {
      expect(getChildLevel(0)).toBe('subgenus');
    });

    it('returns section for depth 1 (subgenus level)', () => {
      expect(getChildLevel(1)).toBe('section');
    });

    it('returns subsection for depth 2 (section level)', () => {
      expect(getChildLevel(2)).toBe('subsection');
    });

    it('returns complex for depth 3 (subsection level)', () => {
      expect(getChildLevel(3)).toBe('complex');
    });

    it('returns undefined for depth 4 (complex level - no children)', () => {
      expect(getChildLevel(4)).toBeUndefined();
    });
  });

  describe('isGenusLevel derived state', () => {
    // Test the logic for determining if at genus level
    const isGenusLevel = (taxonPath) => taxonPath.length === 0;

    it('returns true for empty path', () => {
      expect(isGenusLevel([])).toBe(true);
    });

    it('returns false for non-empty path', () => {
      expect(isGenusLevel(['Quercus'])).toBe(false);
    });

    it('returns false for deep path', () => {
      expect(isGenusLevel(['Quercus', 'Quercus', 'Albae'])).toBe(false);
    });
  });

  describe('taxonName extraction', () => {
    // Get the current taxon name from path
    const getTaxonName = (taxonPath) => taxonPath[taxonPath.length - 1] || '';

    it('returns empty string for empty path', () => {
      expect(getTaxonName([])).toBe('');
    });

    it('returns last element for single-element path', () => {
      expect(getTaxonName(['Quercus'])).toBe('Quercus');
    });

    it('returns last element for multi-element path', () => {
      expect(getTaxonName(['Quercus', 'Quercus', 'Albae'])).toBe('Albae');
    });
  });

  describe('subTaxa transformation', () => {
    // Transform API taxa response to display format
    const transformSubTaxa = (apiTaxa) => {
      return apiTaxa.map(t => ({ name: t.name, count: t.species_count }));
    };

    it('transforms API taxa to display format', () => {
      const apiTaxa = [
        { name: 'Quercus', level: 'section', species_count: 150 },
        { name: 'Cerris', level: 'section', species_count: 45 }
      ];
      const result = transformSubTaxa(apiTaxa);
      expect(result).toEqual([
        { name: 'Quercus', count: 150 },
        { name: 'Cerris', count: 45 }
      ]);
    });

    it('handles empty array', () => {
      expect(transformSubTaxa([])).toEqual([]);
    });

    it('handles taxa with zero species', () => {
      const apiTaxa = [{ name: 'Empty', level: 'section', species_count: 0 }];
      const result = transformSubTaxa(apiTaxa);
      expect(result).toEqual([{ name: 'Empty', count: 0 }]);
    });
  });
});
