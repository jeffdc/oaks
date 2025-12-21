<script>
  import { base } from '$app/paths';
  import { onMount, tick } from 'svelte';
  import { getSourceInfo, getSpeciesBySource } from '$lib/stores/dataStore.js';

  export let sourceId;

  let source = null;
  let speciesList = [];
  let isLoading = true;
  let showAllSpecies = false;
  let gridElement;
  let columnCount = 1;

  // Number of rows to show before "Show more"
  const PREVIEW_ROWS = 10;

  onMount(() => {
    loadSourceData();
    window.addEventListener('resize', updateColumnCount);
    return () => window.removeEventListener('resize', updateColumnCount);
  });

  // Update column count when grid element becomes available
  $: if (gridElement) {
    tick().then(updateColumnCount);
  }

  // Reload when sourceId changes
  $: if (sourceId) {
    loadSourceData();
  }

  async function loadSourceData() {
    isLoading = true;
    source = await getSourceInfo(Number(sourceId));
    if (source) {
      speciesList = await getSpeciesBySource(Number(sourceId));
    }
    isLoading = false;
  }

  function updateColumnCount() {
    if (!gridElement) return;
    const width = gridElement.offsetWidth;
    // Match CSS breakpoints: 1 col < 480px, 2 cols < 768px, 3 cols < 1024px, 4 cols >= 1024px
    if (width >= 1024) columnCount = 4;
    else if (width >= 768) columnCount = 3;
    else if (width >= 480) columnCount = 2;
    else columnCount = 1;
  }

  $: previewCount = columnCount * PREVIEW_ROWS;
  $: displayedSpecies = showAllSpecies ? speciesList : speciesList.slice(0, previewCount);
  $: hasMoreSpecies = speciesList.length > previewCount;

  // Check if there's any metadata to display
  $: hasMetadata = source && (
    source.source_type ||
    source.author ||
    source.year ||
    source.isbn ||
    source.license ||
    source.source_url ||
    source.description ||
    source.notes
  );
</script>

{#if isLoading}
  <div class="loading">
    <div class="loading-spinner"></div>
    <p>Loading source...</p>
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
      <h1 class="source-name">{source.source_name}</h1>
      {#if source.license}
        <span class="license-badge">{source.license}</span>
      {/if}
    </header>

    <!-- Metadata section -->
    {#if hasMetadata}
    <section class="metadata-section">
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
        {#if source.license}
          <div class="metadata-item">
            <dt>License</dt>
            <dd>
              {#if source.license_url}
                <a href={source.license_url} target="_blank" rel="noopener noreferrer" class="license-link">
                  {source.license}
                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                  </svg>
                </a>
              {:else}
                {source.license}
              {/if}
            </dd>
          </div>
        {/if}
        {#if source.source_url}
          <div class="metadata-item">
            <dt>Website</dt>
            <dd>
              <a href={source.source_url} target="_blank" rel="noopener noreferrer" class="url-link">
                {source.source_url}
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
        <div class="stat-card">
          <span class="stat-value">{source.species_count}</span>
          <span class="stat-label">Species</span>
        </div>
        <div class="stat-card">
          <span class="stat-value">{source.coverage_percent}%</span>
          <span class="stat-label">of Database</span>
        </div>
      </div>
    </section>

    <!-- Species list -->
    <section class="species-section">
      <h2 class="section-title">Species with Data from This Source</h2>

      <div class="species-grid" bind:this={gridElement}>
        {#each displayedSpecies as species}
          <a href="{base}/species/{encodeURIComponent(species.name)}/?source={sourceId}" class="species-link">
            <span class="species-name">
              {#if species.is_hybrid}
                Q. ×{species.name.startsWith('×') ? species.name.slice(1) : species.name}
              {:else}
                Q. {species.name}
              {/if}
            </span>
          </a>
        {/each}
      </div>

      {#if hasMoreSpecies}
        <button class="toggle-btn" on:click={() => showAllSpecies = !showAllSpecies}>
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
  </article>
{/if}

<style>
  .loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 4rem 2rem;
    color: var(--color-text-secondary);
  }

  .loading-spinner {
    width: 2rem;
    height: 2rem;
    border: 3px solid var(--color-border);
    border-top-color: var(--color-forest-600);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    margin-bottom: 1rem;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
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
    align-items: baseline;
    gap: 0.75rem;
    margin-bottom: 1rem;
  }

  .source-name {
    font-family: var(--font-serif);
    font-size: 1.875rem;
    font-weight: 700;
    color: var(--color-forest-800);
  }

  .license-badge {
    font-size: 0.75rem;
    font-weight: 500;
    padding: 0.25rem 0.625rem;
    background-color: var(--color-stone-100);
    color: var(--color-text-secondary);
    border-radius: 9999px;
  }

  .metadata-section {
    margin-bottom: 2rem;
    padding: 1.25rem;
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.75rem;
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

  .license-link,
  .url-link {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    color: var(--color-forest-600);
    text-decoration: none;
  }

  .license-link:hover,
  .url-link:hover {
    color: var(--color-forest-700);
    text-decoration: underline;
  }

  .url-link {
    word-break: break-all;
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

  .section-title {
    font-family: var(--font-serif);
    font-size: 1.25rem;
    font-weight: 600;
    color: var(--color-text-primary);
    margin-bottom: 1rem;
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
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.75rem;
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
