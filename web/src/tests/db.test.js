import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  getPrimarySource,
  getAllSources,
  getSourceById,
  getSourceCompleteness,
  db,
  populateFromJson,
  getAllSpecies,
  getSpeciesByName,
  getSpeciesCounts,
  getAllSourcesInfo,
  getSourceInfo,
  getSpeciesBySource,
  hasData,
  getMetadata
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

// IndexedDB function tests with mocking
describe('IndexedDB functions', () => {
  // Mock species data
  const mockSpeciesArray = [
    { name: 'alba', is_hybrid: false, author: 'L.', sources: [{ source_id: 1 }] },
    { name: 'rubra', is_hybrid: false, author: 'L.', sources: [{ source_id: 1 }, { source_id: 2 }] },
    { name: '× bebbiana', is_hybrid: true, author: 'Schneid.', sources: [{ source_id: 1 }] }
  ];

  beforeEach(() => {
    // Reset mocks before each test
    vi.clearAllMocks();
  });

  describe('getAllSpecies', () => {
    it('returns species sorted with non-hybrids first', async () => {
      // Mock the db.species.toArray method
      vi.spyOn(db.species, 'toArray').mockResolvedValue([...mockSpeciesArray]);

      const result = await getAllSpecies();

      // Non-hybrids should come before hybrids
      expect(result[0].is_hybrid).toBe(false);
      expect(result[1].is_hybrid).toBe(false);
      expect(result[2].is_hybrid).toBe(true);
    });

    it('sorts alphabetically within hybrid/non-hybrid groups', async () => {
      vi.spyOn(db.species, 'toArray').mockResolvedValue([...mockSpeciesArray]);

      const result = await getAllSpecies();

      // alba before rubra
      expect(result[0].name).toBe('alba');
      expect(result[1].name).toBe('rubra');
    });
  });

  describe('getSpeciesByName', () => {
    it('returns species by name', async () => {
      vi.spyOn(db.species, 'get').mockResolvedValue({ name: 'alba', is_hybrid: false });

      const result = await getSpeciesByName('alba');

      expect(result.name).toBe('alba');
      expect(db.species.get).toHaveBeenCalledWith('alba');
    });

    it('returns undefined for non-existent species', async () => {
      vi.spyOn(db.species, 'get').mockResolvedValue(undefined);

      const result = await getSpeciesByName('nonexistent');

      expect(result).toBeUndefined();
    });
  });

  describe('getSpeciesCounts', () => {
    it('returns correct species and hybrid counts', async () => {
      // Mock the where().equals().count() chain
      const mockWhere = vi.fn().mockReturnValue({
        equals: vi.fn().mockReturnValue({
          count: vi.fn()
            .mockResolvedValueOnce(2)  // speciesCount (is_hybrid = false)
            .mockResolvedValueOnce(1)  // hybridCount (is_hybrid = true)
        })
      });
      vi.spyOn(db.species, 'where').mockImplementation(mockWhere);

      const result = await getSpeciesCounts();

      expect(result.speciesCount).toBe(2);
      expect(result.hybridCount).toBe(1);
      expect(result.total).toBe(3);
    });
  });

  describe('hasData', () => {
    it('returns true when species table has records', async () => {
      vi.spyOn(db.species, 'count').mockResolvedValue(100);

      const result = await hasData();

      expect(result).toBe(true);
    });

    it('returns false when species table is empty', async () => {
      vi.spyOn(db.species, 'count').mockResolvedValue(0);

      const result = await hasData();

      expect(result).toBe(false);
    });
  });

  describe('getMetadata', () => {
    it('returns metadata as key-value object', async () => {
      vi.spyOn(db.metadata, 'toArray').mockResolvedValue([
        { key: 'dataVersion', value: '1.0' },
        { key: 'lastUpdated', value: '2024-01-01' }
      ]);

      const result = await getMetadata();

      expect(result.dataVersion).toBe('1.0');
      expect(result.lastUpdated).toBe('2024-01-01');
    });

    it('returns empty object when no metadata', async () => {
      vi.spyOn(db.metadata, 'toArray').mockResolvedValue([]);

      const result = await getMetadata();

      expect(Object.keys(result)).toHaveLength(0);
    });
  });

  describe('getSpeciesBySource', () => {
    it('returns species that have data from specified source', async () => {
      vi.spyOn(db.species, 'toArray').mockResolvedValue([...mockSpeciesArray]);

      const result = await getSpeciesBySource(2);

      // Only rubra has source_id 2
      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('rubra');
    });

    it('returns empty array when no species have specified source', async () => {
      vi.spyOn(db.species, 'toArray').mockResolvedValue([...mockSpeciesArray]);

      const result = await getSpeciesBySource(99);

      expect(result).toHaveLength(0);
    });

    it('sorts results with non-hybrids first', async () => {
      const speciesWithSource = [
        { name: 'hybrid1', is_hybrid: true, sources: [{ source_id: 1 }] },
        { name: 'alba', is_hybrid: false, sources: [{ source_id: 1 }] }
      ];
      vi.spyOn(db.species, 'toArray').mockResolvedValue(speciesWithSource);

      const result = await getSpeciesBySource(1);

      expect(result[0].is_hybrid).toBe(false);
      expect(result[1].is_hybrid).toBe(true);
    });
  });

  describe('getAllSourcesInfo', () => {
    it('returns sources with coverage stats', async () => {
      const speciesWithSources = [
        { name: 'alba', sources: [{ source_id: 1, source_name: 'Source 1' }] },
        { name: 'rubra', sources: [{ source_id: 1, source_name: 'Source 1' }, { source_id: 2, source_name: 'Source 2' }] }
      ];
      vi.spyOn(db.species, 'toArray').mockResolvedValue(speciesWithSources);
      vi.spyOn(db.sources, 'toArray').mockResolvedValue([]);

      const result = await getAllSourcesInfo();

      // Source 1 should cover 2 species, Source 2 should cover 1
      const source1 = result.find(s => s.source_id === 1);
      const source2 = result.find(s => s.source_id === 2);

      expect(source1.species_count).toBe(2);
      expect(source2.species_count).toBe(1);
    });

    it('sorts sources by species count descending', async () => {
      const speciesWithSources = [
        { name: 'alba', sources: [{ source_id: 1 }] },
        { name: 'rubra', sources: [{ source_id: 2 }] },
        { name: 'robur', sources: [{ source_id: 2 }] }
      ];
      vi.spyOn(db.species, 'toArray').mockResolvedValue(speciesWithSources);
      vi.spyOn(db.sources, 'toArray').mockResolvedValue([]);

      const result = await getAllSourcesInfo();

      // Source 2 has more species, should come first
      expect(result[0].source_id).toBe(2);
      expect(result[1].source_id).toBe(1);
    });

    it('uses stored source metadata when available', async () => {
      const speciesWithSources = [
        { name: 'alba', sources: [{ source_id: 1, source_name: 'Fallback Name' }] }
      ];
      const storedSources = [
        { id: 1, name: 'Stored Name', author: 'Author', year: 2024 }
      ];
      vi.spyOn(db.species, 'toArray').mockResolvedValue(speciesWithSources);
      vi.spyOn(db.sources, 'toArray').mockResolvedValue(storedSources);

      const result = await getAllSourcesInfo();

      expect(result[0].source_name).toBe('Stored Name');
      expect(result[0].author).toBe('Author');
      expect(result[0].year).toBe(2024);
    });
  });

  describe('getSourceInfo', () => {
    it('returns info for a specific source by ID', async () => {
      const speciesWithSources = [
        { name: 'alba', sources: [{ source_id: 1, source_name: 'Source 1' }] }
      ];
      vi.spyOn(db.species, 'toArray').mockResolvedValue(speciesWithSources);
      vi.spyOn(db.sources, 'toArray').mockResolvedValue([]);

      const result = await getSourceInfo(1);

      expect(result).not.toBeNull();
      expect(result.source_id).toBe(1);
    });

    it('returns null for non-existent source', async () => {
      vi.spyOn(db.species, 'toArray').mockResolvedValue([]);
      vi.spyOn(db.sources, 'toArray').mockResolvedValue([]);

      const result = await getSourceInfo(999);

      expect(result).toBeNull();
    });
  });

  describe('populateFromJson', () => {
    it('skips update when version matches current', async () => {
      vi.spyOn(db.metadata, 'get').mockResolvedValue({ value: '1.0' });

      const result = await populateFromJson({
        metadata: { version: '1.0' },
        species: []
      });

      expect(result).toBe(0);
    });

    it('populates database when no current version exists', async () => {
      vi.spyOn(db.metadata, 'get').mockResolvedValue(undefined);

      // Mock all db methods that transaction will call
      vi.spyOn(db.species, 'clear').mockResolvedValue(undefined);
      vi.spyOn(db.species, 'bulkAdd').mockResolvedValue(undefined);
      vi.spyOn(db.metadata, 'put').mockResolvedValue(undefined);
      vi.spyOn(db.sources, 'clear').mockResolvedValue(undefined);
      vi.spyOn(db.sources, 'bulkAdd').mockResolvedValue(undefined);

      // Mock transaction to execute the callback
      vi.spyOn(db, 'transaction').mockImplementation(async (...args) => {
        const callback = args[args.length - 1];
        if (typeof callback === 'function') {
          await callback();
        }
        return undefined;
      });

      const mockSpecies = [{ name: 'alba' }, { name: 'rubra' }];
      const result = await populateFromJson({
        metadata: { version: '1.0' },
        species: mockSpecies
      });

      expect(result).toBe(2);
    });
  });
});
