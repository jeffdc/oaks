<script>
	import { base } from '$app/paths';
	import { onMount } from 'svelte';
	import { getAllSourcesInfo } from '$lib/stores/dataStore.js';

	let sources = [];
	let isLoading = true;

	onMount(async () => {
		sources = await getAllSourcesInfo();
		isLoading = false;
	});
</script>

<svelte:head>
	<title>Data Sources - Oak Compendium</title>
</svelte:head>

<div class="sources-page">
	<header class="page-header">
		<h1 class="page-title">Data Sources</h1>
		<p class="page-subtitle">
			The Oak Compendium draws from multiple sources to provide comprehensive information about oak species.
		</p>
	</header>

	{#if isLoading}
		<div class="loading">
			<div class="loading-spinner"></div>
			<p>Loading sources...</p>
		</div>
	{:else if sources.length === 0}
		<p class="empty-state">No sources found.</p>
	{:else}
		<div class="sources-grid">
			{#each sources as source}
				<a href="{base}/sources/{source.source_id}/" class="source-card">
					<h2 class="source-name">{source.source_name}</h2>
					{#if source.license}
						<span class="license-badge">{source.license}</span>
					{/if}
					<div class="source-stats">
						<span class="stat">
							<strong>{source.species_count}</strong> species
						</span>
						<span class="stat-separator">·</span>
						<span class="stat">
							<strong>{source.coverage_percent}%</strong> coverage
						</span>
					</div>
					<div class="card-arrow">
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
						</svg>
					</div>
				</a>
			{/each}
		</div>
	{/if}
</div>

<style>
	.sources-page {
		max-width: 48rem;
		margin: 0 auto;
	}

	.page-header {
		margin-bottom: 2rem;
	}

	.page-title {
		font-family: var(--font-serif);
		font-size: 1.875rem;
		font-weight: 700;
		color: var(--color-forest-800);
		margin-bottom: 0.5rem;
	}

	.page-subtitle {
		font-size: 1.0625rem;
		color: var(--color-text-secondary);
		line-height: 1.6;
	}

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		color: var(--color-text-secondary);
	}

	.loading-spinner {
		width: 2rem;
		height: 2rem;
		border: 3px solid var(--color-border);
		border-top-color: var(--color-forest-600);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.empty-state {
		text-align: center;
		padding: 3rem;
		color: var(--color-text-secondary);
	}

	.sources-grid {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.source-card {
		position: relative;
		display: block;
		padding: 1.5rem;
		padding-right: 3rem;
		background-color: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: 0.75rem;
		box-shadow: var(--shadow-sm);
		text-decoration: none;
		transition: all 0.2s;
	}

	.source-card:hover {
		border-color: var(--color-forest-400);
		box-shadow: var(--shadow-md);
		transform: translateY(-1px);
	}

	.source-card:focus-visible {
		outline: none;
		border-color: var(--color-forest-600);
		box-shadow: var(--shadow-md), 0 0 0 3px rgba(30, 126, 75, 0.15);
	}

	.source-name {
		font-family: var(--font-serif);
		font-size: 1.25rem;
		font-weight: 600;
		color: var(--color-forest-800);
		margin-bottom: 0.5rem;
	}

	.license-badge {
		display: inline-block;
		font-size: 0.75rem;
		font-weight: 500;
		padding: 0.1875rem 0.5rem;
		background-color: var(--color-stone-100);
		color: var(--color-text-secondary);
		border-radius: 9999px;
		margin-bottom: 0.75rem;
	}

	.source-stats {
		font-size: 0.9375rem;
		color: var(--color-text-secondary);
	}

	.source-stats strong {
		color: var(--color-forest-700);
		font-weight: 600;
	}

	.stat-separator {
		margin: 0 0.375rem;
		color: var(--color-text-tertiary);
	}

	.card-arrow {
		position: absolute;
		right: 1rem;
		top: 50%;
		transform: translateY(-50%);
		color: var(--color-text-tertiary);
	}

	.source-card:hover .card-arrow {
		color: var(--color-forest-500);
	}
</style>
