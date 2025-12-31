<script>
  import { onMount, createEventDispatcher } from 'svelte';
  import { fetchTaxa } from '$lib/apiClient.js';

  /**
   * TaxonSelect - Taxonomy field selector with dropdown or autocomplete
   *
   * For subgenus: Simple dropdown with fixed values
   * For section/subsection/complex: Autocomplete with API suggestions
   *
   * Usage:
   *   <TaxonSelect level="section" bind:value={section} on:change={handleChange} />
   */

  /** @type {'subgenus' | 'section' | 'subsection' | 'complex'} */
  export let level;

  /** @type {string} */
  export let value = '';

  /** @type {boolean} */
  export let disabled = false;

  /** @type {string | undefined} Parent taxon for filtering (e.g., subgenus for sections) */
  export let parentTaxon = undefined;

  /** @type {string | undefined} Optional ID for aria-labelledby */
  export let labelledBy = undefined;

  const dispatch = createEventDispatcher();

  // Fixed subgenus values
  const SUBGENERA = ['Quercus', 'Cerris', 'Cyclobalanopsis'];

  // Autocomplete state
  /** @type {Array<{name: string, level: string, parent?: string}>} */
  let allTaxa = [];
  /** @type {Array<string>} */
  let suggestions = [];
  let isOpen = false;
  let isLoading = false;
  let activeIndex = -1;
  let inputElement;
  let listboxElement;

  // Generate unique IDs for ARIA
  const inputId = `taxon-${level}-${Math.random().toString(36).substr(2, 9)}`;
  const listboxId = `${inputId}-listbox`;

  // Fetch taxa on mount (for autocomplete levels)
  onMount(async () => {
    if (level !== 'subgenus') {
      await loadTaxa();
    }
  });

  async function loadTaxa() {
    isLoading = true;
    try {
      allTaxa = await fetchTaxa();
    } catch (err) {
      console.error('Failed to load taxa:', err);
      allTaxa = [];
    } finally {
      isLoading = false;
    }
  }

  // Filter suggestions based on current input
  $: if (level !== 'subgenus') {
    const query = value.toLowerCase().trim();
    const filtered = allTaxa
      .filter(t => {
        // Match the level
        if (t.level !== level) return false;
        // Optionally filter by parent taxon
        if (parentTaxon && t.parent !== parentTaxon) return false;
        // Match the query
        if (!query) return true;
        return t.name.toLowerCase().includes(query);
      })
      .map(t => t.name)
      .sort();

    // Limit to 10 suggestions
    suggestions = filtered.slice(0, 10);
  }

  function handleInput(event) {
    value = event.target.value;
    isOpen = true;
    activeIndex = -1;
    dispatch('change', { value });
  }

  function handleSelectChange(event) {
    value = event.target.value;
    dispatch('change', { value });
  }

  function selectSuggestion(suggestion) {
    value = suggestion;
    isOpen = false;
    activeIndex = -1;
    dispatch('change', { value });
    inputElement?.focus();
  }

  function handleKeydown(event) {
    if (!isOpen && event.key !== 'Escape') {
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        isOpen = true;
        event.preventDefault();
        return;
      }
    }

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        if (suggestions.length > 0) {
          activeIndex = (activeIndex + 1) % suggestions.length;
          scrollActiveIntoView();
        }
        break;

      case 'ArrowUp':
        event.preventDefault();
        if (suggestions.length > 0) {
          activeIndex = activeIndex <= 0 ? suggestions.length - 1 : activeIndex - 1;
          scrollActiveIntoView();
        }
        break;

      case 'Enter':
        event.preventDefault();
        if (activeIndex >= 0 && activeIndex < suggestions.length) {
          selectSuggestion(suggestions[activeIndex]);
        } else {
          isOpen = false;
        }
        break;

      case 'Escape':
        event.preventDefault();
        isOpen = false;
        activeIndex = -1;
        break;

      case 'Tab':
        isOpen = false;
        activeIndex = -1;
        break;
    }
  }

  function scrollActiveIntoView() {
    if (listboxElement && activeIndex >= 0) {
      const activeOption = listboxElement.children[activeIndex];
      activeOption?.scrollIntoView({ block: 'nearest' });
    }
  }

  function handleFocus() {
    if (level !== 'subgenus') {
      isOpen = true;
    }
  }

  function handleBlur(event) {
    // Delay close to allow click on suggestions
    setTimeout(() => {
      isOpen = false;
      activeIndex = -1;
    }, 150);
  }

  function clearValue() {
    value = '';
    isOpen = false;
    activeIndex = -1;
    dispatch('change', { value: '' });
    inputElement?.focus();
  }
</script>

