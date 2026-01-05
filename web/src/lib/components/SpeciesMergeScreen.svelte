<script>
  /**
   * SpeciesMergeScreen - Side-by-side view for merging a synonym into a target species
   *
   * Displays both species, allows editing the target, and shows referencing species.
   */

  import { base } from '$app/paths';
  import { fetchSpeciesFull, fetchSpeciesReferences, ApiError } from '$lib/apiClient.js';
  import LoadingSpinner from './LoadingSpinner.svelte';
  import MergeFieldRow from './MergeFieldRow.svelte';

  /** @type {{ synonymName: string, targetName: string }} */
  let { synonymName, targetName } = $props();

  // State
  let synonymData = $state(null);
  let targetData = $state(null);
  let referencingSpecies = $state([]);
  let loading = $state(true);
  let error = $state(null);

  // Editable target fields (bound to MergeFieldRow)
  let editedTarget = $state({
    author: null,
    conservation_status: null,
    subgenus: null,
    section: null,
    subsection: null,
    complex: null,
    parent1: null,
    parent2: null
  });

  // Format species name for display (handle hybrids)
  function formatName(name, isHybrid) {
    if (!name) return '';
    const prefix = isHybrid ? '\u00d7 ' : '';
    return prefix + name;
  }

  // Load data on mount
  $effect(() => {
    loadData();
  });

  async function loadData() {
    loading = true;
    error = null;

    try {
      // Fetch both species and references in parallel
      const [synonymResult, targetResult, refsResult] = await Promise.all([
        fetchSpeciesFull(synonymName),
        fetchSpeciesFull(targetName),
        fetchSpeciesReferences(synonymName)
      ]);

      synonymData = synonymResult;
      targetData = targetResult;
      referencingSpecies = refsResult.data || [];

      // Initialize editable fields from target
      editedTarget = {
        author: targetData.author || null,
        conservation_status: targetData.conservation_status || null,
        subgenus: targetData.subgenus || null,
        section: targetData.section || null,
        subsection: targetData.subsection || null,
        complex: targetData.complex || null,
        parent1: targetData.parent1 || null,
        parent2: targetData.parent2 || null
      };
    } catch (err) {
      console.error('Failed to load merge data:', err);
      if (err instanceof ApiError && err.status === 404) {
        error = `Species not found: ${err.message}`;
      } else {
        error = err instanceof ApiError ? err.message : 'Failed to load species data';
      }
    } finally {
      loading = false;
    }
  }

  function handleCancel() {
    // Navigate back to the synonym's species page
    window.history.back();
  }
</script>

