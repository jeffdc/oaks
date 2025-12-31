<script>
  /**
   * TagInput - Tag/chip input for array fields
   *
   * Usage:
   *   <TagInput
   *     values={localNames}
   *     placeholder="Add common name..."
   *     onChange={(newValues) => localNames = newValues}
   *   />
   */

  /** @type {string[]} Current tag values */
  export let values = [];

  /** @type {string} Placeholder text for the input */
  export let placeholder = 'Add tag...';

  /** @type {(values: string[]) => void} Callback when values change */
  export let onChange = () => {};

  /** @type {boolean} Whether the input is disabled */
  export let disabled = false;

  /** @type {string} Current input value */
  let inputValue = '';

  /** @type {HTMLInputElement|null} Reference to the input element */
  let inputEl = null;

  /**
   * Add a tag to the list
   * @param {string} tag - The tag to add
   */
  function addTag(tag) {
    const trimmed = tag.trim();
    if (!trimmed) return;

    // Prevent duplicates (case-insensitive check)
    const lowerTrimmed = trimmed.toLowerCase();
    if (values.some(v => v.toLowerCase() === lowerTrimmed)) {
      return;
    }

    const newValues = [...values, trimmed];
    onChange(newValues);
  }

  /**
   * Remove a tag from the list
   * @param {number} index - Index of tag to remove
   */
  function removeTag(index) {
    const newValues = values.filter((_, i) => i !== index);
    onChange(newValues);
    // Focus back to input after removal
    inputEl?.focus();
  }

  /**
   * Handle keydown events on the input
   * @param {KeyboardEvent} event
   */
  function handleKeyDown(event) {
    if (event.key === 'Enter' || event.key === ',') {
      event.preventDefault();
      if (inputValue.trim()) {
        addTag(inputValue);
        inputValue = '';
      }
    } else if (event.key === 'Backspace' && !inputValue && values.length > 0) {
      // Remove last tag when backspace on empty input
      removeTag(values.length - 1);
    }
  }

  /**
   * Handle paste events - split on comma or newline
   * @param {ClipboardEvent} event
   */
  function handlePaste(event) {
    event.preventDefault();
    const pastedText = event.clipboardData?.getData('text') || '';
    const tags = pastedText.split(/[,\n]+/).map(t => t.trim()).filter(Boolean);

    if (tags.length > 0) {
      tags.forEach(addTag);
      inputValue = '';
    }
  }

  /**
   * Handle blur - add current input as tag
   */
  function handleBlur() {
    if (inputValue.trim()) {
      addTag(inputValue);
      inputValue = '';
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
  class="tag-input-container"
  class:disabled
  on:click={focusInput}
>
  {#if values.length > 0}
    <ul class="tag-list" role="list" aria-label="Tags">
      {#each values as tag, index (tag)}
        <li class="tag">
          <span class="tag-text">{tag}</span>
          <button
            type="button"
            class="tag-remove"
            aria-label="Remove {tag}"
            on:click|stopPropagation={() => removeTag(index)}
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
    bind:value={inputValue}
    type="text"
    class="tag-input"
    {placeholder}
    {disabled}
    on:keydown={handleKeyDown}
    on:paste={handlePaste}
    on:blur={handleBlur}
    aria-label="Add new tag"
  />
</div>

<style>
  .tag-input-container {
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

  .tag-input-container:focus-within {
    border-color: var(--color-forest-600);
    box-shadow: 0 0 0 3px rgba(30, 126, 75, 0.15);
  }

  .tag-input-container.disabled {
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

  .tag-remove:focus {
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

  .tag-input {
    flex: 1;
    min-width: 120px;
    padding: 0.125rem 0.25rem;
    font-size: 0.9375rem;
    color: var(--color-text-primary);
    background: transparent;
    border: none;
    outline: none;
  }

  .tag-input::placeholder {
    color: var(--color-text-tertiary);
  }

  .tag-input:disabled {
    cursor: not-allowed;
  }
</style>
