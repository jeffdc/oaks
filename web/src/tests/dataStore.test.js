import { describe, it, expect, beforeEach } from 'vitest';
import { get } from 'svelte/store';
import {
  allSpecies,
  searchQuery,
  filteredSpecies,
  speciesCounts,
  totalCounts,
  formatSpeciesName,
  findSpeciesByName
} from '../lib/stores/dataStore.js';

// Sample test data
const mockSpecies = [
  {
    name: 'alba',
    author: 'L.',
    is_hybrid: false,
    synonyms: [{ name: 'alba var. repanda' }],
    sources: [
      {
        source_id: 1,
        local_names: ['white oak', 'eastern white oak'],
        range: 'Eastern North America'
      }
    ]
  },
  {
    name: 'rubra',
    author: 'L.',
    is_hybrid: false,
    synonyms: [],
    sources: [
      {
        source_id: 1,
        local_names: ['red oak', 'northern red oak'],
        range: 'Eastern United States'
      }
    ]
  },
  {
    name: '× bebbiana',
    author: 'C.K.Schneid.',
    is_hybrid: true,
    synonyms: [],
    sources: [
      {
        source_id: 1,
        local_names: [],
        range: 'Eastern North America'
      }
    ]
  }
];

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

describe('filteredSpecies store', () => {
  beforeEach(() => {
    allSpecies.set(mockSpecies);
    searchQuery.set('');
  });

  it('returns all species when search query is empty', () => {
    const result = get(filteredSpecies);
    expect(result).toHaveLength(3);
  });

  it('filters by species name', () => {
    searchQuery.set('alba');
    const result = get(filteredSpecies);
    expect(result).toHaveLength(1);
    expect(result[0].name).toBe('alba');
  });

  it('filters by author', () => {
    searchQuery.set('Schneid');
    const result = get(filteredSpecies);
    expect(result).toHaveLength(1);
    expect(result[0].name).toBe('× bebbiana');
  });

  it('filters by synonym', () => {
    searchQuery.set('repanda');
    const result = get(filteredSpecies);
    expect(result).toHaveLength(1);
    expect(result[0].name).toBe('alba');
  });

  it('filters by local name (common name)', () => {
    searchQuery.set('white oak');
    const result = get(filteredSpecies);
    expect(result).toHaveLength(1);
    expect(result[0].name).toBe('alba');
  });

  it('filters by range', () => {
    searchQuery.set('United States');
    const result = get(filteredSpecies);
    expect(result).toHaveLength(1);
    expect(result[0].name).toBe('rubra');
  });

  it('is case insensitive', () => {
    searchQuery.set('ALBA');
    const result = get(filteredSpecies);
    expect(result).toHaveLength(1);
    expect(result[0].name).toBe('alba');
  });

  it('returns empty array when no matches', () => {
    searchQuery.set('xyz123');
    const result = get(filteredSpecies);
    expect(result).toHaveLength(0);
  });
});

describe('speciesCounts store', () => {
  beforeEach(() => {
    allSpecies.set(mockSpecies);
    searchQuery.set('');
  });

  it('counts species and hybrids correctly', () => {
    const counts = get(speciesCounts);
    expect(counts.speciesCount).toBe(2);
    expect(counts.hybridCount).toBe(1);
    expect(counts.total).toBe(3);
  });

  it('updates counts when search filters results', () => {
    searchQuery.set('alba');
    const counts = get(speciesCounts);
    expect(counts.speciesCount).toBe(1);
    expect(counts.hybridCount).toBe(0);
    expect(counts.total).toBe(1);
  });
});

describe('totalCounts store', () => {
  beforeEach(() => {
    allSpecies.set(mockSpecies);
  });

  it('counts total species independent of search', () => {
    searchQuery.set('alba');
    const counts = get(totalCounts);
    expect(counts.speciesCount).toBe(2);
    expect(counts.hybridCount).toBe(1);
    expect(counts.total).toBe(3);
  });
});

// Mock sources data for filteredSources tests
const mockSources = [
  {
    source_id: 1,
    source_name: 'iNaturalist',
    author: 'Community',
    species_count: 500
  },
  {
    source_id: 2,
    source_name: 'Oaks of the World',
    author: 'Antoine Le Hardÿ de Beaulieu',
    species_count: 450
  },
  {
    source_id: 3,
    source_name: 'Personal Notes',
    author: null,
    species_count: 50
  }
];

