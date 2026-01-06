<script>
	import { page } from '$app/stores';
	import { base } from '$app/paths';
	import { goto } from '$app/navigation';
	import { formatSpeciesName } from '$lib/stores/dataStore.js';
	import { fetchSpeciesFull, fetchSpeciesByName, ApiError } from '$lib/apiClient.js';
	import SpeciesDetail from '$lib/components/SpeciesDetail.svelte';

	// Local state
	let species = $state(null);
	let isLoading = $state(true);
	let error = $state(null);
	let notFound = $state(false);
	let lastLoadedName = $state('');

	// Synonym disambiguation state
	let showDisambiguation = $state(false);
	let disambiguationMatches = $state([]);
	let disambiguationLoading = $state(false);
	let disambiguationSpecies = $state([]);

	// Derived values
	let speciesName = $derived(decodeURIComponent($page.params.name));
	let sourceParam = $derived($page.url.searchParams.get('source'));
	let initialSourceId = $derived(sourceParam ? Number(sourceParam) : null);

	// Effect to fetch species when name changes
	$effect(() => {
		if (speciesName && speciesName !== lastLoadedName) {
			lastLoadedName = speciesName;
			loadSpecies(speciesName);
		}
	});

	async function loadSpecies(name) {
		try {
			isLoading = true;
			error = null;
			notFound = false;
			showDisambiguation = false;
			disambiguationMatches = [];
			disambiguationSpecies = [];
			species = await fetchSpeciesFull(name);
		} catch (err) {
			console.error('Failed to fetch species:', err);
			if (err instanceof ApiError && err.status === 404) {
				// Check for synonym redirect
				if (err.code === 'SYNONYM_REDIRECT' && err.details?.synonym_of) {
					// Redirect to target species (replaceState so back button doesn't return here)
					goto(`${base}/species/${encodeURIComponent(err.details.synonym_of)}/`, {
						replaceState: true
					});
					return;
				}

				// Check for ambiguous synonym
				if (err.code === 'AMBIGUOUS_SYNONYM' && err.details?.matches) {
					disambiguationMatches = err.details.matches;
					showDisambiguation = true;
					loadDisambiguationData(err.details.matches);
				} else {
					notFound = true;
				}
			} else {
				error = err instanceof ApiError ? err.message : 'Failed to load species data';
			}
			species = null;
		} finally {
			isLoading = false;
		}
	}

	async function loadDisambiguationData(matches) {
		disambiguationLoading = true;
		try {
			// Fetch basic info for each matching species to help user distinguish
			const results = await Promise.all(
				matches.map(async (name) => {
					try {
						return await fetchSpeciesByName(name);
					} catch {
						// Return minimal info if fetch fails
						return { scientific_name: name };
					}
				})
			);
			disambiguationSpecies = results;
		} catch (err) {
			console.error('Failed to load disambiguation data:', err);
			// Still show matches even without extra info
			disambiguationSpecies = matches.map(name => ({ scientific_name: name }));
		} finally {
			disambiguationLoading = false;
		}
	}

	async function retry() {
		await loadSpecies(speciesName);
	}
</script>

