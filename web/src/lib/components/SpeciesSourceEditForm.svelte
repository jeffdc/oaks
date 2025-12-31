<script>
  import EditModal from './EditModal.svelte';
  import FieldSection from './FieldSection.svelte';
  import TagInput from './TagInput.svelte';
  import { canEdit, getCannotEditReason } from '$lib/stores/authStore.js';

  /**
   * SpeciesSourceEditForm - Form for editing source-attributed species data
   *
   * Uses EditModal as wrapper. Fields match the species_sources table:
   * - local_names (TagInput)
   * - range, growth_habit, leaves, flowers, fruits, bark_twigs_buds,
   *   hardiness_habitat, miscellaneous (textareas)
   * - url (text input with URL validation)
   * - is_preferred (checkbox)
   */

  /** @type {string} Species name (epithet, e.g., "alba") */
  export let speciesName;
  /** @type {Object} Source data for pre-fill (includes source_name, source_id, and field data) */
  export let sourceData;
  /** @type {boolean} Whether the modal is open */
  export let isOpen = false;
  /** @type {() => void} Handler called when modal should close */
  export let onClose;
  /** @type {(data: Object) => Promise<any>} Handler called with form data when save completes */
  export let onSave;

  // Form state - initialized from sourceData prop
  let formData = {
    source_id: null,
    local_names: [],
    range: '',
    growth_habit: '',
    leaves: '',
    flowers: '',
    fruits: '',
    bark: '',
    twigs: '',
    buds: '',
    hardiness_habitat: '',
    miscellaneous: '',
    url: '',
    is_preferred: false
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

  // Initialize form when source data changes or modal opens
  $: if (isOpen && sourceData) {
    initializeForm();
  }

  function initializeForm() {
    formData = {
      source_id: sourceData.source_id || null,
      local_names: [...(sourceData.local_names || [])],
      range: sourceData.range || '',
      growth_habit: sourceData.growth_habit || '',
      leaves: sourceData.leaves || '',
      flowers: sourceData.flowers || '',
      fruits: sourceData.fruits || '',
      bark: sourceData.bark || '',
      twigs: sourceData.twigs || '',
      buds: sourceData.buds || '',
      hardiness_habitat: sourceData.hardiness_habitat || '',
      miscellaneous: sourceData.miscellaneous || '',
      url: sourceData.url || '',
      is_preferred: sourceData.is_preferred || false
    };
    errors = {};
  }

  /**
   * Validate URL format
   * @param {string} urlString
   * @returns {boolean}
   */
  function isValidUrl(urlString) {
    if (!urlString || !urlString.trim()) return true; // Empty is valid (optional field)
    try {
      new URL(urlString);
      return true;
    } catch {
      return false;
    }
  }

  function validate() {
    const newErrors = {};

    // Validate URL format if provided
    if (formData.url && !isValidUrl(formData.url)) {
      newErrors.url = 'Please enter a valid URL (e.g., https://example.com)';
    }

    errors = newErrors;
    return Object.keys(newErrors).length === 0;
  }

  // Map API field names to form field names
  function mapApiFieldToFormField(apiField) {
    // Most fields map 1:1, but add mappings for any differences
    const fieldMap = {
      'local_names': 'local_names',
      'range': 'range',
      'growth_habit': 'growth_habit',
      'leaves': 'leaves',
      'flowers': 'flowers',
      'fruits': 'fruits',
      'bark': 'bark',
      'twigs': 'twigs',
      'buds': 'buds',
      'hardiness_habitat': 'hardiness_habitat',
      'miscellaneous': 'miscellaneous',
      'url': 'url',
      'is_preferred': 'is_preferred'
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
      console.error('Failed to save source data:', error);
    } finally {
      isSaving = false;
    }
  }

  // Modal title based on source name
  $: modalTitle = sourceData?.source_name
    ? `Edit ${sourceData.source_name} Data`
    : 'Edit Source Data';
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

  <form class="source-form" on:submit|preventDefault={handleSave}>
    <!-- Section 1: Common Names -->
    <FieldSection title="Common Names">
      <div class="field">
        <label id="local-names-label" class="field-label">Local Names</label>
        <p class="field-hint">Common names for this species (press Enter or comma to add)</p>
        <TagInput
          values={formData.local_names}
          placeholder="Add common name..."
          onChange={(values) => formData.local_names = values}
        />
      </div>
    </FieldSection>

    <!-- Section 2: Description -->
    <FieldSection title="Description">
      <div class="field">
        <label for="growth-habit" class="field-label">Growth Habit</label>
        <textarea
          id="growth-habit"
          class="field-textarea"
          class:error={errors.growth_habit}
          bind:value={formData.growth_habit}
          placeholder="Tree form, size, branching pattern..."
          rows="3"
        />
        {#if errors.growth_habit}
          <p class="error-message">{errors.growth_habit}</p>
        {/if}
      </div>

      <div class="field">
        <label for="range" class="field-label">Range & Distribution</label>
        <textarea
          id="range"
          class="field-textarea"
          class:error={errors.range}
          bind:value={formData.range}
          placeholder="Geographic distribution, elevation range..."
          rows="3"
        />
        {#if errors.range}
          <p class="error-message">{errors.range}</p>
        {/if}
      </div>

      <div class="field">
        <label for="hardiness-habitat" class="field-label">Hardiness & Habitat</label>
        <textarea
          id="hardiness-habitat"
          class="field-textarea"
          class:error={errors.hardiness_habitat}
          bind:value={formData.hardiness_habitat}
          placeholder="Climate zones, soil preferences, associated species..."
          rows="3"
        />
        {#if errors.hardiness_habitat}
          <p class="error-message">{errors.hardiness_habitat}</p>
        {/if}
      </div>
    </FieldSection>

    <!-- Section 3: Morphology -->
    <FieldSection title="Morphology">
      <div class="field">
        <label for="leaves" class="field-label">Leaves</label>
        <textarea
          id="leaves"
          class="field-textarea"
          class:error={errors.leaves}
          bind:value={formData.leaves}
          placeholder="Leaf shape, size, color, texture..."
          rows="4"
        />
        {#if errors.leaves}
          <p class="error-message">{errors.leaves}</p>
        {/if}
      </div>

      <div class="field">
        <label for="flowers" class="field-label">Flowers</label>
        <textarea
          id="flowers"
          class="field-textarea"
          class:error={errors.flowers}
          bind:value={formData.flowers}
          placeholder="Catkin description, flowering time..."
          rows="3"
        />
        {#if errors.flowers}
          <p class="error-message">{errors.flowers}</p>
        {/if}
      </div>

      <div class="field">
        <label for="fruits" class="field-label">Fruits (Acorns)</label>
        <textarea
          id="fruits"
          class="field-textarea"
          class:error={errors.fruits}
          bind:value={formData.fruits}
          placeholder="Acorn shape, size, cup characteristics..."
          rows="4"
        />
        {#if errors.fruits}
          <p class="error-message">{errors.fruits}</p>
        {/if}
      </div>
    </FieldSection>

    <!-- Section 4: Bark, Twigs & Buds -->
    <FieldSection title="Bark, Twigs & Buds" collapsible collapsed>
      <div class="field">
        <label for="bark" class="field-label">Bark</label>
        <textarea
          id="bark"
          class="field-textarea"
          class:error={errors.bark}
          bind:value={formData.bark}
          placeholder="Bark texture, color, patterns..."
          rows="3"
        />
        {#if errors.bark}
          <p class="error-message">{errors.bark}</p>
        {/if}
      </div>

      <div class="field">
        <label for="twigs" class="field-label">Twigs</label>
        <textarea
          id="twigs"
          class="field-textarea"
          class:error={errors.twigs}
          bind:value={formData.twigs}
          placeholder="Twig color, texture, lenticels..."
          rows="3"
        />
        {#if errors.twigs}
          <p class="error-message">{errors.twigs}</p>
        {/if}
      </div>

      <div class="field">
        <label for="buds" class="field-label">Buds</label>
        <textarea
          id="buds"
          class="field-textarea"
          class:error={errors.buds}
          bind:value={formData.buds}
          placeholder="Bud shape, size, arrangement..."
          rows="3"
        />
        {#if errors.buds}
          <p class="error-message">{errors.buds}</p>
        {/if}
      </div>
    </FieldSection>

    <!-- Section 5: Additional Information -->
    <FieldSection title="Additional Information" collapsible collapsed>
      <div class="field">
        <label for="miscellaneous" class="field-label">Miscellaneous</label>
        <textarea
          id="miscellaneous"
          class="field-textarea"
          class:error={errors.miscellaneous}
          bind:value={formData.miscellaneous}
          placeholder="Uses, historical notes, other relevant information..."
          rows="4"
        />
        {#if errors.miscellaneous}
          <p class="error-message">{errors.miscellaneous}</p>
        {/if}
      </div>

      <div class="field">
        <label for="source-url" class="field-label">Source URL</label>
        <input
          id="source-url"
          type="url"
          class="field-input"
          class:error={errors.url}
          bind:value={formData.url}
          placeholder="https://example.com/species-page"
        />
        {#if errors.url}
          <p class="error-message">{errors.url}</p>
        {/if}
      </div>

      <div class="field field-checkbox">
        <label class="checkbox-label">
          <input
            type="checkbox"
            class="checkbox-input"
            bind:checked={formData.is_preferred}
          />
          <span class="checkbox-text">Preferred source for this species</span>
        </label>
        <p class="field-hint">When multiple sources have data, the preferred source is shown first</p>
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
  .source-form {
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

  /* Checkbox styles */
  .field-checkbox {
    flex-direction: column;
    gap: 0.25rem;
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
