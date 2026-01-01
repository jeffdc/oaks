<script>
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { base } from '$app/paths';
	import { formatSpeciesName } from '$lib/stores/dataStore.js';
	import { fetchSpeciesFull, ApiError } from '$lib/apiClient.js';
	import SpeciesDetail from '$lib/components/SpeciesDetail.svelte';

	// Local state
	let species = $state(null);
	let isLoading = $state(true);
	let error = $state(null);
	let notFound = $state(false);

	$: speciesName = decodeURIComponent($page.params.name);
	$: sourceParam = $page.url.searchParams.get('source');
	$: initialSourceId = sourceParam ? Number(sourceParam) : null;

	// Fetch species when name changes
	$: if (speciesName) {
		loadSpecies(speciesName);
	}

	async function loadSpecies(name) {
		try {
			isLoading = true;
			error = null;
			notFound = false;
			species = await fetchSpeciesFull(name);
		} catch (err) {
			console.error('Failed to fetch species:', err);
			if (err instanceof ApiError && err.status === 404) {
				notFound = true;
			} else {
				error = err instanceof ApiError ? err.message : 'Failed to load species data';
			}
			species = null;
		} finally {
			isLoading = false;
		}
	}

	async function retry() {
		await loadSpecies(speciesName);
	}
</script>

<svelte:head>
	{#if species}
		<title>{formatSpeciesName(species)} - Oak Compendium</title>
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
		<SpeciesDetail {species} {initialSourceId} />
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
</style>
