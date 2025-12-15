<script>
  import { searchQuery, filteredSpecies } from './dataStore.js';

  let inputValue = $searchQuery;

  function handleInput(event) {
    inputValue = event.target.value;
    searchQuery.set(inputValue);
  }

  function handleClear() {
    inputValue = '';
    searchQuery.set('');
  }
</script>

<div class="search-container">
  <div class="relative group">
    <input
      type="text"
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
    background-color: rgba(255, 255, 255, 0.15);
    backdrop-filter: blur(8px);
    border: 1.5px solid rgba(255, 255, 255, 0.2);
    color: white;
    box-shadow: var(--shadow-sm);
  }

  .search-input:focus {
    background-color: rgba(255, 255, 255, 0.2);
    border-color: rgba(255, 255, 255, 0.4);
    box-shadow: var(--shadow-md), 0 0 0 3px rgba(255, 255, 255, 0.1);
  }

  .search-input::placeholder {
    color: rgba(255, 255, 255, 0.6);
  }
</style>
