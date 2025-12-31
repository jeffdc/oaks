<script>
  /**
   * FieldSection - Groups related form fields within EditModal
   *
   * Usage:
   *   <FieldSection title="Core Information" collapsible={false}>
   *     <input type="text" ... />
   *   </FieldSection>
   *
   *   <FieldSection title="Taxonomy" collapsed={true}>
   *     <!-- Fields here -->
   *   </FieldSection>
   */

  /** @type {string} Section heading text */
  export let title;

  /** @type {boolean} Whether section can be collapsed */
  export let collapsible = false;

  /** @type {boolean} Initial collapsed state (only applies if collapsible) */
  export let collapsed = false;

  /** @type {string|null} Optional description text below title */
  export let description = null;

  /** @type {boolean} Internal collapsed state */
  let isCollapsed = collapsed;

  function toggleCollapse() {
    if (collapsible) {
      isCollapsed = !isCollapsed;
    }
  }

  /** @type {string} Unique ID for accessibility */
  const sectionId = `field-section-${Math.random().toString(36).substr(2, 9)}`;
</script>

<section class="field-section" class:collapsed={isCollapsed && collapsible}>
  <header class="field-section-header">
    {#if collapsible}
      <button
        type="button"
        class="section-toggle"
        aria-expanded={!isCollapsed}
        aria-controls={sectionId}
        on:click={toggleCollapse}
      >
        <svg
          class="toggle-icon"
          class:rotated={!isCollapsed}
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <polyline points="9 18 15 12 9 6"></polyline>
        </svg>
        <h3 class="section-title">{title}</h3>
      </button>
    {:else}
      <h3 class="section-title">{title}</h3>
    {/if}
    {#if description}
      <p class="section-description">{description}</p>
    {/if}
  </header>

  <div
    id={sectionId}
    class="field-section-content"
    class:hidden={isCollapsed && collapsible}
  >
    <slot />
  </div>
</section>

<style>
  .field-section {
    border-bottom: 1px solid var(--color-border);
    padding-bottom: 1.25rem;
    margin-bottom: 1.25rem;
  }

  .field-section:last-child {
    border-bottom: none;
    padding-bottom: 0;
    margin-bottom: 0;
  }

  .field-section-header {
    margin-bottom: 1rem;
  }

  .section-toggle {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    width: 100%;
    padding: 0;
    background: none;
    border: none;
    cursor: pointer;
    text-align: left;
    color: inherit;
  }

  .section-toggle:hover .section-title {
    color: var(--color-forest-700);
  }

  .section-toggle:focus-visible {
    outline: 2px solid var(--color-forest-500);
    outline-offset: 2px;
    border-radius: 0.25rem;
  }

  .toggle-icon {
    flex-shrink: 0;
    color: var(--color-text-secondary);
    transition: transform 0.2s ease;
  }

  .toggle-icon.rotated {
    transform: rotate(90deg);
  }

  .section-title {
    margin: 0;
    font-size: 0.9375rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--color-forest-700);
  }

  .section-description {
    margin: 0.375rem 0 0;
    font-size: 0.8125rem;
    color: var(--color-text-secondary);
  }

  .field-section-content {
    display: grid;
    gap: 1rem;
  }

  .field-section-content.hidden {
    display: none;
  }

  /* Collapsed state styling */
  .field-section.collapsed {
    padding-bottom: 0;
    margin-bottom: 1rem;
  }

  .field-section.collapsed .field-section-header {
    margin-bottom: 0;
  }

  /* Mobile adjustments */
  @media (max-width: 640px) {
    .field-section {
      padding-bottom: 1rem;
      margin-bottom: 1rem;
    }

    .section-title {
      font-size: 0.875rem;
    }

    .section-toggle {
      /* Minimum 44px touch target */
      min-height: 2.75rem;
      padding: 0.625rem 0;
      margin: -0.625rem 0;
    }

    .toggle-icon {
      width: 20px;
      height: 20px;
    }
  }
</style>
