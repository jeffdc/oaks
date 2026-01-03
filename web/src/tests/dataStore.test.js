import { describe, it, expect, beforeEach } from 'vitest';
import { get } from 'svelte/store';
import {
  searchQuery,
  isLoading,
  error,
  searchResults,
  searchLoading,
  searchError,
  cancelSearch,
  clearSearch,
  formatSpeciesName,
  getPrimarySource,
  getAllSources,
  getSourceById,
  getSourceCompleteness
} from '../lib/stores/dataStore.js';

// Test data for source helper functions
const speciesWithMultipleSources = {
  name: 'alba',
  sources: [
    {
      source_id: 1,
      source_name: 'iNaturalist',
      is_preferred: false,
      range: 'Eastern North America',
      leaves: null,
      local_names: []
    },
    {
      source_id: 2,
      source_name: 'Oaks of the World',
      is_preferred: true,
      range: 'Eastern North America; 0 to 1600 m',
      leaves: '8-20 cm long, obovate',
      flowers: 'Staminate catkins',
      fruits: '1.5-2.5 cm long',
      local_names: ['white oak', 'eastern white oak']
    },
    {
      source_id: 3,
      source_name: 'Personal Notes',
      is_preferred: false,
      range: null,
      leaves: 'Distinctive rounded lobes',
      local_names: []
    }
  ]
};

const speciesWithSparsePreferred = {
  name: 'rubra',
  sources: [
    {
      source_id: 1,
      is_preferred: true,
      range: null,
      leaves: null,
      local_names: []
    },
    {
      source_id: 2,
      is_preferred: false,
      range: 'Eastern United States',
      leaves: 'Bristle-tipped lobes',
      flowers: 'Catkins',
      fruits: 'Acorn 2 cm',
      local_names: ['red oak']
    }
  ]
};

const speciesWithNoPreferred = {
  name: 'macrocarpa',
  sources: [
    {
      source_id: 1,
      range: 'Central North America',
      leaves: null,
      local_names: []
    },
    {
      source_id: 2,
      range: 'Great Plains to Eastern US',
      leaves: 'Large, deeply lobed',
      fruits: 'Large acorns with fringed caps',
      local_names: ['bur oak']
    }
  ]
};

const speciesWithNoSources = {
  name: 'unknown',
  sources: []
};

describe('stores', () => {
  describe('searchQuery', () => {
    beforeEach(() => {
      searchQuery.set('');
    });

    it('starts with empty string', () => {
      expect(get(searchQuery)).toBe('');
    });

    it('can be updated', () => {
      searchQuery.set('alba');
      expect(get(searchQuery)).toBe('alba');
    });
  });

  describe('isLoading', () => {
    beforeEach(() => {
      isLoading.set(false);
    });

    it('starts with false', () => {
      expect(get(isLoading)).toBe(false);
    });

    it('can be set to true', () => {
      isLoading.set(true);
      expect(get(isLoading)).toBe(true);
    });
  });

  describe('error', () => {
    beforeEach(() => {
      error.set(null);
    });

    it('starts with null', () => {
      expect(get(error)).toBeNull();
    });

    it('can be set to an error message', () => {
      error.set('Something went wrong');
      expect(get(error)).toBe('Something went wrong');
    });
  });

  describe('searchResults', () => {
    beforeEach(() => {
      searchResults.set([]);
    });

    it('starts with empty array', () => {
      expect(get(searchResults)).toEqual([]);
    });

    it('can be set to an array of species', () => {
      const results = [{ scientific_name: 'alba' }, { scientific_name: 'rubra' }];
      searchResults.set(results);
      expect(get(searchResults)).toEqual(results);
    });
  });

  describe('searchLoading', () => {
    beforeEach(() => {
      searchLoading.set(false);
    });

    it('starts with false', () => {
      expect(get(searchLoading)).toBe(false);
    });

    it('can be set to true', () => {
      searchLoading.set(true);
      expect(get(searchLoading)).toBe(true);
    });
  });

  describe('searchError', () => {
    beforeEach(() => {
      searchError.set(null);
    });

    it('starts with null', () => {
      expect(get(searchError)).toBeNull();
    });

    it('can be set to an error message', () => {
      searchError.set('Search failed');
      expect(get(searchError)).toBe('Search failed');
    });
  });

  describe('cancelSearch', () => {
    it('sets searchLoading to false', () => {
      searchLoading.set(true);
      cancelSearch();
      expect(get(searchLoading)).toBe(false);
    });
  });

  describe('clearSearch', () => {
    it('clears all search state', () => {
      searchQuery.set('test');
      searchResults.set({
        species: [{ scientific_name: 'alba' }],
        taxa: [{ name: 'Quercus', level: 'section' }],
        sources: [{ id: 1, name: 'Source' }],
        counts: { species: 1, taxa: 1, sources: 1, total: 3 }
      });
      searchError.set('Some error');
      searchLoading.set(true);

      clearSearch();

      expect(get(searchQuery)).toBe('');
      expect(get(searchResults)).toEqual({
        species: [],
        taxa: [],
        sources: [],
        counts: { species: 0, taxa: 0, sources: 0, total: 0 }
      });
      expect(get(searchError)).toBeNull();
      expect(get(searchLoading)).toBe(false);
    });
  });
});

