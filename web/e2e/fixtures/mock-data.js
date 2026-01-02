/**
 * Mock API data for E2E tests.
 *
 * This provides realistic test data that mirrors the actual API responses.
 * All API calls in E2E tests are intercepted and return this mock data.
 */

// =============================================================================
// Stats
// =============================================================================

export const mockStats = {
  species_count: 450,
  hybrid_count: 85,
  taxa_count: 120,
  source_count: 3
};

// =============================================================================
// Sources
// =============================================================================

export const mockSources = [
  {
    id: 1,
    source_type: 'website',
    name: 'iNaturalist',
    description: 'Community science platform for biodiversity observation',
    author: null,
    year: 2024,
    url: 'https://www.inaturalist.org',
    isbn: null,
    doi: null,
    notes: 'Primary source for taxonomy',
    license: 'CC BY-NC 4.0',
    license_url: 'https://creativecommons.org/licenses/by-nc/4.0/'
  },
  {
    id: 2,
    source_type: 'website',
    name: 'Oaks of the World',
    description: 'Comprehensive oak species database',
    author: 'Eike Jablonski',
    year: 2024,
    url: 'https://oaksoftheworld.fr',
    isbn: null,
    doi: null,
    notes: 'Rich morphological descriptions',
    license: null,
    license_url: null
  },
  {
    id: 3,
    source_type: 'personal_observation',
    name: 'Oak Compendium',
    description: 'Personal field notes and observations',
    author: 'Jeff Yegge',
    year: 2024,
    url: null,
    isbn: null,
    doi: null,
    notes: 'Curated content and field observations',
    license: null,
    license_url: null
  }
];

// =============================================================================
// Taxa
// =============================================================================

export const mockTaxa = [
  // Subgenera
  { name: 'Quercus', level: 'subgenus', parent: null, author: 'L.', notes: 'White oaks', species_count: 200 },
  { name: 'Lobatae', level: 'subgenus', parent: null, author: 'Loudon', notes: 'Red oaks', species_count: 180 },
  { name: 'Cerris', level: 'subgenus', parent: null, author: '(Spach) Oerst.', notes: 'Cerris oaks', species_count: 70 },

  // Sections under Quercus
  { name: 'Quercus', level: 'section', parent: 'Quercus', author: null, notes: 'Type section', species_count: 80 },
  { name: 'Albae', level: 'section', parent: 'Quercus', author: 'Loudon', notes: 'White oak section', species_count: 50 },
  { name: 'Virentes', level: 'section', parent: 'Quercus', author: 'Loudon', notes: 'Live oaks', species_count: 15 },

  // Sections under Lobatae
  { name: 'Lobatae', level: 'section', parent: 'Lobatae', author: null, notes: 'Red oak section', species_count: 120 },

  // Subsections
  { name: 'Dumosae', level: 'subsection', parent: 'Quercus', author: null, notes: null, species_count: 10 },
];

// =============================================================================
// Species
// =============================================================================

export const mockSpeciesList = [
  {
    name: 'alba',
    author: 'L.',
    is_hybrid: false,
    conservation_status: 'LC',
    subgenus: 'Quercus',
    section: 'Quercus',
    subsection: null,
    complex: null
  },
  {
    name: 'rubra',
    author: 'L.',
    is_hybrid: false,
    conservation_status: 'LC',
    subgenus: 'Lobatae',
    section: 'Lobatae',
    subsection: null,
    complex: null
  },
  {
    name: 'macrocarpa',
    author: 'Michx.',
    is_hybrid: false,
    conservation_status: 'LC',
    subgenus: 'Quercus',
    section: 'Quercus',
    subsection: null,
    complex: null
  },
  {
    name: 'virginiana',
    author: 'Mill.',
    is_hybrid: false,
    conservation_status: 'LC',
    subgenus: 'Quercus',
    section: 'Virentes',
    subsection: null,
    complex: null
  },
  {
    name: 'palustris',
    author: 'Münchh.',
    is_hybrid: false,
    conservation_status: 'LC',
    subgenus: 'Lobatae',
    section: 'Lobatae',
    subsection: null,
    complex: null
  },
  {
    name: '× bebbiana',
    author: 'C.K.Schneid.',
    is_hybrid: true,
    conservation_status: null,
    subgenus: 'Quercus',
    section: 'Quercus',
    subsection: null,
    complex: null
  }
];

// =============================================================================
// Full Species (with sources)
// =============================================================================