<div class="merge-screen">
  {#if loading}
    <div class="loading-container">
      <LoadingSpinner size="lg" message="Loading species data..." />
    </div>
  {:else if error}
    <div class="error-container">
      <svg class="error-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
      </svg>
      <p class="error-title">Unable to load species</p>
      <p class="error-message">{error}</p>
      <a href="{base}/list/" class="back-link">&larr; Back to species list</a>
    </div>
  {:else if synonymData && targetData}
    <!-- Header -->
    <header class="merge-header">
      <h1 class="merge-title">
        Merge:
        <span class="species-name synonym-name">
          {formatName(synonymData.scientific_name, synonymData.is_hybrid)}
        </span>
        <span class="arrow">&rarr;</span>
        <span class="species-name target-name">
          {formatName(targetData.scientific_name, targetData.is_hybrid)}
        </span>
      </h1>
      <p class="merge-subtitle">
        The synonym will be deleted and its data merged into the target species.
      </p>
    </header>

    <!-- Column headers -->
    <div class="column-headers">
      <div class="column-header synonym-header">
        <span class="column-label">Synonym (Read-only)</span>
        <span class="species-link">
          <a href="{base}/species/{encodeURIComponent(synonymName)}/">
            {formatName(synonymData.scientific_name, synonymData.is_hybrid)}
          </a>
        </span>
      </div>
      <div class="spacer"></div>
      <div class="column-header target-header">
        <span class="column-label">Target (Editable)</span>
        <span class="species-link">
          <a href="{base}/species/{encodeURIComponent(targetName)}/">
            {formatName(targetData.scientific_name, targetData.is_hybrid)}
          </a>
        </span>
      </div>
    </div>

    <!-- Field rows -->
    <section class="merge-fields">
      <h2 class="section-title">Species Fields</h2>

      <MergeFieldRow
        label="Author"
        synonymValue={synonymData.author}
        bind:targetValue={editedTarget.author}
        type="text"
      />

      <MergeFieldRow
        label="Conservation Status"
        synonymValue={synonymData.conservation_status}
        bind:targetValue={editedTarget.conservation_status}
        type="text"
      />

      <h3 class="subsection-title">Taxonomy</h3>

      <MergeFieldRow
        label="Subgenus"
        synonymValue={synonymData.subgenus}
        bind:targetValue={editedTarget.subgenus}
        type="text"
      />

      <MergeFieldRow
        label="Section"
        synonymValue={synonymData.section}
        bind:targetValue={editedTarget.section}
        type="text"
      />

      <MergeFieldRow
        label="Subsection"
        synonymValue={synonymData.subsection}
        bind:targetValue={editedTarget.subsection}
        type="text"
      />

      <MergeFieldRow
        label="Complex"
        synonymValue={synonymData.complex}
        bind:targetValue={editedTarget.complex}
        type="text"
      />

      {#if synonymData.is_hybrid || targetData.is_hybrid}
        <h3 class="subsection-title">Hybrid Parents</h3>

        <MergeFieldRow
          label="Parent 1"
          synonymValue={synonymData.parent1}
          bind:targetValue={editedTarget.parent1}
          type="text"
        />

        <MergeFieldRow
          label="Parent 2"
          synonymValue={synonymData.parent2}
          bind:targetValue={editedTarget.parent2}
          type="text"
        />
      {/if}
    </section>

    <!-- Referencing species -->
    {#if referencingSpecies.length > 0}
      <section class="references-section">
        <h2 class="section-title">
          Species Referencing "{synonymData.scientific_name}"
          <span class="reference-count">({referencingSpecies.length})</span>
        </h2>
        <p class="references-note">
          These species reference the synonym and will be updated to reference the target instead.
        </p>
        <ul class="references-list">
          {#each referencingSpecies as ref}
            <li class="reference-item">
              <a href="{base}/species/{encodeURIComponent(ref.scientific_name)}/" class="reference-link">
                {ref.scientific_name}
              </a>
              <span class="reference-type badge badge-muted">{ref.reference_type}</span>
            </li>
          {/each}
        </ul>
      </section>
    {/if}

    <!-- Action bar -->
    <footer class="action-bar">
      <button type="button" class="btn btn-secondary" onclick={handleCancel}>
        Cancel
      </button>
      <button type="button" class="btn btn-primary" disabled>
        Save Merge
      </button>
    </footer>
  {/if}
</div>

<style>
  .merge-screen {
    max-width: 1200px;
    margin: 0 auto;
    padding: 1.5rem;
  }

  /* Loading state */
  .loading-container {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 400px;
    background-color: var(--color-surface);
    border-radius: 1rem;
    box-shadow: var(--shadow-sm);
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

  .back-link {
    display: inline-flex;
    align-items: center;
    color: var(--color-forest-600);
    font-weight: 500;
    text-decoration: none;
    transition: color 0.15s ease;
  }

  .back-link:hover {
    color: var(--color-forest-700);
  }

  /* Header */
  .merge-header {
    margin-bottom: 1.5rem;
    padding: 1.5rem;
    background-color: var(--color-surface);
    border-radius: 1rem;
    box-shadow: var(--shadow-sm);
  }

  .merge-title {
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--color-text-primary);
    margin: 0 0 0.5rem 0;
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 0.5rem;
  }

  .species-name {
    font-style: italic;
    font-family: var(--font-serif);
  }

  .synonym-name {
    color: var(--color-text-secondary);
  }

  .target-name {
    color: var(--color-forest-700);
  }

  .arrow {
    color: var(--color-text-tertiary);
    font-style: normal;
  }

  .merge-subtitle {
    font-size: 0.9375rem;
    color: var(--color-text-secondary);
    margin: 0;
  }

  /* Column headers */
  .column-headers {
    display: grid;
    grid-template-columns: 1fr auto 1fr;
    gap: 0.75rem;
    margin-bottom: 1rem;
    padding: 0 0.75rem;
  }

  .column-header {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .column-label {
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--color-text-tertiary);
  }

  .synonym-header .column-label {
    color: var(--color-text-tertiary);
  }

  .target-header .column-label {
    color: var(--color-forest-600);
  }

  .species-link a {
    font-size: 0.875rem;
    font-style: italic;
    font-family: var(--font-serif);
    color: var(--color-forest-600);
    text-decoration: none;
  }

  .species-link a:hover {
    text-decoration: underline;
  }

  .spacer {
    width: 2rem;
  }

  /* Fields section */
  .merge-fields {
    background-color: var(--color-surface);
    border-radius: 1rem;
    box-shadow: var(--shadow-sm);
    padding: 1.5rem;
    margin-bottom: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .section-title {
    font-size: 1.125rem;
    font-weight: 600;
    color: var(--color-text-primary);
    margin: 0 0 0.5rem 0;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid var(--color-border);
  }

  .subsection-title {
    font-size: 0.9375rem;
    font-weight: 600;
    color: var(--color-text-secondary);
    margin: 1rem 0 0.5rem 0;
  }

  /* References section */
  .references-section {
    background-color: var(--color-surface);
    border-radius: 1rem;
    box-shadow: var(--shadow-sm);
    padding: 1.5rem;
    margin-bottom: 1.5rem;
  }

  .reference-count {
    font-weight: 400;
    color: var(--color-text-secondary);
  }

  .references-note {
    font-size: 0.875rem;
    color: var(--color-text-secondary);
    margin: 0 0 1rem 0;
  }

  .references-list {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .reference-item {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.5rem 0.75rem;
    background-color: var(--color-background);
    border-radius: 0.5rem;
  }

  .reference-link {
    font-style: italic;
    font-family: var(--font-serif);
    color: var(--color-forest-600);
    text-decoration: none;
  }

  .reference-link:hover {
    text-decoration: underline;
  }

  .reference-type {
    font-size: 0.75rem;
  }

  /* Action bar */
  .action-bar {
    position: sticky;
    bottom: 0;
    display: flex;
    justify-content: flex-end;
    gap: 0.75rem;
    padding: 1rem 1.5rem;
    background-color: var(--color-surface);
    border-radius: 1rem;
    box-shadow: var(--shadow-lg);
  }

  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 0.625rem 1.25rem;
    font-size: 0.9375rem;
    font-weight: 500;
    border-radius: 0.5rem;
    cursor: pointer;
    transition: all 0.15s ease;
    border: none;
  }

  .btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-secondary {
    background-color: var(--color-background);
    color: var(--color-text-primary);
    border: 1px solid var(--color-border);
  }

  .btn-secondary:hover:not(:disabled) {
    background-color: var(--color-border);
  }

  .btn-primary {
    background-color: var(--color-forest-600);
    color: white;
  }

  .btn-primary:hover:not(:disabled) {
    background-color: var(--color-forest-700);
  }

  /* Responsive */
  @media (max-width: 768px) {
    .merge-screen {
      padding: 1rem;
    }

    .column-headers {
      display: none;
    }

    .merge-title {
      font-size: 1.25rem;
    }
  }
</style>
