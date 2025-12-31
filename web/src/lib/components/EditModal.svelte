<script>
  import { onMount, onDestroy, tick } from 'svelte';
  import LoadingSpinner from './LoadingSpinner.svelte';

  /**
   * EditModal - Reusable modal container for edit forms
   *
   * Usage:
   *   <EditModal
   *     title="Edit Species"
   *     isOpen={showModal}
   *     isSaving={saving}
   *     onClose={() => showModal = false}
   *     onSave={handleSave}
   *   >
   *     <form>...</form>
   *   </EditModal>
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

  /** @type {HTMLElement|null} */
  let modalElement = null;

  /** @type {HTMLElement|null} */
  let previouslyFocused = null;

  /** @type {string} */
  const titleId = `modal-title-${Math.random().toString(36).substr(2, 9)}`;

  // Handle escape key
  function handleKeydown(event) {
    if (!isOpen) return;

    if (event.key === 'Escape' && !isSaving) {
      event.preventDefault();
      onClose();
      return;
    }

    // Focus trap - cycle through focusable elements
    if (event.key === 'Tab' && modalElement) {
      const focusableElements = modalElement.querySelectorAll(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
      );
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

  // Focus management when modal opens/closes
  $: if (isOpen) {
    // Store reference to previously focused element
    previouslyFocused = document.activeElement;

    // Focus the modal after it renders
    tick().then(() => {
      if (modalElement) {
        // Focus the close button or first focusable element
        const firstFocusable = modalElement.querySelector(
          'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
        );
        firstFocusable?.focus();
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
    // Ensure body scroll is restored
    document.body.style.overflow = '';
  });

  function handleBackdropClick(event) {
    // Only close if clicking the backdrop itself, not modal content
    if (event.target === event.currentTarget && !isSaving) {
      onClose();
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
          on:click={onClose}
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
            on:click={onClose}
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
    max-height: calc(100vh - 2rem);
    background-color: var(--color-surface);
    border-radius: 0.75rem;
    box-shadow: var(--shadow-xl);
    overflow: hidden;
  }

  .modal-header {
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
    width: 2rem;
    height: 2rem;
    padding: 0;
    color: var(--color-text-secondary);
    background: none;
    border: none;
    border-radius: 0.375rem;
    cursor: pointer;
    transition: background-color 0.15s ease, color 0.15s ease;
  }

  .close-button:hover:not(:disabled) {
    background-color: var(--color-forest-100);
    color: var(--color-forest-700);
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
  }

  .modal-footer {
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
    padding: 0.5rem 1rem;
    font-size: 0.9375rem;
    font-weight: 500;
    line-height: 1.5;
    border: 1px solid transparent;
    border-radius: 0.5rem;
    cursor: pointer;
    transition: background-color 0.15s ease, border-color 0.15s ease, color 0.15s ease;
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

  /* Responsive adjustments */
  @media (max-width: 640px) {
    .modal-backdrop {
      padding: 0.5rem;
    }

    .modal-container {
      max-height: calc(100vh - 1rem);
    }

    .modal-header,
    .modal-content,
    .modal-footer {
      padding-left: 1rem;
      padding-right: 1rem;
    }
  }
</style>
