<script>
	import { page } from '$app/stores';
	import { allSpecies, formatSpeciesName } from '$lib/stores/dataStore.js';
	import SpeciesDetail from '$lib/components/SpeciesDetail.svelte';

	$: speciesName = decodeURIComponent($page.params.name);
	$: species = $allSpecies.find(s => s.name === speciesName);
</script>

<svelte:head>
	{#if species}
		<title>{formatSpeciesName(species)} - Quercus Compendium</title>
	{:else}
		<title>Species Not Found - Quercus Compendium</title>
	{/if}
</svelte:head>

{#if species}
	<div class="rounded-xl overflow-hidden" style="background-color: var(--color-surface); box-shadow: var(--shadow-xl);">
		<SpeciesDetail {species} />
	</div>
{:else}
	<div class="text-center py-16">
		<h1 class="text-2xl font-bold" style="color: var(--color-text-primary);">Species Not Found</h1>
		<p class="mt-2" style="color: var(--color-text-secondary);">Could not find species: {speciesName}</p>
	</div>
{/if}
