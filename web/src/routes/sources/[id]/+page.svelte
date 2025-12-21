<script>
	import { page } from '$app/stores';
	import SourceDetail from '$lib/components/SourceDetail.svelte';
</script>

<svelte:head>
	<title>Source - Oak Compendium</title>
</svelte:head>

<div class="rounded-xl overflow-hidden" style="background-color: var(--color-surface); box-shadow: var(--shadow-xl); padding: 2rem;">
	<SourceDetail sourceId={$page.params.id} />
</div>
