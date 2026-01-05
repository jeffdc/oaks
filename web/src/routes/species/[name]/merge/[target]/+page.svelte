<script>
	import { page } from '$app/stores';
	import SpeciesMergeScreen from '$lib/components/SpeciesMergeScreen.svelte';

	// Extract route params
	// [name] is the synonym (will be deleted)
	// [target] is the species that will receive merged data
	let synonymName = $derived(decodeURIComponent($page.params.name));
	let targetName = $derived(decodeURIComponent($page.params.target));
</script>

<svelte:head>
	<title>Merge: {synonymName} → {targetName} - Oak Compendium</title>
</svelte:head>

<SpeciesMergeScreen {synonymName} {targetName} />
