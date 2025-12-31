<script>
  /**
   * FormField - Labeled input wrapper with error handling and accessibility
   *
   * Usage:
   *   <FormField label="Species Name" name="species-name" error={errors.name} required
   *     let:inputProps>
   *     <input type="text" {...inputProps} bind:value={name} />
   *   </FormField>
   *
   * The inputProps slot prop provides: id, aria-describedby, aria-invalid
   */

  /** @type {string} Label text displayed above the input */
  export let label;

  /** @type {string} Name/ID for associating label with input */
  export let name;

  /** @type {string|undefined} Error message to display */
  export let error = undefined;

  /** @type {boolean} Whether the field is required */
  export let required = false;

  /** @type {string|undefined} Help text displayed below the input */
  export let helpText = undefined;

  $: errorId = error ? `${name}-error` : undefined;
  $: helpId = helpText ? `${name}-help` : undefined;
  $: describedBy = [errorId, helpId].filter(Boolean).join(' ') || undefined;

  // Props to spread onto the input element for accessibility
  $: inputProps = {
    id: name,
    'aria-describedby': describedBy,
    'aria-invalid': error ? true : undefined,
    'aria-required': required ? true : undefined
  };
</script>

<div class="form-field" class:has-error={error}>
  <label for={name} class="form-label">
    {label}
    {#if required}
      <span class="required-indicator" aria-hidden="true">*</span>
    {/if}
  </label>

  <div class="input-wrapper">
    <slot {inputProps} />
  </div>

  {#if error}
    <p id={errorId} class="error-message" role="alert">
      {error}
    </p>
  {/if}

  {#if helpText && !error}
    <p id={helpId} class="help-text">
      {helpText}
    </p>
  {/if}
</div>

<style>
  .form-field {
    display: flex;
    flex-direction: column;
    gap: 0.375rem;
  }

  .form-label {
    display: flex;
    align-items: baseline;
    gap: 0.25rem;
    font-size: 0.875rem;
    font-weight: 500;
    color: var(--color-text-primary);
  }

  .required-indicator {
    color: #dc2626;
    font-weight: 400;
  }

  .input-wrapper {
    position: relative;
  }

  /* Style inputs within the wrapper */
  .input-wrapper :global(input),
  .input-wrapper :global(textarea),
  .input-wrapper :global(select) {
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

  .input-wrapper :global(textarea) {
    min-height: 6rem;
    resize: vertical;
  }

  .input-wrapper :global(input::placeholder),
  .input-wrapper :global(textarea::placeholder) {
    color: var(--color-text-tertiary);
  }

  .input-wrapper :global(input:focus),
  .input-wrapper :global(textarea:focus),
  .input-wrapper :global(select:focus) {
    outline: none;
    border-color: var(--color-forest-600);
    box-shadow: 0 0 0 3px rgba(30, 126, 75, 0.15);
  }

  /* Error state styling */
  .has-error .input-wrapper :global(input),
  .has-error .input-wrapper :global(textarea),
  .has-error .input-wrapper :global(select) {
    border-color: #dc2626;
  }

  .has-error .input-wrapper :global(input:focus),
  .has-error .input-wrapper :global(textarea:focus),
  .has-error .input-wrapper :global(select:focus) {
    border-color: #dc2626;
    box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.15);
  }

  .error-message {
    font-size: 0.8125rem;
    color: #dc2626;
    margin: 0;
  }

  .help-text {
    font-size: 0.8125rem;
    color: var(--color-text-secondary);
    margin: 0;
  }
</style>
