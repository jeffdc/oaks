<script>
  import { base } from '$app/paths';
  import { formatSpeciesName, forceRefresh } from '$lib/stores/dataStore.js';
  import { canEdit, getCannotEditReason } from '$lib/stores/authStore.js';
  import { toast } from '$lib/stores/toastStore.js';
  import { fetchTaxaByLevel, fetchSpeciesByTaxon, fetchStats, fetchTaxon, updateTaxon, deleteTaxon, ApiError } from '$lib/apiClient.js';
  import TaxonEditForm from './TaxonEditForm.svelte';
  import DeleteConfirmDialog from './DeleteConfirmDialog.svelte';

  let { taxonPath = [] } = $props(); // e.g., ['Quercus', 'Quercus', 'Albae']

  // Local state
  let subTaxaFromApi = $state([]); // Sub-taxa with species_count from API
  let matchingSpeciesFromApi = $state([]); // Species at this taxon level
  let totalSpeciesCount = $state(0); // Total species count for genus level
  let isLoading = $state(true);
  let error = $state(null);

  // Fetch data reactively when taxonPath changes
  $effect(() => {
    // Create a snapshot of taxonPath to use in the async function
    const currentPath = [...taxonPath];
    loadData(currentPath);
  });

  async function loadData(path) {
    try {
      isLoading = true;
      error = null;

      const depth = path.length;

      // Determine what child level to fetch
      const childLevelMap = ['subgenus', 'section', 'subsection', 'complex'];
      const childLevel = childLevelMap[depth];

      // Fetch sub-taxa if we're not at the deepest level
      if (childLevel) {
        const taxa = await fetchTaxaByLevel(childLevel, path);
        subTaxaFromApi = taxa;
      } else {
        subTaxaFromApi = [];
      }

      // Fetch species at this taxon level
      matchingSpeciesFromApi = await fetchSpeciesByTaxon(path);

      // For genus level, get total count from stats
      if (depth === 0) {
        const stats = await fetchStats();
        totalSpeciesCount = stats.species_count + stats.hybrid_count;
      }
    } catch (err) {
      console.error('Failed to fetch taxonomy data:', err);
      error = err instanceof ApiError ? err.message : 'Failed to load taxonomy data';
    } finally {
      isLoading = false;
    }
  }

  // Retry function for error state
  async function retry() {
    await loadData([...taxonPath]);
  }

  // Edit/Delete modal state
  let showEditForm = false;
  let showDeleteDialog = false;
  let isDeleting = false;
  let editingTaxon = null;
  let deletingTaxon = null;
  let deleteCascadeInfo = null;

  // Determine the taxon level and name from the path
  let isGenusLevel = $derived(taxonPath.length === 0);
  let taxonLevel = $derived(getTaxonLevel(taxonPath.length));
  let taxonName = $derived(taxonPath[taxonPath.length - 1] || '');

  // Use API data directly
  let matchingSpecies = $derived(matchingSpeciesFromApi);
  let subTaxa = $derived(subTaxaFromApi.map(t => ({ name: t.name, count: t.species_count })));

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

  // Helper to get species name (supports both API format and legacy format)
  function getSpeciesName(s) {
    return s.scientific_name || s.name;
  }

  // Build taxonomy path URL
  function getTaxonUrl(path) {
    if (path.length === 0) return `${base}/taxonomy/`;
    return `${base}/taxonomy/${path.map(encodeURIComponent).join('/')}/`;
  }

  // Get the taxon level for a child at the current depth
  function getChildLevel(depth) {
    const levels = ['subgenus', 'section', 'subsection', 'complex'];
    return levels[depth] || 'taxon';
  }

  // Handle edit button click
  async function handleEditClick(subTaxon, event) {
    event.preventDefault();
    event.stopPropagation();

    const level = getChildLevel(taxonPath.length);
    try {
      // Fetch the full taxon data from API
      const taxonData = await fetchTaxon(level, subTaxon.name);
      editingTaxon = { ...taxonData, level };
      showEditForm = true;
    } catch (error) {
      if (error instanceof ApiError) {
        toast.error(`Failed to load taxon: ${error.message}`);
      } else {
        toast.error('Failed to load taxon data');
      }
    }
  }

  // Handle delete button click
  function handleDeleteClick(subTaxon, event) {
    event.preventDefault();
    event.stopPropagation();

    const level = getChildLevel(taxonPath.length);
    deletingTaxon = { name: subTaxon.name, level, count: subTaxon.count };
    // If there are species using this taxon, show error dialog
    if (subTaxon.count > 0) {
      deleteCascadeInfo = { count: subTaxon.count, type: 'species' };
    } else {
      deleteCascadeInfo = null;
    }
    showDeleteDialog = true;
  }

  // Handle save from edit form
  async function handleSaveTaxon(formData) {
    if (!editingTaxon) return null;

    try {
      await updateTaxon(editingTaxon.level, editingTaxon.name, formData);
      toast.success(`${getLevelLabel(editingTaxon.level)} updated successfully`);
      // Refresh data to show changes
      await forceRefresh();
      return null; // Success
    } catch (error) {
      if (error instanceof ApiError) {
        if (error.status === 400 && error.fieldErrors) {
          return error.fieldErrors;
        }
        toast.error(`Failed to update: ${error.message}`);
      } else {
        toast.error('Failed to update taxon');
      }
      throw error;
    }
  }

  // Handle delete confirmation
  async function handleDeleteConfirm() {
    if (!deletingTaxon) return;

    isDeleting = true;
    try {
      await deleteTaxon(deletingTaxon.level, deletingTaxon.name);
      toast.success(`${getLevelLabel(deletingTaxon.level)} deleted successfully`);
      showDeleteDialog = false;
      deletingTaxon = null;
      deleteCascadeInfo = null;
      // Refresh data to show changes
      await forceRefresh();
    } catch (error) {
      if (error instanceof ApiError) {
        toast.error(`Failed to delete: ${error.message}`);
      } else {
        toast.error('Failed to delete taxon');
      }
    } finally {
      isDeleting = false;
    }
  }

  // Handle delete cancel
  function handleDeleteCancel() {
    showDeleteDialog = false;
    deletingTaxon = null;
    deleteCascadeInfo = null;
  }

  // Get level label for messages
  function getLevelLabel(level) {
    const labels = {
      subgenus: 'Subgenus',
      section: 'Section',
      subsection: 'Subsection',
      complex: 'Complex'
    };
    return labels[level] || 'Taxon';
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
          {totalSpeciesCount} species
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
          <a href="{getTaxonUrl([...taxonPath, subTaxon.name])}" class="sub-taxon-card" class:can-edit={$canEdit}>
            <div class="sub-taxon-content">
              <span class="sub-taxon-name">
                {#if taxonPath.length === 3}Q. {/if}{subTaxon.name}
              </span>
              <span class="sub-taxon-count">{subTaxon.count} species</span>
            </div>
            {#if $canEdit}
              <div class="taxon-actions">
                <button
                  type="button"
                  class="taxon-action-btn taxon-action-edit"
                  title="Edit {getChildLevel(taxonPath.length)}"
                  on:click={(e) => handleEditClick(subTaxon, e)}
                >
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
                    <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
                  </svg>
                </button>
                <button
                  type="button"
                  class="taxon-action-btn taxon-action-delete"
                  title="Delete {getChildLevel(taxonPath.length)}"
                  on:click={(e) => handleDeleteClick(subTaxon, e)}
                >
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="3,6 5,6 21,6" />
                    <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
                    <line x1="10" y1="11" x2="10" y2="17" />
                    <line x1="14" y1="11" x2="14" y2="17" />
                  </svg>
                </button>
              </div>
            {/if}
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

<!-- Edit Taxon Modal -->
{#if showEditForm && editingTaxon}
  <TaxonEditForm
    taxon={editingTaxon}
    isOpen={showEditForm}
    onClose={() => { showEditForm = false; editingTaxon = null; }}
    onSave={handleSaveTaxon}
  />
{/if}

<!-- Delete Confirmation Dialog -->
{#if showDeleteDialog && deletingTaxon}
  <DeleteConfirmDialog
    entityType="taxon"
    entityName={deletingTaxon.name}
    cascadeInfo={deleteCascadeInfo}
    {isDeleting}
    onConfirm={handleDeleteConfirm}
    onCancel={handleDeleteCancel}
  />
{/if}

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
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
    padding: 1rem;
    background-color: var(--color-forest-50);
    border: 1px solid var(--color-forest-200);
    border-radius: 0.5rem;
    cursor: pointer;
    transition: all 0.15s ease;
    text-align: left;
    font-family: inherit;
    text-decoration: none;
    gap: 0.5rem;
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

  .sub-taxon-content {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    flex: 1;
    min-width: 0;
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

  /* Taxon action buttons */
  .taxon-actions {
    display: flex;
    gap: 0.25rem;
    flex-shrink: 0;
    opacity: 0;
    transition: opacity 0.15s ease;
  }

  /* Show on hover (desktop) */
  .sub-taxon-card.can-edit:hover .taxon-actions {
    opacity: 1;
  }

  .taxon-action-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 1.75rem;
    height: 1.75rem;
    padding: 0;
    border: none;
    border-radius: 0.375rem;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .taxon-action-btn svg {
    flex-shrink: 0;
  }

  .taxon-action-edit {
    color: var(--color-forest-700);
    background-color: var(--color-forest-100);
  }

  .taxon-action-edit:hover {
    background-color: var(--color-forest-200);
  }

  .taxon-action-edit:focus-visible {
    outline: 2px solid var(--color-forest-500);
    outline-offset: 1px;
  }

  .taxon-action-delete {
    color: #dc2626;
    background-color: #fef2f2;
  }

  .taxon-action-delete:hover {
    background-color: #fee2e2;
  }

  .taxon-action-delete:focus-visible {
    outline: 2px solid #dc2626;
    outline-offset: 1px;
  }

  /* Mobile: always show action buttons when canEdit */
  @media (max-width: 640px) {
    .sub-taxon-card.can-edit .taxon-actions {
      opacity: 1;
    }

    .taxon-action-btn {
      width: 2rem;
      height: 2rem;
    }
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
