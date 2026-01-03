<script>
  import EditModal from './EditModal.svelte';
  import FieldSection from './FieldSection.svelte';
  import TaxonSelect from './TaxonSelect.svelte';
  import TagInput from './TagInput.svelte';
  import { searchSpecies } from '$lib/apiClient.js';
  import { canEdit, getCannotEditReason } from '$lib/stores/authStore.js';
  import { MAX_LENGTHS, validateScientificName, validateLength } from '$lib/utils/validation.js';

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

  // Validation errors (from client-side validation or server)
  let errors = {};

  // Track if connection was lost mid-edit
  let connectionLostDuringEdit = false;

  // Watch canEdit - if it becomes false while editing, show warning
  $: if (isOpen && !$canEdit && !connectionLostDuringEdit) {
    connectionLostDuringEdit = true;
  }

  // Reset connection warning when modal reopens with connection available
  $: if (isOpen && $canEdit) {
    connectionLostDuringEdit = false;
  }

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

  // Search species using API (debounced)
  let searchTimeout1 = null;
  let searchTimeout2 = null;

  async function searchParentSpecies(query, targetIndex) {
    if (!query || query.length < 2) {
      if (targetIndex === 1) parent1Suggestions = [];
      else parent2Suggestions = [];
      return;
    }
    try {
      const results = await searchSpecies(query);
      const names = results.slice(0, 8).map(s => s.scientific_name || s.name);
      if (targetIndex === 1) parent1Suggestions = names;
      else parent2Suggestions = names;
    } catch {
      // Silently fail - autocomplete is not critical
    }
  }

  // Debounced reactive search for parent1
  $: {
    if (searchTimeout1) clearTimeout(searchTimeout1);
    if (parent1Query && parent1Query.length >= 2) {
      searchTimeout1 = setTimeout(() => searchParentSpecies(parent1Query, 1), 200);
    } else {
      parent1Suggestions = [];
    }
  }

  // Debounced reactive search for parent2
  $: {
    if (searchTimeout2) clearTimeout(searchTimeout2);
    if (parent2Query && parent2Query.length >= 2) {
      searchTimeout2 = setTimeout(() => searchParentSpecies(parent2Query, 2), 200);
    } else {
      parent2Suggestions = [];
    }
  }

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
    } else {
      // Validate scientific name characters and length
      const nameValidation = validateScientificName(formData.name);
      if (!nameValidation.valid) {
        newErrors.name = nameValidation.message;
      }
    }

    // Validate author length
    const authorValidation = validateLength(formData.author, MAX_LENGTHS.author);
    if (!authorValidation.valid) {
      newErrors.author = authorValidation.message;
    }

    // If hybrid, should have at least one parent
    if (formData.is_hybrid && !formData.parent1 && !formData.parent2) {
      newErrors.parents = 'At least one parent is recommended for hybrids';
    }

    errors = newErrors;
    return Object.keys(newErrors).length === 0;
  }

  // Map API field names to form field names
  function mapApiFieldToFormField(apiField) {
    const fieldMap = {
      'scientific_name': 'name',
      'conservation_status': 'conservation_status',
      'is_hybrid': 'is_hybrid',
      'author': 'author',
      'subgenus': 'taxonomy.subgenus',
      'section': 'taxonomy.section',
      'subsection': 'taxonomy.subsection',
      'complex': 'taxonomy.complex',
      'parent1': 'parent1',
      'parent2': 'parent2',
      'hybrids': 'hybrids',
      'closely_related_to': 'closely_related_to',
      'synonyms': 'synonyms',
      'subspecies_varieties': 'subspecies_varieties'
    };
    return fieldMap[apiField] || apiField;
  }

  // Convert API field errors to form errors object
  function mapFieldErrors(fieldErrors) {
    const mapped = {};
    for (const error of fieldErrors) {
      const formField = mapApiFieldToFormField(error.field);
      // Use the first error for each field
      if (!mapped[formField]) {
        mapped[formField] = error.message;
      }
    }
    return mapped;
  }

  async function handleSave() {
    if (!validate()) {
      return;
    }

    // Check connection before saving
    if (!$canEdit) {
      return;
    }

    isSaving = true;
    try {
      // Parent's onSave returns field errors array on 400, or null on success
      const fieldErrors = await onSave(formData);

      if (fieldErrors && fieldErrors.length > 0) {
        // Map API field errors to form errors
        errors = mapFieldErrors(fieldErrors);
        return; // Don't close modal - keep showing errors
      }

      // Success - close modal
      onClose();
    } catch (error) {
      // Error already handled by parent (toast shown)
      // Modal stays open so user can retry
      console.error('Failed to save species:', error);
    } finally {
      isSaving = false;
    }
  }

  // Modal title based on mode
  $: modalTitle = species
    ? `Edit Species: Quercus ${species.name}`
    : 'Create New Species';

  /**
   * Prevents Enter from submitting the form when pressed in text fields.
   * Allows Enter in buttons (to trigger their action), textareas (for line breaks),
   * and in cases where the event was already handled (e.g., autocomplete selection).
   * @param {KeyboardEvent} event
   */
  function handleFormKeydown(event) {
    if (event.key === 'Enter') {
      const target = event.target;
      // Allow Enter on buttons and submit inputs
      if (target.tagName === 'BUTTON' || target.type === 'submit') {
        return;
      }
      // Allow Enter in textareas (for line breaks)
      if (target.tagName === 'TEXTAREA') {
        return;
      }
      // Prevent Enter from submitting form in text fields
      event.preventDefault();
    }
  }
