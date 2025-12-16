<script>
  import { onMount, onDestroy } from 'svelte';
  import { loadSpeciesData, selectedSpecies, isLoading, error, findSpeciesByName, searchQuery } from './lib/dataStore.js';
  import Header from './lib/Header.svelte';
  import SpeciesList from './lib/SpeciesList.svelte';
  import SpeciesDetail from './lib/SpeciesDetail.svelte';
  import TaxonomyTree from './lib/TaxonomyTree.svelte';
  import TaxonView from './lib/TaxonView.svelte';
  import UpdatePrompt from './lib/UpdatePrompt.svelte';

  let view = 'list'; // 'list', 'taxonomy', 'taxon', or 'detail'
  let browseMode = 'list'; // 'list' or 'taxonomy' - remembers preferred browse mode
  let taxonPath = []; // Path for taxon view, e.g., ['Quercus', 'Quercus', 'Albae']

  // Auto-switch to list when searching (from any view including detail)
  // When search is cleared, return to previous view
  $: effectiveView = $searchQuery ? 'list' :
                     view === 'detail' ? 'detail' :
                     view === 'taxon' ? 'taxon' :
                     browseMode;

  onMount(async () => {
    try {
      await loadSpeciesData();

      // Parse initial URL hash
      const initialState = parseUrlHash(window.location.hash);

      // Initialize history state if not already set
      if (!history.state) {
        history.replaceState(initialState, '', window.location.href);
        restoreFromHistoryState(initialState);
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

  function parseUrlHash(hash) {
    if (!hash || hash === '#') {
      return { view: 'list' };
    }

    const path = hash.slice(1); // Remove leading #

    // Check for taxonomy paths: taxonomy/Subgenus/Section/...
    if (path.startsWith('taxonomy/')) {
      const segments = path.slice(9).split('/').filter(s => s); // Remove 'taxonomy/' prefix
      if (segments.length > 0) {
        return { view: 'taxon', taxonPath: segments };
      }
      return { view: 'taxonomy', browseMode: 'taxonomy' };
    }

    if (path === 'taxonomy') {
      return { view: 'taxonomy', browseMode: 'taxonomy' };
    }

    // Otherwise treat as species name
    return { view: 'detail', speciesName: decodeURIComponent(path) };
  }

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

    // Restore browseMode if present
    if (state.browseMode) {
      browseMode = state.browseMode;
    }

    // Restore taxon path if present
    if (state.taxonPath) {
      taxonPath = state.taxonPath;
    } else {
      taxonPath = [];
    }

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

  function setBrowseMode(mode) {
    browseMode = mode;
    view = mode;
    history.pushState({ view: mode, browseMode: mode }, '', mode === 'taxonomy' ? '#taxonomy' : '#');
  }

  function handleGoHome() {
    searchQuery.set('');
    selectedSpecies.set(null);
    view = 'list';
    browseMode = 'list';
    taxonPath = [];
    history.pushState({ view: 'list', browseMode: 'list' }, '', '#');
    window.scrollTo(0, 0);
  }

  function handleSelectSpecies(species) {
    searchQuery.set('');  // Clear search so detail view shows
    selectedSpecies.set(species);
    view = 'detail';

    // Push new state to history (include browseMode for back navigation)
    history.pushState(
      { view: 'detail', speciesName: species.name, browseMode },
      '',
      `#${species.name}`
    );

    // Scroll to top
    window.scrollTo(0, 0);
  }

  function handleNavigate(species) {
    searchQuery.set('');  // Clear search so detail view shows
    selectedSpecies.set(species);
    view = 'detail';

    // Push new state to history (include browseMode for back navigation)
    history.pushState(
      { view: 'detail', speciesName: species.name, browseMode },
      '',
      `#${species.name}`
    );

    // Scroll to top
    window.scrollTo(0, 0);
  }

  function handleNavigateToTaxon(pathOrObject) {
    // Handle both array paths (from TaxonView) and object paths (from SpeciesDetail)
    let newPath;

    if (Array.isArray(pathOrObject)) {
      newPath = pathOrObject;
    } else {
      // Convert object format { subgenus, section, ... } to array
      newPath = [];
      if (pathOrObject.subgenus) newPath.push(pathOrObject.subgenus);
      if (pathOrObject.section) newPath.push(pathOrObject.section);
      if (pathOrObject.subsection) newPath.push(pathOrObject.subsection);
      if (pathOrObject.complex) newPath.push(pathOrObject.complex);
    }

    // Clear search when navigating to taxon
    searchQuery.set('');

    if (newPath.length === 0) {
      // Navigate to taxonomy tree view
      browseMode = 'taxonomy';
      view = 'taxonomy';
      taxonPath = [];
      selectedSpecies.set(null);

      history.pushState(
        { view: 'taxonomy', browseMode: 'taxonomy' },
        '',
        '#taxonomy'
      );
    } else {
      // Navigate to taxon page
      view = 'taxon';
      taxonPath = newPath;
      selectedSpecies.set(null);

      const url = '#taxonomy/' + newPath.map(encodeURIComponent).join('/');
      history.pushState(
        { view: 'taxon', taxonPath: newPath },
        '',
        url
      );
    }

    // Scroll to top
    window.scrollTo(0, 0);
  }
</script>

<div class="app min-h-screen" style="background-color: var(--color-background);">

  <Header onGoHome={handleGoHome} />


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
    {:else if effectiveView === 'list'}
      <SpeciesList onSelectSpecies={handleSelectSpecies} />
    {:else if effectiveView === 'taxonomy'}
      <TaxonomyTree onSelectSpecies={handleSelectSpecies} />
    {:else if effectiveView === 'taxon'}
      <TaxonView
        {taxonPath}
        onSelectSpecies={handleSelectSpecies}
        onNavigateToTaxon={handleNavigateToTaxon}
        onGoHome={handleGoHome}
      />
    {:else if effectiveView === 'detail' && $selectedSpecies}
      <div class="rounded-xl overflow-hidden" style="background-color: var(--color-surface); box-shadow: var(--shadow-xl);">
        <SpeciesDetail
          species={$selectedSpecies}
          onNavigate={handleNavigate}
          onNavigateToTaxon={handleNavigateToTaxon}
          onGoHome={handleGoHome}
        />
      </div>
    {/if}
  </main>

  <UpdatePrompt />
</div>

