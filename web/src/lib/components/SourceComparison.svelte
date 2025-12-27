<script>
  import { base } from '$app/paths';
  import { marked } from 'marked';
  import DOMPurify from 'dompurify';
  import { getAllSources, formatSpeciesName } from '$lib/stores/dataStore.js';

  // Configure marked for safe rendering
  marked.setOptions({
    breaks: true,
    gfm: true,
  });

  export let species;

  // All available sources for this species
  $: sources = getAllSources(species);

  // Selected source IDs for comparison (default: first two, or all if <= 3)
  let selectedSourceIds = [];

  $: {
    if (species && sources.length > 0) {
      // Default: select up to 3 sources
      selectedSourceIds = sources.slice(0, 3).map(s => s.source_id);
    }
  }

  // Sources currently being compared
  $: selectedSources = sources.filter(s => selectedSourceIds.includes(s.source_id));

  // Fields to compare (in display order)
  const fields = [
    { key: 'local_names', label: 'Common Names', type: 'array' },
    { key: 'range', label: 'Geographic Range', type: 'markdown' },
    { key: 'growth_habit', label: 'Growth Habit', type: 'markdown' },
    { key: 'leaves', label: 'Leaves', type: 'markdown' },
    { key: 'fruits', label: 'Fruits (Acorns)', type: 'markdown' },
    { key: 'flowers', label: 'Flowers', type: 'markdown' },
    { key: 'bark', label: 'Bark', type: 'markdown' },
    { key: 'twigs', label: 'Twigs', type: 'markdown' },
    { key: 'buds', label: 'Buds', type: 'markdown' },
    { key: 'hardiness_habitat', label: 'Hardiness & Habitat', type: 'markdown' },
    { key: 'miscellaneous', label: 'Additional Information', type: 'markdown' },
  ];

  // Toggle source selection
  function toggleSource(sourceId) {
    if (selectedSourceIds.includes(sourceId)) {
      // Don't allow deselecting if only one source selected
      if (selectedSourceIds.length > 1) {
        selectedSourceIds = selectedSourceIds.filter(id => id !== sourceId);
      }
    } else {
      // Limit to 4 sources max for readability
      if (selectedSourceIds.length < 4) {
        selectedSourceIds = [...selectedSourceIds, sourceId];
      }
    }
  }

  // Render Markdown to HTML with DOMPurify sanitization
  function renderMarkdown(text) {
    if (!text) return '';
    const html = marked.parse(text);
    return DOMPurify.sanitize(html);
  }

  // Render field value based on type
  function renderValue(source, field) {
    const value = source[field.key];
    if (!value) return null;

    if (field.type === 'array' && Array.isArray(value)) {
      return value.join(', ');
    }
    return value;
  }

  // Check if a field has any data across selected sources
  function fieldHasData(field) {
    return selectedSources.some(s => {
      const val = s[field.key];
      if (Array.isArray(val)) return val.length > 0;
      return val && val.trim && val.trim().length > 0;
    });
  }
</script>