</script>

<EditModal
  title={modalTitle}
  {isOpen}
  {isSaving}
  {onClose}
  onSave={handleSave}
>
  <!-- Connection warning banner -->
  {#if connectionLostDuringEdit}
    <div class="connection-warning" role="alert">
      <svg class="warning-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
        <line x1="12" y1="9" x2="12" y2="13" />
        <line x1="12" y1="17" x2="12.01" y2="17" />
      </svg>
      <span>Connection lost. Your changes are preserved.</span>
    </div>
  {/if}

  <form class="species-form" onsubmit={(e) => { e.preventDefault(); handleSave(); }} onkeydown={handleFormKeydown}>
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
            maxlength={MAX_LENGTHS.scientific_name}
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
          class:error={errors.author}
          bind:value={formData.author}
          placeholder="e.g., L. 1753"
          maxlength={MAX_LENGTHS.author}
        />
        {#if errors.author}
          <p class="error-message">{errors.author}</p>
        {/if}
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
                oninput={handleParent1Input}
                onkeydown={handleParent1Keydown}
                onfocus={() => parent1Open = true}
                onblur={() => setTimeout(() => { parent1Open = false; }, 150)}
              />
              {#if parent1Query}
                <button
                  type="button"
                  class="clear-button"
                  aria-label="Clear parent 1"
                  onclick={clearParent1}
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
                    onmousedown={(e) => { e.preventDefault(); selectParent1(suggestion); }}
                    onmouseenter={() => activeParent1Index = index}
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
                oninput={handleParent2Input}
                onkeydown={handleParent2Keydown}
                onfocus={() => parent2Open = true}
                onblur={() => setTimeout(() => { parent2Open = false; }, 150)}
              />
              {#if parent2Query}
                <button
                  type="button"
                  class="clear-button"
                  aria-label="Clear parent 2"
                  onclick={clearParent2}
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
                    onmousedown={(e) => { e.preventDefault(); selectParent2(suggestion); }}
                    onmouseenter={() => activeParent2Index = index}
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

  <!-- Custom footer with connection-aware Save button -->
  <svelte:fragment slot="footer">
    <button
      type="button"
      class="btn btn-secondary"
      disabled={isSaving}
      onclick={onClose}
    >
      Cancel
    </button>
    <button
      type="button"
      class="btn btn-primary"
      disabled={isSaving || !$canEdit}
      title={!$canEdit ? getCannotEditReason() : ''}
      onclick={handleSave}
    >
      {#if isSaving}
        <span class="btn-spinner"></span>
        <span>Saving...</span>
      {:else}
        Save
      {/if}
    </button>
  </svelte:fragment>
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

  .clear-button:focus-visible {
    outline: 2px solid var(--color-forest-600);
    outline-offset: 1px;
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

  /* Connection warning banner */
  .connection-warning {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1rem;
    margin-bottom: 1rem;
    font-size: 0.875rem;
    color: #92400e;
    background-color: #fef3c7;
    border: 1px solid #fcd34d;
    border-radius: 0.5rem;
  }

  .warning-icon {
    flex-shrink: 0;
    color: #f59e0b;
  }

  /* Footer button styles (matching EditModal) */
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
    transition: background-color 0.15s ease, border-color 0.15s ease, color 0.15s ease;
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

  /* Spinner for save button */
  .btn-spinner {
    display: inline-block;
    width: 1rem;
    height: 1rem;
    border: 2px solid transparent;
    border-top-color: currentColor;
    border-radius: 50%;
    animation: spin 0.6s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  /* Mobile: Larger touch targets and better UX */
  @media (max-width: 640px) {
    .field-input,
    .field-select {
      /* Prevent zoom on iOS */
      font-size: 1rem;
      min-height: 2.75rem;
      padding: 0.625rem 0.75rem;
    }

    .input-wrapper .field-input {
      padding-right: 2.75rem;
    }

    .clear-button {
      /* Minimum 44x44px touch target */
      width: 2.75rem;
      height: 2.75rem;
      right: 0.25rem;
    }

    .clear-button svg {
      width: 18px;
      height: 18px;
    }

    .suggestion-item {
      /* Minimum 44px height for touch */
      min-height: 2.75rem;
      padding: 0.75rem;
      font-size: 1rem;
      display: flex;
      align-items: center;
    }

    .suggestions-list {
      padding: 0.375rem;
    }

    /* Larger checkbox touch target */
    .checkbox-label {
      min-height: 2.75rem;
      padding: 0.5rem 0;
    }

    .checkbox-input {
      width: 1.5rem;
      height: 1.5rem;
    }

    .checkbox-text {
      font-size: 1rem;
    }

    /* Genus prefix stays visible but wraps better */
    .name-input-wrapper {
      flex-wrap: wrap;
    }

    .genus-prefix {
      font-size: 1rem;
    }

    /* Footer buttons take more space on mobile */
    .btn {
      min-height: 3rem;
      padding: 0.75rem 1.25rem;
      font-size: 1rem;
    }

    /* Connection warning */
    .connection-warning {
      font-size: 0.9375rem;
      padding: 0.875rem 1rem;
    }
  }
</style>
