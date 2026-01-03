<script>
  import { onMount, onDestroy, tick } from 'svelte';
  import LoadingSpinner from './LoadingSpinner.svelte';

  /**
   * EditModal - Reusable modal container for edit forms
   *
   * Features:
   * - Fixed header/footer with scrollable content area
   * - Full-screen on mobile devices (<640px)
   * - Large touch targets for mobile
   * - Native scroll momentum on iOS
   * - Focus trap and keyboard navigation
   * - Unsaved changes warning (via isDirty prop)
   *
   * Basic usage:
   *   <EditModal
   *     title="Edit Species"
   *     isOpen={showModal}
   *     isSaving={saving}
   *     isDirty={hasChanges}
   *     onClose={() => showModal = false}
   *     onSave={handleSave}
   *   >
   *     <form>...</form>
   *   </EditModal>
   *
   * With FieldSection for grouped forms:
   *   <EditModal title="Edit Species" ...>
   *     <FieldSection title="Core Information">
   *       <input type="text" ... />
   *     </FieldSection>
   *     <FieldSection title="Taxonomy">
   *       <select>...</select>
   *     </FieldSection>
   *     <FieldSection title="Related Species" collapsible collapsed>
   *       <!-- Less frequently edited fields -->
   *     </FieldSection>
   *   </EditModal>
   *
   * Unsaved changes warning:
   * When isDirty is true, the modal will:
   * - Show a confirmation dialog on Cancel, Escape, backdrop click, or X button
   * - Trigger the browser's native beforeunload warning on page close/refresh
   */

  /** @type {string} Modal title displayed in the header */
  export let title;

  /** @type {boolean} Whether the modal is open */
  export let isOpen;

  /** @type {boolean} Whether a save operation is in progress */
  export let isSaving = false;

  /** @type {() => void} Handler called when modal should close */
  export let onClose;

  /** @type {() => void} Handler called when Save button is clicked */
  export let onSave;

  /** @type {boolean} Whether the form has unsaved changes */
  export let isDirty = false;

  /** @type {HTMLElement|null} */
  let modalElement = null;

  /** @type {HTMLElement|null} */
  let previouslyFocused = null;

  /** @type {string} */
  const titleId = `modal-title-${Math.random().toString(36).substr(2, 9)}`;

  /**
   * Attempts to close the modal, showing a confirmation dialog if there are unsaved changes.
   * @returns {boolean} Whether the close was allowed
   */
  function handleCloseAttempt() {
    if (isDirty) {
      const confirmed = confirm('You have unsaved changes. Discard them?');
      if (!confirmed) {
        return false;
      }
    }
    onClose();
    return true;
  }

  /**
   * Handles the beforeunload event to warn about unsaved changes when closing/refreshing browser.
   * @param {BeforeUnloadEvent} event
   */
  function handleBeforeUnload(event) {
    if (isDirty && isOpen) {
      event.preventDefault();
      // Modern browsers ignore custom messages but still show a warning
      event.returnValue = 'You have unsaved changes. Are you sure you want to leave?';
      return event.returnValue;
    }
  }

  /**
   * Gets all focusable elements within the modal, excluding hidden and disabled elements.
   * @returns {HTMLElement[]}
   */
  function getFocusableElements() {
    if (!modalElement) return [];

    const selector = 'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])';
    const elements = Array.from(modalElement.querySelectorAll(selector));

    return elements.filter(el => {
      // Skip disabled elements
      if (el.disabled) return false;

      // Skip elements with tabindex="-1"
      if (el.getAttribute('tabindex') === '-1') return false;

      // Skip hidden elements
      const style = window.getComputedStyle(el);
      if (style.display === 'none' || style.visibility === 'hidden') return false;

      // Check if any ancestor has display:none (for collapsed sections)
      let parent = el.parentElement;
      while (parent && parent !== modalElement) {
        const parentStyle = window.getComputedStyle(parent);
        if (parentStyle.display === 'none') return false;
        parent = parent.parentElement;
      }

      return true;
    });
  }

  // Handle escape key and focus trap
  function handleKeydown(event) {
    if (!isOpen) return;

    if (event.key === 'Escape' && !isSaving) {
      event.preventDefault();
      handleCloseAttempt();
      return;
    }

    // Focus trap - cycle through focusable elements
    if (event.key === 'Tab' && modalElement) {
      const focusableElements = getFocusableElements();
      if (focusableElements.length === 0) return;

      const firstElement = focusableElements[0];
      const lastElement = focusableElements[focusableElements.length - 1];

      if (event.shiftKey) {
        // Shift+Tab: if on first element, move to last
        if (document.activeElement === firstElement) {
          event.preventDefault();
          lastElement?.focus();
        }
      } else {
        // Tab: if on last element, move to first
        if (document.activeElement === lastElement) {
          event.preventDefault();
          firstElement?.focus();
        }
      }
    }
  }

  // Manage beforeunload listener based on isDirty and isOpen
  $: {
    if (typeof window !== 'undefined') {
      if (isOpen && isDirty) {
        window.addEventListener('beforeunload', handleBeforeUnload);
      } else {
        window.removeEventListener('beforeunload', handleBeforeUnload);
      }
    }
  }

  // Focus management when modal opens/closes
  $: if (isOpen) {
    // Store reference to previously focused element
    previouslyFocused = document.activeElement;

    // Focus the modal after it renders
    tick().then(() => {
      if (modalElement) {
        // Focus the first focusable element (uses getFocusableElements to skip hidden/disabled)
        const focusableElements = getFocusableElements();
        if (focusableElements.length > 0) {
          focusableElements[0].focus();
        }
      }
    });

    // Prevent body scroll
    document.body.style.overflow = 'hidden';
  } else {
    // Return focus to previously focused element
    if (previouslyFocused && typeof previouslyFocused.focus === 'function') {
      previouslyFocused.focus();
    }
    previouslyFocused = null;

    // Restore body scroll
    document.body.style.overflow = '';
  }

  onMount(() => {
    document.addEventListener('keydown', handleKeydown);
  });

  onDestroy(() => {
    document.removeEventListener('keydown', handleKeydown);
    window.removeEventListener('beforeunload', handleBeforeUnload);
    // Ensure body scroll is restored
    document.body.style.overflow = '';
  });

  function handleBackdropClick(event) {
    // Only close if clicking the backdrop itself, not modal content
    if (event.target === event.currentTarget && !isSaving) {
      handleCloseAttempt();
    }
  }
