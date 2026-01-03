<script>
  import { base } from '$app/paths';
  import { goto } from '$app/navigation';
  import { onMount, tick } from 'svelte';
  import { fetchSourceById, fetchSpeciesBySource, updateSource, deleteSource, ApiError } from '$lib/apiClient.js';
  import { forceRefresh } from '$lib/stores/dataStore.js';
  import { canEdit } from '$lib/stores/authStore.js';
  import { toast } from '$lib/stores/toastStore.js';
  import SourceEditForm from './SourceEditForm.svelte';
  import DeleteConfirmDialog from './DeleteConfirmDialog.svelte';

  let { sourceId } = $props();

  let source = $state(null);
  let speciesList = $state([]);
  let isLoading = $state(true);
  let error = $state(null);
  let showAllSpecies = $state(false);
  let gridElement = $state(null);
  let columnCount = $state(1);

  // Edit/Delete modal state
  let showEditForm = $state(false);
  let showDeleteDialog = $state(false);
  let isDeleting = $state(false);
  let deleteError = $state(null);

  // Number of rows to show before "Show more"
  const PREVIEW_ROWS = 10;

  async function loadSourceData(id) {
    try {
      isLoading = true;
      error = null;

      // Fetch source details and species in parallel
      const [sourceData, speciesData] = await Promise.all([
        fetchSourceById(Number(id)),
        fetchSpeciesBySource(Number(id))
      ]);

      source = sourceData;
      // Sort by species name
      speciesList = (speciesData || []).sort((a, b) => {
        const nameA = a.scientific_name || a.name || '';
        const nameB = b.scientific_name || b.name || '';
        return nameA.localeCompare(nameB);
      });
    } catch (err) {
      console.error('Failed to fetch source:', err);
      error = err instanceof ApiError ? err.message : 'Failed to load source';
      source = null;
    } finally {
      isLoading = false;
    }
  }

  onMount(() => {
    loadSourceData(sourceId);
    window.addEventListener('resize', updateColumnCount);
    return () => window.removeEventListener('resize', updateColumnCount);
  });

  // Reload when sourceId changes
  $effect(() => {
    if (sourceId) {
      loadSourceData(sourceId);
    }
  });

  // Update column count when grid element becomes available
  $effect(() => {
    if (gridElement) {
      tick().then(updateColumnCount);
    }
  });

  function updateColumnCount() {
    if (!gridElement) return;
    const width = gridElement.offsetWidth;
    // Match CSS breakpoints: 1 col < 480px, 2 cols < 768px, 3 cols < 1024px, 4 cols >= 1024px
    if (width >= 1024) columnCount = 4;
    else if (width >= 768) columnCount = 3;
    else if (width >= 480) columnCount = 2;
    else columnCount = 1;
  }

  let previewCount = $derived(columnCount * PREVIEW_ROWS);
  let displayedSpecies = $derived(showAllSpecies ? speciesList : speciesList.slice(0, previewCount));
  let hasMoreSpecies = $derived(speciesList.length > previewCount);

  // Check if there's any metadata to display
  let hasMetadata = $derived(source && (
    source.source_type ||
    source.author ||
    source.year ||
    source.isbn ||
    source.url ||
    source.description ||
    source.notes
  ));

  // Handle edit button click
  function handleEditClick() {
    showEditForm = true;
  }

  // Handle delete button click
  function handleDeleteClick() {
    deleteError = null;
    showDeleteDialog = true;
  }

  // Handle save from edit form
  async function handleSaveSource(formData) {
    try {
      await updateSource(source.id, formData);

      // Success: show toast and refresh data
      toast.success(`Source "${formData.name}" updated successfully`);

      // Refresh data
      forceRefresh();
      loadSourceData(sourceId);

      return null; // No errors - signal success to form
    } catch (err) {
      if (err instanceof ApiError) {
        // 400 with field errors - return them so form can display
        if (err.status === 400 && err.fieldErrors) {
          return err.fieldErrors;
        }

        // Other API errors - show toast
        toast.error(`Failed to update source: ${err.message}`);
      } else {
        toast.error('Failed to update source: Network error');
      }

      throw err; // Re-throw so form stays open
    }
  }

  // Handle delete confirmation
  async function handleDeleteConfirm() {
    isDeleting = true;
    deleteError = null;
    try {
      await deleteSource(source.id);

      // Success: show toast
      toast.success(`Source "${source.name}" deleted successfully`);

      showDeleteDialog = false;

      // Refresh data in background
      forceRefresh();

      // Navigate back to sources list after delete
      goto(`${base}/sources/`);
    } catch (err) {
      if (err instanceof ApiError) {
        if (err.status === 409) {
          // Constraint violation - source has species data
          deleteError = err.message || 'Cannot delete: species have data from this source.';
        } else {
          toast.error(`Failed to delete source: ${err.message}`);
        }
      } else {
        toast.error('Failed to delete source: Network error');
      }
    } finally {
      isDeleting = false;
    }
  }
</script>

