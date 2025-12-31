<script>
  import EditModal from './EditModal.svelte';
  import FieldSection from './FieldSection.svelte';
  import TaxonSelect from './TaxonSelect.svelte';
  import TagInput from './TagInput.svelte';
  import { allSpecies } from '$lib/stores/dataStore.js';

  /**
   * SpeciesEditForm - Full species editing form using EditModal as wrapper
   *
   * Props:
   * - species: Species object for edit mode (null for create mode)
   * - onSave: Callback with form data when save completes
   * - onClose: Callback when modal closes
   */

  /** @type {Object|null} Species object to edit (null for create mode) */
  export let species = null;
  /** @type {boolean} Whether the modal is open */
  export let isOpen = false;
  /** @type {() => void} Handler called when modal should close */
  export let onClose;
  /** @type {(data: Object) => Promise<void>} Handler called with form data when save completes */
  export let onSave;

  // Conservation status options per IUCN Red List
  const CONSERVATION_STATUSES = [
    { value: '', label: 'Select status...' },
    { value: 'NE', label: 'NE - Not Evaluated' },
    { value: 'DD', label: 'DD - Data Deficient' },
    { value: 'LC', label: 'LC - Least Concern' },
    { value: 'NT', label: 'NT - Near Threatened' },
    { value: 'VU', label: 'VU - Vulnerable' },
    { value: 'EN', label: 'EN - Endangered' },
    { value: 'CR', label: 'CR - Critically Endangered' },
    { value: 'EW', label: 'EW - Extinct in the Wild' },
    { value: 'EX', label: 'EX - Extinct' }
  ];

  // Form state - initialized from species prop or defaults
  let formData = {
    name: '',
    author: '',
    is_hybrid: false,
    conservation_status: '',
    taxonomy: {
      subgenus: '',
      section: '',
      subsection: '',
      complex: ''
    },
    parent1: '',
    parent2: '',
    hybrids: [],
    closely_related_to: [],
    synonyms: [],
    subspecies_varieties: []
  };

  // Track saving state
  let isSaving = false;

  // Validation errors
  let errors = {};

  // Species autocomplete state for hybrid parents
  let parent1Query = '';
  let parent2Query = '';
  let parent1Suggestions = [];
  let parent2Suggestions = [];
  let parent1Open = false;
  let parent2Open = false;
  let activeParent1Index = -1;
  let activeParent2Index = -1;

  // Initialize form when species changes
  $: if (isOpen) {
    initializeForm();
  }

  function initializeForm() {
    if (species) {
      // Edit mode - populate from species
      formData = {
        name: species.name || '',
        author: species.author || '',
        is_hybrid: species.is_hybrid || false,
        conservation_status: species.conservation_status || '',
        taxonomy: {
          subgenus: species.taxonomy?.subgenus || '',
          section: species.taxonomy?.section || '',
          subsection: species.taxonomy?.subsection || '',
          complex: species.taxonomy?.complex || ''
        },
        parent1: species.parent1 || '',
        parent2: species.parent2 || '',
        hybrids: [...(species.hybrids || [])],
        closely_related_to: [...(species.closely_related_to || [])],
        // Handle synonyms as strings (extract name if object)
        synonyms: (species.synonyms || []).map(s => typeof s === 'string' ? s : s.name),
        subspecies_varieties: [...(species.subspecies_varieties || [])]
      };
      parent1Query = species.parent1 || '';
      parent2Query = species.parent2 || '';
    } else {
      // Create mode - reset to defaults
      formData = {
        name: '',
        author: '',
        is_hybrid: false,
        conservation_status: '',
        taxonomy: {
          subgenus: '',
          section: '',
          subsection: '',
          complex: ''
        },
        parent1: '',
        parent2: '',
        hybrids: [],
        closely_related_to: [],
        synonyms: [],
        subspecies_varieties: []
      };
      parent1Query = '';
      parent2Query = '';
    }
    errors = {};
  }

  // Filter species suggestions based on query
  function filterSpecies(query) {
    if (!query || query.length < 2) return [];
    const q = query.toLowerCase();
    return $allSpecies
      .filter(s => s.name.toLowerCase().includes(q))
      .slice(0, 8)
      .map(s => s.name);
  }

  $: parent1Suggestions = filterSpecies(parent1Query);
  $: parent2Suggestions = filterSpecies(parent2Query);

  function selectParent1(name) {
    formData.parent1 = name;
    parent1Query = name;
    parent1Open = false;
    activeParent1Index = -1;
  }

  function selectParent2(name) {
    formData.parent2 = name;
    parent2Query = name;
    parent2Open = false;
    activeParent2Index = -1;
  }

  function handleParent1Keydown(event) {
    if (!parent1Open && event.key !== 'Escape') {
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        parent1Open = true;
        event.preventDefault();
        return;
      }
    }

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        if (parent1Suggestions.length > 0) {
          activeParent1Index = (activeParent1Index + 1) % parent1Suggestions.length;
        }
        break;
      case 'ArrowUp':
        event.preventDefault();
        if (parent1Suggestions.length > 0) {
          activeParent1Index = activeParent1Index <= 0 ? parent1Suggestions.length - 1 : activeParent1Index - 1;
        }
        break;
      case 'Enter':
        event.preventDefault();
        if (activeParent1Index >= 0 && activeParent1Index < parent1Suggestions.length) {
          selectParent1(parent1Suggestions[activeParent1Index]);
        } else {
          parent1Open = false;
          formData.parent1 = parent1Query;
        }
        break;
      case 'Escape':
        event.preventDefault();
        parent1Open = false;
        activeParent1Index = -1;
        break;
      case 'Tab':
        parent1Open = false;
        formData.parent1 = parent1Query;
        break;
    }
  }

  function handleParent2Keydown(event) {
    if (!parent2Open && event.key !== 'Escape') {
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        parent2Open = true;
        event.preventDefault();
        return;
      }
    }

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        if (parent2Suggestions.length > 0) {
          activeParent2Index = (activeParent2Index + 1) % parent2Suggestions.length;
        }
        break;
      case 'ArrowUp':
        event.preventDefault();
        if (parent2Suggestions.length > 0) {
          activeParent2Index = activeParent2Index <= 0 ? parent2Suggestions.length - 1 : activeParent2Index - 1;
        }
        break;
      case 'Enter':
        event.preventDefault();
        if (activeParent2Index >= 0 && activeParent2Index < parent2Suggestions.length) {
          selectParent2(parent2Suggestions[activeParent2Index]);
        } else {
          parent2Open = false;
          formData.parent2 = parent2Query;
        }
        break;
      case 'Escape':
        event.preventDefault();
        parent2Open = false;
        activeParent2Index = -1;
        break;
      case 'Tab':
        parent2Open = false;
        formData.parent2 = parent2Query;
        break;
    }
  }

  function handleParent1Input(event) {
    parent1Query = event.target.value;
    formData.parent1 = parent1Query;
    parent1Open = true;
    activeParent1Index = -1;
  }

  function handleParent2Input(event) {
    parent2Query = event.target.value;
    formData.parent2 = parent2Query;
    parent2Open = true;
    activeParent2Index = -1;
  }

  function clearParent1() {
    parent1Query = '';
    formData.parent1 = '';
    parent1Open = false;
  }

  function clearParent2() {
    parent2Query = '';
    formData.parent2 = '';
    parent2Open = false;
  }

  function validate() {
    const newErrors = {};

    // Required: scientific_name
    if (!formData.name.trim()) {
      newErrors.name = 'Species name is required';
    }

    // If hybrid, should have at least one parent
    if (formData.is_hybrid && !formData.parent1 && !formData.parent2) {
      newErrors.parents = 'At least one parent is recommended for hybrids';
    }

    errors = newErrors;
    return Object.keys(newErrors).length === 0;
  }

  async function handleSave() {
    if (!validate()) {
      return;
    }

    isSaving = true;
    try {
      await onSave(formData);
      onClose();
    } catch (error) {
      console.error('Failed to save species:', error);
      // Error handling could be enhanced with toast notification
    } finally {
      isSaving = false;
    }
  }

  // Modal title based on mode
  $: modalTitle = species
    ? `Edit Species: Quercus ${species.name}`
    : 'Create New Species';
