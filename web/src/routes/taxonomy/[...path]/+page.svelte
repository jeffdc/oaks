<script>
	import { page } from '$app/stores';
	import TaxonView from '$lib/components/TaxonView.svelte';

	$: taxonPath = $page.params.path ? $page.params.path.split('/').filter(Boolean).map(decodeURIComponent) : [];
	$: taxonName = taxonPath[taxonPath.length - 1] || 'Taxonomy';
</script>

<svelte:head>
	<title>{taxonName} - Quercus Compendium</title>
</svelte:head>

<TaxonView {taxonPath} />
