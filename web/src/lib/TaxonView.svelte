<script>
  import { allSpecies, formatSpeciesName } from './dataStore.js';

  export let taxonPath = []; // e.g., ['Quercus', 'Quercus', 'Albae']
  export let onSelectSpecies;
  export let onNavigateToTaxon;
  export let onGoHome = null;

  // Determine the taxon level and name from the path
  $: taxonLevel = getTaxonLevel(taxonPath.length);
  $: taxonName = taxonPath[taxonPath.length - 1] || '';

  // Filter species that belong to this taxon
  $: matchingSpecies = getSpeciesInTaxon($allSpecies, taxonPath);

  // Get sub-taxa (children of this taxon)
  $: subTaxa = getSubTaxa($allSpecies, taxonPath);

  function getTaxonLevel(depth) {
    const levels = ['subgenus', 'section', 'subsection', 'complex'];
    return levels[depth - 1] || 'taxon';
  }

  function getTaxonLevelLabel(depth) {
    const labels = ['Subgenus', 'Section', 'Subsection', 'Complex'];
    return labels[depth - 1] || 'Taxon';
  }

  function getSpeciesInTaxon(species, path) {
    if (!path || path.length === 0) return [];

    return species.filter(s => {
      if (!s.taxonomy) return false;

      const t = s.taxonomy;
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
      return a.name.localeCompare(b.name);
    });
  }

  function getSubTaxa(species, path) {
    const depth = path.length;
    const childLevel = getTaxonLevel(depth + 1);

    if (depth >= 4) return []; // Complex is the deepest level with children

    const childTaxa = new Map();

    species.forEach(s => {
      if (!s.taxonomy) return;

      const t = s.taxonomy;
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

  function handleSubTaxonClick(subTaxonName) {
    onNavigateToTaxon([...taxonPath, subTaxonName]);
  }

  function handleBreadcrumbClick(index) {
    if (index === -1) {
      // Click on "Taxonomy" - go to taxonomy tree view
      onNavigateToTaxon([]);
    } else {
      // Navigate to ancestor taxon
      onNavigateToTaxon(taxonPath.slice(0, index + 1));
    }
  }
</script>

<div class="taxon-view">
  <!-- Breadcrumb navigation -->
  <nav class="breadcrumb">
    <button class="breadcrumb-link" on:click={onGoHome}>
      Browse
    </button>
    <span class="breadcrumb-separator">›</span>
    <button class="breadcrumb-link" on:click={() => handleBreadcrumbClick(-1)}>
      Taxonomy
    </button>
    {#each taxonPath as segment, i}
      <span class="breadcrumb-separator">›</span>
      {#if i < taxonPath.length - 1}
        <button class="breadcrumb-link" on:click={() => handleBreadcrumbClick(i)}>
          {segment}
        </button>
      {:else}
        <span class="breadcrumb-current">{segment}</span>
      {/if}
    {/each}
  </nav>

  <!-- Taxon header -->
  <header class="taxon-header">
    <span class="taxon-level">{getTaxonLevelLabel(taxonPath.length)}</span>
    <h1 class="taxon-name">
      {#if taxonLevel === 'complex'}Q. {/if}{taxonName}
    </h1>
    <p class="taxon-count">{matchingSpecies.length} species</p>
  </header>

  <!-- Sub-taxa (if any) -->
  {#if subTaxa.length > 0}
    <section class="sub-taxa-section">
      <h2 class="section-title">
        {getTaxonLevelLabel(taxonPath.length + 1)}s in this {getTaxonLevelLabel(taxonPath.length).toLowerCase()}
      </h2>
      <div class="sub-taxa-grid">
        {#each subTaxa as subTaxon}
          <button class="sub-taxon-card" on:click={() => handleSubTaxonClick(subTaxon.name)}>
            <span class="sub-taxon-name">
              {#if taxonPath.length === 3}Q. {/if}{subTaxon.name}
            </span>
            <span class="sub-taxon-count">{subTaxon.count} species</span>
          </button>
        {/each}
      </div>
    </section>
  {/if}

  <!-- Species list -->
  <section class="species-section">
    <h2 class="section-title">Species</h2>
    <div class="species-grid">
      {#each matchingSpecies as species}
        <button class="species-card" on:click={() => onSelectSpecies(species)}>
          <span class="species-name">
            {formatSpeciesName(species)}
          </span>
          {#if species.author}
            <span class="species-author">{species.author}</span>
          {/if}
        </button>
      {/each}
    </div>
  </section>
</div>

<style>
  .taxon-view {
    padding: 1rem;
  }

  /* Breadcrumb */
  .breadcrumb {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 0.5rem;
    padding: 1rem 1.5rem;
    margin-bottom: 1.5rem;
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.75rem;
    font-size: 0.875rem;
  }

  .breadcrumb-link {
    color: var(--color-forest-700);
    background: none;
    border: none;
    padding: 0;
    cursor: pointer;
    font-family: inherit;
    font-size: inherit;
    text-decoration: none;
    transition: color 0.15s ease;
  }

  .breadcrumb-link:hover {
    color: var(--color-forest-500);
    text-decoration: underline;
  }

  .breadcrumb-separator {
    color: var(--color-text-tertiary);
  }

  .breadcrumb-current {
    color: var(--color-text-primary);
    font-weight: 500;
  }

  /* Taxon header */
  .taxon-header {
    padding: 2rem;
    margin-bottom: 1.5rem;
    background: linear-gradient(135deg, var(--color-forest-50) 0%, var(--color-forest-100) 100%);
    border: 1px solid var(--color-forest-200);
    border-radius: 0.75rem;
    text-align: center;
  }

  .taxon-level {
    display: inline-block;
    padding: 0.25rem 0.75rem;
    margin-bottom: 0.75rem;
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--color-forest-700);
    background-color: var(--color-forest-200);
    border-radius: 9999px;
  }

  .taxon-name {
    font-size: 2rem;
    font-weight: 700;
    color: var(--color-forest-900);
    font-family: var(--font-serif);
    margin: 0 0 0.5rem 0;
  }

  .taxon-count {
    font-size: 0.9375rem;
    color: var(--color-text-secondary);
    margin: 0;
  }

  /* Section titles */
  .section-title {
    font-size: 1rem;
    font-weight: 600;
    color: var(--color-forest-800);
    margin: 0 0 1rem 0;
    font-family: var(--font-serif);
  }

  /* Sub-taxa section */
  .sub-taxa-section {
    padding: 1.5rem;
    margin-bottom: 1.5rem;
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.75rem;
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
  }

  .sub-taxon-card:hover {
    background-color: var(--color-forest-100);
    border-color: var(--color-forest-300);
    transform: translateY(-1px);
    box-shadow: var(--shadow-sm);
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
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.75rem;
  }

  .species-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 0.75rem;
  }

  .species-card {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    padding: 1rem;
    background-color: var(--color-background);
    border: 1px solid var(--color-border);
    border-radius: 0.5rem;
    cursor: pointer;
    transition: all 0.15s ease;
    text-align: left;
    font-family: inherit;
  }

  .species-card:hover {
    background-color: var(--color-forest-50);
    border-color: var(--color-forest-300);
    transform: translateY(-1px);
    box-shadow: var(--shadow-sm);
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
    margin-top: 0.25rem;
    font-style: normal;
  }
</style>