{#if isLoading}
  <div class="loading">
    <div class="loading-spinner"></div>
    <p>Loading source...</p>
  </div>
{:else if error}
  <div class="not-found">
    <h2>Error</h2>
    <p>{error}</p>
    <a href="{base}/" class="back-link">Return to home</a>
  </div>
{:else if !source}
  <div class="not-found">
    <h2>Source Not Found</h2>
    <p>The requested source could not be found.</p>
    <a href="{base}/" class="back-link">Return to home</a>
  </div>
{:else}
  <article class="source-detail">
    <!-- Header -->
    <header class="source-header">
      <div class="source-header-left">
        <h1 class="source-name">{source.name}</h1>
        {#if source.source_type}
          <span class="type-badge">{source.source_type}</span>
        {/if}
      </div>

      <!-- Edit/Delete buttons -->
      <div class="source-actions">
        {#if $canEdit}
          <button
            type="button"
            class="action-btn action-btn-edit"
            title="Edit source"
            onclick={handleEditClick}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
              <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
            </svg>
            <span>Edit</span>
          </button>
          <button
            type="button"
            class="action-btn action-btn-delete"
            title="Delete source"
            onclick={handleDeleteClick}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="3,6 5,6 21,6" />
              <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
              <line x1="10" y1="11" x2="10" y2="17" />
              <line x1="14" y1="11" x2="14" y2="17" />
            </svg>
            <span>Delete</span>
          </button>
        {/if}
      </div>
    </header>

    <!-- Metadata section -->
    {#if hasMetadata}
    <section class="card metadata-section">
      <dl class="metadata-list">
        {#if source.source_type}
          <div class="metadata-item">
            <dt>Type</dt>
            <dd>{source.source_type}</dd>
          </div>
        {/if}
        {#if source.author}
          <div class="metadata-item">
            <dt>Author</dt>
            <dd>{source.author}</dd>
          </div>
        {/if}
        {#if source.year}
          <div class="metadata-item">
            <dt>Year</dt>
            <dd>{source.year}</dd>
          </div>
        {/if}
        {#if source.isbn}
          <div class="metadata-item">
            <dt>ISBN</dt>
            <dd>{source.isbn}</dd>
          </div>
        {/if}
        {#if source.url}
          <div class="metadata-item">
            <dt>Website</dt>
            <dd>
              <a href={source.url} target="_blank" rel="noopener noreferrer" class="url-link">
                {source.url}
                <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                </svg>
              </a>
            </dd>
          </div>
        {/if}
      </dl>

      {#if source.description}
        <p class="description">{source.description}</p>
      {/if}

      {#if source.notes}
        <p class="notes">{source.notes}</p>
      {/if}
    </section>
    {/if}

    <!-- Coverage stats -->
    <section class="coverage-section">
      <h2 class="section-title">Coverage</h2>
      <div class="stats-grid">
        <div class="card stat-card">
          <span class="stat-value">{speciesList.length}</span>
          <span class="stat-label">Species</span>
        </div>
      </div>
    </section>

    <!-- Species list -->
    {#if speciesList.length > 0}
    <section class="species-section">
      <h2 class="section-title">Species with Data from This Source</h2>

      <div class="species-grid" bind:this={gridElement}>
        {#each displayedSpecies as species}
          {@const speciesName = species.scientific_name || species.name}
          <a href="{base}/species/{encodeURIComponent(speciesName)}/?source={sourceId}" class="species-link">
            <span class="species-name">
              {#if species.is_hybrid}
                Q. ×{speciesName.startsWith('×') ? speciesName.slice(1) : speciesName}
              {:else}
                Q. {speciesName}
              {/if}
            </span>
          </a>
        {/each}
      </div>

      {#if hasMoreSpecies}
        <button class="toggle-btn" onclick={() => showAllSpecies = !showAllSpecies}>
          {#if showAllSpecies}
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M5 15l7-7 7 7" />
            </svg>
            Show fewer
          {:else}
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
            </svg>
            More ({speciesList.length - previewCount} remaining)
          {/if}
        </button>
      {/if}
    </section>
    {/if}
  </article>
{/if}

<!-- Edit Source Modal -->
{#if showEditForm && source}
  <SourceEditForm
    {source}
    isOpen={showEditForm}
    onClose={() => showEditForm = false}
    onSave={handleSaveSource}
  />
{/if}

<!-- Delete Confirmation Dialog -->
{#if showDeleteDialog && source}
  <DeleteConfirmDialog
    entityType="source"
    entityName={source.name}
    {isDeleting}
    cascadeInfo={deleteError ? { message: deleteError } : undefined}
    onConfirm={handleDeleteConfirm}
    onCancel={() => { showDeleteDialog = false; deleteError = null; }}
  />
{/if}

<style>
  .loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 4rem 2rem;
    gap: 1rem;
    color: var(--color-text-secondary);
  }

  .not-found {
    text-align: center;
    padding: 4rem 2rem;
  }

  .not-found h2 {
    font-family: var(--font-serif);
    font-size: 1.5rem;
    font-weight: 600;
    color: var(--color-text-primary);
    margin-bottom: 0.5rem;
  }

  .not-found p {
    color: var(--color-text-secondary);
    margin-bottom: 1.5rem;
  }

  .back-link {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    color: var(--color-forest-600);
    font-weight: 500;
  }

  .back-link:hover {
    color: var(--color-forest-700);
  }

  .source-detail {
    max-width: 48rem;
    margin: 0 auto;
  }

  .source-header {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: 0.75rem;
    margin-bottom: 1rem;
  }

  .source-header-left {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: 0.75rem;
  }

  .source-name {
    font-family: var(--font-serif);
    font-size: 1.875rem;
    font-weight: 700;
    color: var(--color-forest-800);
  }

  .type-badge {
    font-size: 0.75rem;
    font-weight: 500;
    padding: 0.25rem 0.625rem;
    background-color: var(--color-stone-100);
    color: var(--color-text-secondary);
    border-radius: 9999px;
    text-transform: capitalize;
  }

  /* Edit/Delete action buttons */
  .source-actions {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    flex-shrink: 0;
  }

  .action-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.5rem 0.75rem;
    border-radius: 0.5rem;
    font-size: 0.875rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.15s ease;
    border: 1px solid transparent;
  }

  .action-btn svg {
    flex-shrink: 0;
  }

  .action-btn-edit {
    color: var(--color-forest-700);
    background-color: var(--color-forest-100);
    border-color: var(--color-forest-200);
  }

  .action-btn-edit:hover {
    background-color: var(--color-forest-200);
    border-color: var(--color-forest-300);
  }

  .action-btn-edit:focus-visible {
    outline: 2px solid var(--color-forest-500);
    outline-offset: 2px;
  }

  .action-btn-delete {
    color: #dc2626;
    background-color: #fef2f2;
    border-color: #fecaca;
  }

  .action-btn-delete:hover {
    background-color: #fee2e2;
    border-color: #fca5a5;
  }

  .action-btn-delete:focus-visible {
    outline: 2px solid #dc2626;
    outline-offset: 2px;
  }

  /* Hide button text on small screens */
  @media (max-width: 640px) {
    .action-btn span {
      display: none;
    }

    .action-btn {
      min-width: 2.75rem;
      min-height: 2.75rem;
      padding: 0.75rem;
    }

    .action-btn svg {
      width: 20px;
      height: 20px;
    }
  }

  .metadata-section {
    margin-bottom: 2rem;
    padding: 1.25rem;
  }

  .metadata-list {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(12rem, 1fr));
    gap: 1rem;
    margin: 0;
  }

  .metadata-item {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .metadata-item dt {
    font-size: 0.75rem;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.025em;
    color: var(--color-text-tertiary);
  }

  .metadata-item dd {
    margin: 0;
    font-size: 0.9375rem;
    color: var(--color-text-primary);
  }

  .url-link {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    color: var(--color-forest-600);
    text-decoration: none;
    word-break: break-all;
  }

  .url-link:hover {
    color: var(--color-forest-700);
    text-decoration: underline;
  }

  .description {
    margin: 1rem 0 0;
    padding-top: 1rem;
    border-top: 1px solid var(--color-border);
    font-size: 0.9375rem;
    color: var(--color-text-secondary);
    line-height: 1.6;
  }

  .notes {
    margin: 0.75rem 0 0;
    font-size: 0.875rem;
    font-style: italic;
    color: var(--color-text-tertiary);
  }

  .coverage-section {
    margin-bottom: 2.5rem;
  }

  .stats-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 1rem;
    max-width: 20rem;
  }

  .stat-card {
    display: flex;
    flex-direction: column;
    padding: 1.25rem;
    text-align: center;
  }

  .stat-value {
    font-family: var(--font-serif);
    font-size: 2rem;
    font-weight: 700;
    color: var(--color-forest-700);
  }

  .stat-label {
    font-size: 0.875rem;
    color: var(--color-text-secondary);
    margin-top: 0.25rem;
  }

  .species-section {
    margin-bottom: 2rem;
  }

  .species-grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: 0.25rem 1rem;
  }

  @media (min-width: 480px) {
    .species-grid {
      grid-template-columns: repeat(2, 1fr);
    }
  }

  @media (min-width: 768px) {
    .species-grid {
      grid-template-columns: repeat(3, 1fr);
    }
  }

  @media (min-width: 1024px) {
    .species-grid {
      grid-template-columns: repeat(4, 1fr);
    }
  }

  .species-link {
    display: block;
    padding: 0.375rem 0.5rem;
    text-decoration: none;
    border-radius: 0.25rem;
    transition: background-color 0.15s;
  }

  .species-link:hover {
    background-color: var(--color-forest-50);
  }

  .species-name {
    font-family: var(--font-serif);
    font-style: italic;
    font-size: 0.9375rem;
    color: var(--color-forest-700);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .toggle-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    margin-top: 1rem;
    padding: 0.625rem 1rem;
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.5rem;
    color: var(--color-forest-600);
    font-size: 0.9375rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
  }

  .toggle-btn:hover {
    border-color: var(--color-forest-400);
    background-color: var(--color-forest-50);
  }

  .toggle-btn:focus-visible {
    outline: none;
    border-color: var(--color-forest-600);
    box-shadow: 0 0 0 3px rgba(30, 126, 75, 0.15);
  }
</style>
