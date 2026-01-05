<script>
  import EditModal from './EditModal.svelte';
  import FieldSection from './FieldSection.svelte';
  import TagInput from './TagInput.svelte';
  import MarkdownEditor from './MarkdownEditor.svelte';
  import { canEdit, getCannotEditReason } from '$lib/stores/authStore.js';
  import { MAX_LENGTHS, validateLength } from '$lib/utils/validation.js';

  /**
   * ArticleEditForm - Form for creating and editing articles
   *
   * Uses EditModal as wrapper. Fields:
   * - title (text, required)
   * - author (text, required)
   * - content (markdown with preview)
   * - tags (TagInput for categorization)
   * - is_published (checkbox)
   *
   * Create mode: Pass article=null
   * Edit mode: Pass existing article object
   */

  /** @type {Object|null} Article data for pre-fill (null for create mode) */
  export let article = null;
  /** @type {boolean} Whether the modal is open */
  export let isOpen = false;
  /** @type {() => void} Handler called when modal should close */
  export let onClose;
  /** @type {(data: Object) => Promise<any>} Handler called with form data when save completes */
  export let onSave;
  /** @type {() => void} Handler called when delete is requested (edit mode only) */
  export let onDelete = null;

  // Determine if we're in create mode
  $: isCreateMode = !article;

  // Form state - initialized from article prop
  let formData = {
    title: '',
    author: '',
    content: '',
    tags: [],
    is_published: false
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

  // Initialize form when article changes or modal opens
  $: if (isOpen) {
    initializeForm();
  }

  function initializeForm() {
    if (article) {
      // Edit mode: populate from existing article
      formData = {
        title: article.title || '',
        author: article.author || '',
        content: article.content || '',
        tags: [...(article.tags || [])],
        is_published: article.is_published || false
      };
    } else {
      // Create mode: start with empty form
      formData = {
        title: '',
        author: '',
        content: '',
        tags: [],
        is_published: false
      };
    }
    errors = {};
  }

  function validate() {
    const newErrors = {};

    // Title is required
    if (!formData.title || !formData.title.trim()) {
      newErrors.title = 'Title is required';
    } else {
      const titleResult = validateLength(formData.title, MAX_LENGTHS.name || 200);
      if (!titleResult.valid) {
        newErrors.title = titleResult.message;
      }
    }

    // Author is required
    if (!formData.author || !formData.author.trim()) {
      newErrors.author = 'Author is required';
    } else {
      const authorResult = validateLength(formData.author, MAX_LENGTHS.author || 200);
      if (!authorResult.valid) {
        newErrors.author = authorResult.message;
      }
    }

    // Validate content length
    const contentResult = validateLength(formData.content, MAX_LENGTHS.content || 100000);
    if (!contentResult.valid) {
      newErrors.content = contentResult.message;
    }

    errors = newErrors;
    return Object.keys(newErrors).length === 0;
  }

  // Map API field names to form field names
  function mapApiFieldToFormField(apiField) {
    const fieldMap = {
      'title': 'title',
      'author': 'author',
      'content': 'content',
      'tags': 'tags',
      'is_published': 'is_published'
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
      console.error('Failed to save article:', error);
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
      const target = /** @type {HTMLElement} */ (event.target);
      // Allow Enter on buttons and submit inputs
      if (target.tagName === 'BUTTON' || ('type' in target && target.type === 'submit')) {
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
  title={isCreateMode ? 'Create Article' : `Edit: ${article?.title}`}
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

  <form class="article-form" onsubmit={(e) => { e.preventDefault(); handleSave(); }} onkeydown={handleFormKeydown}>
    <!-- Section 1: Core Information -->
    <FieldSection title="Article Information">
      <div class="field">
        <label for="article-title" class="field-label">Title <span class="required">*</span></label>
        <input
          id="article-title"
          type="text"
          class="field-input"
          class:error={errors.title}
          bind:value={formData.title}
          placeholder="Enter article title"
          maxlength={200}
        />
        {#if errors.title}
          <p class="error-message">{errors.title}</p>
        {/if}
      </div>

      <div class="field">
        <label for="article-author" class="field-label">Author <span class="required">*</span></label>
        <input
          id="article-author"
          type="text"
          class="field-input"
          class:error={errors.author}
          bind:value={formData.author}
          placeholder="Enter author name"
          maxlength={200}
        />
        {#if errors.author}
          <p class="error-message">{errors.author}</p>
        {/if}
      </div>

      <div class="field">
        <label id="article-tags-label" class="field-label">Tags</label>
        <p class="field-hint">Categorize your article (e.g., "guide", "identification", "review")</p>
        <TagInput
          values={formData.tags}
          placeholder="Add tag..."
          onChange={(values) => formData.tags = values}
        />
        {#if errors.tags}
          <p class="error-message">{errors.tags}</p>
        {/if}
      </div>

      <div class="field checkbox-field">
        <input
          id="article-published"
          type="checkbox"
          bind:checked={formData.is_published}
        />
        <label for="article-published" class="checkbox-label">
          <span class="checkbox-text">Published</span>
          <span class="checkbox-hint">Uncheck to save as draft (only visible to authenticated users)</span>
        </label>
      </div>
    </FieldSection>

    <!-- Section 2: Content -->
    <FieldSection title="Content" collapsible>
      <div class="field">
        <label for="article-content" class="field-label">Content</label>
        <p class="field-hint">Write your article using Markdown formatting</p>
        <MarkdownEditor
          value={formData.content}
          placeholder="Write your article content here..."
          onchange={(value) => formData.content = value}
          rows={20}
        />
        {#if errors.content}
          <p class="error-message">{errors.content}</p>
        {/if}
      </div>
    </FieldSection>
  </form>

  <!-- Custom footer with connection-aware Save button -->
  <svelte:fragment slot="footer">
    {#if !isCreateMode && onDelete}
      <button
        type="button"
        class="btn btn-danger"
        disabled={isSaving}
        onclick={onDelete}
      >
        Delete
      </button>
    {/if}
    <div class="spacer"></div>
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
  .article-form {
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

  .field-input {
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

  .field-input:focus {
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

  .checkbox-field {
    flex-direction: row;
    align-items: flex-start;
    gap: 0.75rem;
  }

  .checkbox-field input[type="checkbox"] {
    width: 1.125rem;
    height: 1.125rem;
    margin-top: 0.125rem;
    accent-color: var(--color-forest-600);
    cursor: pointer;
  }

  .checkbox-label {
    display: flex;
    flex-direction: column;
    gap: 0.125rem;
    cursor: pointer;
  }

  .checkbox-text {
    font-size: 0.9375rem;
    font-weight: 500;
    color: var(--color-text-primary);
  }

  .checkbox-hint {
    font-size: 0.8125rem;
    color: var(--color-text-tertiary);
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

  /* Footer button styles */
  .spacer {
    flex: 1;
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

  .btn-danger {
    color: white;
    background-color: var(--color-danger, #dc2626);
    border-color: var(--color-danger, #dc2626);
  }

  .btn-danger:hover:not(:disabled) {
    background-color: #b91c1c;
    border-color: #b91c1c;
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
    .field-input {
      /* Prevent zoom on iOS */
      font-size: 1rem;
      min-height: 2.75rem;
      padding: 0.625rem 0.75rem;
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
