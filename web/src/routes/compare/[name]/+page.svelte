<script>
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { formatSpeciesName } from '$lib/stores/dataStore.js';
	import { fetchSpeciesFull, ApiError } from '$lib/apiClient.js';
	import SourceComparison from '$lib/components/SourceComparison.svelte';

	let species = $state(null);
	let isLoading = $state(true);
	let error = $state(null);

	let speciesName = $derived(decodeURIComponent($page.params.name));

	async function loadSpecies(name) {
		try {
			isLoading = true;
			error = null;
			species = await fetchSpeciesFull(name);
		} catch (err) {
			console.error('Failed to fetch species:', err);
			error = err instanceof ApiError ? err.message : 'Failed to load species';
			species = null;
		} finally {
			isLoading = false;
		}
	}

	$effect(() => {
		if (speciesName) {
			loadSpecies(speciesName);
		}
	});
</script>

<svelte:head>
	{#if species}
		<title>Compare Sources - {formatSpeciesName(species)} - Oak Compendium</title>
	{:else}
		<title>Species Not Found - Oak Compendium</title>
	{/if}
</svelte:head>

{#if isLoading}
	<div class="text-center py-16">
		<div class="loading-spinner mx-auto mb-4"></div>
		<p style="color: var(--color-text-secondary);">Loading species...</p>
	</div>
{:else if error}
	<div class="text-center py-16">
		<h1 class="text-2xl font-bold" style="color: var(--color-text-primary);">Error</h1>
		<p class="mt-2" style="color: var(--color-text-secondary);">{error}</p>
	</div>
{:else if species}
	<div class="rounded-xl overflow-hidden" style="background-color: var(--color-surface); box-shadow: var(--shadow-xl);">
		<SourceComparison {species} />
	</div>
{:else}
	<div class="text-center py-16">
		<h1 class="text-2xl font-bold" style="color: var(--color-text-primary);">Species Not Found</h1>
		<p class="mt-2" style="color: var(--color-text-secondary);">Could not find species: {speciesName}</p>
	</div>
{/if}
