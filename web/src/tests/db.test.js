import { describe, it, expect } from 'vitest';
import {
  getPrimarySource,
  getAllSources,
  getSourceById,
  getSourceCompleteness
} from '../lib/db.js';

// Test data
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
