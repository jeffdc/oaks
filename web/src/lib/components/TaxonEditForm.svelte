<script>
  import { onMount } from 'svelte';
  import EditModal from './EditModal.svelte';
  import FieldSection from './FieldSection.svelte';
  import TagInput from './TagInput.svelte';
  import { fetchTaxa } from '$lib/apiClient.js';
  import { canEdit, getCannotEditReason } from '$lib/stores/authStore.js';
  import { MAX_LENGTHS, validateLength, validateUrl, getCharacterCount } from '$lib/utils/validation.js';

  /**
   * TaxonEditForm - Form for creating and editing taxon data
   *
   * Uses EditModal as wrapper. Fields match the taxa table:
   * - name (text, required)
   * - level (select, editable only in create mode)
   * - parent (TaxonSelect filtered by valid parent levels)
   * - author (text)
   * - notes (textarea)
   * - links (TagInput for URLs)
   *
   * Parent hierarchy rules:
   * - subgenus: no parent
   * - section: parent must be subgenus
   * - subsection: parent must be section
   * - complex: parent must be subsection or section
   *
   * Create mode: Pass taxon=null and optionally defaultLevel
   * Edit mode: Pass existing taxon object
   */

  /** @type {Object|null} Taxon data for pre-fill (null for create mode) */
  export let taxon = null;
  /** @type {string} Default level for create mode (e.g., 'section') */
  export let defaultLevel = 'subgenus';
  /** @type {boolean} Whether the modal is open */
  export let isOpen = false;
  /** @type {() => void} Handler called when modal should close */
  export let onClose;
  /** @type {(data: Object) => Promise<any>} Handler called with form data when save completes */
  export let onSave;

  // Determine if we're in create mode
  $: isCreateMode = !taxon;

  // Available taxon levels for create mode dropdown
  const taxonLevels = [
    { value: 'subgenus', label: 'Subgenus' },
    { value: 'section', label: 'Section' },
    { value: 'subsection', label: 'Subsection' },
    { value: 'complex', label: 'Complex' }
  ];

  // Fixed subgenus values (for parent selection when level is 'section')
  const SUBGENERA = ['Quercus', 'Cerris', 'Cyclobalanopsis'];

  // Form state - initialized from taxon prop
  let formData = {
    name: '',
    level: '',
    parent: '',
    author: '',
    notes: '',
    links: []
  };

  // Track saving state
  let isSaving = false;

  // Validation errors
  let errors = {};

  // Track if connection was lost mid-edit
  let connectionLostDuringEdit = false;

  // All taxa for parent autocomplete
  /** @type {Array<{name: string, level: string, parent?: string}>} */
  let allTaxa = [];

  // Parent autocomplete state
  let parentQuery = '';
  /** @type {Array<string>} */
  let parentSuggestions = [];
  let isParentOpen = false;
  let activeParentIndex = -1;
  /** @type {HTMLInputElement|null} */
  let parentInputElement = null;

  // Watch canEdit - if it becomes false while editing, show warning
  $: if (isOpen && !$canEdit && !connectionLostDuringEdit) {
    connectionLostDuringEdit = true;
  }

  // Reset connection warning when modal reopens with connection available
  $: if (isOpen && $canEdit) {
    connectionLostDuringEdit = false;
  }

  // Initialize form when taxon changes or modal opens
  $: if (isOpen) {
    initializeForm();
  }

  // Load taxa for parent autocomplete
  onMount(async () => {
    try {
      allTaxa = await fetchTaxa();
    } catch (err) {
      console.error('Failed to load taxa:', err);
      allTaxa = [];
    }
  });

  function initializeForm() {
    if (taxon) {
      // Edit mode: populate from existing taxon
      formData = {
        name: taxon.name || '',
        level: taxon.level || '',
        parent: taxon.parent || '',
        author: taxon.author || '',
        notes: taxon.notes || '',
        links: [...(taxon.links || [])]
      };
      parentQuery = taxon.parent || '';
    } else {
      // Create mode: start with empty form
      formData = {
        name: '',
        level: defaultLevel,
        parent: '',
        author: '',
        notes: '',
        links: []
      };
      parentQuery = '';
    }
    errors = {};
    isParentOpen = false;
    activeParentIndex = -1;
  }

  // Get valid parent levels based on current level
  function getValidParentLevels(level) {
    switch (level) {
      case 'subgenus':
        return []; // No parent allowed
      case 'section':
        return ['subgenus'];
      case 'subsection':
        return ['section'];
      case 'complex':
        return ['subsection', 'section'];
      default:
        return [];
    }
  }

  // Check if parent field should be shown
  $: showParentField = formData.level && formData.level !== 'subgenus';

  // Get hint text for parent field
  $: parentHint = (() => {
    switch (formData.level) {
      case 'section':
        return 'Parent must be a subgenus';
      case 'subsection':
        return 'Parent must be a section';
      case 'complex':
        return 'Parent must be a section or subsection';
      default:
        return '';
    }
  })();

  // Filter parent suggestions based on query and valid parent levels
  $: {
    const validLevels = getValidParentLevels(formData.level);
    if (validLevels.length === 0) {
      parentSuggestions = [];
    } else if (validLevels.includes('subgenus')) {
      // For sections, parent is subgenus - use fixed list
      const query = parentQuery.toLowerCase().trim();
      parentSuggestions = SUBGENERA.filter(s =>
        !query || s.toLowerCase().includes(query)
      );
    } else {
      // For subsection/complex, search taxa
      const query = parentQuery.toLowerCase().trim();
      parentSuggestions = allTaxa
        .filter(t => {
          if (!validLevels.includes(t.level)) return false;
          if (!query) return true;
          return t.name.toLowerCase().includes(query);
        })
        .map(t => t.name)
        .sort()
        .slice(0, 10);
    }
  }

  function handleParentInput(event) {
    parentQuery = event.target.value;
    formData.parent = parentQuery;
    isParentOpen = true;
    activeParentIndex = -1;
  }

  function selectParent(name) {
    formData.parent = name;
    parentQuery = name;
    isParentOpen = false;
    activeParentIndex = -1;
    parentInputElement?.focus();
  }

  function clearParent() {
    formData.parent = '';
    parentQuery = '';
    isParentOpen = false;
    activeParentIndex = -1;
    parentInputElement?.focus();
  }

  function handleParentKeydown(event) {
    if (!isParentOpen && event.key !== 'Escape') {
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        isParentOpen = true;
        event.preventDefault();
        return;
      }
    }

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        if (parentSuggestions.length > 0) {
          activeParentIndex = (activeParentIndex + 1) % parentSuggestions.length;
        }
        break;
      case 'ArrowUp':
        event.preventDefault();
        if (parentSuggestions.length > 0) {
          activeParentIndex = activeParentIndex <= 0 ? parentSuggestions.length - 1 : activeParentIndex - 1;
        }
        break;
      case 'Enter':
        event.preventDefault();
        if (activeParentIndex >= 0 && activeParentIndex < parentSuggestions.length) {
          selectParent(parentSuggestions[activeParentIndex]);
        } else {
          isParentOpen = false;
        }
        break;
      case 'Escape':
        event.preventDefault();
        isParentOpen = false;
        activeParentIndex = -1;
        break;
      case 'Tab':
        isParentOpen = false;
        activeParentIndex = -1;
        break;
    }
  }

  function handleParentFocus() {
    isParentOpen = true;
  }

  function handleParentBlur() {
    // Delay close to allow click on suggestions
    setTimeout(() => {
      isParentOpen = false;
      activeParentIndex = -1;
    }, 150);
  }

  // Clear parent when level changes (in create mode)
  function handleLevelChange() {
    if (isCreateMode) {
      formData.parent = '';
      parentQuery = '';
    }
  }

  function validate() {
    const newErrors = {};

    // Name is required
    if (!formData.name || !formData.name.trim()) {
      newErrors.name = 'Name is required';
    } else {
      // Validate name length
      const nameResult = validateLength(formData.name, MAX_LENGTHS.name);
      if (!nameResult.valid) {
        newErrors.name = nameResult.message;
      }
    }

    // Level is required in create mode
    if (isCreateMode && (!formData.level || !formData.level.trim())) {
      newErrors.level = 'Level is required';
    }

    // Validate author length
    const authorResult = validateLength(formData.author, MAX_LENGTHS.author);
    if (!authorResult.valid) {
      newErrors.author = authorResult.message;
    }

    // Validate notes length
    const notesResult = validateLength(formData.notes, MAX_LENGTHS.notes);
    if (!notesResult.valid) {
      newErrors.notes = notesResult.message;
    }

    // Validate URLs if any links provided
    for (const link of formData.links) {
      const urlResult = validateUrl(link);
      if (!urlResult.valid) {
        newErrors.links = urlResult.message;
        break;
      }
    }

    errors = newErrors;
    return Object.keys(newErrors).length === 0;
  }

  // Map API field names to form field names
  function mapApiFieldToFormField(apiField) {
    const fieldMap = {
      'name': 'name',
      'level': 'level',
      'parent': 'parent',
      'author': 'author',
      'notes': 'notes',
      'links': 'links'
    };
    return fieldMap[apiField] || apiField;
  }

  // Convert API field errors to form errors object
  function mapFieldErrors(fieldErrors) {
    const mapped = {};
    for (const error of fieldErrors) {
      const formField = mapApiFieldToFormField(error.field);
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
        errors = mapFieldErrors(fieldErrors);
        return;
      }

      // Success - close modal
      onClose();
    } catch (error) {
      console.error('Failed to save taxon:', error);
    } finally {
      isSaving = false;
    }
  }

  // Get level label for display
  function getLevelLabel(level) {
    const labels = {
      subgenus: 'Subgenus',
      section: 'Section',
      subsection: 'Subsection',
      complex: 'Complex'
    };
    return labels[level] || level;
  }
