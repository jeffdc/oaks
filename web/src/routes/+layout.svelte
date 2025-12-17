<script>
	import { onMount } from 'svelte';
	import '../app.css';
	import Header from '$lib/components/Header.svelte';
	import { loadSpeciesData, isLoading, error } from '$lib/stores/dataStore.js';

	let { children } = $props();

	onMount(async () => {
		await loadSpeciesData();
	});
</script>

<div class="app min-h-screen" style="background-color: var(--color-background);">
	<Header />

	<main class="max-w-screen-xl mx-auto px-4 sm:px-6 lg:px-12 py-10">
		{#if $isLoading}
			<div class="flex justify-center items-center py-32">
				<div class="text-center">
					<div class="inline-block animate-spin rounded-full h-16 w-16 border-4 border-t-transparent" style="border-color: var(--color-forest-600); border-top-color: transparent;"></div>
					<p class="mt-6 font-medium" style="color: var(--color-text-secondary);">Loading species data...</p>
				</div>
			</div>
		{:else if $error}
			<div class="rounded-lg p-6" style="background-color: #fef2f2; border-left: 4px solid #dc2626;">
				<h3 class="text-base font-semibold text-red-900 mb-1">Error loading data</h3>
				<p class="text-sm text-red-700">{$error}</p>
			</div>
		{:else}
			{@render children()}
		{/if}
	</main>
</div>
