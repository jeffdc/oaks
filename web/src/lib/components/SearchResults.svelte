<script>
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { searchQuery, searchResults, searchLoading, searchError, getPrimarySource } from '$lib/stores/dataStore.js';
	import { fetchSpecies, ApiError } from '$lib/apiClient.js';

	// Local state for species list (for browsing mode - no search query)
	let allSpecies = $state([]);
	let isLoadingList = $state(true);
	let listError = $state(null);

	// Fetch all species on mount (for browsing when no search query)
	onMount(async () => {
		try {
			isLoadingList = true;
			listError = null;
			const species = await fetchSpecies();
			// Sort by scientific_name
			allSpecies = species.sort((a, b) =>
				a.scientific_name.localeCompare(b.scientific_name)
			);
		} catch (err) {
			console.error('Failed to fetch species:', err);
			listError = err instanceof ApiError ? err.message : 'Failed to load species data';
		} finally {
			isLoadingList = false;
		}
	});

	// Retry function for error state
	async function retry() {
		try {
			isLoadingList = true;
			listError = null;
			const species = await fetchSpecies();
			allSpecies = species.sort((a, b) =>
				a.scientific_name.localeCompare(b.scientific_name)
			);
		} catch (err) {
			console.error('Failed to fetch species:', err);
			listError = err instanceof ApiError ? err.message : 'Failed to load species data';
		} finally {
			isLoadingList = false;
		}
	}

	// Check if hybrid name already has × symbol (most do)
	function needsHybridSymbol(species) {
		return species.is_hybrid && !species.scientific_name.startsWith('×');
	}

	// Get common names - search results may have local_names directly
	function getCommonNames(species) {
		// Search results may include local_names from primary source
		if (species.local_names && species.local_names.length > 0) {
			return species.local_names;
		}
		// Fall back to getting from primary source (for full species data)
		const source = getPrimarySource(species);
		return source?.local_names || [];
	}

	// Check if we're in search mode (have a query)
	$: isSearching = $searchQuery && $searchQuery.length > 0;

	// Use search results when searching, otherwise show all species
	$: displaySpecies = isSearching ? $searchResults : allSpecies;

	// Combined loading state
	$: isLoading = isSearching ? $searchLoading : isLoadingList;

	// Combined error state
	$: error = isSearching ? $searchError : listError;

	// Compute counts from displayed species
	$: speciesCounts = {
		speciesCount: displaySpecies.filter(s => !s.is_hybrid).length,
		hybridCount: displaySpecies.filter(s => s.is_hybrid).length,
		total: displaySpecies.length
	};

	$: hasSpeciesResults = displaySpecies.length > 0;
</script>