export const mockSpeciesFull = {
  alba: {
    name: 'alba',
    author: 'L.',
    is_hybrid: false,
    conservation_status: 'LC',
    taxonomy: {
      genus: 'Quercus',
      subgenus: 'Quercus',
      section: 'Quercus',
      subsection: null,
      complex: null
    },
    parent1: null,
    parent2: null,
    hybrids: ['× bebbiana', '× jackiana'],
    closely_related_to: ['stellata', 'macrocarpa'],
    subspecies_varieties: [],
    synonyms: [{ name: 'alba var. repanda', author: 'Michx.' }],
    external_links: [
      { name: 'Wikipedia', url: 'https://en.wikipedia.org/wiki/Quercus_alba' }
    ],
    sources: [
      {
        source_id: 2,
        source_name: 'Oaks of the World',
        is_preferred: true,
        local_names: ['white oak', 'eastern white oak', 'stave oak'],
        range: 'Eastern North America, from Maine to Florida, west to Minnesota and Texas; 0-1600m elevation',
        growth_habit: 'Deciduous tree reaching 20-35m tall with a broad, rounded crown. Trunk can reach 1-2m in diameter.',
        leaves: 'Alternate, simple, 12-22cm long, with 5-9 rounded lobes. Bright green above, pale beneath, turning wine-red to purple in autumn.',
        flowers: 'Monoecious. Male catkins 5-8cm long, yellowish-green. Female flowers small, in clusters of 2-3.',
        fruits: 'Acorns 1.5-2.5cm long, oval, enclosed 1/4 by a warty cup. Matures in one year.',
        bark_twigs_buds: 'Bark light gray, scaly to shallowly fissured. Twigs reddish-brown, glabrous. Buds small, rounded, reddish-brown.',
        hardiness_habitat: 'Hardy to zone 3. Grows in varied habitats from dry uplands to moist bottomlands. Prefers deep, well-drained soils.',
        miscellaneous: 'One of the most important timber trees in North America. Wood prized for furniture, flooring, and barrels.',
        url: 'https://oaksoftheworld.fr/species/alba'
      },
      {
        source_id: 1,
        source_name: 'iNaturalist',
        is_preferred: false,
        local_names: ['white oak'],
        range: 'Eastern North America',
        growth_habit: null,
        leaves: null,
        flowers: null,
        fruits: null,
        bark_twigs_buds: null,
        hardiness_habitat: null,
        miscellaneous: null,
        url: 'https://www.inaturalist.org/taxa/54809-Quercus-alba'
      }
    ]
  },
  rubra: {
    name: 'rubra',
    author: 'L.',
    is_hybrid: false,
    conservation_status: 'LC',
    taxonomy: {
      genus: 'Quercus',
      subgenus: 'Lobatae',
      section: 'Lobatae',
      subsection: null,
      complex: null
    },
    parent1: null,
    parent2: null,
    hybrids: ['× runcinata'],
    closely_related_to: ['velutina', 'coccinea'],
    subspecies_varieties: [],
    synonyms: [{ name: 'rubra var. borealis', author: 'Michx.' }],
    external_links: [],
    sources: [
      {
        source_id: 2,
        source_name: 'Oaks of the World',
        is_preferred: true,
        local_names: ['northern red oak', 'red oak'],
        range: 'Eastern North America, from Nova Scotia to Minnesota, south to Georgia and Oklahoma',
        growth_habit: 'Large deciduous tree reaching 25-35m tall.',
        leaves: 'Alternate, simple, 12-22cm long, with 7-11 bristle-tipped lobes.',
        flowers: 'Monoecious. Male catkins yellowish-green.',
        fruits: 'Acorns 2-3cm long, oval, with flat saucer-like cup. Matures in two years.',
        bark_twigs_buds: 'Bark dark gray with wide, flat-topped ridges forming a striped pattern.',
        hardiness_habitat: 'Hardy to zone 3. Adaptable to many soil types.',
        miscellaneous: 'Important timber tree. Faster growing than white oaks.',
        url: 'https://oaksoftheworld.fr/species/rubra'
      }
    ]
  },
  '× bebbiana': {
    name: '× bebbiana',
    author: 'C.K.Schneid.',
    is_hybrid: true,
    conservation_status: null,
    taxonomy: {
      genus: 'Quercus',
      subgenus: 'Quercus',
      section: 'Quercus',
      subsection: null,
      complex: null
    },
    parent1: 'alba',
    parent2: 'macrocarpa',
    hybrids: [],
    closely_related_to: [],
    subspecies_varieties: [],
    synonyms: [],
    external_links: [],
    sources: [
      {
        source_id: 2,
        source_name: 'Oaks of the World',
        is_preferred: true,
        local_names: ["Bebb's oak"],
        range: 'Eastern North America, where parent species overlap',
        growth_habit: 'Medium-sized tree, intermediate between parents.',
        leaves: 'Intermediate between alba and macrocarpa.',
        flowers: null,
        fruits: 'Acorns intermediate in size.',
        bark_twigs_buds: null,
        hardiness_habitat: null,
        miscellaneous: 'Natural hybrid between Q. alba and Q. macrocarpa.',
        url: null
      }
    ]
  }
};

