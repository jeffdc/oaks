<script>
  import { useRegisterSW } from 'virtual:pwa-register/svelte';

  const {
    needRefresh,
    updateServiceWorker,
  } = useRegisterSW({
    onRegisterError(error) {
      console.error('SW registration error:', error);
    },
  });

  function handleUpdate() {
    updateServiceWorker(true);
  }
</script>

{#if $needRefresh}
  <div class="update-prompt">
    <div class="update-content">
      <div class="update-icon">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
        </svg>
      </div>
      <div class="update-text">
        <h3 class="update-title">Update Available</h3>
        <p class="update-description">A new version is ready. Refresh to update.</p>
        <button on:click={handleUpdate} class="update-button">
          Refresh Now
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .update-prompt {
    position: fixed;
    bottom: 1rem;
    right: 1rem;
    max-width: 20rem;
    padding: 1rem;
    background-color: var(--color-surface);
    border: 2px solid var(--color-forest-700);
    border-radius: 0.5rem;
    box-shadow: var(--shadow-lg);
    z-index: 50;
  }

  .update-content {
    display: flex;
    align-items: flex-start;
    gap: 0.75rem;
  }

  .update-icon {
    flex-shrink: 0;
    color: var(--color-forest-700);
  }

  .update-text {
    flex: 1;
  }

  .update-title {
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--color-text-primary);
    margin-bottom: 0.25rem;
  }

  .update-description {
    font-size: 0.75rem;
    color: var(--color-text-secondary);
    margin-bottom: 0.75rem;
  }

  .update-button {
    width: 100%;
    padding: 0.5rem 1rem;
    background-color: var(--color-forest-700);
    color: white;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    font-weight: 500;
    transition: background-color 0.15s;
  }

  .update-button:hover {
    background-color: var(--color-forest-800);
  }
</style>
