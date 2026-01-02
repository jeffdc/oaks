<script>
  import { onMount } from 'svelte';
  import { base } from '$app/paths';
  import { formatSpeciesName } from '$lib/stores/dataStore.js';
  import { fetchSpecies, ApiError } from '$lib/apiClient.js';

  let { taxonPath = [] } = $props(); // e.g., ['Quercus', 'Quercus', 'Albae']

  // Local state for species list
  let allSpecies = $state([]);
  let isLoading = $state(true);
  let error = $state(null);

  // Fetch species on mount
  onMount(async () => {
    try {
      isLoading = true;
      error = null;
      const species = await fetchSpecies();
      allSpecies = species;
    } catch (err) {
      console.error('Failed to fetch species:', err);
      error = err instanceof ApiError ? err.message : 'Failed to load species data';
    } finally {
      isLoading = false;
    }
  });

  // Retry function for error state
  async function retry() {
    try {
      isLoading = true;
      error = null;
      const species = await fetchSpecies();
      allSpecies = species;
    } catch (err) {
      console.error('Failed to fetch species:', err);
      error = err instanceof ApiError ? err.message : 'Failed to load species data';
    } finally {
      isLoading = false;
    }
  }

  // Determine the taxon level and name from the path
  let isGenusLevel = $derived(taxonPath.length === 0);
  let taxonLevel = $derived(getTaxonLevel(taxonPath.length));
  let taxonName = $derived(taxonPath[taxonPath.length - 1] || '');

  // Filter species that belong to this taxon
  let matchingSpecies = $derived(getSpeciesInTaxon(allSpecies, taxonPath));

  // Get sub-taxa (children of this taxon)
  let subTaxa = $derived(getSubTaxa(allSpecies, taxonPath));

  function getTaxonLevel(depth) {
    const levels = ['genus', 'subgenus', 'section', 'subsection', 'complex'];
    return levels[depth] || 'taxon';
  }

  function getTaxonLevelLabel(depth) {
    const labels = ['Genus', 'Subgenus', 'Section', 'Subsection', 'Complex'];
    return labels[depth] || 'Taxon';
  }

  function getTaxonLevelLabelPlural(depth) {
    const labels = ['Genera', 'Subgenera', 'Sections', 'Subsections', 'Complexes'];
    return labels[depth] || 'Taxa';
  }

  // Get lowercase level label for breadcrumb items (path index → level)
  function getBreadcrumbLevelLabel(pathIndex) {
    const labels = ['subgenus', 'section', 'subsection', 'complex'];
    return labels[pathIndex] || '';
  }

  // Helper to get taxonomy fields (supports both flat API format and nested legacy format)
  function getTaxonomy(s) {
    return {
      subgenus: s.subgenus || s.taxonomy?.subgenus,
      section: s.section || s.taxonomy?.section,
      subsection: s.subsection || s.taxonomy?.subsection,
      complex: s.complex || s.taxonomy?.complex
    };
  }

  // Helper to get species name (supports both API format and legacy format)
  function getSpeciesName(s) {
    return s.scientific_name || s.name;
  }

  function getSpeciesInTaxon(species, path) {
    // At genus level, show only species without a subgenus assignment
    if (!path || path.length === 0) {
      return species.filter(s => {
        const t = getTaxonomy(s);
        return !t.subgenus || t.subgenus === 'null';
      }).sort((a, b) => {
          if (a.is_hybrid !== b.is_hybrid) return a.is_hybrid ? 1 : -1;
          return getSpeciesName(a).localeCompare(getSpeciesName(b));
        });
    }

    return species.filter(s => {
      const t = getTaxonomy(s);
      if (!t.subgenus && !t.section && !t.subsection && !t.complex) return false;

      const [subgenus, section, subsection, complex] = path;

      // Match based on path depth
      if (subgenus && t.subgenus !== subgenus) return false;
      if (section && t.section !== section) return false;
      if (subsection && t.subsection !== subsection) return false;
      if (complex && t.complex !== complex) return false;

      return true;
    }).sort((a, b) => {
      // Non-hybrids first, then alphabetically
      if (a.is_hybrid !== b.is_hybrid) return a.is_hybrid ? 1 : -1;
      return getSpeciesName(a).localeCompare(getSpeciesName(b));
    });
  }

  function getSubTaxa(species, path) {
    const depth = path.length;
    const childLevel = getTaxonLevel(depth + 1);

    if (depth >= 4) return []; // Complex is the deepest level with children

    const childTaxa = new Map();

    species.forEach(s => {
      const t = getTaxonomy(s);
      if (!t.subgenus && !t.section && !t.subsection && !t.complex) return;

      const [subgenus, section, subsection, complex] = path;

      // Check if species matches current path
      if (subgenus && t.subgenus !== subgenus) return;
      if (section && t.section !== section) return;
      if (subsection && t.subsection !== subsection) return;
      if (complex && t.complex !== complex) return;

      // Get the child taxon value
      let childValue;
      if (depth === 0) childValue = t.subgenus;
      else if (depth === 1) childValue = t.section;
      else if (depth === 2) childValue = t.subsection;
      else if (depth === 3) childValue = t.complex;

      if (childValue && childValue !== 'null') {
        const count = childTaxa.get(childValue) || 0;
        childTaxa.set(childValue, count + 1);
      }
    });

    return Array.from(childTaxa.entries())
      .map(([name, count]) => ({ name, count }))
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  // Build taxonomy path URL
  function getTaxonUrl(path) {
    if (path.length === 0) return `${base}/taxonomy/`;
    return `${base}/taxonomy/${path.map(encodeURIComponent).join('/')}/`;
  }
</script>

<div class="taxon-view">
  <!-- Loading state -->
  {#if isLoading}
    <div class="loading-container">
      <div class="loading-spinner"></div>
      <p class="loading-text">Loading taxonomy...</p>
    </div>
  <!-- Error state -->
  {:else if error}
    <div class="error-container">
      <svg class="error-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
      </svg>
      <p class="error-title">Unable to load taxonomy</p>
      <p class="error-message">{error}</p>
      <button onclick={retry} class="retry-button">
        <svg class="retry-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
        </svg>
        Try again
      </button>
    </div>
  {:else}
  <!-- Combined header with taxon name and taxonomy path -->
  <header class="taxon-header">
    <!-- Current taxon (name first) -->
    <div class="taxon-current">
      <div class="taxon-current-left">
        <span class="badge badge-uppercase badge-forest">{getTaxonLevelLabel(taxonPath.length)}</span>
        <h1 class="taxon-name">
          {#if isGenusLevel}
            <em>Quercus</em>
          {:else if taxonLevel === 'complex'}
            Q. {taxonName}
          {:else}
            {taxonName}
          {/if}
        </h1>
      </div>
      <p class="taxon-count">
        {#if isGenusLevel}
          {allSpecies.length} species
        {:else}
          {matchingSpecies.length} species
        {/if}
      </p>
    </div>

    <!-- Taxonomy path (below name, serves as both navigation and taxonomy display) -->
    {#if !isGenusLevel}
      <nav class="taxonomy-nav" aria-label="Taxonomy breadcrumb">
        <span class="taxonomy-label" aria-hidden="true">Taxonomy:</span>
        <a href="{base}/taxonomy/" class="taxonomy-link">
          <span class="taxonomy-name">Quercus</span>
          <span class="taxonomy-level-label">(genus)</span>
        </a>
        {#each taxonPath.slice(0, -1) as segment, i}
          <span class="taxonomy-separator">›</span>
          <a href="{getTaxonUrl(taxonPath.slice(0, i + 1))}" class="taxonomy-link">
            <span class="taxonomy-name">{segment}</span>
            <span class="taxonomy-level-label">({getBreadcrumbLevelLabel(i)})</span>
          </a>
        {/each}
      </nav>
    {/if}
  </header>

  <!-- Sub-taxa (if any) -->
  {#if subTaxa.length > 0}
    <section class="card sub-taxa-section">
      <h2 class="section-title section-title-sm">{getTaxonLevelLabelPlural(taxonPath.length + 1)}</h2>
      <div class="sub-taxa-grid">
        {#each subTaxa as subTaxon}
          <a href="{getTaxonUrl([...taxonPath, subTaxon.name])}" class="sub-taxon-card">
            <span class="sub-taxon-name">
              {#if taxonPath.length === 3}Q. {/if}{subTaxon.name}
            </span>
            <span class="sub-taxon-count">{subTaxon.count} species</span>
          </a>
        {/each}
      </div>
    </section>
  {/if}

  <!-- Species list -->
  {#if matchingSpecies.length > 0}
    <section class="card species-section">
      <h2 class="section-title section-title-sm">
        {#if isGenusLevel}
          Species without subgenus assignment ({matchingSpecies.length})
        {:else}
          Species
        {/if}
      </h2>
      <div class="species-grid">
        {#each matchingSpecies as species}
          <a href="{base}/species/{encodeURIComponent(getSpeciesName(species))}/" class="species-card">
            <span class="species-name-line">
              <span class="species-name">{formatSpeciesName(species)}</span>
              {#if species.author}<span class="species-author">{species.author}</span>{/if}
            </span>
          </a>
        {/each}
      </div>
    </section>
  {/if}
  {/if}
</div>

<style>
  .taxon-view {
    padding: 1rem;
  }

  /* Combined navigation header */
  .taxon-header {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    padding: 1rem 1.5rem;
    margin-bottom: 1.5rem;
    background: linear-gradient(135deg, var(--color-forest-50) 0%, var(--color-forest-100) 100%);
    border: 1px solid var(--color-forest-200);
    border-radius: 0.75rem;
  }

  /* Current taxon row */
  .taxon-current {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
  }

  .taxon-current-left {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    flex-wrap: wrap;
  }

  .taxon-name {
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--color-forest-900);
    font-family: var(--font-serif);
    margin: 0;
  }

  .taxon-count {
    font-size: 0.9375rem;
    color: var(--color-text-secondary);
    margin: 0;
    flex-shrink: 0;
  }

  /* Sub-taxa section */
  .sub-taxa-section {
    padding: 1.5rem;
    margin-bottom: 1.5rem;
  }

  .sub-taxa-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 0.75rem;
  }

  .sub-taxon-card {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    padding: 1rem;
    background-color: var(--color-forest-50);
    border: 1px solid var(--color-forest-200);
    border-radius: 0.5rem;
    cursor: pointer;
    transition: all 0.15s ease;
    text-align: left;
    font-family: inherit;
    text-decoration: none;
  }

  .sub-taxon-card:hover {
    background-color: var(--color-forest-100);
    border-color: var(--color-forest-300);
    transform: translateY(-1px);
    box-shadow: var(--shadow-sm);
  }

  .sub-taxon-card:focus-visible {
    outline: none;
    border-color: var(--color-forest-600);
    box-shadow: 0 0 0 3px rgba(30, 126, 75, 0.2);
  }

  .sub-taxon-name {
    font-weight: 600;
    color: var(--color-forest-800);
    font-size: 0.9375rem;
  }

  .sub-taxon-count {
    font-size: 0.8125rem;
    color: var(--color-text-tertiary);
    margin-top: 0.25rem;
  }

  /* Species section */
  .species-section {
    padding: 1.5rem;
  }

  .species-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 0.75rem;
  }

  .species-card {
    display: block;
    padding: 1rem;
    background-color: var(--color-background);
    border: 1px solid var(--color-border);
    border-radius: 0.5rem;
    cursor: pointer;
    transition: all 0.15s ease;
    text-align: left;
    font-family: inherit;
    text-decoration: none;
  }

  .species-card:hover {
    background-color: var(--color-forest-50);
    border-color: var(--color-forest-300);
    transform: translateY(-1px);
    box-shadow: var(--shadow-sm);
  }

  .species-card:focus-visible {
    outline: none;
    border-color: var(--color-forest-600);
    box-shadow: 0 0 0 3px rgba(30, 126, 75, 0.2);
  }

  .species-name-line {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: 0.375rem;
    line-height: 1.4;
  }

  .species-name {
    font-style: italic;
    font-weight: 500;
    color: var(--color-forest-700);
    font-size: 0.9375rem;
  }

  .species-author {
    font-size: 0.8125rem;
    color: var(--color-text-tertiary);
    font-style: normal;
    font-weight: 400;
  }

  /* Loading state */
  .loading-container {
    padding: 5rem 1.5rem;
    text-align: center;
    background-color: var(--color-surface);
    border-radius: 1rem;
    box-shadow: var(--shadow-sm);
  }

  .loading-text {
    font-size: 1.125rem;
    font-weight: 500;
    color: var(--color-text-secondary);
    margin-top: 1rem;
  }

  /* Error state */
  .error-container {
    padding: 5rem 1.5rem;
    text-align: center;
    background-color: var(--color-surface);
    border-radius: 1rem;
    box-shadow: var(--shadow-sm);
  }

  .error-icon {
    width: 4rem;
    height: 4rem;
    color: var(--color-error, #dc2626);
    margin: 0 auto 1rem;
  }

  .error-title {
    font-size: 1.125rem;
    font-weight: 500;
    color: var(--color-text-primary);
    margin-bottom: 0.25rem;
  }

  .error-message {
    font-size: 0.875rem;
    color: var(--color-text-secondary);
    margin-bottom: 1rem;
  }

  .retry-button {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.625rem 1.25rem;
    background-color: var(--color-forest-600);
    color: white;
    font-size: 0.9375rem;
    font-weight: 500;
    border: none;
    border-radius: 0.5rem;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .retry-button:hover {
    background-color: var(--color-forest-700);
    transform: translateY(-1px);
  }

  .retry-icon {
    width: 1rem;
    height: 1rem;
  }
</style>
