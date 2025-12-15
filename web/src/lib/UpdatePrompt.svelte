<script>
  import { useRegisterSW } from 'virtual:pwa-register/svelte';

  const {
    needRefresh,
    updateServiceWorker,
  } = useRegisterSW({
    onRegistered(r) {
      console.log('SW Registered:', r);
    },
    onRegisterError(error) {
      console.log('SW registration error', error);
    },
  });

  function handleUpdate() {
    updateServiceWorker(true);
  }
</script>

{#if $needRefresh}
  <div class="fixed bottom-4 right-4 bg-white rounded-lg shadow-lg p-4 max-w-sm border-2 border-green-700 z-50">
    <div class="flex items-start gap-3">
      <div class="flex-shrink-0">
        <svg class="w-6 h-6 text-green-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
        </svg>
      </div>
      <div class="flex-1">
        <h3 class="text-sm font-semibold text-gray-900 mb-1">
          Update Available
        </h3>
        <p class="text-xs text-gray-600 mb-3">
          A new version is ready. Refresh to update.
        </p>
        <button
          on:click={handleUpdate}
          class="w-full px-4 py-2 bg-green-700 text-white rounded-md text-sm font-medium hover:bg-green-800 transition-colors"
        >
          Refresh Now
        </button>
      </div>
    </div>
  </div>
{/if}
