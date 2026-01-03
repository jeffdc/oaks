<script>
  /**
   * SpeciesAutocomplete - Typeahead input for selecting valid species
   *
   * Usage:
   *   <SpeciesAutocomplete
   *     values={closelyRelatedTo}
   *     placeholder="Search species..."
   *     onChange={(newValues) => closelyRelatedTo = newValues}
   *   />
   */
  import { searchSpecies } from '$lib/apiClient.js';

  /** @type {string[]} Current selected species names */
  export let values = [];

  /** @type {string} Placeholder text for the input */
  export let placeholder = 'Search species...';

  /** @type {(values: string[]) => void} Callback when values change */
  export let onChange = () => {};

  /** @type {boolean} Whether the input is disabled */
  export let disabled = false;

  /** @type {string} Current input value */
  let inputValue = '';

  /** @type {HTMLInputElement|null} Reference to the input element */
  let inputEl = null;

  /** @type {Array<{scientific_name: string, author?: string}>} Autocomplete suggestions */
  let suggestions = [];

  /** @type {boolean} Whether suggestions dropdown is visible */
  let showSuggestions = false;

  /** @type {number} Currently highlighted suggestion index */
  let highlightedIndex = -1;

  /** @type {boolean} Loading state for search */
  let isSearching = false;

  /** @type {number|null} Debounce timer */
  let debounceTimer = null;

  /** @type {HTMLDivElement|null} Reference to the container for click outside detection */
  let containerEl = null;

  /**
   * Search for species matching the query
   * @param {string} query
   */
  async function search(query) {
    if (!query || query.length < 2) {
      suggestions = [];
      showSuggestions = false;
      return;
    }

    isSearching = true;
    try {
      const results = await searchSpecies(query);
      // Filter out already selected species
      suggestions = (results || [])
        .filter(s => !values.includes(s.scientific_name))
        .slice(0, 10); // Limit to 10 suggestions
      showSuggestions = suggestions.length > 0;
      highlightedIndex = -1;
    } catch (err) {
      console.error('Species search failed:', err);
      suggestions = [];
      showSuggestions = false;
    } finally {
      isSearching = false;
    }
  }

  /**
   * Debounced search handler
   * @param {string} query
   */
  function debouncedSearch(query) {
    if (debounceTimer) {
      clearTimeout(debounceTimer);
    }
    debounceTimer = setTimeout(() => {
      search(query);
    }, 200);
  }

  /**
   * Handle input changes
   * @param {Event} event
   */
  function handleInput(event) {
    const target = /** @type {HTMLInputElement} */ (event.target);
    inputValue = target.value;
    debouncedSearch(inputValue);
  }

  /**
   * Add a species to the selection
   * @param {string} speciesName
   */
  function addSpecies(speciesName) {
    if (!speciesName || values.includes(speciesName)) {
      return;
    }
    const newValues = [...values, speciesName];
    onChange(newValues);
    inputValue = '';
    suggestions = [];
    showSuggestions = false;
    highlightedIndex = -1;
    inputEl?.focus();
  }

  /**
   * Remove a species from the selection
   * @param {number} index
   */
  function removeSpecies(index) {
    const newValues = values.filter((_, i) => i !== index);
    onChange(newValues);
    inputEl?.focus();
  }

  /**
   * Handle keyboard navigation
   * @param {KeyboardEvent} event
   */
  function handleKeyDown(event) {
    if (!showSuggestions) {
      if (event.key === 'Backspace' && !inputValue && values.length > 0) {
        // Remove last tag when backspace on empty input
        removeSpecies(values.length - 1);
      }
      return;
    }

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        highlightedIndex = Math.min(highlightedIndex + 1, suggestions.length - 1);
        break;
      case 'ArrowUp':
        event.preventDefault();
        highlightedIndex = Math.max(highlightedIndex - 1, 0);
        break;
      case 'Enter':
        event.preventDefault();
        if (highlightedIndex >= 0 && highlightedIndex < suggestions.length) {
          addSpecies(suggestions[highlightedIndex].scientific_name);
        }
        break;
      case 'Escape':
        event.preventDefault();
        showSuggestions = false;
        highlightedIndex = -1;
        break;
      case 'Tab':
        // Allow tab to close suggestions and move focus
        showSuggestions = false;
        break;
    }
  }

  /**
   * Handle clicking a suggestion
   * @param {string} speciesName
   */
  function handleSuggestionClick(speciesName) {
    addSpecies(speciesName);
  }

  /**
   * Handle blur - close suggestions after a small delay to allow click
   */
  function handleBlur() {
    // Delay to allow suggestion click to register
    setTimeout(() => {
      showSuggestions = false;
    }, 150);
  }

  /**
   * Handle focus - show suggestions if we have a query
   */
  function handleFocus() {
    if (inputValue.length >= 2 && suggestions.length > 0) {
      showSuggestions = true;
    }
  }

  /**
   * Focus the input when clicking the container
   */
  function focusInput() {
    if (!disabled) {
      inputEl?.focus();
    }
  }
</script>

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  bind:this={containerEl}
  class="autocomplete-container"
  class:disabled
