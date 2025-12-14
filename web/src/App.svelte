<script>
  import { onMount, onDestroy } from 'svelte';
  import { loadSpeciesData, selectedSpecies, isLoading, error, findSpeciesByName } from './lib/dataStore.js';
  import Search from './lib/Search.svelte';
  import SpeciesList from './lib/SpeciesList.svelte';
  import SpeciesDetail from './lib/SpeciesDetail.svelte';
  import UpdatePrompt from './lib/UpdatePrompt.svelte';

  let view = 'list'; // 'list' or 'detail'

  onMount(async () => {
    try {
      await loadSpeciesData();

      // Initialize history state if not already set
      if (!history.state) {
        history.replaceState({ view: 'list' }, '', window.location.href);
      } else {
        // Restore state from history (e.g., after page reload or back/forward navigation)
        restoreFromHistoryState(history.state);
      }

      // Listen for browser back/forward button
      window.addEventListener('popstate', handlePopState);
    } catch (err) {
      console.error('Failed to load species data:', err);
    }
  });

  onDestroy(() => {
    window.removeEventListener('popstate', handlePopState);
  });

  function handlePopState(event) {
    if (event.state) {
      restoreFromHistoryState(event.state);
    }
  }

  function restoreFromHistoryState(state) {
    view = state.view || 'list';

    if (state.view === 'detail' && state.speciesName) {
      // Find and set the species
      const found = findSpeciesByName(state.speciesName);
      if (found) {
        selectedSpecies.set(found);
      }
    } else {
      selectedSpecies.set(null);
    }
  }

  function handleSelectSpecies(species) {
    selectedSpecies.set(species);
    view = 'detail';

    // Push new state to history
    history.pushState(
      { view: 'detail', speciesName: species.name },
      '',
      `#${species.name}`
    );

    // Scroll to top
    window.scrollTo(0, 0);
  }

  function handleCloseDetail() {
    // Use browser back instead of directly changing state
    history.back();
  }

  function handleNavigate(species) {
    selectedSpecies.set(species);
    view = 'detail';

    // Push new state to history
    history.pushState(
      { view: 'detail', speciesName: species.name },
      '',
      `#${species.name}`
    );

    // Scroll to top
    window.scrollTo(0, 0);
  }
</script>

<div class="app min-h-screen" style="background-color: var(--color-background);">

  <header class="sticky top-0 z-40" style="background: linear-gradient(135deg, var(--color-forest-800) 0%, var(--color-forest-700) 100%); box-shadow: var(--shadow-lg);">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-5">
      {#if view === 'detail'}
        <button
          on:click={handleCloseDetail}
          class="flex items-center gap-2 text-white/90 hover:text-white transition-all duration-200 hover:gap-3 font-medium"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
          </svg>
          <span>Back to List</span>
        </button>
      {:else}
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div class="flex items-center gap-3">
            <img src="/oak-leaf-outline.svg" alt="Oak Leaf" class="w-8 h-12 brightness-0 invert opacity-90" />
            <div>
              <h1 class="text-2xl font-bold text-white" style="font-family: var(--font-serif); letter-spacing: 0.01em;">Quercus Compendium</h1>
              <p class="text-sm text-white/70 mt-0.5">A comprehensive guide to oak species</p>
            </div>
          </div>
          <div class="w-full sm:w-auto sm:flex-1 sm:max-w-md ml-auto">
            <Search />
          </div>
        </div>
      {/if}
    </div>
  </header>


  <main class="max-w-screen-xl mx-auto px-4 sm:px-6 lg:px-12 py-10">
    {#if $isLoading}
      <div class="flex justify-center items-center py-32">
        <div class="text-center">
          <div class="inline-block animate-spin rounded-full h-16 w-16 border-4 border-t-transparent" style="border-color: var(--color-forest-600); border-top-color: transparent;"></div>
          <p class="mt-6 font-medium" style="color: var(--color-text-secondary);">Loading species data...</p>
          <p class="mt-1 text-sm" style="color: var(--color-text-tertiary);">Preparing your oak compendium</p>
        </div>
      </div>
    {:else if $error}
      <div class="rounded-lg p-6" style="background-color: #fef2f2; border-left: 4px solid #dc2626; box-shadow: var(--shadow-md);">
        <div class="flex gap-4">
          <div class="flex-shrink-0">
            <svg class="h-6 w-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
          </div>
          <div>
            <h3 class="text-base font-semibold text-red-900 mb-1">Error loading data</h3>
            <p class="text-sm text-red-700">{$error}</p>
            <button
              on:click={() => window.location.reload()}
              class="mt-3 text-sm font-medium text-red-700 hover:text-red-800 underline"
            >
              Try reloading the page
            </button>
          </div>
        </div>
      </div>
    {:else if view === 'list'}
      <SpeciesList onSelectSpecies={handleSelectSpecies} />
    {:else if view === 'detail' && $selectedSpecies}
      <div class="rounded-xl overflow-hidden" style="background-color: var(--color-surface); box-shadow: var(--shadow-xl);">
        <SpeciesDetail
          species={$selectedSpecies}
          onClose={handleCloseDetail}
          onNavigate={handleNavigate}
        />
      </div>
    {/if}
  </main>

  <UpdatePrompt />
</div>
