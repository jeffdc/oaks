import { describe, it, expect, beforeEach } from 'vitest';
import { get } from 'svelte/store';
import {
  allSpecies,
  searchQuery,
  filteredSpecies,
  speciesCounts,
  totalCounts,
  formatSpeciesName
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