describe('filteredSources store', () => {
  beforeEach(async () => {
    // Import allSources and set it up
    const { allSources } = await import('../lib/stores/dataStore.js');
    allSources.set(mockSources);
    searchQuery.set('');
  });

  it('returns empty array when search query is empty', async () => {
    const { filteredSources } = await import('../lib/stores/dataStore.js');
    const result = get(filteredSources);
    expect(result).toHaveLength(0);
  });

  it('filters by source name', async () => {
    const { filteredSources, allSources } = await import('../lib/stores/dataStore.js');
    allSources.set(mockSources);
    searchQuery.set('iNaturalist');
    const result = get(filteredSources);
    expect(result).toHaveLength(1);
    expect(result[0].source_name).toBe('iNaturalist');
  });

  it('filters by author name', async () => {
    const { filteredSources, allSources } = await import('../lib/stores/dataStore.js');
    allSources.set(mockSources);
    searchQuery.set('Beaulieu');
    const result = get(filteredSources);
    expect(result).toHaveLength(1);
    expect(result[0].source_name).toBe('Oaks of the World');
  });

  it('is case insensitive for source search', async () => {
    const { filteredSources, allSources } = await import('../lib/stores/dataStore.js');
    allSources.set(mockSources);
    searchQuery.set('OAKS');
    const result = get(filteredSources);
    expect(result).toHaveLength(1);
    expect(result[0].source_name).toBe('Oaks of the World');
  });

  it('returns empty array when no sources match', async () => {
    const { filteredSources, allSources } = await import('../lib/stores/dataStore.js');
    allSources.set(mockSources);
    searchQuery.set('nonexistent');
    const result = get(filteredSources);
    expect(result).toHaveLength(0);
  });
});

describe('searchResults store', () => {
  beforeEach(async () => {
    const { allSources } = await import('../lib/stores/dataStore.js');
    allSpecies.set(mockSpecies);
    allSources.set(mockSources);
    searchQuery.set('');
  });

  it('returns empty results when search query is empty', async () => {
    const { searchResults } = await import('../lib/stores/dataStore.js');
    const result = get(searchResults);
    expect(result.species).toHaveLength(0);
    expect(result.sources).toHaveLength(0);
    expect(result.hasResults).toBe(false);
  });

  it('returns species results when searching for species', async () => {
    const { searchResults, allSources } = await import('../lib/stores/dataStore.js');
    allSources.set(mockSources);
    searchQuery.set('alba');
    const result = get(searchResults);
    expect(result.species.length).toBeGreaterThan(0);
    expect(result.hasResults).toBe(true);
  });

  it('returns source results when searching for source name', async () => {
    const { searchResults, allSources } = await import('../lib/stores/dataStore.js');
    allSources.set(mockSources);
    searchQuery.set('iNaturalist');
    const result = get(searchResults);
    expect(result.sources.length).toBeGreaterThan(0);
    expect(result.hasResults).toBe(true);
  });

  it('returns both species and sources when both match', async () => {
    // Create data where both a species and source could match
    const { searchResults, allSources } = await import('../lib/stores/dataStore.js');
    allSources.set([{ source_id: 1, source_name: 'White Oak Database', author: null }]);
    searchQuery.set('white');
    const result = get(searchResults);
    // 'white oak' matches in local_names of alba species
    expect(result.hasResults).toBe(true);
  });
});

describe('findSpeciesByName', () => {
  beforeEach(() => {
    allSpecies.set(mockSpecies);
  });

  it('finds species by exact name', () => {
    const result = findSpeciesByName('alba');
    expect(result).not.toBeNull();
    expect(result.name).toBe('alba');
  });

  it('finds hybrid species by name', () => {
    const result = findSpeciesByName('× bebbiana');
    expect(result).not.toBeNull();
    expect(result.is_hybrid).toBe(true);
  });

  it('returns null/undefined for non-existent species', () => {
    const result = findSpeciesByName('nonexistent');
    expect(result).toBeFalsy();
  });
});
