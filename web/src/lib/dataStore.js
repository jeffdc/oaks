import { writable, derived } from 'svelte/store';

// Store for all species data
export const allSpecies = writable([]);

// Store for loading state
export const isLoading = writable(true);

// Store for error state
export const error = writable(null);

// Store for search query
export const searchQuery = writable('');

// Store for selected species (for detail view)
export const selectedSpecies = writable(null);

// Derived store: filtered species based on search
export const filteredSpecies = derived(
  [allSpecies, searchQuery],
  ([$allSpecies, $searchQuery]) => {
    if (!$searchQuery) return $allSpecies;

    const query = $searchQuery.toLowerCase();
    return $allSpecies.filter(species => {
      // Search in species name
      if (species.name.toLowerCase().includes(query)) return true;

      // Search in author
      if (species.author && species.author.toLowerCase().includes(query)) return true;

      // Search in synonyms
      if (species.synonyms && species.synonyms.some(syn =>
        syn.name && syn.name.toLowerCase().includes(query)
      )) return true;

      // Search in local names
      if (species.local_names && species.local_names.some(name =>
        name.toLowerCase().includes(query)
      )) return true;

      // Search in range
      if (species.range && species.range.toLowerCase().includes(query)) return true;

      return false;
    });
  }
);

// Derived store: species counts
export const speciesCounts = derived(
  filteredSpecies,
  ($filteredSpecies) => {
    const speciesCount = $filteredSpecies.filter(s => !s.is_hybrid).length;
    const hybridCount = $filteredSpecies.filter(s => s.is_hybrid).length;
    const total = $filteredSpecies.length;
    return { speciesCount, hybridCount, total };
  }
);

// Load species data from JSON
export async function loadSpeciesData() {
  try {
    isLoading.set(true);
    error.set(null);

    const response = await fetch('/quercus_data.json');
    if (!response.ok) {
      throw new Error(`Failed to load data: ${response.statusText}`);
    }

    const data = await response.json();

    // Sort species alphabetically by name
    const sorted = data.species.sort((a, b) =>
      a.name.localeCompare(b.name)
    );

    allSpecies.set(sorted);
    isLoading.set(false);

    return sorted;
  } catch (err) {
    console.error('Error loading species data:', err);
    error.set(err.message);
    isLoading.set(false);
    throw err;
  }
}

// Helper to find species by name
export function findSpeciesByName(name) {
  let result = null;
  const unsubscribe = allSpecies.subscribe(species => {
    result = species.find(s => s.name === name);
  });
  unsubscribe();
  return result;
}