<div class="source-comparison">
  <!-- Header with species name and back link -->
  <header class="comparison-header">
    <a href="{base}/species/{encodeURIComponent(species.name)}/" class="back-link">
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
      </svg>
      Back to species
    </a>
    <h1 class="species-title">
      <span class="prefix">Compare sources for</span>
      <em>{formatSpeciesName(species)}</em>
    </h1>
  </header>

  <!-- Source picker -->
  <div class="source-picker">
    <span class="picker-label">Select sources to compare:</span>
    <div class="source-chips">
      {#each sources as source}
        <button
          class="source-chip"
          class:selected={selectedSourceIds.includes(source.source_id)}
          on:click={() => toggleSource(source.source_id)}
        >
          {source.source_name}
          {#if source.is_preferred}
            <span class="preferred-badge" title="Preferred source">★</span>
          {/if}
        </button>
      {/each}
    </div>
    {#if sources.length > 4}
      <span class="picker-hint">(max 4 sources)</span>
    {/if}
  </div>

  <!-- Comparison table -->
  <div class="comparison-table" style="--column-count: {selectedSources.length}">
    <!-- Column headers -->
    <div class="table-header">
      <div class="field-label-cell header-cell">Field</div>
      {#each selectedSources as source}
        <div class="source-header-cell header-cell">
          <span class="source-name">{source.source_name}</span>
          {#if source.is_preferred}
            <span class="preferred-badge">★</span>
          {/if}
          {#if source.source_url}
            <a
              href={source.source_url}
              target="_blank"
              rel="noopener noreferrer"
              class="source-link"
              title="Visit source"
            >
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
              </svg>
            </a>
          {/if}
        </div>
      {/each}
    </div>

    <!-- Field rows -->
    {#each fields as field}
      {#if fieldHasData(field)}
        <div class="table-row">
          <div class="field-label-cell">
            {field.label}
          </div>
          {#each selectedSources as source}
            <div class="value-cell">
              {#if renderValue(source, field)}
                {#if field.type === 'markdown'}
                  <div class="markdown-content">{@html renderMarkdown(renderValue(source, field))}</div>
                {:else}
                  <div class="text-content">{renderValue(source, field)}</div>
                {/if}
              {:else}
                <span class="no-data">—</span>
              {/if}
            </div>
          {/each}
        </div>
      {/if}
    {/each}
  </div>

  <!-- No sources message -->
  {#if sources.length === 0}
    <div class="no-sources">
      <p>No source data available for this species.</p>
    </div>
  {/if}
</div>

<style>
  .source-comparison {
    padding: 1.5rem;
  }

  /* Header */
  .comparison-header {
    margin-bottom: 1.5rem;
  }

  .back-link {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    font-size: 0.875rem;
    color: var(--color-forest-700);
    text-decoration: none;
    margin-bottom: 0.75rem;
    transition: color 0.15s ease;
  }

  .back-link:hover {
    color: var(--color-forest-500);
  }

  .back-link svg {
    width: 1rem;
    height: 1rem;
  }

  .species-title {
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--color-forest-900);
    font-family: var(--font-serif);
    margin: 0;
  }

  .species-title .prefix {
    font-weight: 400;
    font-style: normal;
    color: var(--color-text-secondary);
    font-family: var(--font-sans);
    font-size: 1rem;
    display: block;
    margin-bottom: 0.25rem;
  }

  /* Source picker */
  .source-picker {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.75rem;
    margin-bottom: 1.5rem;
    padding: 1rem;
    background-color: var(--color-forest-50);
    border-radius: 0.5rem;
    border: 1px solid var(--color-forest-200);
  }

  .picker-label {
    font-size: 0.875rem;
    font-weight: 500;
    color: var(--color-text-secondary);
  }

  .source-chips {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
  }

  .source-chip {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    padding: 0.5rem 0.875rem;
    border-radius: 9999px;
    font-size: 0.875rem;
    font-weight: 500;
    border: 1.5px solid var(--color-forest-300);
    background-color: var(--color-surface);
    color: var(--color-text-secondary);
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .source-chip:hover {
    border-color: var(--color-forest-500);
    color: var(--color-forest-700);
  }

  .source-chip.selected {
    background-color: var(--color-forest-600);
    border-color: var(--color-forest-600);
    color: white;
  }

  .source-chip.selected:hover {
    background-color: var(--color-forest-700);
    border-color: var(--color-forest-700);
  }

  .source-chip .preferred-badge {
    font-size: 0.75rem;
    color: var(--color-oak-brown);
  }

  .source-chip.selected .preferred-badge {
    color: var(--color-oak-100, #fef3c7);
  }

  .picker-hint {
    font-size: 0.75rem;
    color: var(--color-text-tertiary);
  }

  /* Comparison table */
  .comparison-table {
    display: grid;
    grid-template-columns: minmax(140px, 180px) repeat(var(--column-count), 1fr);
    gap: 0;
    border: 1px solid var(--color-border);
    border-radius: 0.5rem;
    overflow: hidden;
    background-color: var(--color-surface);
  }

  .table-header {
    display: contents;
  }

  .header-cell {
    padding: 0.875rem 1rem;
    font-weight: 600;
    font-size: 0.875rem;
    background-color: var(--color-forest-100);
    border-bottom: 2px solid var(--color-forest-300);
    color: var(--color-forest-800);
  }

  .field-label-cell {
    padding: 0.875rem 1rem;
    font-weight: 600;
    font-size: 0.875rem;
    color: var(--color-forest-700);
    background-color: var(--color-forest-50);
    border-right: 1px solid var(--color-border);
  }

  .source-header-cell {
    display: flex;
    align-items: center;
    gap: 0.375rem;
    border-right: 1px solid var(--color-border);
  }

  .source-header-cell:last-child {
    border-right: none;
  }

  .source-header-cell .source-name {
    white-space: nowrap;
  }

  .source-header-cell .preferred-badge {
    font-size: 0.75rem;
    color: var(--color-oak-brown);
  }

  .source-link {
    display: inline-flex;
    align-items: center;
    color: var(--color-text-tertiary);
    padding: 0.125rem;
    border-radius: 0.25rem;
    transition: all 0.15s ease;
  }

  .source-link:hover {
    color: var(--color-forest-600);
    background-color: var(--color-forest-200);
  }

  .table-row {
    display: contents;
  }

  .table-row:nth-child(even) .field-label-cell,
  .table-row:nth-child(even) .value-cell {
    background-color: var(--color-background);
  }

  .table-row .field-label-cell,
  .table-row .value-cell {
    border-bottom: 1px solid var(--color-border);
  }

  .value-cell {
    padding: 0.875rem 1rem;
    font-size: 0.9375rem;
    line-height: 1.6;
    color: var(--color-text-primary);
    border-right: 1px solid var(--color-border);
  }

  .value-cell:last-child {
    border-right: none;
  }

  .no-data {
    color: var(--color-text-tertiary);
    font-style: italic;
  }

  /* Markdown content styling */
  .markdown-content :global(p) {
    margin: 0 0 0.5rem 0;
  }

  .markdown-content :global(p:last-child) {
    margin-bottom: 0;
  }

  .markdown-content :global(ul),
  .markdown-content :global(ol) {
    margin: 0.25rem 0;
    padding-left: 1.25rem;
  }

  .markdown-content :global(li) {
    margin: 0.125rem 0;
  }

  .markdown-content :global(strong) {
    font-weight: 600;
  }

  .markdown-content :global(em) {
    font-style: italic;
  }

  .text-content {
    line-height: 1.5;
  }

  /* No sources state */
  .no-sources {
    text-align: center;
    padding: 3rem;
    color: var(--color-text-secondary);
  }

  /* Responsive: stack on mobile */
  @media (max-width: 768px) {
    .comparison-table {
      display: block;
    }

    .table-header {
      display: none;
    }

    .table-row {
      display: block;
      margin-bottom: 1.5rem;
      border: 1px solid var(--color-border);
      border-radius: 0.5rem;
      overflow: hidden;
    }

    .table-row .field-label-cell {
      display: block;
      width: 100%;
      border-right: none;
      border-bottom: 1px solid var(--color-border);
      background-color: var(--color-forest-100);
      font-weight: 700;
    }

    .table-row .value-cell {
      display: block;
      border-right: none;
      padding: 0.75rem 1rem;
    }

    .table-row .value-cell::before {
      content: attr(data-source);
      display: block;
      font-size: 0.75rem;
      font-weight: 600;
      color: var(--color-forest-600);
      margin-bottom: 0.25rem;
    }
  }
</style>