</script>

{#if isOpen}
  <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
  <div
    class="modal-backdrop"
    role="dialog"
    aria-modal="true"
    aria-labelledby={titleId}
    tabindex="-1"
    bind:this={modalElement}
    on:click={handleBackdropClick}
    on:keydown={handleKeydown}
  >
    <div class="modal-container" role="document">
      <!-- Header -->
      <header class="modal-header">
        <h2 id={titleId} class="modal-title">{title}</h2>
        <button
          type="button"
          class="close-button"
          aria-label="Close modal"
          disabled={isSaving}
          on:click={handleCloseAttempt}
        >
          <svg
            width="20"
            height="20"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
        </button>
      </header>

      <!-- Content (scrollable) -->
      <div class="modal-content">
        <slot />
      </div>

      <!-- Footer -->
      <footer class="modal-footer">
        <slot name="footer">
          <button
            type="button"
            class="btn btn-secondary"
            disabled={isSaving}
            on:click={handleCloseAttempt}
          >
            Cancel
          </button>
          <button
            type="button"
            class="btn btn-primary"
            disabled={isSaving}
            on:click={onSave}
          >
            {#if isSaving}
              <LoadingSpinner size="sm" />
              <span>Saving...</span>
            {:else}
              Save
            {/if}
          </button>
        </slot>
      </footer>
    </div>
  </div>
{/if}

<style>
  .modal-backdrop {
    position: fixed;
    inset: 0;
    z-index: 100;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1rem;
    background-color: rgba(0, 0, 0, 0.5);
    backdrop-filter: blur(2px);
  }

  .modal-container {
    display: flex;
    flex-direction: column;
    width: 100%;
    max-width: 40rem;
    max-height: 85vh;
    background-color: var(--color-surface);
    border-radius: 0.75rem;
    box-shadow: var(--shadow-xl);
    overflow: hidden;
  }

  .modal-header {
    position: sticky;
    top: 0;
    z-index: 10;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.25rem;
    border-bottom: 1px solid var(--color-border);
    background-color: var(--color-forest-50);
    flex-shrink: 0;
  }

  .modal-title {
    margin: 0;
    font-size: 1.25rem;
    font-weight: 600;
    font-family: var(--font-serif);
    color: var(--color-forest-800);
  }

  .close-button {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 2.5rem;
    height: 2.5rem;
    padding: 0;
    color: var(--color-text-secondary);
    background: none;
    border: none;
    border-radius: 0.5rem;
    cursor: pointer;
    transition: background-color 0.15s ease, color 0.15s ease;
  }

  .close-button:hover:not(:disabled) {
    background-color: var(--color-forest-100);
    color: var(--color-forest-700);
  }

  .close-button:focus-visible {
    outline: 2px solid var(--color-forest-500);
    outline-offset: 2px;
  }

  .close-button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .modal-content {
    flex: 1;
    overflow-y: auto;
    padding: 1.25rem;
    min-height: 0;
    /* Native scroll momentum on iOS */
    -webkit-overflow-scrolling: touch;
    /* Smooth scrolling */
    scroll-behavior: smooth;
  }

  .modal-footer {
    position: sticky;
    bottom: 0;
    z-index: 10;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 0.75rem;
    padding: 1rem 1.25rem;
    border-top: 1px solid var(--color-border);
    background-color: var(--color-background);
    flex-shrink: 0;
  }

  /* Button styles */
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
    /* Minimum touch target size */
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

  /* Mobile: Full-screen modal */
  @media (max-width: 640px) {
    .modal-backdrop {
      padding: 0;
      align-items: stretch;
    }

    .modal-container {
      max-width: none;
      max-height: none;
      height: 100%;
      border-radius: 0;
    }

    .modal-header {
      padding: 0.875rem 1rem;
    }

    .modal-title {
      font-size: 1.125rem;
    }

    .modal-content {
      padding: 1rem;
    }

    .modal-footer {
      padding: 0.875rem 1rem;
      /* Safe area for devices with home indicator */
      padding-bottom: max(0.875rem, env(safe-area-inset-bottom));
    }

    /* Larger touch targets on mobile */
    .btn {
      min-height: 3rem;
      padding: 0.75rem 1.25rem;
      font-size: 1rem;
    }

    .close-button {
      width: 2.75rem;
      height: 2.75rem;
    }

    .close-button svg {
      width: 22px;
      height: 22px;
    }
  }

  /* Small height devices (landscape phone) */
  @media (max-height: 500px) {
    .modal-container {
      max-height: 100vh;
    }

    .modal-header,
    .modal-footer {
      padding-top: 0.5rem;
      padding-bottom: 0.5rem;
    }

    .modal-content {
      padding-top: 0.75rem;
      padding-bottom: 0.75rem;
    }
  }
</style>