<svelte:head>
	{#if species}
		<title>{formatSpeciesName(species)} - Oak Compendium</title>
	{:else if showDisambiguation}
		<title>"{speciesName}" matches multiple species - Oak Compendium</title>
	{:else if notFound}
		<title>Species Not Found - Oak Compendium</title>
	{:else}
		<title>Loading... - Oak Compendium</title>
	{/if}
</svelte:head>

<!-- Loading state -->
{#if isLoading}
	<div class="loading-container">
		<div class="loading-spinner"></div>
		<p class="loading-text">Loading species...</p>
	</div>
<!-- Error state -->
{:else if error}
	<div class="error-container">
		<svg class="error-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
			<path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
		</svg>
		<p class="error-title">Unable to load species</p>
		<p class="error-message">{error}</p>
		<button onclick={retry} class="retry-button">
			<svg class="retry-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
				<path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
			</svg>
			Try again
		</button>
	</div>
<!-- Disambiguation state (ambiguous synonym) -->
{:else if showDisambiguation}
	<div class="disambiguation-container">
		<svg class="disambiguation-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
			<path stroke-linecap="round" stroke-linejoin="round" d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z" />
		</svg>
		<h1 class="disambiguation-title">"{speciesName}" matches multiple species</h1>
		<p class="disambiguation-message">
			This name appears as a synonym in multiple species. Which did you mean?
		</p>

		{#if disambiguationLoading}
			<div class="loading-matches">
				<div class="loading-spinner"></div>
				<span>Loading species info...</span>
			</div>
		{:else}
			<ul class="matches-list">
				{#each disambiguationSpecies as sp}
					<li class="match-item">
						<a href="{base}/species/{encodeURIComponent(sp.scientific_name)}/" class="match-link">
							<span class="match-name">
								{#if sp.is_hybrid}× {/if}{sp.scientific_name}
							</span>
							{#if sp.section || sp.author}
								<span class="match-details">
									{#if sp.section}Section {sp.section}{/if}
									{#if sp.section && sp.author} · {/if}
									{#if sp.author}{sp.author}{/if}
								</span>
							{/if}
						</a>
					</li>
				{/each}
			</ul>
		{/if}

		<a href="{base}/list/" class="search-link">Or search for a different species</a>
	</div>
<!-- Not found state -->
{:else if notFound}
	<div class="not-found-container">
		<svg class="not-found-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
			<path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
		</svg>
		<h1 class="not-found-title">Species Not Found</h1>
		<p class="not-found-message">Could not find species: {speciesName}</p>
		<a href="{base}/list/" class="back-link">← Back to species list</a>
	</div>
<!-- Species detail -->
{:else if species}
	<div class="rounded-xl overflow-hidden" style="background-color: var(--color-surface); box-shadow: var(--shadow-xl);">
		<SpeciesDetail {species} {initialSourceId} onDataChange={() => loadSpecies(speciesName)} />
	</div>
{/if}

<style>
	.loading-container {
		padding: 5rem 1.5rem;
		text-align: center;
		background-color: var(--color-surface);
		border-radius: 1rem;
		box-shadow: var(--shadow-sm);
	}

	.loading-text {
		font-size: 1.125rem;
		font-weight: 500;
		color: var(--color-text-secondary);
		margin-top: 1rem;
	}

	.error-container {
		padding: 5rem 1.5rem;
		text-align: center;
		background-color: var(--color-surface);
		border-radius: 1rem;
		box-shadow: var(--shadow-sm);
	}

	.error-icon {
		width: 4rem;
		height: 4rem;
		color: var(--color-error, #dc2626);
		margin: 0 auto 1rem;
	}

	.error-title {
		font-size: 1.125rem;
		font-weight: 500;
		color: var(--color-text-primary);
		margin-bottom: 0.25rem;
	}

	.error-message {
		font-size: 0.875rem;
		color: var(--color-text-secondary);
		margin-bottom: 1rem;
	}

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

	.retry-icon {
		width: 1rem;
		height: 1rem;
	}

	.not-found-container {
		padding: 5rem 1.5rem;
		text-align: center;
		background-color: var(--color-surface);
		border-radius: 1rem;
		box-shadow: var(--shadow-sm);
	}

	.not-found-icon {
		width: 4rem;
		height: 4rem;
		color: var(--color-text-tertiary);
		margin: 0 auto 1rem;
	}

	.not-found-title {
		font-size: 1.5rem;
		font-weight: 700;
		color: var(--color-text-primary);
		margin-bottom: 0.5rem;
	}

	.not-found-message {
		font-size: 0.9375rem;
		color: var(--color-text-secondary);
		margin-bottom: 1.5rem;
	}

	.back-link {
		display: inline-flex;
		align-items: center;
		color: var(--color-forest-600);
		font-weight: 500;
		text-decoration: none;
		transition: color 0.15s ease;
	}

	.back-link:hover {
		color: var(--color-forest-700);
	}

	/* Disambiguation state */
	.disambiguation-container {
		padding: 3rem 1.5rem;
		text-align: center;
		background-color: var(--color-surface);
		border-radius: 1rem;
		box-shadow: var(--shadow-sm);
	}

	.disambiguation-icon {
		width: 4rem;
		height: 4rem;
		color: var(--color-forest-500);
		margin: 0 auto 1rem;
	}

	.disambiguation-title {
		font-size: 1.25rem;
		font-weight: 700;
		color: var(--color-text-primary);
		margin-bottom: 0.5rem;
	}

	.disambiguation-message {
		font-size: 0.9375rem;
		color: var(--color-text-secondary);
		margin-bottom: 1.5rem;
	}

	.loading-matches {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		padding: 1rem;
		color: var(--color-text-secondary);
		font-size: 0.875rem;
	}

	.matches-list {
		list-style: none;
		padding: 0;
		margin: 0 auto 1.5rem;
		max-width: 400px;
		text-align: left;
	}

	.match-item {
		border-bottom: 1px solid var(--color-border);
	}

	.match-item:last-child {
		border-bottom: none;
	}

	.match-link {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		padding: 0.875rem 1rem;
		text-decoration: none;
		transition: background-color 0.15s ease;
	}

	.match-link:hover {
		background-color: var(--color-forest-50);
	}

	.match-name {
		font-family: var(--font-serif);
		font-style: italic;
		font-size: 1.125rem;
		color: var(--color-forest-700);
		font-weight: 500;
	}

	.match-details {
		font-size: 0.8125rem;
		color: var(--color-text-tertiary);
		font-style: normal;
	}

	.search-link {
		display: inline-block;
		color: var(--color-forest-600);
		font-size: 0.875rem;
		text-decoration: none;
	}

	.search-link:hover {
		text-decoration: underline;
	}
</style>