</script>

<EditModal
  title={modalTitle}
  {isOpen}
  {isSaving}
  {onClose}
  onSave={handleSave}
>
  <form class="species-form" on:submit|preventDefault={handleSave}>
    <!-- Section 1: Core Information -->
    <FieldSection title="Core Information">
      <!-- Scientific Name (required) -->
      <div class="field">
        <label for="species-name" class="field-label">
          Scientific Name <span class="required">*</span>
        </label>
        <div class="name-input-wrapper">
          <span class="genus-prefix">Quercus</span>
          <input
            id="species-name"
            type="text"
            class="field-input name-input"
            class:error={errors.name}
            bind:value={formData.name}
            placeholder="e.g., alba"
            required
          />
        </div>
        {#if errors.name}
          <p class="error-message">{errors.name}</p>
        {/if}
      </div>

      <!-- Author -->
      <div class="field">
        <label for="species-author" class="field-label">Author</label>
        <input
          id="species-author"
          type="text"
          class="field-input"
          bind:value={formData.author}
          placeholder="e.g., L. 1753"
        />
      </div>

      <!-- Is Hybrid checkbox -->
      <div class="field field-checkbox">
        <label class="checkbox-label">
          <input
            type="checkbox"
            class="checkbox-input"
            bind:checked={formData.is_hybrid}
          />
          <span class="checkbox-text">This is a hybrid</span>
        </label>
      </div>

      <!-- Conservation Status -->
      <div class="field">
        <label for="conservation-status" class="field-label">Conservation Status</label>
        <select
          id="conservation-status"
          class="field-select"
          bind:value={formData.conservation_status}
        >
          {#each CONSERVATION_STATUSES as status}
            <option value={status.value}>{status.label}</option>
          {/each}
        </select>
      </div>
    </FieldSection>

    <!-- Section 2: Taxonomy -->
    <FieldSection title="Taxonomy">
      <div class="field">
        <label id="subgenus-label" class="field-label">Subgenus</label>
        <TaxonSelect
          level="subgenus"
          bind:value={formData.taxonomy.subgenus}
          labelledBy="subgenus-label"
        />
      </div>

      <div class="field">
        <label id="section-label" class="field-label">Section</label>
        <TaxonSelect
          level="section"
          bind:value={formData.taxonomy.section}
          parentTaxon={formData.taxonomy.subgenus}
          labelledBy="section-label"
        />
      </div>

      <div class="field">
        <label id="subsection-label" class="field-label">Subsection</label>
        <TaxonSelect
          level="subsection"
          bind:value={formData.taxonomy.subsection}
          parentTaxon={formData.taxonomy.section}
          labelledBy="subsection-label"
        />
      </div>

      <div class="field">
        <label id="complex-label" class="field-label">Complex</label>
        <TaxonSelect
          level="complex"
          bind:value={formData.taxonomy.complex}
          labelledBy="complex-label"
        />
      </div>
    </FieldSection>

    <!-- Section 3: Hybrid Parents (shown only when is_hybrid is true) -->
    {#if formData.is_hybrid}
      <FieldSection title="Hybrid Parents">
        {#if errors.parents}
          <p class="warning-message">{errors.parents}</p>
        {/if}

        <!-- Parent 1 -->
        <div class="field">
          <label id="parent1-label" class="field-label">Parent 1</label>
          <div class="autocomplete-container">
            <div class="input-wrapper">
              <input
                type="text"
                class="field-input"
                value={parent1Query}
                placeholder="Search species..."
                role="combobox"
                aria-autocomplete="list"
                aria-expanded={parent1Open && parent1Suggestions.length > 0}
                aria-labelledby="parent1-label"
                on:input={handleParent1Input}
                on:keydown={handleParent1Keydown}
                on:focus={() => parent1Open = true}
                on:blur={() => setTimeout(() => { parent1Open = false; }, 150)}
              />
              {#if parent1Query}
                <button
                  type="button"
                  class="clear-button"
                  aria-label="Clear parent 1"
                  on:click={clearParent1}
                >
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                    <line x1="18" y1="6" x2="6" y2="18"></line>
                    <line x1="6" y1="6" x2="18" y2="18"></line>
                  </svg>
                </button>
              {/if}
            </div>
            {#if parent1Open && parent1Suggestions.length > 0}
              <ul class="suggestions-list" role="listbox">
                {#each parent1Suggestions as suggestion, index}
                  <li
                    class="suggestion-item"
                    class:active={index === activeParent1Index}
                    role="option"
                    aria-selected={index === activeParent1Index}
                    on:mousedown|preventDefault={() => selectParent1(suggestion)}
                    on:mouseenter={() => activeParent1Index = index}
                  >
                    Q. {suggestion}
                  </li>
                {/each}
              </ul>
            {/if}
          </div>
        </div>

        <!-- Parent 2 -->
        <div class="field">
          <label id="parent2-label" class="field-label">Parent 2</label>
          <div class="autocomplete-container">
            <div class="input-wrapper">
              <input
                type="text"
                class="field-input"
                value={parent2Query}
                placeholder="Search species..."
                role="combobox"
                aria-autocomplete="list"
                aria-expanded={parent2Open && parent2Suggestions.length > 0}
                aria-labelledby="parent2-label"
                on:input={handleParent2Input}
                on:keydown={handleParent2Keydown}
                on:focus={() => parent2Open = true}
                on:blur={() => setTimeout(() => { parent2Open = false; }, 150)}
              />
              {#if parent2Query}
                <button
                  type="button"
                  class="clear-button"
                  aria-label="Clear parent 2"
                  on:click={clearParent2}
                >
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                    <line x1="18" y1="6" x2="6" y2="18"></line>
                    <line x1="6" y1="6" x2="18" y2="18"></line>
                  </svg>
                </button>
              {/if}
            </div>
            {#if parent2Open && parent2Suggestions.length > 0}
              <ul class="suggestions-list" role="listbox">
                {#each parent2Suggestions as suggestion, index}
                  <li
                    class="suggestion-item"
                    class:active={index === activeParent2Index}
                    role="option"
                    aria-selected={index === activeParent2Index}
                    on:mousedown|preventDefault={() => selectParent2(suggestion)}
                    on:mouseenter={() => activeParent2Index = index}
                  >
                    Q. {suggestion}
                  </li>
                {/each}
              </ul>
            {/if}
          </div>
        </div>
      </FieldSection>
    {/if}

    <!-- Section 4: Relationships -->
    <FieldSection title="Relationships" collapsible collapsed>
      <div class="field">
        <label id="hybrids-label" class="field-label">Hybrids</label>
        <p class="field-hint">Names of hybrid species that involve this species</p>
        <TagInput
          values={formData.hybrids}
          placeholder="Add hybrid name..."
          onChange={(values) => formData.hybrids = values}
        />
      </div>

      <div class="field">
        <label id="related-label" class="field-label">Closely Related To</label>
        <p class="field-hint">Species that are closely related taxonomically</p>
        <TagInput
          values={formData.closely_related_to}
          placeholder="Add related species..."
          onChange={(values) => formData.closely_related_to = values}
        />
      </div>
    </FieldSection>

    <!-- Section 5: Nomenclature -->
    <FieldSection title="Nomenclature" collapsible collapsed>
      <div class="field">
        <label id="synonyms-label" class="field-label">Synonyms</label>
        <p class="field-hint">Alternative scientific names for this species</p>
        <TagInput
          values={formData.synonyms}
          placeholder="Add synonym..."
          onChange={(values) => formData.synonyms = values}
        />
      </div>

      <div class="field">
        <label id="subspecies-label" class="field-label">Subspecies & Varieties</label>
        <p class="field-hint">Infraspecific taxa (subspecies, varieties, forms)</p>
        <TagInput
          values={formData.subspecies_varieties}
          placeholder="Add subspecies or variety..."
          onChange={(values) => formData.subspecies_varieties = values}
        />
      </div>
    </FieldSection>
  </form>
</EditModal>

<style>
  .species-form {
    display: flex;
    flex-direction: column;
  }

  .field {
    display: flex;
    flex-direction: column;
    gap: 0.375rem;
  }

  .field-label {
    font-size: 0.875rem;
    font-weight: 500;
    color: var(--color-text-primary);
  }

  .required {
    color: var(--color-danger, #dc2626);
  }

  .field-hint {
    margin: 0;
    font-size: 0.8125rem;
    color: var(--color-text-tertiary);
  }

  .name-input-wrapper {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .genus-prefix {
    font-size: 0.9375rem;
    font-style: italic;
    color: var(--color-text-secondary);
    white-space: nowrap;
  }

  .name-input {
    flex: 1;
    font-style: italic;
  }

  .field-input,
  .field-select {
    width: 100%;
    padding: 0.5rem 0.75rem;
    font-size: 0.9375rem;
    line-height: 1.5;
    color: var(--color-text-primary);
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.5rem;
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
  }

  .field-input::placeholder {
    color: var(--color-text-tertiary);
  }

  .field-input:focus,
  .field-select:focus {
    outline: none;
    border-color: var(--color-forest-600);
    box-shadow: 0 0 0 3px rgba(30, 126, 75, 0.15);
  }

  .field-input.error {
    border-color: var(--color-danger, #dc2626);
  }

  .field-input.error:focus {
    box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.15);
  }

  .field-select {
    cursor: pointer;
  }

  .error-message {
    margin: 0;
    font-size: 0.8125rem;
    color: var(--color-danger, #dc2626);
  }

  .warning-message {
    margin: 0 0 0.5rem;
    padding: 0.5rem 0.75rem;
    font-size: 0.8125rem;
    color: var(--color-warning-text, #92400e);
    background-color: var(--color-warning-bg, #fef3c7);
    border-radius: 0.375rem;
  }

  /* Checkbox styles */
  .field-checkbox {
    flex-direction: row;
    align-items: center;
  }

  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    cursor: pointer;
  }

  .checkbox-input {
    width: 1.125rem;
    height: 1.125rem;
    accent-color: var(--color-forest-600);
    cursor: pointer;
  }

  .checkbox-text {
    font-size: 0.9375rem;
    color: var(--color-text-primary);
  }

  /* Autocomplete styles (for hybrid parents) */
  .autocomplete-container {
    position: relative;
  }

  .input-wrapper {
    position: relative;
    display: flex;
    align-items: center;
  }

  .input-wrapper .field-input {
    padding-right: 2.25rem;
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
    font-style: italic;
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
</style>
