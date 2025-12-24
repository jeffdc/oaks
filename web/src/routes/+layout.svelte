<script>
	import { onMount, tick } from 'svelte';
	import { afterNavigate } from '$app/navigation';
	import { updated } from '$app/stores';
	import '../app.css';
	import Header from '$lib/components/Header.svelte';
	import { loadSpeciesData, isLoading, error } from '$lib/stores/dataStore.js';

	let { children } = $props();
	let mainContent;
	let announcer = '';

	onMount(async () => {
		await loadSpeciesData();
	});

	// Manage focus on route changes for accessibility
	afterNavigate(async ({ to }) => {
		// Wait for DOM to update
		await tick();

		// Focus the main content area so screen readers announce new content
		if (mainContent) {
			mainContent.focus();
		}

		// Announce the page change to screen readers
		if (to?.route?.id) {
			const pageName = getPageName(to.route.id);
			announcer = `Navigated to ${pageName}`;
			// Clear announcer after announcement
			setTimeout(() => { announcer = ''; }, 1000);
		}
	});

	function getPageName(routeId) {
		const names = {
			'/': 'home page',
			'/list': 'species list',
			'/about': 'about page',
			'/taxonomy': 'taxonomy browser',
			'/taxonomy/[...path]': 'taxonomy section',
			'/species/[name]': 'species detail',
			'/sources': 'data sources',
			'/sources/[id]': 'source detail'
		};
		return names[routeId] || 'new page';
	}

	function reloadPage() {
		window.location.reload();
	}
</script>

<div class="app min-h-screen" style="background-color: var(--color-background);">
	<!-- Screen reader announcer for route changes -->
	<div class="sr-only" role="status" aria-live="polite" aria-atomic="true">
		{announcer}
	</div>

	<!-- Skip to main content link for keyboard/screen reader users -->
	<a href="#main-content" class="skip-link">Skip to main content</a>

	{#if $updated}
		<div class="update-banner" role="alert">
			<span>A new version is available.</span>
			<button onclick={reloadPage}>Reload</button>
		</div>
	{/if}
	<Header />

	<main id="main-content" bind:this={mainContent} class="max-w-screen-xl mx-auto px-4 sm:px-6 lg:px-12 py-10" tabindex="-1">
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

<style>
	/* Skip link - hidden until focused */
	.skip-link {
		position: absolute;
		top: -100%;
		left: 1rem;
		z-index: 100;
		padding: 0.75rem 1.5rem;
		background-color: var(--color-forest-700);
		color: white;
		font-weight: 600;
		border-radius: 0 0 0.5rem 0.5rem;
		text-decoration: none;
		transition: top 0.2s;
	}

	.skip-link:focus {
		top: 0;
		outline: 2px solid white;
		outline-offset: 2px;
	}

	.update-banner {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 1rem;
		padding: 0.75rem 1rem;
		background-color: var(--color-forest-700);
		color: white;
		font-size: 0.875rem;
	}

	.update-banner button {
		padding: 0.25rem 0.75rem;
		background-color: white;
		color: var(--color-forest-700);
		border-radius: 0.25rem;
		font-weight: 500;
		transition: background-color 0.15s;
	}

	.update-banner button:hover {
		background-color: var(--color-forest-100);
	}
</style>