>
  <div class="input-area" on:click={focusInput}>
    {#if values.length > 0}
      <ul class="tag-list" role="list" aria-label="Selected species">
        {#each values as species, index (species)}
          <li class="tag">
            <span class="tag-text">Q. {species}</span>
            <button
              type="button"
              class="tag-remove"
              aria-label="Remove {species}"
              on:click|stopPropagation={() => removeSpecies(index)}
              {disabled}
            >
              <svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z"/>
              </svg>
            </button>
          </li>
        {/each}
      </ul>
    {/if}

    <input
      bind:this={inputEl}
      type="text"
      class="autocomplete-input"
      value={inputValue}
      {placeholder}
      {disabled}
      on:input={handleInput}
      on:keydown={handleKeyDown}
      on:blur={handleBlur}
      on:focus={handleFocus}
      autocomplete="off"
      role="combobox"
      aria-autocomplete="list"
      aria-expanded={showSuggestions}
      aria-controls="species-suggestions"
      aria-label="Search for species"
    />

    {#if isSearching}
      <div class="loading-indicator">
        <svg class="spinner" viewBox="0 0 24 24" fill="none" stroke="currentColor">
          <circle cx="12" cy="12" r="10" stroke-width="2" stroke-dasharray="31.4 31.4" />
        </svg>
      </div>
    {/if}
  </div>

  {#if showSuggestions && suggestions.length > 0}
    <ul
      id="species-suggestions"
      class="suggestions-dropdown"
      role="listbox"
    >
      {#each suggestions as suggestion, index}
        <!-- svelte-ignore a11y_click_events_have_key_events -->
        <li
          class="suggestion-item"
          class:highlighted={index === highlightedIndex}
          role="option"
          aria-selected={index === highlightedIndex}
          on:mousedown|preventDefault={() => handleSuggestionClick(suggestion.scientific_name)}
          on:mouseenter={() => highlightedIndex = index}
        >
          <span class="suggestion-name">Quercus {suggestion.scientific_name}</span>
          {#if suggestion.author}
            <span class="suggestion-author">{suggestion.author}</span>
          {/if}
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .autocomplete-container {
    position: relative;
  }

  .input-area {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.375rem;
    min-height: 2.5rem;
    padding: 0.375rem 0.5rem;
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.5rem;
    cursor: text;
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
  }

  .input-area:focus-within {
    border-color: var(--color-forest-600);
    box-shadow: 0 0 0 3px rgba(30, 126, 75, 0.15);
  }

  .autocomplete-container.disabled .input-area {
    background-color: var(--color-background);
    cursor: not-allowed;
    opacity: 0.7;
  }

  .tag-list {
    display: flex;
    flex-wrap: wrap;
    gap: 0.375rem;
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .tag {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    padding: 0.125rem 0.25rem 0.125rem 0.5rem;
    font-size: 0.875rem;
    font-style: italic;
    line-height: 1.4;
    color: var(--color-forest-800);
    background-color: var(--color-forest-100);
    border-radius: 0.25rem;
  }

  .tag-text {
    max-width: 200px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .tag-remove {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 1.125rem;
    height: 1.125rem;
    padding: 0;
    color: var(--color-forest-600);
    background: transparent;
    border: none;
    border-radius: 0.125rem;
    cursor: pointer;
    transition: background-color 0.15s ease, color 0.15s ease;
  }

  .tag-remove:hover:not(:disabled) {
    color: var(--color-forest-900);
    background-color: var(--color-forest-200);
  }

  .tag-remove:focus-visible {
    outline: 2px solid var(--color-forest-600);
    outline-offset: 1px;
  }

  .tag-remove:disabled {
    cursor: not-allowed;
    opacity: 0.5;
  }

  .tag-remove svg {
    width: 0.875rem;
    height: 0.875rem;
  }

  .autocomplete-input {
    flex: 1;
    min-width: 150px;
    padding: 0.125rem 0.25rem;
    font-size: 0.9375rem;
    color: var(--color-text-primary);
    background: transparent;
    border: none;
    outline: none;
  }

  .autocomplete-input::placeholder {
    color: var(--color-text-tertiary);
  }

  .autocomplete-input:disabled {
    cursor: not-allowed;
  }

  .loading-indicator {
    display: flex;
    align-items: center;
    padding: 0 0.25rem;
  }

  .spinner {
    width: 1rem;
    height: 1rem;
    color: var(--color-forest-600);
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  .suggestions-dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    z-index: 50;
    margin-top: 0.25rem;
    padding: 0.25rem 0;
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.5rem;
    box-shadow: var(--shadow-lg);
    list-style: none;
    max-height: 240px;
    overflow-y: auto;
  }

  .suggestion-item {
    display: flex;
    flex-direction: column;
    gap: 0.125rem;
    padding: 0.5rem 0.75rem;
    cursor: pointer;
    transition: background-color 0.1s ease;
  }

  .suggestion-item:hover,
  .suggestion-item.highlighted {
    background-color: var(--color-forest-50);
  }

  .suggestion-name {
    font-style: italic;
    color: var(--color-text-primary);
  }

  .suggestion-author {
    font-size: 0.8125rem;
    color: var(--color-text-secondary);
  }

  /* Mobile: Larger touch targets */
  @media (max-width: 640px) {
    .input-area {
      min-height: 2.75rem;
      padding: 0.5rem;
      gap: 0.5rem;
    }

    .tag-list {
      gap: 0.5rem;
    }

    .tag {
      padding: 0.25rem 0.375rem 0.25rem 0.625rem;
      font-size: 0.9375rem;
    }

    .tag-text {
      max-width: min(150px, 40vw);
    }

    .tag-remove {
      width: 2.75rem;
      height: 2.75rem;
      padding: 0.625rem;
    }

    .tag-remove svg {
      width: 1rem;
      height: 1rem;
    }

    .autocomplete-input {
      font-size: 1rem;
      min-height: 2.5rem;
    }

    .suggestion-item {
      padding: 0.75rem 1rem;
    }
  }
</style>