</script>

<EditModal
  title={isCreateMode ? 'Create Taxon' : `Edit ${getLevelLabel(taxon?.level)}: ${taxon?.name}`}
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

  <form class="taxon-form" on:submit|preventDefault={handleSave}>
    <!-- Section 1: Core Information -->
    <FieldSection title="Core Information">
      <div class="field">
        <label for="taxon-level" class="field-label">Level {#if isCreateMode}<span class="required">*</span>{/if}</label>
        {#if isCreateMode}
          <select
            id="taxon-level"
            class="field-select"
            class:error={errors.level}
            bind:value={formData.level}
            on:change={handleLevelChange}
          >
            <option value="">Select level...</option>
            {#each taxonLevels as level}
              <option value={level.value}>{level.label}</option>
            {/each}
          </select>
          {#if errors.level}
            <p class="error-message">{errors.level}</p>
          {/if}
        {:else}
          <input
            id="taxon-level"
            type="text"
            class="field-input"
            value={getLevelLabel(formData.level)}
            disabled
          />
          <p class="field-hint">Taxon level cannot be changed</p>
        {/if}
      </div>

      <div class="field">
        <label for="taxon-name" class="field-label">Name <span class="required">*</span></label>
        <input
          id="taxon-name"
          type="text"
          class="field-input"
          class:error={errors.name}
          bind:value={formData.name}
          placeholder="Enter taxon name"
          maxlength={MAX_LENGTHS.name}
        />
        {#if errors.name}
          <p class="error-message">{errors.name}</p>
        {/if}
      </div>

      {#if showParentField}
        <div class="field">
          <label for="taxon-parent" class="field-label">Parent</label>
          <p class="field-hint">{parentHint}</p>
          <div class="autocomplete-container">
            <div class="input-wrapper">
              <input
                bind:this={parentInputElement}
                id="taxon-parent"
                type="text"
                class="field-input"
                class:error={errors.parent}
                value={parentQuery}
                placeholder="Search or select parent..."
                role="combobox"
                aria-autocomplete="list"
                aria-expanded={isParentOpen && parentSuggestions.length > 0}
                on:input={handleParentInput}
                on:keydown={handleParentKeydown}
                on:focus={handleParentFocus}
                on:blur={handleParentBlur}
              />
              {#if parentQuery}
                <button
                  type="button"
                  class="clear-button"
                  aria-label="Clear parent"
                  on:click={clearParent}
                >
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                    <line x1="18" y1="6" x2="6" y2="18"></line>
                    <line x1="6" y1="6" x2="18" y2="18"></line>
                  </svg>
                </button>
              {/if}
            </div>
            {#if isParentOpen && parentSuggestions.length > 0}
              <ul class="suggestions-list" role="listbox">
                {#each parentSuggestions as suggestion, index}
                  <li
                    class="suggestion-item"
                    class:active={index === activeParentIndex}
                    role="option"
                    aria-selected={index === activeParentIndex}
                    on:mousedown|preventDefault={() => selectParent(suggestion)}
                    on:mouseenter={() => activeParentIndex = index}
                  >
                    {suggestion}
                  </li>
                {/each}
              </ul>
            {/if}
          </div>
          {#if errors.parent}
            <p class="error-message">{errors.parent}</p>
          {/if}
        </div>
      {/if}

      <div class="field">
        <label for="taxon-author" class="field-label">Author</label>
        <input
          id="taxon-author"
          type="text"
          class="field-input"
          class:error={errors.author}
          bind:value={formData.author}
          placeholder="e.g., (DC.) A.Camus"
          maxlength={MAX_LENGTHS.author}
        />
        {#if errors.author}
          <p class="error-message">{errors.author}</p>
        {/if}
      </div>
    </FieldSection>

    <!-- Section 2: Additional Information -->
    <FieldSection title="Additional Information" collapsible>
      <div class="field">
        <label for="taxon-notes" class="field-label">Notes</label>
        <textarea
          id="taxon-notes"
          class="field-textarea"
          class:error={errors.notes}
          bind:value={formData.notes}
          placeholder="Additional notes about this taxon..."
          rows="4"
          maxlength={MAX_LENGTHS.notes}
        ></textarea>
        <div class="field-footer">
          {#if errors.notes}
            <p class="error-message">{errors.notes}</p>
          {:else}
            <span></span>
          {/if}
          <span class="char-count" class:warning={getCharacterCount(formData.notes, MAX_LENGTHS.notes).remaining < 500}>
            {formData.notes?.length || 0} / {MAX_LENGTHS.notes}
          </span>
        </div>
      </div>

      <div class="field">
        <label id="taxon-links-label" class="field-label">Links</label>
        <p class="field-hint">Press Enter or comma to add URLs</p>
        <TagInput
          values={formData.links}
          placeholder="Add URL..."
          onChange={(values) => formData.links = values}
        />
        {#if errors.links}
          <p class="error-message">{errors.links}</p>
        {/if}
      </div>
    </FieldSection>
  </form>

  <!-- Custom footer with connection-aware Save button -->
  <svelte:fragment slot="footer">
    <button
      type="button"
      class="btn btn-secondary"
      disabled={isSaving}
      on:click={onClose}
    >
      Cancel
    </button>
    <button
      type="button"
      class="btn btn-primary"
      disabled={isSaving || !$canEdit}
      title={!$canEdit ? getCannotEditReason() : ''}
      on:click={handleSave}
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
  .taxon-form {
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
    color: #dc2626;
  }

  .field-hint {
    margin: 0;
    font-size: 0.8125rem;
    color: var(--color-text-tertiary);
  }

  .field-input,
  .field-select,
  .field-textarea {
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

  .field-select {
    cursor: pointer;
  }

  .field-input:disabled {
    background-color: var(--color-background);
    color: var(--color-text-secondary);
    cursor: not-allowed;
  }

  .field-input::placeholder,
  .field-textarea::placeholder {
    color: var(--color-text-tertiary);
  }

  .field-input:focus,
  .field-select:focus,
  .field-textarea:focus {
    outline: none;
    border-color: var(--color-forest-600);
    box-shadow: 0 0 0 3px rgba(30, 126, 75, 0.15);
  }

  .field-input.error,
  .field-select.error,
  .field-textarea.error {
    border-color: var(--color-danger, #dc2626);
  }

  .field-input.error:focus,
  .field-select.error:focus,
  .field-textarea.error:focus {
    box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.15);
  }

  .field-textarea {
    resize: vertical;
    min-height: 4rem;
    font-family: inherit;
  }

  .error-message {
    margin: 0;
    font-size: 0.8125rem;
    color: var(--color-danger, #dc2626);
  }

  .field-footer {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 0.5rem;
  }

  .char-count {
    font-size: 0.75rem;
    color: var(--color-text-tertiary);
    white-space: nowrap;
    flex-shrink: 0;
  }

  .char-count.warning {
    color: var(--color-warning-text, #b45309);
  }

  /* Autocomplete styles for parent field */
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
</style>
