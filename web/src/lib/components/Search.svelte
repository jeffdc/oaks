<script>
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { page } from '$app/stores';
  import { searchQuery, filteredSpecies } from '$lib/stores/dataStore.js';

  let inputElement;

  // Keep inputValue synced with the store (handles external clears like handleGoHome)
  $: inputValue = $searchQuery;

  async function handleInput(event) {
    const value = event.target.value;
    searchQuery.set(value);

    // Navigate to list page when user starts typing (if not already there)
    if (value && !$page.url.pathname.endsWith('/list/')) {
      await goto(`${base}/list/`);
      // Restore focus after navigation
      inputElement?.focus();
    }
  }

  function handleClear() {
    searchQuery.set('');
  }
</script>

<div class="search-container">
  <div class="relative group">
    <input
      type="text"
      bind:this={inputElement}
      bind:value={inputValue}
      on:input={handleInput}
      placeholder="Search by name, author, synonym, or location..."
      class="search-input w-full pl-12 pr-12 py-3.5 text-base rounded-lg transition-all duration-200 focus:outline-none"
    />
    {#if inputValue}
      <button
        on:click={handleClear}
        class="absolute right-3 top-1/2 transform -translate-y-1/2 transition-all duration-200 rounded-full p-1.5 text-white/60 hover:text-white hover:bg-white/10"
        aria-label="Clear search"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    {/if}
  </div>

  {#if $searchQuery}
    <div class="mt-2 text-sm font-medium text-white/80">
      {$filteredSpecies.length} species found
    </div>
  {/if}
</div>

<style>
  .search-input {
    background-color: var(--color-white-15);
    backdrop-filter: blur(8px);
    border: 1.5px solid var(--color-white-20);
    color: white;
    box-shadow: var(--shadow-sm);
  }

  .search-input:focus {
    background-color: var(--color-white-20);
    border-color: var(--color-white-40);
    box-shadow: var(--shadow-md), 0 0 0 3px var(--color-white-10);
  }

  .search-input::placeholder {
    color: var(--color-white-60);
  }
</style>
