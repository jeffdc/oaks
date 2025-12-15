<script>
  import { filteredSpecies, speciesCounts } from './dataStore.js';

  export let onSelectSpecies;

  function handleClick(species) {
    onSelectSpecies(species);
  }

  // Check if hybrid name already has × symbol (most do)
  function needsHybridSymbol(species) {
    return species.is_hybrid && !species.name.startsWith('×');
  }
</script>

<div class="species-list">
  {#if $filteredSpecies.length > 0}
    <div class="counts-bar">
      <span class="count-item">{$speciesCounts.speciesCount} species</span>
      <span class="separator">|</span>
      <span class="count-item">{$speciesCounts.hybridCount} hybrids</span>
      <span class="separator">|</span>
      <span class="count-item count-total">{$speciesCounts.total} total</span>
    </div>
  {/if}

  {#if $filteredSpecies.length === 0}
    <div class="py-20 text-center" style="background-color: var(--color-surface); border-radius: 1rem; box-shadow: var(--shadow-sm);">
      <svg class="w-16 h-16 mx-auto mb-4" style="color: var(--color-text-tertiary);" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
        <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607zM10.5 7.5v6m3-3h-6" />
      </svg>
      <p class="text-lg font-medium mb-1" style="color: var(--color-text-secondary);">No species found</p>
      <p class="text-sm" style="color: var(--color-text-tertiary);">Try adjusting your search terms</p>
    </div>
  {:else}
    <ul class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      {#each $filteredSpecies as species (species.name)}
        <li class="species-item">
          <button
            on:click={() => handleClick(species)}
            class="species-button w-full text-left transition-all duration-200 focus:outline-none group"
          >
            <div>
              <h3 class="species-name mb-2">
                Quercus {#if needsHybridSymbol(species)}× {/if}<span class="italic">{species.name}</span>
              </h3>
              {#if species.author}
                <p class="text-sm mb-3" style="color: var(--color-text-secondary); line-height: 1.4;">{species.author}</p>
              {/if}
              {#if species.range}
                <div class="flex items-center gap-2">
                  <svg class="w-5 h-5 flex-shrink-0" style="color: var(--color-forest-600);" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                  <p class="text-sm" style="color: var(--color-text-primary); line-height: 1.6;">{species.range}</p>
                </div>
              {/if}
            </div>
          </button>
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .species-button {
    padding: 1.25rem;
    border-radius: 0.75rem;
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    box-shadow: var(--shadow-sm);
    text-align: left !important;
  }

  .species-button:hover {
    border-color: var(--color-forest-400);
    box-shadow: var(--shadow-md);
    transform: translateY(-1px);
  }

  .species-button:active {
    transform: translateY(0);
  }

  .species-button:focus-visible {
    border-color: var(--color-forest-600);
    box-shadow: var(--shadow-md), 0 0 0 3px rgba(30, 126, 75, 0.1);
  }

  .species-name {
    font-size: 1.125rem;
    font-weight: 600;
    color: var(--color-forest-800);
    font-family: var(--font-serif);
    line-height: 1.4;
    text-align: left !important;
  }

  .counts-bar {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 1rem 1.5rem;
    margin-bottom: 1.5rem;
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.75rem;
    box-shadow: var(--shadow-sm);
  }

  .count-item {
    font-size: 0.875rem;
    color: var(--color-text-secondary);
    font-weight: 500;
  }

  .count-total {
    color: var(--color-forest-700);
    font-weight: 600;
  }

  .separator {
    color: var(--color-border);
    font-weight: 300;
  }
</style>
