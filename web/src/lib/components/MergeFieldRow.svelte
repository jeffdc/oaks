<script>
  /**
   * MergeFieldRow - Display a field side-by-side for merging species
   *
   * Shows synonym value (read-only) on left, target value (editable) on right,
   * with a copy button to transfer values from synonym to target.
   */

  /** @type {string} Field label to display */
  export let label;

  /** @type {string|string[]|null|undefined} Value from synonym (read-only) */
  export let synonymValue = null;

  /** @type {string|string[]|null|undefined} Value from target (editable, bindable) */
  export let targetValue = null;

  /** @type {'text' | 'textarea' | 'array'} Input type */
  export let type = 'text';

  // Check if values differ (for visual highlighting)
  $: valuesDiffer = normalizeValue(synonymValue) !== normalizeValue(targetValue);

  // Check if synonym has a value worth copying
  $: synonymHasValue = hasValue(synonymValue);

  // For array type, we need to format display
  $: synonymDisplay = formatValue(synonymValue, type);
  $: targetDisplay = formatValue(targetValue, type);

  function normalizeValue(val) {
    if (val === null || val === undefined) return '';
    if (Array.isArray(val)) return val.join(', ');
    return String(val).trim();
  }

  function hasValue(val) {
    if (val === null || val === undefined) return false;
    if (Array.isArray(val)) return val.length > 0;
    return String(val).trim() !== '';
  }

  function formatValue(val, fieldType) {
    if (val === null || val === undefined) return '';
    if (Array.isArray(val)) return val.join(', ');
    return String(val);
  }

  function copyToTarget() {
    // For arrays, make a copy
    if (Array.isArray(synonymValue)) {
      targetValue = [...synonymValue];
    } else {
      targetValue = synonymValue;
    }
  }

  // Handle array input (comma-separated)
  function handleArrayInput(event) {
    const text = event.target.value;
    if (text.trim() === '') {
      targetValue = [];
    } else {
      targetValue = text.split(',').map(s => s.trim()).filter(s => s !== '');
    }
  }
</script>

<div class="merge-field-row" class:values-differ={valuesDiffer}>
  <div class="field-label">{label}</div>

  <div class="field-values">
    <!-- Synonym value (read-only) -->
    <div class="value-column synonym-column">
      {#if type === 'textarea'}
        <div class="value-display textarea-display">
          {synonymDisplay || '—'}
        </div>
      {:else}
        <div class="value-display">
          {synonymDisplay || '—'}
        </div>
      {/if}
    </div>

    <!-- Copy button -->
    <div class="copy-column">
      {#if synonymHasValue}
        <button
          type="button"
          class="copy-button"
          onclick={copyToTarget}
          title="Copy to target"
          aria-label="Copy value to target"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="copy-icon">
            <path fill-rule="evenodd" d="M3 10a.75.75 0 01.75-.75h10.638L10.23 5.29a.75.75 0 111.04-1.08l5.5 5.25a.75.75 0 010 1.08l-5.5 5.25a.75.75 0 11-1.04-1.08l4.158-3.96H3.75A.75.75 0 013 10z" clip-rule="evenodd" />
          </svg>
        </button>
      {:else}
        <div class="copy-placeholder"></div>
      {/if}
    </div>

    <!-- Target value (editable) -->
    <div class="value-column target-column">
      {#if type === 'textarea'}
        <textarea
          class="value-input"
          bind:value={targetValue}
          rows="3"
        ></textarea>
      {:else if type === 'array'}
        <input
          type="text"
          class="value-input"
          value={targetDisplay}
          oninput={handleArrayInput}
          placeholder="Comma-separated values"
        />
      {:else}
        <input
          type="text"
          class="value-input"
          bind:value={targetValue}
        />
      {/if}
    </div>
  </div>
</div>

<style>
  .merge-field-row {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    padding: 0.75rem;
    border-radius: 0.5rem;
    background-color: var(--color-surface);
    transition: background-color 0.15s ease;
  }

  .merge-field-row.values-differ {
    background-color: rgba(30, 126, 75, 0.05);
    border-left: 3px solid var(--color-forest-500);
  }

  .field-label {
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--color-text-primary);
  }

  .field-values {
    display: grid;
    grid-template-columns: 1fr auto 1fr;
    gap: 0.75rem;
    align-items: start;
  }

  .value-column {
    min-width: 0;
  }

  .synonym-column {
    opacity: 0.7;
  }

  .value-display {
    padding: 0.5rem 0.75rem;
    font-size: 0.9375rem;
    line-height: 1.5;
    color: var(--color-text-secondary);
    background-color: var(--color-background);
    border: 1px solid var(--color-border);
    border-radius: 0.5rem;
    min-height: 2.5rem;
    word-break: break-word;
  }

  .textarea-display {
    min-height: 5rem;
    white-space: pre-wrap;
  }

  .value-input {
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

  .value-input:focus {
    outline: none;
    border-color: var(--color-forest-600);
    box-shadow: 0 0 0 3px rgba(30, 126, 75, 0.15);
  }

  textarea.value-input {
    min-height: 5rem;
    resize: vertical;
  }

  .copy-column {
    display: flex;
    align-items: center;
    justify-content: center;
    padding-top: 0.5rem;
  }

  .copy-button {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 2rem;
    height: 2rem;
    padding: 0;
    background-color: var(--color-forest-100);
    color: var(--color-forest-700);
    border: 1px solid var(--color-forest-300);
    border-radius: 0.375rem;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .copy-button:hover {
    background-color: var(--color-forest-200);
    border-color: var(--color-forest-400);
  }

  .copy-button:active {
    transform: scale(0.95);
  }

  .copy-icon {
    width: 1rem;
    height: 1rem;
  }

  .copy-placeholder {
    width: 2rem;
    height: 2rem;
  }

  /* Responsive: stack on small screens */
  @media (max-width: 768px) {
    .field-values {
      grid-template-columns: 1fr;
      gap: 0.5rem;
    }

    .copy-column {
      order: 3;
      padding-top: 0;
    }

    .copy-button {
      width: 100%;
    }

    .copy-placeholder {
      display: none;
    }
  }
</style>