describe('formatSpeciesName', () => {
  it('formats full species name', () => {
    const species = { name: 'alba' };
    expect(formatSpeciesName(species)).toBe('Quercus alba');
  });

  it('formats abbreviated species name', () => {
    const species = { name: 'alba' };
    expect(formatSpeciesName(species, { abbreviated: true })).toBe('Q. alba');
  });

  it('handles hybrid names with cross symbol', () => {
    const species = { name: '× bebbiana', is_hybrid: true };
    expect(formatSpeciesName(species)).toBe('Quercus × bebbiana');
  });
});

describe('getPrimarySource', () => {
  it('returns preferred source when it has substantial content', () => {
    const primary = getPrimarySource(speciesWithMultipleSources);
    expect(primary.source_id).toBe(2);
    expect(primary.source_name).toBe('Oaks of the World');
  });

  it('falls back to most complete source when preferred is sparse', () => {
    const primary = getPrimarySource(speciesWithSparsePreferred);
    expect(primary.source_id).toBe(2);
    expect(primary.is_preferred).toBe(false);
  });

  it('selects most complete source when no preferred flag set', () => {
    const primary = getPrimarySource(speciesWithNoPreferred);
    expect(primary.source_id).toBe(2);
  });

  it('returns null for species with empty sources array', () => {
    expect(getPrimarySource(speciesWithNoSources)).toBeNull();
  });

  it('returns null for species with undefined sources', () => {
    expect(getPrimarySource({ name: 'test' })).toBeNull();
  });

  it('returns null for null/undefined species', () => {
    expect(getPrimarySource(null)).toBeNull();
    expect(getPrimarySource(undefined)).toBeNull();
  });
});

describe('getAllSources', () => {
  it('returns all sources for a species', () => {
    const sources = getAllSources(speciesWithMultipleSources);
    expect(sources).toHaveLength(3);
  });

  it('returns empty array for species with no sources', () => {
    expect(getAllSources(speciesWithNoSources)).toEqual([]);
  });

  it('returns empty array for null/undefined species', () => {
    expect(getAllSources(null)).toEqual([]);
    expect(getAllSources(undefined)).toEqual([]);
  });
});

describe('getSourceById', () => {
  it('finds source by ID', () => {
    const source = getSourceById(speciesWithMultipleSources, 2);
    expect(source.source_name).toBe('Oaks of the World');
  });

  it('returns null for non-existent source ID', () => {
    expect(getSourceById(speciesWithMultipleSources, 999)).toBeNull();
  });

  it('returns null for species with no sources', () => {
    expect(getSourceById(speciesWithNoSources, 1)).toBeNull();
  });

  it('returns null for null/undefined species', () => {
    expect(getSourceById(null, 1)).toBeNull();
    expect(getSourceById(undefined, 1)).toBeNull();
  });
});

describe('getSourceCompleteness', () => {
  it('counts populated string fields', () => {
    const source = {
      range: 'Eastern North America',
      leaves: 'Large lobed leaves',
      flowers: null,
      fruits: ''
    };
    expect(getSourceCompleteness(source)).toBe(2);
  });

  it('counts populated array fields', () => {
    const source = {
      local_names: ['white oak', 'eastern white oak'],
      range: 'Eastern North America'
    };
    expect(getSourceCompleteness(source)).toBe(2);
  });

  it('does not count empty arrays', () => {
    const source = {
      local_names: [],
      range: 'Eastern North America'
    };
    expect(getSourceCompleteness(source)).toBe(1);
  });

  it('returns 0 for empty source', () => {
    expect(getSourceCompleteness({})).toBe(0);
  });

  it('returns 0 for null/undefined', () => {
    expect(getSourceCompleteness(null)).toBe(0);
    expect(getSourceCompleteness(undefined)).toBe(0);
  });

  it('correctly counts a fully populated source', () => {
    const fullSource = {
      local_names: ['oak'],
      range: 'North America',
      growth_habit: 'Tree',
      leaves: 'Lobed',
      flowers: 'Catkins',
      fruits: 'Acorns',
      bark: 'Furrowed',
      twigs: 'Brown',
      buds: 'Clustered',
      hardiness_habitat: 'Zone 5',
      miscellaneous: 'Notes',
      url: 'https://example.com'
    };
    expect(getSourceCompleteness(fullSource)).toBe(12);
  });
});
