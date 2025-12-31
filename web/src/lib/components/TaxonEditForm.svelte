<script>
  import EditModal from './EditModal.svelte';
  import FieldSection from './FieldSection.svelte';
  import { canEdit, getCannotEditReason } from '$lib/stores/authStore.js';

  /**
   * TaxonEditForm - Form for editing taxon data
   *
   * Uses EditModal as wrapper. Fields match the taxa table:
   * - name (text, required)
   * - level (select, readonly - cannot change level)
   * - parent (text)
   * - author (text)
   * - notes (textarea)
   * - links (array of strings)
   */

  /** @type {Object} Taxon data for pre-fill */
  export let taxon;
  /** @type {boolean} Whether the modal is open */
  export let isOpen = false;
  /** @type {() => void} Handler called when modal should close */
  export let onClose;
  /** @type {(data: Object) => Promise<any>} Handler called with form data when save completes */
  export let onSave;

  // Form state - initialized from taxon prop
  let formData = {
    name: '',
    level: '',
    parent: '',
    author: '',
    notes: '',
    links: []
  };

  // Links as newline-separated text for easier editing
  let linksText = '';

  // Track saving state
  let isSaving = false;

  // Validation errors
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

  // Initialize form when taxon changes or modal opens
  $: if (isOpen && taxon) {
    initializeForm();
  }

  function initializeForm() {
    formData = {
      name: taxon.name || '',
      level: taxon.level || '',
      parent: taxon.parent || '',
      author: taxon.author || '',
      notes: taxon.notes || '',
      links: [...(taxon.links || [])]
    };
    linksText = formData.links.join('\n');
    errors = {};
  }

  // Parse links from text
  function parseLinks(text) {
    return text
      .split('\n')
      .map(line => line.trim())
      .filter(line => line.length > 0);
  }

  // Sync linksText to formData
  $: formData.links = parseLinks(linksText);

  function validate() {
    const newErrors = {};

    // Name is required
    if (!formData.name || !formData.name.trim()) {
      newErrors.name = 'Name is required';
    }

    // Validate URLs if any links provided
    for (const link of formData.links) {
      try {
        new URL(link);
      } catch {
        newErrors.links = 'Please enter valid URLs (one per line)';
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
  title="Edit {getLevelLabel(taxon?.level)}: {taxon?.name}"
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
        <label for="taxon-level" class="field-label">Level</label>
        <input
          id="taxon-level"
          type="text"
          class="field-input"
          value={getLevelLabel(formData.level)}
          disabled
        />
        <p class="field-hint">Taxon level cannot be changed</p>
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
        />
        {#if errors.name}
          <p class="error-message">{errors.name}</p>
        {/if}
      </div>

      <div class="field">
        <label for="taxon-parent" class="field-label">Parent</label>
        <input
          id="taxon-parent"
          type="text"
          class="field-input"
          class:error={errors.parent}
          bind:value={formData.parent}
          placeholder="Parent taxon name (optional)"
        />
        {#if errors.parent}
          <p class="error-message">{errors.parent}</p>
        {/if}
      </div>

      <div class="field">
        <label for="taxon-author" class="field-label">Author</label>
        <input
          id="taxon-author"
          type="text"
          class="field-input"
          class:error={errors.author}
          bind:value={formData.author}
          placeholder="e.g., (DC.) A.Camus"
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
        ></textarea>
        {#if errors.notes}
          <p class="error-message">{errors.notes}</p>
        {/if}
      </div>

      <div class="field">
        <label for="taxon-links" class="field-label">Links</label>
        <p class="field-hint">One URL per line</p>
        <textarea
          id="taxon-links"
          class="field-textarea"
          class:error={errors.links}
          bind:value={linksText}
          placeholder="https://example.com/taxon-info&#10;https://another-source.org/details"
          rows="3"
        ></textarea>
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
  .field-textarea:focus {
    outline: none;
    border-color: var(--color-forest-600);
    box-shadow: 0 0 0 3px rgba(30, 126, 75, 0.15);
  }

  .field-input.error,
  .field-textarea.error {
    border-color: var(--color-danger, #dc2626);
  }

  .field-input.error:focus,
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
