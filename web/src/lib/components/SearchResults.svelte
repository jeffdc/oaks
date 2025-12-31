<script>
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { goto } from '$app/navigation';
	import { searchQuery, searchResults, searchLoading, searchError, getPrimarySource, forceRefresh } from '$lib/stores/dataStore.js';
	import { canEdit } from '$lib/stores/authStore.js';
	import { toast } from '$lib/stores/toastStore.js';
	import { fetchSpecies, createSpecies, ApiError } from '$lib/apiClient.js';
	import SpeciesEditForm from './SpeciesEditForm.svelte';

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

	// Check if hybrid name already has the hybrid symbol
	function needsHybridSymbol(species) {
		const name = species.scientific_name || species.name;
		return species.is_hybrid && !name.startsWith('×');
	}

	// Get species name (supports both API formats)
	function getSpeciesName(species) {
		return species.scientific_name || species.name;
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
	let isSearching = $derived($searchQuery && $searchQuery.length > 0);

	// Extract search results components
	let searchSpecies = $derived($searchResults.species || []);
	let searchTaxa = $derived($searchResults.taxa || []);
	let searchSources = $derived($searchResults.sources || []);
	let searchCounts = $derived($searchResults.counts || { species: 0, taxa: 0, sources: 0, total: 0 });

	// For browsing mode, use all species
	let displaySpecies = $derived(isSearching ? searchSpecies : allSpecies);

	// Combined loading state
	let isLoading = $derived(isSearching ? $searchLoading : isLoadingList);

	// Combined error state
	let error = $derived(isSearching ? $searchError : listError);

	// Compute browse mode counts (species only)
	let browseCounts = $derived({
		speciesCount: allSpecies.filter(s => !s.is_hybrid).length,
		hybridCount: allSpecies.filter(s => s.is_hybrid).length,
		total: allSpecies.length
	});

	// Has any results to display
	let hasResults = $derived(
		isSearching
			? searchCounts.total > 0
			: allSpecies.length > 0
	);

	// Section visibility in search mode
	let hasTaxaResults = $derived(isSearching && searchTaxa.length > 0);
	let hasSourceResults = $derived(isSearching && searchSources.length > 0);
	let hasSpeciesResults = $derived(displaySpecies.length > 0);

	// Create species modal state
	let showCreateForm = $state(false);

	function handleAddClick() {
		showCreateForm = true;
	}

	// Handle save from create form
	async function handleCreateSpecies(formData) {
		try {
			await createSpecies(formData);

			// Success: show toast and refresh data
			toast.success(`Species "${formData.name}" created successfully`);

			// Refresh data in background
			forceRefresh().catch(err => {
				console.warn('Background refresh failed:', err);
			});

			// Navigate to the new species detail page
			goto(`${base}/species/${encodeURIComponent(formData.name)}/`);

			return null; // No errors - signal success to form
		} catch (err) {
			if (err instanceof ApiError) {
				// 400 with field errors - return them so form can display
				if (err.status === 400 && err.fieldErrors) {
					return err.fieldErrors;
				}

				// Other API errors - show toast
				toast.error(`Failed to create species: ${err.message}`);
			} else {
				toast.error('Failed to create species: Network error');
			}

			throw err; // Re-throw so form stays open
		}
	}
</script>

<div class="species-list">
	<!-- Loading state -->
	{#if isLoading}
		<div class="py-20 text-center" style="background-color: var(--color-surface); border-radius: 1rem; box-shadow: var(--shadow-sm);">
			<div class="loading-spinner mx-auto mb-4"></div>
			<p class="text-lg font-medium" style="color: var(--color-text-secondary);">Loading...</p>
		</div>
	<!-- Error state -->
	{:else if error}
		<div class="py-20 text-center" style="background-color: var(--color-surface); border-radius: 1rem; box-shadow: var(--shadow-sm);">
			<svg class="w-16 h-16 mx-auto mb-4" style="color: var(--color-error, #dc2626);" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
				<path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
			</svg>
			<p class="text-lg font-medium mb-1" style="color: var(--color-text-primary);">Unable to load data</p>
			<p class="text-sm mb-4" style="color: var(--color-text-secondary);">{error}</p>
			<button onclick={retry} class="retry-button">
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
					<path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
				</svg>
				Try again
			</button>
		</div>
	{:else if hasResults}
		<!-- Counts bar -->
		<div class="card counts-bar">
			{#if isSearching}
				<!-- Search mode: show all result types -->
				{#if searchCounts.taxa > 0}
					<span class="count-item">{searchCounts.taxa} tax{searchCounts.taxa === 1 ? 'on' : 'a'}</span>
					<span class="separator">|</span>
				{/if}
				{#if searchCounts.sources > 0}
					<span class="count-item">{searchCounts.sources} source{searchCounts.sources !== 1 ? 's' : ''}</span>
					<span class="separator">|</span>
				{/if}
				<span class="count-item">{searchCounts.species} species</span>
				<span class="separator">|</span>
				<span class="count-item count-total">{searchCounts.total} total</span>
			{:else}
				<!-- Browse mode: species counts only -->
				<span class="count-item">{browseCounts.speciesCount} species</span>
				<span class="separator">|</span>
				<span class="count-item">{browseCounts.hybridCount} hybrids</span>
				<span class="separator">|</span>
				<span class="count-item count-total">{browseCounts.total} total</span>
			{/if}

			{#if $canEdit}
				<button
					type="button"
					class="add-species-btn"
					title="Add new species"
					onclick={handleAddClick}
				>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
						<line x1="12" y1="5" x2="12" y2="19"></line>
						<line x1="5" y1="12" x2="19" y2="12"></line>
					</svg>
					<span>Add Species</span>
				</button>
			{/if}
		</div>

		<!-- Taxa results (search mode only) -->
		{#if hasTaxaResults}
			<div class="results-section">
				<h3 class="section-label">Taxa</h3>
				<ul class="card results-list">
					{#each searchTaxa as taxon (taxon.name + taxon.level)}
						<li>
							<a
								href="{base}/taxonomy/{taxon.level}/{encodeURIComponent(taxon.name)}/"
								class="result-row taxon-row"
							>
								<div class="result-main">
									<span class="result-icon taxon-icon">
										<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
											<path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z" />
										</svg>
									</span>
									<span class="taxon-name">{taxon.name}</span>
									<span class="taxon-level">{taxon.level}</span>
								</div>
								{#if taxon.species_count > 0}
									<div class="result-meta">{taxon.species_count} species</div>
								{/if}
							</a>
						</li>
					{/each}
				</ul>
			</div>
		{/if}

		<!-- Source results (search mode only) -->
		{#if hasSourceResults}
			<div class="results-section">
				<h3 class="section-label">Sources</h3>
				<ul class="card results-list">
					{#each searchSources as source (source.id)}
						<li>
							<a
								href="{base}/sources/{source.id}/"
								class="result-row source-row"
							>
								<div class="result-main">
									<span class="result-icon source-icon">
										<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
											<path stroke-linecap="round" stroke-linejoin="round" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
										</svg>
									</span>
									<span class="source-name">{source.name}</span>
									{#if source.author}<span class="source-author">{source.author}</span>{/if}
								</div>
								{#if source.year}
									<div class="result-meta">{source.year}</div>
								{/if}
							</a>
						</li>
					{/each}
				</ul>
			</div>
		{/if}

		<!-- Species results -->
		{#if hasSpeciesResults}
			{#if isSearching && (hasTaxaResults || hasSourceResults)}
				<div class="results-section">
					<h3 class="section-label">Species</h3>
					<ul class="card results-list">
						{#each displaySpecies as species (getSpeciesName(species))}
							{@const commonNames = getCommonNames(species)}
							<li>
								<a
									href="{base}/species/{encodeURIComponent(getSpeciesName(species))}/"
									class="result-row"
								>
									<div class="result-main">
										<span class="result-icon species-icon">
											<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
												<path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12c0 1.268-.63 2.39-1.593 3.068a3.745 3.745 0 0 1-1.043 3.296 3.745 3.745 0 0 1-3.296 1.043A3.745 3.745 0 0 1 12 21c-1.268 0-2.39-.63-3.068-1.593a3.746 3.746 0 0 1-3.296-1.043 3.745 3.745 0 0 1-1.043-3.296A3.745 3.745 0 0 1 3 12c0-1.268.63-2.39 1.593-3.068a3.745 3.745 0 0 1 1.043-3.296 3.746 3.746 0 0 1 3.296-1.043A3.746 3.746 0 0 1 12 3c1.268 0 2.39.63 3.068 1.593a3.746 3.746 0 0 1 3.296 1.043 3.746 3.746 0 0 1 1.043 3.296A3.745 3.745 0 0 1 21 12Z" />
											</svg>
										</span>
										<span class="species-name">Quercus {#if needsHybridSymbol(species)}× {/if}<span class="italic">{getSpeciesName(species)}</span></span>
										{#if species.author}<span class="species-author">{species.author}</span>{/if}
									</div>
									{#if commonNames.length > 0}
										<div class="common-names">{commonNames.join(', ')}</div>
									{/if}
								</a>
							</li>
						{/each}
					</ul>
				</div>
			{:else}
				<!-- No section header needed when species is the only result type -->
				<ul class="card results-list">
					{#each displaySpecies as species (getSpeciesName(species))}
						{@const commonNames = getCommonNames(species)}
						<li>
							<a
								href="{base}/species/{encodeURIComponent(getSpeciesName(species))}/"
								class="result-row"
							>
								<div class="result-main">
									<span class="species-name">Quercus {#if needsHybridSymbol(species)}× {/if}<span class="italic">{getSpeciesName(species)}</span></span>
									{#if species.author}<span class="species-author">{species.author}</span>{/if}
								</div>
								{#if commonNames.length > 0}
									<div class="common-names">{commonNames.join(', ')}</div>
								{/if}
							</a>
						</li>
					{/each}
				</ul>
			{/if}
		{/if}
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

<!-- Create Species Modal -->
{#if showCreateForm}
	<SpeciesEditForm
		species={null}
		isOpen={showCreateForm}
		onClose={() => showCreateForm = false}
		onSave={handleCreateSpecies}
	/>
{/if}

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
		align-items: center;
		gap: 0.5rem;
	}

	.result-icon {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 1.5rem;
		height: 1.5rem;
		border-radius: 0.25rem;
		flex-shrink: 0;
	}

	.taxon-icon {
		background-color: var(--color-forest-100);
		color: var(--color-forest-700);
	}

	.source-icon {
		background-color: var(--color-oak-100, #fef3c7);
		color: var(--color-oak-brown);
	}

	.species-icon {
		background-color: var(--color-forest-100);
		color: var(--color-forest-600);
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

	.taxon-name {
		font-size: 1rem;
		font-weight: 600;
		color: var(--color-forest-800);
		font-family: var(--font-sans);
	}

	.taxon-level {
		font-size: 0.75rem;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.03em;
		color: var(--color-text-tertiary);
		background-color: var(--color-forest-50);
		padding: 0.125rem 0.375rem;
		border-radius: 0.25rem;
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

	.common-names {
		font-size: 0.875rem;
		color: var(--color-text-tertiary);
		margin-top: 0.25rem;
		padding-left: 2rem;
	}

	.result-meta {
		font-size: 0.8125rem;
		color: var(--color-text-tertiary);
		margin-top: 0.25rem;
		padding-left: 2rem;
	}

	.counts-bar {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
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

	/* Section styling for grouped results */
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

	/* Add Species button */
	.add-species-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.375rem;
		margin-left: auto;
		padding: 0.5rem 0.875rem;
		border-radius: 0.5rem;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.15s ease;
		color: var(--color-forest-700);
		background-color: var(--color-forest-100);
		border: 1px solid var(--color-forest-200);
	}

	.add-species-btn:hover {
		background-color: var(--color-forest-200);
		border-color: var(--color-forest-300);
	}

	.add-species-btn:focus-visible {
		outline: 2px solid var(--color-forest-500);
		outline-offset: 2px;
	}

	.add-species-btn svg {
		flex-shrink: 0;
	}

	/* Hide button text on small screens */
	@media (max-width: 640px) {
		.add-species-btn span {
			display: none;
		}

		.add-species-btn {
			padding: 0.5rem;
		}
	}
</style>