<div class="species-list">
	<!-- Loading state -->
	{#if isLoading}
		<div class="py-20 text-center" style="background-color: var(--color-surface); border-radius: 1rem; box-shadow: var(--shadow-sm);">
			<div class="loading-spinner mx-auto mb-4"></div>
			<p class="text-lg font-medium" style="color: var(--color-text-secondary);">Loading species...</p>
		</div>
	<!-- Error state -->
	{:else if error}
		<div class="py-20 text-center" style="background-color: var(--color-surface); border-radius: 1rem; box-shadow: var(--shadow-sm);">
			<svg class="w-16 h-16 mx-auto mb-4" style="color: var(--color-error, #dc2626);" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
				<path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
			</svg>
			<p class="text-lg font-medium mb-1" style="color: var(--color-text-primary);">Unable to load species</p>
			<p class="text-sm mb-4" style="color: var(--color-text-secondary);">{error}</p>
			<button onclick={retry} class="retry-button">
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
					<path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
				</svg>
				Try again
			</button>
		</div>
	{:else if hasSpeciesResults}
		<div class="card counts-bar">
			<span class="count-item">{speciesCounts.speciesCount} species</span>
			<span class="separator">|</span>
			<span class="count-item">{speciesCounts.hybridCount} hybrids</span>
			<span class="separator">|</span>
			<span class="count-item count-total">{speciesCounts.total} total</span>
		</div>

		<!-- Species results -->
		<ul class="card results-list">
			{#each displaySpecies as species (species.scientific_name)}
				{@const commonNames = getCommonNames(species)}
				<li>
					<a
						href="{base}/species/{encodeURIComponent(species.scientific_name)}/"
						class="result-row"
					>
						<div class="result-main">
							<span class="species-name">Quercus {#if needsHybridSymbol(species)}× {/if}<span class="italic">{species.scientific_name}</span></span>
							{#if species.author}<span class="species-author">{species.author}</span>{/if}
						</div>
						{#if commonNames.length > 0}
							<div class="common-names">{commonNames.join(', ')}</div>
						{/if}
					</a>
				</li>
			{/each}
		</ul>
	{:else}
		<!-- No results state -->
		<div class="py-20 text-center" style="background-color: var(--color-surface); border-radius: 1rem; box-shadow: var(--shadow-sm);">
			<svg class="w-16 h-16 mx-auto mb-4" style="color: var(--color-text-tertiary);" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
				<path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607zM10.5 7.5v6m3-3h-6" />
			</svg>
			<p class="text-lg font-medium mb-1" style="color: var(--color-text-secondary);">
				{#if isSearching}No results found{:else}No species found{/if}
			</p>
			<p class="text-sm" style="color: var(--color-text-tertiary);">
				{#if isSearching}Try adjusting your search terms{:else}Species data could not be loaded{/if}
			</p>
		</div>
	{/if}
</div>

<style>
	.results-list {
		list-style: none;
		padding: 0;
		margin: 0;
		overflow: hidden;
	}

	.results-list li {
		border-bottom: 1px solid var(--color-border);
	}

	.results-list li:last-child {
		border-bottom: none;
	}

	.result-row {
		display: block;
		padding: 0.75rem 1rem;
		text-decoration: none;
		transition: background-color 0.15s ease;
	}

	.result-row:hover {
		background-color: var(--color-forest-50);
	}

	.result-row:focus-visible {
		outline: none;
		background-color: var(--color-forest-50);
		box-shadow: inset 0 0 0 2px var(--color-forest-400);
	}

	.result-main {
		display: flex;
		flex-wrap: wrap;
		align-items: baseline;
		gap: 0.5rem;
	}

	.species-name {
		font-size: 1rem;
		font-weight: 600;
		color: var(--color-forest-800);
		font-family: var(--font-serif);
	}

	.species-author {
		font-size: 0.875rem;
		font-weight: 400;
		color: var(--color-text-secondary);
		font-family: var(--font-sans);
	}

	.common-names {
		font-size: 0.875rem;
		color: var(--color-text-tertiary);
		margin-top: 0.25rem;
	}

	.counts-bar {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem 1.5rem;
		margin-bottom: 1.5rem;
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

	/* Section styling for mixed results */
	.results-section {
		margin-bottom: 1.5rem;
	}

	.section-label {
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: var(--color-text-tertiary);
		margin-bottom: 0.5rem;
		padding-left: 0.25rem;
	}

	/* Source-specific styles */
	.source-row .result-main {
		align-items: center;
	}

	.source-icon {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 1.5rem;
		height: 1.5rem;
		background-color: var(--color-border-light);
		border-radius: 0.25rem;
		color: var(--color-oak-brown);
		flex-shrink: 0;
	}

	.source-name {
		font-size: 1rem;
		font-weight: 600;
		color: var(--color-oak-brown);
		font-family: var(--font-sans);
	}

	.source-author {
		font-size: 0.875rem;
		font-weight: 400;
		color: var(--color-text-secondary);
	}

	.source-meta {
		font-size: 0.8125rem;
		color: var(--color-text-tertiary);
		margin-top: 0.25rem;
		padding-left: 2rem;
	}

	/* Retry button for error state */
	.retry-button {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.625rem 1.25rem;
		background-color: var(--color-forest-600);
		color: white;
		font-size: 0.9375rem;
		font-weight: 500;
		border: none;
		border-radius: 0.5rem;
		cursor: pointer;
		transition: all 0.15s ease;
	}

	.retry-button:hover {
		background-color: var(--color-forest-700);
		transform: translateY(-1px);
	}

	.retry-button:focus-visible {
		outline: none;
		box-shadow: 0 0 0 3px rgba(30, 126, 75, 0.3);
	}
</style>