// =============================================================================
// Search Results
// =============================================================================

export const mockSearchResults = {
  // Search for "alba"
  alba: {
    species: [
      { name: 'alba', author: 'L.', is_hybrid: false, conservation_status: 'LC' }
    ],
    taxa: [],
    sources: [],
    counts: { species: 1, taxa: 0, sources: 0, total: 1 }
  },
  // Search for "white"
  white: {
    species: [
      { name: 'alba', author: 'L.', is_hybrid: false, conservation_status: 'LC' }
    ],
    taxa: [],
    sources: [],
    counts: { species: 1, taxa: 0, sources: 0, total: 1 }
  },
  // Search for "oak"
  oak: {
    species: mockSpeciesList,
    taxa: [],
    sources: [mockSources[0], mockSources[1]],
    counts: { species: 6, taxa: 0, sources: 2, total: 8 }
  },
  // Search for "bebbiana" (hybrid)
  bebbiana: {
    species: [
      { name: '× bebbiana', author: 'C.K.Schneid.', is_hybrid: true, conservation_status: null }
    ],
    taxa: [],
    sources: [],
    counts: { species: 1, taxa: 0, sources: 0, total: 1 }
  },
  // Empty search
  zzzznotfound: {
    species: [],
    taxa: [],
    sources: [],
    counts: { species: 0, taxa: 0, sources: 0, total: 0 }
  }
};

// =============================================================================
// Helper to get mock data by endpoint
// =============================================================================

/**
 * Get mock response for an API endpoint
 * @param {string} url - The full URL being requested
 * @returns {object|null} Mock response or null if not matched
 */
export function getMockResponse(url) {
  const urlObj = new URL(url);
  const path = urlObj.pathname;
  const searchParams = urlObj.searchParams;

  // Stats
  if (path === '/api/v1/stats') {
    return mockStats;
  }

  // Sources list
  if (path === '/api/v1/sources' && !path.includes('/sources/')) {
    return mockSources;
  }

  // Single source
  const sourceMatch = path.match(/^\/api\/v1\/sources\/(\d+)$/);
  if (sourceMatch) {
    const id = parseInt(sourceMatch[1]);
    return mockSources.find(s => s.id === id) || null;
  }

  // Taxa list
  if (path === '/api/v1/taxa') {
    const level = searchParams.get('level');
    const parent = searchParams.get('parent');

    let filtered = mockTaxa;
    if (level) {
      filtered = filtered.filter(t => t.level === level);
    }
    if (parent) {
      filtered = filtered.filter(t => t.parent === parent);
    }
    return { data: filtered };
  }

  // Single taxon
  const taxonMatch = path.match(/^\/api\/v1\/taxa\/([^/]+)\/([^/]+)$/);
  if (taxonMatch) {
    const [, level, name] = taxonMatch;
    return mockTaxa.find(t => t.level === level && t.name === decodeURIComponent(name)) || null;
  }

  // Search
  if (path === '/api/v1/search') {
    const query = searchParams.get('q')?.toLowerCase() || '';
    // Return predefined results if available, otherwise empty
    return mockSearchResults[query] || mockSearchResults.zzzznotfound;
  }

  // Species search
  if (path === '/api/v1/species/search') {
    const query = searchParams.get('q')?.toLowerCase() || '';
    const results = mockSearchResults[query];
    return { data: results?.species || [] };
  }

  // Species full (with sources)
  const speciesFullMatch = path.match(/^\/api\/v1\/species\/([^/]+)\/full$/);
  if (speciesFullMatch) {
    const name = decodeURIComponent(speciesFullMatch[1]);
    return mockSpeciesFull[name] || null;
  }

  // Species list
  if (path === '/api/v1/species') {
    let filtered = [...mockSpeciesList];

    // Filter by taxonomy
    const subgenus = searchParams.get('subgenus');
    const section = searchParams.get('section');
    if (subgenus) {
      filtered = filtered.filter(s => s.subgenus === subgenus);
    }
    if (section) {
      filtered = filtered.filter(s => s.section === section);
    }

    return { data: filtered };
  }

  // Single species (basic)
  const speciesMatch = path.match(/^\/api\/v1\/species\/([^/]+)$/);
  if (speciesMatch) {
    const name = decodeURIComponent(speciesMatch[1]);
    return mockSpeciesList.find(s => s.name === name) || null;
  }

  // Health check
  if (path === '/health') {
    return { status: 'ok' };
  }

  return null;
}
