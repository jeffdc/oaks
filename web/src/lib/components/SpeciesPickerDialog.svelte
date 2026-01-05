<script>
  import { onMount, onDestroy } from 'svelte';
  import { searchSpecies, fetchSpeciesFull } from '$lib/apiClient.js';
  import LoadingSpinner from './LoadingSpinner.svelte';

  /**
   * SpeciesPickerDialog - Modal for selecting a species from search results
   *
   * Used for synonymization workflow to select a target species.
   *
   * Props:
   * - currentSpecies: The species being made into a synonym (excluded from results)
   * - onSelect: Callback when user confirms selection with the selected species
   * - onCancel: Callback when user cancels/closes the dialog
   */

  /** @type {Object} The species being made into a synonym */
  export let currentSpecies;

  /** @type {(targetSpecies: Object) => void} Callback when user confirms selection */
  export let onSelect;

  /** @type {() => void} Callback when user cancels */
  export let onCancel;

  // Search state
  let searchQuery = '';
  let searchResults = [];
  let isSearching = false;
  let searchError = null;

  // Selection state
  let selectedSpecies = null;
  let isValidating = false;
  let validationError = null;

  // Debounce timer
  let debounceTimer = null;

  // Get current species name for comparison
  $: currentSpeciesName = currentSpecies?.scientific_name || currentSpecies?.name || '';

  // Debounced search function
  function handleSearchInput() {
    // Clear previous timer
    if (debounceTimer) {
      clearTimeout(debounceTimer);
    }

    // Clear selection when search changes
    selectedSpecies = null;
    validationError = null;

    // Don't search if query is too short
    if (searchQuery.trim().length < 2) {
      searchResults = [];
      isSearching = false;
      return;
    }

    isSearching = true;

    // Debounce the search (300ms)
    debounceTimer = setTimeout(async () => {
      try {
        const results = await searchSpecies(searchQuery.trim());

        // Filter out the current species to prevent self-synonymization
        searchResults = results.filter(s => {
          const name = s.scientific_name || s.name;
          return name.toLowerCase() !== currentSpeciesName.toLowerCase();
        });

        searchError = null;
      } catch (err) {
        searchError = 'Failed to search species';
        searchResults = [];
        console.error('Search error:', err);
      } finally {
        isSearching = false;
      }
    }, 300);
  }

  // Handle species selection
  async function handleSelectSpecies(species) {
    selectedSpecies = species;
    validationError = null;

    // Validate: check if this would create a circular synonym
    isValidating = true;
    try {
      const targetName = species.scientific_name || species.name;
      const fullSpecies = await fetchSpeciesFull(targetName);

      // Check if target already has current species as a synonym
      if (fullSpecies.synonyms && fullSpecies.synonyms.length > 0) {
        const synonymNames = fullSpecies.synonyms.map(s =>
          (typeof s === 'string' ? s : s.name || '').toLowerCase()
        );

        if (synonymNames.includes(currentSpeciesName.toLowerCase())) {
          validationError = 'Circular synonyms are not allowed. This species already lists the current species as a synonym.';
          selectedSpecies = null;
        }
      }
    } catch (err) {
      console.error('Validation error:', err);
      // Don't block selection on validation error - the server will catch it
    } finally {
      isValidating = false;
    }
  }

  // Handle confirm button click
  function handleConfirm() {
    if (selectedSpecies && !validationError && !isValidating) {
      onSelect(selectedSpecies);
    }
  }

  // Handle keyboard events
  function handleKeydown(event) {
    if (event.key === 'Escape') {
      onCancel();
    }
  }

  // Format species display name
  function formatSpeciesName(species) {
    const name = species.scientific_name || species.name;
    const prefix = species.is_hybrid && !name.startsWith('×') ? '× ' : '';
    return `Quercus ${prefix}${name}`;
  }

  // Cleanup on destroy
  onDestroy(() => {
    if (debounceTimer) {
      clearTimeout(debounceTimer);
    }
  });
</script>

<svelte:window on:keydown={handleKeydown} />

<!-- Modal backdrop -->
<div
  class="overlay"
  role="dialog"
  aria-modal="true"
  aria-labelledby="picker-title"
