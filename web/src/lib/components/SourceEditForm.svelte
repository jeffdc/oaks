<script>
  import EditModal from './EditModal.svelte';
  import FieldSection from './FieldSection.svelte';
  import { canEdit, getCannotEditReason } from '$lib/stores/authStore.js';
  import { MAX_LENGTHS, validateLength, validateUrl, getCharacterCount } from '$lib/utils/validation.js';

  /**
   * SourceEditForm - Form for editing source metadata
   *
   * Uses EditModal as wrapper. Fields match the sources table:
   * - name (text, required)
   * - source_type (select)
   * - author (text)
   * - year (number)
   * - url (text/url)
   * - isbn (text)
   * - doi (text)
   * - description (textarea)
   * - notes (textarea)
   * - license (text)
   * - license_url (text/url)
   */

  /** @type {Object|null} Source data for pre-fill */
  export let source = null;
  /** @type {boolean} Whether the modal is open */
  export let isOpen = false;
  /** @type {() => void} Handler called when modal should close */
  export let onClose;
  /** @type {(data: Object) => Promise<any>} Handler called with form data when save completes */
  export let onSave;

  // Available source types
  const sourceTypes = [
    { value: 'Website', label: 'Website' },
    { value: 'Book', label: 'Book' },
    { value: 'Personal Observation', label: 'Personal Observation' },
    { value: 'Database', label: 'Database' }
  ];

  // Form state - initialized from source prop
  let formData = {
    name: '',
    source_type: '',
    author: '',
    year: null,
    url: '',
    isbn: '',
    doi: '',
    description: '',
    notes: '',
    license: '',
    license_url: ''
  };

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

  // Initialize form when source changes or modal opens
  $: if (isOpen) {
    initializeForm();
  }

  function initializeForm() {
    if (source) {
      formData = {
        name: source.source_name || source.name || '',
        source_type: source.source_type || '',
        author: source.author || '',
        year: source.year || null,
        url: source.source_url || source.url || '',
        isbn: source.isbn || '',
        doi: source.doi || '',
        description: source.description || '',
        notes: source.notes || '',
        license: source.license || '',
        license_url: source.license_url || ''
      };
    } else {
      formData = {
        name: '',
        source_type: '',
        author: '',
        year: null,
        url: '',
        isbn: '',
        doi: '',
        description: '',
        notes: '',
        license: '',
        license_url: ''
      };
    }
    errors = {};
  }

  /**
   * Validate DOI format (10.xxxx/xxxxx pattern)
   * @param {string} doi - DOI to validate
   * @returns {boolean} True if valid or empty
   */
  function isValidDoi(doi) {
    if (!doi || !doi.trim()) return true;
    // DOI pattern: 10.xxxx/xxxxx where xxxx is 4+ digits and xxxxx is suffix
    const doiPattern = /^10\.\d{4,}\/\S+$/;
    return doiPattern.test(doi.trim());
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

    // Validate author length
    const authorResult = validateLength(formData.author, MAX_LENGTHS.author);
    if (!authorResult.valid) {
      newErrors.author = authorResult.message;
    }

    // Validate URL if provided (format and length)
    const urlResult = validateUrl(formData.url);
    if (!urlResult.valid) {
      newErrors.url = urlResult.message;
    }

    // Validate license URL if provided
    const licenseUrlResult = validateUrl(formData.license_url);
    if (!licenseUrlResult.valid) {
      newErrors.license_url = licenseUrlResult.message;
    }

    // Validate license length
    const licenseResult = validateLength(formData.license, MAX_LENGTHS.license);
    if (!licenseResult.valid) {
      newErrors.license = licenseResult.message;
    }

    // Validate description length
    const descResult = validateLength(formData.description, MAX_LENGTHS.description);
    if (!descResult.valid) {
      newErrors.description = descResult.message;
    }

    // Validate notes length
    const notesResult = validateLength(formData.notes, MAX_LENGTHS.notes);
    if (!notesResult.valid) {
      newErrors.notes = notesResult.message;
    }

    // Validate DOI format if provided
    if (!isValidDoi(formData.doi)) {
      newErrors.doi = 'Please enter a valid DOI (e.g., 10.1234/example)';
    }

    // Validate year if provided
    if (formData.year !== null && formData.year !== '') {
      const year = parseInt(formData.year, 10);
      if (isNaN(year) || year < 1500 || year > new Date().getFullYear() + 1) {
        newErrors.year = 'Please enter a valid year';
      }
    }

    errors = newErrors;
    return Object.keys(newErrors).length === 0;
  }

  // Map API field names to form field names
  function mapApiFieldToFormField(apiField) {
    const fieldMap = {
      'name': 'name',
      'source_type': 'source_type',
      'author': 'author',
      'year': 'year',
      'url': 'url',
      'isbn': 'isbn',
      'doi': 'doi',
      'description': 'description',
      'notes': 'notes',
      'license': 'license',
      'license_url': 'license_url'
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

  async function handleSave(event) {
    if (event) event.preventDefault();
    if (!validate()) {
      return;
    }

    // Check connection before saving
    if (!$canEdit) {
      return;
    }

    isSaving = true;
    try {
      // Prepare data for API
      const apiData = {
        name: formData.name.trim(),
        source_type: formData.source_type || null,
        author: formData.author.trim() || null,
        year: formData.year ? parseInt(formData.year, 10) : null,
        url: formData.url.trim() || null,
        isbn: formData.isbn.trim() || null,
        doi: formData.doi.trim() || null,
        description: formData.description.trim() || null,
        notes: formData.notes.trim() || null,
        license: formData.license.trim() || null,
        license_url: formData.license_url.trim() || null
      };

      // Parent's onSave returns field errors array on 400, or null on success
      const fieldErrors = await onSave(apiData);

      if (fieldErrors && fieldErrors.length > 0) {
        errors = mapFieldErrors(fieldErrors);
        return;
      }

      // Success - close modal
      onClose();
    } catch (error) {
      console.error('Failed to save source:', error);
    } finally {
      isSaving = false;
    }
  }

  /**
   * Prevents Enter from submitting the form when pressed in text fields.
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
  title={source ? `Edit Source: ${source.source_name || source.name}` : 'Create Source'}
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

  <form class="source-form" onsubmit={handleSave} onkeydown={handleFormKeydown}>
    <!-- Section 1: Core Information -->
    <FieldSection title="Core Information">
      <div class="field">
        <label for="source-name" class="field-label">Name <span class="required">*</span></label>
        <input
          id="source-name"
          type="text"
          class="field-input"
          class:error={errors.name}
          bind:value={formData.name}
          placeholder="Enter source name"
          maxlength={MAX_LENGTHS.name}
        />
        {#if errors.name}
          <p class="error-message">{errors.name}</p>
        {/if}
      </div>

      <div class="field">
        <label for="source-type" class="field-label">Type</label>
        <select
          id="source-type"
          class="field-select"
          class:error={errors.source_type}
          bind:value={formData.source_type}
        >
          <option value="">Select type...</option>
          {#each sourceTypes as type}
            <option value={type.value}>{type.label}</option>
          {/each}
        </select>
        {#if errors.source_type}
          <p class="error-message">{errors.source_type}</p>
        {/if}
      </div>

      <div class="field">
        <label for="source-url" class="field-label">URL</label>
        <input
          id="source-url"
          type="url"
          class="field-input"
          class:error={errors.url}
          bind:value={formData.url}
          placeholder="https://example.com"
          maxlength={MAX_LENGTHS.url}
        />
        {#if errors.url}
          <p class="error-message">{errors.url}</p>
        {/if}
      </div>
    </FieldSection>

    <!-- Section 2: Attribution -->
    <FieldSection title="Attribution" collapsible>
      <div class="field">
        <label for="source-author" class="field-label">Author</label>
        <input
          id="source-author"
          type="text"
          class="field-input"
          class:error={errors.author}
          bind:value={formData.author}
          placeholder="e.g., John Smith"
          maxlength={MAX_LENGTHS.author}
        />
        {#if errors.author}
          <p class="error-message">{errors.author}</p>
        {/if}
      </div>

      <div class="field">
        <label for="source-year" class="field-label">Year</label>
        <input
          id="source-year"
          type="number"
          class="field-input"
          class:error={errors.year}
          bind:value={formData.year}
          placeholder="e.g., 2023"
          min="1500"
          max={new Date().getFullYear() + 1}
        />
        {#if errors.year}
          <p class="error-message">{errors.year}</p>
        {/if}
      </div>

      <div class="field-row">
        <div class="field">
          <label for="source-isbn" class="field-label">ISBN</label>
          <input
            id="source-isbn"
            type="text"
            class="field-input"
            class:error={errors.isbn}
            bind:value={formData.isbn}
            placeholder="e.g., 978-0-123456-78-9"
          />
          {#if errors.isbn}
            <p class="error-message">{errors.isbn}</p>
          {/if}
        </div>

        <div class="field">
          <label for="source-doi" class="field-label">DOI</label>
          <input
            id="source-doi"
            type="text"
            class="field-input"
            class:error={errors.doi}
            bind:value={formData.doi}
            placeholder="e.g., 10.1000/xyz123"
          />
          {#if errors.doi}
            <p class="error-message">{errors.doi}</p>
          {/if}
        </div>
      </div>
    </FieldSection>

    <!-- Section 3: License -->
    <FieldSection title="License" collapsible collapsed>
      <div class="field">
        <label for="source-license" class="field-label">License</label>
        <input
          id="source-license"
          type="text"
          class="field-input"
          class:error={errors.license}
          bind:value={formData.license}
          placeholder="e.g., CC BY 4.0"
          maxlength={MAX_LENGTHS.license}
        />
        {#if errors.license}
          <p class="error-message">{errors.license}</p>
        {/if}
      </div>

      <div class="field">
        <label for="source-license-url" class="field-label">License URL</label>
        <input
          id="source-license-url"
          type="url"
          class="field-input"
          class:error={errors.license_url}
          bind:value={formData.license_url}
          placeholder="https://creativecommons.org/licenses/..."
          maxlength={MAX_LENGTHS.url}
        />
        {#if errors.license_url}
          <p class="error-message">{errors.license_url}</p>
        {/if}
      </div>
    </FieldSection>

    <!-- Section 4: Additional Information -->
    <FieldSection title="Additional Information" collapsible collapsed>
      <div class="field">
        <label for="source-description" class="field-label">Description</label>
        <textarea
          id="source-description"
          class="field-textarea"
          class:error={errors.description}
          bind:value={formData.description}
          placeholder="Brief description of this source..."
          rows="3"
          maxlength={MAX_LENGTHS.description}
        ></textarea>
        <div class="field-footer">
          {#if errors.description}
            <p class="error-message">{errors.description}</p>
          {:else}
            <span></span>
          {/if}
          <span class="char-count" class:warning={getCharacterCount(formData.description, MAX_LENGTHS.description).remaining < 500}>
            {formData.description?.length || 0} / {MAX_LENGTHS.description}
          </span>
        </div>
      </div>

      <div class="field">
        <label for="source-notes" class="field-label">Notes</label>
        <textarea
          id="source-notes"
          class="field-textarea"
          class:error={errors.notes}
          bind:value={formData.notes}
          placeholder="Additional notes..."
          rows="3"
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
  .source-form {
    display: flex;
    flex-direction: column;
  }

  .field {
    display: flex;
    flex-direction: column;
    gap: 0.375rem;
  }

  .field-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
  }

  @media (max-width: 480px) {
    .field-row {
      grid-template-columns: 1fr;
    }
  }

  .field-label {
    font-size: 0.875rem;
    font-weight: 500;
    color: var(--color-text-primary);
  }

  .required {
    color: #dc2626;
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
    .field-select,
    .field-textarea {
      /* Prevent zoom on iOS */
      font-size: 1rem;
      min-height: 2.75rem;
      padding: 0.625rem 0.75rem;
    }

    .field-textarea {
      min-height: 5rem;
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