{#if level === 'subgenus'}
  <!-- Simple dropdown for subgenus -->
  <select
    class="taxon-select"
    {disabled}
    bind:value
    on:change={handleSelectChange}
    aria-labelledby={labelledBy}
  >
    <option value="">Select subgenus...</option>
    {#each SUBGENERA as subgenus}
      <option value={subgenus}>{subgenus}</option>
    {/each}
  </select>
{:else}
  <!-- Autocomplete for section/subsection/complex -->
  <div class="autocomplete-container">
    <div class="input-wrapper">
      <input
        bind:this={inputElement}
        type="text"
        class="taxon-input"
        {value}
        {disabled}
        placeholder="Type to search {level}s..."
        role="combobox"
        aria-autocomplete="list"
        aria-expanded={isOpen && suggestions.length > 0}
        aria-controls={listboxId}
        aria-activedescendant={activeIndex >= 0 ? `${listboxId}-option-${activeIndex}` : undefined}
        aria-labelledby={labelledBy}
        on:input={handleInput}
        on:keydown={handleKeydown}
        on:focus={handleFocus}
        on:blur={handleBlur}
      />
      {#if value && !disabled}
        <button
          type="button"
          class="clear-button"
          aria-label="Clear selection"
          on:click={clearValue}
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
        </button>
      {/if}
    </div>

    {#if isOpen && !disabled}
      <ul
        bind:this={listboxElement}
        id={listboxId}
        class="suggestions-list"
        role="listbox"
        aria-label="{level} suggestions"
      >
        {#if isLoading}
          <li class="suggestion-item loading" role="option" aria-disabled="true">
            Loading...
          </li>
        {:else if suggestions.length === 0}
          <li class="suggestion-item empty" role="option" aria-disabled="true">
            {value ? 'No matches found' : `No ${level}s available`}
          </li>
        {:else}
          {#each suggestions as suggestion, index}
            <li
              id="{listboxId}-option-{index}"
              class="suggestion-item"
              class:active={index === activeIndex}
              role="option"
              aria-selected={index === activeIndex}
              on:mousedown|preventDefault={() => selectSuggestion(suggestion)}
              on:mouseenter={() => activeIndex = index}
            >
              {suggestion}
            </li>
          {/each}
        {/if}
      </ul>
    {/if}
  </div>
{/if}

<style>
  .taxon-select {
    width: 100%;
    padding: 0.5rem 0.75rem;
    font-size: 0.9375rem;
    line-height: 1.5;
    color: var(--color-text-primary);
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.5rem;
    cursor: pointer;
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
  }

  .taxon-select:focus {
    outline: none;
    border-color: var(--color-forest-600);
    box-shadow: 0 0 0 3px rgba(30, 126, 75, 0.15);
  }

  .taxon-select:disabled {
    background-color: var(--color-background);
    color: var(--color-text-tertiary);
    cursor: not-allowed;
  }

  .autocomplete-container {
    position: relative;
  }

  .input-wrapper {
    position: relative;
    display: flex;
    align-items: center;
  }

  .taxon-input {
    width: 100%;
    padding: 0.5rem 2.25rem 0.5rem 0.75rem;
    font-size: 0.9375rem;
    line-height: 1.5;
    color: var(--color-text-primary);
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.5rem;
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
  }

  .taxon-input::placeholder {
    color: var(--color-text-tertiary);
  }

  .taxon-input:focus {
    outline: none;
    border-color: var(--color-forest-600);
    box-shadow: 0 0 0 3px rgba(30, 126, 75, 0.15);
  }

  .taxon-input:disabled {
    background-color: var(--color-background);
    color: var(--color-text-tertiary);
    cursor: not-allowed;
  }

  .clear-button {
    position: absolute;
    right: 0.5rem;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 1.5rem;
    height: 1.5rem;
    padding: 0;
    color: var(--color-text-tertiary);
    background: none;
    border: none;
    border-radius: 0.25rem;
    cursor: pointer;
    transition: color 0.15s ease, background-color 0.15s ease;
  }

  .clear-button:hover {
    color: var(--color-text-primary);
    background-color: var(--color-border-light);
  }

  .suggestions-list {
    position: absolute;
    top: calc(100% + 4px);
    left: 0;
    right: 0;
    z-index: 50;
    max-height: 15rem;
    overflow-y: auto;
    margin: 0;
    padding: 0.25rem;
    list-style: none;
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.5rem;
    box-shadow: var(--shadow-lg);
  }

  .suggestion-item {
    padding: 0.5rem 0.75rem;
    font-size: 0.9375rem;
    color: var(--color-text-primary);
    border-radius: 0.375rem;
    cursor: pointer;
    transition: background-color 0.1s ease;
  }

  .suggestion-item:hover,
  .suggestion-item.active {
    background-color: var(--color-forest-50);
    color: var(--color-forest-800);
  }

  .suggestion-item.loading,
  .suggestion-item.empty {
    color: var(--color-text-tertiary);
    font-style: italic;
    cursor: default;
  }

  .suggestion-item.loading:hover,
  .suggestion-item.empty:hover {
    background-color: transparent;
    color: var(--color-text-tertiary);
  }
</style>