>
  <div class="dialog">
    <!-- Header -->
    <header class="dialog-header">
      <h2 id="picker-title" class="dialog-title">Select Target Species</h2>
      <button
        type="button"
        class="close-button"
        aria-label="Close dialog"
        on:click={onCancel}
      >
        <svg
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <line x1="18" y1="6" x2="6" y2="18"></line>
          <line x1="6" y1="6" x2="18" y2="18"></line>
        </svg>
      </button>
    </header>

    <!-- Description -->
    <p class="dialog-description">
      Select the species that <em>Quercus {currentSpeciesName}</em> will become a synonym of.
    </p>

    <!-- Search input -->
    <div class="search-container">
      <input
        type="text"
        class="search-input"
        placeholder="Search for a species..."
        bind:value={searchQuery}
        on:input={handleSearchInput}
        autofocus
      />
      {#if isSearching}
        <div class="search-spinner">
          <LoadingSpinner size="sm" />
        </div>
      {/if}
    </div>

    <!-- Error message for validation -->
    {#if validationError}
      <div class="error-message">
        <svg class="error-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10" />
          <line x1="12" y1="8" x2="12" y2="12" />
          <line x1="12" y1="16" x2="12.01" y2="16" />
        </svg>
        <span>{validationError}</span>
      </div>
    {/if}

    <!-- Search results -->
    <div class="results-container">
      {#if searchQuery.trim().length < 2}
        <p class="hint-text">Type at least 2 characters to search</p>
      {:else if searchError}
        <p class="error-text">{searchError}</p>
      {:else if searchResults.length === 0 && !isSearching}
        <p class="no-results">No species found matching "{searchQuery}"</p>
      {:else}
        <ul class="results-list" role="listbox">
          {#each searchResults as species}
            {@const speciesName = species.scientific_name || species.name}
            {@const isSelected = selectedSpecies && (selectedSpecies.scientific_name || selectedSpecies.name) === speciesName}
            <li>
              <button
                type="button"
                class="result-item"
                class:selected={isSelected}
                role="option"
                aria-selected={isSelected}
                on:click={() => handleSelectSpecies(species)}
              >
                <div class="result-name">
                  <span class="species-name">
                    {#if species.is_hybrid}
                      <span class="hybrid-indicator">×</span>
                    {/if}
                    {speciesName}
                  </span>
                  {#if species.author}
                    <span class="species-author">{species.author}</span>
                  {/if}
                </div>
                <div class="result-meta">
                  {#if species.section}
                    <span class="section-badge">sect. {species.section}</span>
                  {/if}
                  {#if species.is_hybrid}
                    <span class="hybrid-badge">Hybrid</span>
                  {/if}
                </div>
              </button>
            </li>
          {/each}
        </ul>
      {/if}
    </div>

    <!-- Footer with actions -->
    <footer class="dialog-footer">
      <button
        type="button"
        class="btn btn-secondary"
        on:click={onCancel}
      >
        Cancel
      </button>
      <button
        type="button"
        class="btn btn-primary"
        disabled={!selectedSpecies || !!validationError || isValidating}
        on:click={handleConfirm}
      >
        {#if isValidating}
          <LoadingSpinner size="sm" />
          <span>Validating...</span>
        {:else}
          Confirm
        {/if}
      </button>
    </footer>
  </div>
</div>

<style>
  .overlay {
    position: fixed;
    inset: 0;
    z-index: 100;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: rgba(0, 0, 0, 0.5);
    backdrop-filter: blur(2px);
    padding: 1rem;
  }

  .dialog {
    display: flex;
    flex-direction: column;
    width: 100%;
    max-width: 32rem;
    max-height: 80vh;
    background-color: var(--color-surface);
    border-radius: 0.75rem;
    box-shadow: var(--shadow-xl);
    overflow: hidden;
  }

  .dialog-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.25rem;
    border-bottom: 1px solid var(--color-border);
    background-color: var(--color-forest-50);
    flex-shrink: 0;
  }

  .dialog-title {
    margin: 0;
    font-size: 1.25rem;
    font-weight: 600;
    font-family: var(--font-serif);
    color: var(--color-forest-800);
  }

  .close-button {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 2.25rem;
    height: 2.25rem;
    padding: 0;
    color: var(--color-text-secondary);
    background: none;
    border: none;
    border-radius: 0.5rem;
    cursor: pointer;
    transition: background-color 0.15s ease, color 0.15s ease;
  }

  .close-button:hover {
    background-color: var(--color-forest-100);
    color: var(--color-forest-700);
  }

  .close-button:focus-visible {
    outline: 2px solid var(--color-forest-500);
    outline-offset: 2px;
  }

  .dialog-description {
    margin: 0;
    padding: 0.875rem 1.25rem;
    font-size: 0.875rem;
    color: var(--color-text-secondary);
    border-bottom: 1px solid var(--color-border);
  }

  .dialog-description em {
    color: var(--color-forest-700);
    font-weight: 500;
  }

  .search-container {
    position: relative;
    padding: 1rem 1.25rem;
    flex-shrink: 0;
  }

  .search-input {
    width: 100%;
    padding: 0.75rem 1rem;
    padding-right: 2.5rem;
    font-size: 0.9375rem;
    border: 1px solid var(--color-border);
    border-radius: 0.5rem;
    background-color: var(--color-surface);
    color: var(--color-text-primary);
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
  }

  .search-input:focus {
    outline: none;
    border-color: var(--color-forest-500);
    box-shadow: 0 0 0 3px rgba(34, 139, 34, 0.1);
  }

  .search-input::placeholder {
    color: var(--color-text-tertiary);
  }

  .search-spinner {
    position: absolute;
    right: 2rem;
    top: 50%;
    transform: translateY(-50%);
  }

  .error-message {
    display: flex;
    align-items: flex-start;
    gap: 0.5rem;
    margin: 0 1.25rem 1rem;
    padding: 0.75rem;
    background-color: #fef2f2;
    border: 1px solid #fecaca;
    border-radius: 0.5rem;
    color: #991b1b;
    font-size: 0.875rem;
  }

  .error-icon {
    width: 1.25rem;
    height: 1.25rem;
    flex-shrink: 0;
    stroke: #dc2626;
  }

  .results-container {
    flex: 1;
    overflow-y: auto;
    min-height: 200px;
    max-height: 300px;
    padding: 0 1.25rem;
    -webkit-overflow-scrolling: touch;
  }

  .hint-text,
  .no-results,
  .error-text {
    text-align: center;
    padding: 2rem 1rem;
    color: var(--color-text-secondary);
    font-size: 0.875rem;
  }

  .error-text {
    color: #dc2626;
  }

  .results-list {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .result-item {
    width: 100%;
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    padding: 0.75rem 1rem;
    margin-bottom: 0.5rem;
    background-color: var(--color-background);
    border: 1px solid var(--color-border);
    border-radius: 0.5rem;
    cursor: pointer;
    text-align: left;
    transition: all 0.15s ease;
  }

  .result-item:hover {
    background-color: var(--color-forest-50);
    border-color: var(--color-forest-300);
  }

  .result-item.selected {
    background-color: var(--color-forest-100);
    border-color: var(--color-forest-500);
    box-shadow: 0 0 0 2px rgba(34, 139, 34, 0.2);
  }

  .result-item:focus-visible {
    outline: 2px solid var(--color-forest-500);
    outline-offset: 2px;
  }

  .result-name {
    display: flex;
    align-items: baseline;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .species-name {
    font-weight: 600;
    font-style: italic;
    color: var(--color-forest-800);
  }

  .hybrid-indicator {
    font-style: normal;
    color: var(--color-forest-600);
  }

  .species-author {
    font-size: 0.8125rem;
    color: var(--color-text-secondary);
    font-style: normal;
  }

  .result-meta {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .section-badge,
  .hybrid-badge {
    display: inline-flex;
    padding: 0.125rem 0.5rem;
    font-size: 0.75rem;
    font-weight: 500;
    border-radius: 9999px;
  }

  .section-badge {
    background-color: var(--color-forest-100);
    color: var(--color-forest-700);
  }

  .hybrid-badge {
    background-color: #fef3c7;
    color: #92400e;
  }

  .dialog-footer {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 0.75rem;
    padding: 1rem 1.25rem;
    border-top: 1px solid var(--color-border);
    background-color: var(--color-background);
    flex-shrink: 0;
  }

  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    padding: 0.625rem 1.25rem;
    font-size: 0.9375rem;
    font-weight: 500;
    line-height: 1.5;
    border: 1px solid transparent;
    border-radius: 0.5rem;
    cursor: pointer;
    transition: background-color 0.15s ease, border-color 0.15s ease;
    min-height: 2.75rem;
  }

  .btn:focus-visible {
    outline: 2px solid var(--color-forest-500);
    outline-offset: 2px;
  }

  .btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .btn-secondary {
    color: var(--color-text-primary);
    background-color: var(--color-surface);
    border-color: var(--color-border);
  }

  .btn-secondary:hover:not(:disabled) {
    background-color: var(--color-background);
    border-color: var(--color-text-tertiary);
  }

  .btn-primary {
    color: white;
    background-color: var(--color-forest-600);
    border-color: var(--color-forest-600);
  }

  .btn-primary:hover:not(:disabled) {
    background-color: var(--color-forest-700);
    border-color: var(--color-forest-700);
  }

  /* Mobile: Full-screen dialog */
  @media (max-width: 640px) {
    .overlay {
      padding: 0;
      align-items: stretch;
    }

    .dialog {
      max-width: none;
      max-height: none;
      height: 100%;
      border-radius: 0;
    }

    .results-container {
      max-height: none;
      flex: 1;
    }

    .dialog-footer {
      padding-bottom: max(1rem, env(safe-area-inset-bottom));
    }

    .btn {
      min-height: 3rem;
      font-size: 1rem;
    }
  }
</style>
