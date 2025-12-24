<script>
	import { base } from '$app/paths';
	import { allSpecies, totalCounts, dataSource, forceRefresh, getPrimarySource, getAllSourcesInfo } from '$lib/stores/dataStore.js';
	import { onMount } from 'svelte';

	let featuredSpecies = null;
	let featuredSource = null;
	let sources = [];
	let isRefreshing = false;

	async function handleForceRefresh() {
		if (isRefreshing) return;
		isRefreshing = true;
		try {
			await forceRefresh();
			// Reload sources after refresh
			const allSources = await getAllSourcesInfo();
			sources = allSources.sort((a, b) => {
				if (a.source_id === 3) return -1;
				if (b.source_id === 3) return 1;
				const nameA = a.source_name || '';
				const nameB = b.source_name || '';
				return nameA.localeCompare(nameB);
			});
			pickFeaturedSpecies();
		} finally {
			isRefreshing = false;
		}
	}

	// Pick a random non-hybrid species on mount and load sources
	onMount(async () => {
		pickFeaturedSpecies();
		const allSources = await getAllSourcesInfo();
		// Sort: Oak Compendium (ID 3) first, then alphabetical by name
		sources = allSources.sort((a, b) => {
			if (a.source_id === 3) return -1;
			if (b.source_id === 3) return 1;
			const nameA = a.source_name || '';
			const nameB = b.source_name || '';
			return nameA.localeCompare(nameB);
		});
	});

	function pickFeaturedSpecies() {
		const species = $allSpecies.filter(s => !s.is_hybrid && s.range);
		if (species.length > 0) {
			const randomIndex = Math.floor(Math.random() * species.length);
			featuredSpecies = species[randomIndex];
			featuredSource = getPrimarySource(featuredSpecies);
		}
	}
</script>

<div class="landing-page">
	<!-- Welcome section -->
	<section class="welcome-section">
		<h2 class="welcome-title">Explore the World of Oaks</h2>
		<p class="welcome-subtitle">
			A comprehensive database of <strong>{$totalCounts.speciesCount}</strong> oak species
			and <strong>{$totalCounts.hybridCount}</strong> hybrids from around the globe.
		</p>
	</section>

	<!-- Featured species -->
	{#if featuredSpecies}
		<section class="featured-section">
			<div class="section-header">
				<h3 class="section-title">Featured Species</h3>
				<button class="shuffle-btn" on:click={pickFeaturedSpecies} aria-label="Show another random species">
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
						<path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
					</svg>
				</button>
			</div>
			<a href="{base}/species/{encodeURIComponent(featuredSpecies.name)}/" class="featured-card">
				<div class="featured-content">
					<h4 class="featured-name">
						Quercus <span class="italic">{featuredSpecies.name}</span>
					</h4>
					{#if featuredSpecies.author}
						<p class="featured-author">{featuredSpecies.author}</p>
					{/if}
					{#if featuredSource?.range || featuredSpecies.range}
						<div class="featured-range">
							<svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
								<path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
								<path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
							</svg>
							<span>{featuredSource?.range || featuredSpecies.range}</span>
						</div>
					{/if}
					{#if featuredSpecies.taxonomy?.section}
						<div class="featured-taxonomy">
							Section {featuredSpecies.taxonomy.section}
							{#if featuredSpecies.taxonomy.subgenus}
								<span class="taxonomy-separator">·</span>
								Subgenus {featuredSpecies.taxonomy.subgenus}
							{/if}
						</div>
					{/if}
				</div>
				<div class="featured-arrow">
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
						<path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
					</svg>
				</div>
			</a>
		</section>
	{/if}

	<!-- Browse options -->
	<section class="browse-section">
		<h3 class="section-title">What would you like to do?</h3>
		<div class="browse-options">
			<a href="{base}/taxonomy/" class="browse-card">
				<div class="browse-icon">
					<svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
						<path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z" />
					</svg>
				</div>
				<div class="browse-text">
					<h4 class="browse-title">Taxonomy Tree</h4>
					<p class="browse-description">Explore by subgenus, section, and more</p>
				</div>
				<svg class="browse-arrow" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
					<path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
				</svg>
			</a>

			<div class="browse-card browse-card-disabled">
				<div class="browse-icon browse-icon-disabled">
					<svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
						<path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
					</svg>
				</div>
				<div class="browse-text">
					<h4 class="browse-title browse-title-disabled">
						Identification
						<span class="coming-soon-badge">Coming Soon</span>
					</h4>
					<p class="browse-description">Identify oaks by their characteristics</p>
				</div>
			</div>
		</div>
	</section>

	<!-- Data sources -->
	{#if sources.length > 0}
		<section class="sources-section">
			<h3 class="section-title">Data Sources</h3>
			<div class="sources-list">
				{#each sources as source}
					<a href="{base}/sources/{source.source_id}/" class="source-item" class:source-item-primary={source.source_id === 3}>
						<div class="source-info">
							<span class="source-name">{source.source_name}</span>
							{#if source.source_id === 3}
								<span class="primary-badge">Primary</span>
							{/if}
							<span class="source-stats">{source.species_count} species</span>
						</div>
						<svg class="source-arrow" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
						</svg>
					</a>
				{/each}
			</div>
		</section>
	{/if}

	<!-- Data version info -->
	<section class="version-section">
		<div class="version-info">
			<span class="version-label">Data version:</span>
			<span class="version-value">{$dataSource.version || 'Loading...'}</span>
			<button
				class="refresh-btn"
				on:click={handleForceRefresh}
				disabled={isRefreshing}
				title="Force refresh data from server"
			>
				{#if isRefreshing}
					<svg class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
						<path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
					</svg>
				{:else}
					<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
						<path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
					</svg>
				{/if}
				Refresh
			</button>
		</div>
	</section>
</div>

<style>
	.landing-page {
		max-width: 48rem;
		margin: 0 auto;
	}

	.welcome-section {
		text-align: center;
		margin-bottom: 2.5rem;
	}

	.welcome-title {
		font-family: var(--font-serif);
		font-size: 1.875rem;
		font-weight: 700;
		color: var(--color-forest-800);
		margin-bottom: 0.75rem;
	}

	.welcome-subtitle {
		font-size: 1.125rem;
		color: var(--color-text-secondary);
		line-height: 1.6;
	}

	.welcome-subtitle strong {
		color: var(--color-forest-700);
		font-weight: 600;
	}

	.section-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 1rem;
	}

	.section-title {
		font-family: var(--font-serif);
		font-size: 1.25rem;
		font-weight: 600;
		color: var(--color-text-primary);
	}

	.shuffle-btn {
		padding: 0.5rem;
		border-radius: 0.5rem;
		color: var(--color-text-tertiary);
		transition: all 0.2s;
	}

	.shuffle-btn:hover {
		background-color: var(--color-surface);
		color: var(--color-forest-600);
	}

	.shuffle-btn:focus-visible {
		outline: none;
		background-color: var(--color-surface);
		color: var(--color-forest-600);
		box-shadow: 0 0 0 2px var(--color-forest-600);
	}

	.featured-section {
		margin-bottom: 2.5rem;
	}

	.featured-card {
		width: 100%;
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 1.5rem;
		background-color: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: 1rem;
		box-shadow: var(--shadow-md);
		text-align: left;
		text-decoration: none;
		transition: all 0.2s;
	}

	.featured-card:hover {
		border-color: var(--color-forest-400);
		box-shadow: var(--shadow-lg);
		transform: translateY(-2px);
	}

	.featured-card:focus-visible {
		outline: none;
		border-color: var(--color-forest-600);
		box-shadow: var(--shadow-lg), 0 0 0 3px rgba(30, 126, 75, 0.15);
	}

	.featured-content {
		flex: 1;
	}

	.featured-name {
		font-family: var(--font-serif);
		font-size: 1.375rem;
		font-weight: 600;
		color: var(--color-forest-800);
		margin-bottom: 0.375rem;
	}

	.featured-author {
		font-size: 0.9375rem;
		color: var(--color-text-secondary);
		margin-bottom: 0.75rem;
	}

	.featured-range {
		display: flex;
		align-items: flex-start;
		gap: 0.5rem;
		font-size: 0.9375rem;
		color: var(--color-text-primary);
		margin-bottom: 0.5rem;
	}

	.featured-range svg {
		color: var(--color-forest-600);
		margin-top: 0.125rem;
	}

	.featured-taxonomy {
		font-size: 0.875rem;
		color: var(--color-text-tertiary);
	}

	.taxonomy-separator {
		margin: 0 0.375rem;
	}

	.featured-arrow {
		flex-shrink: 0;
		color: var(--color-forest-500);
	}

	.browse-section {
		margin-bottom: 2rem;
	}

	.browse-section .section-title {
		margin-bottom: 1rem;
	}

	.browse-options {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.browse-card {
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 1.25rem;
		background-color: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: 0.75rem;
		box-shadow: var(--shadow-sm);
		text-align: left;
		text-decoration: none;
		transition: all 0.2s;
	}

	.browse-card:hover {
		border-color: var(--color-forest-400);
		box-shadow: var(--shadow-md);
		transform: translateY(-1px);
	}

	.browse-card:focus-visible {
		outline: none;
		border-color: var(--color-forest-600);
		box-shadow: var(--shadow-md), 0 0 0 3px rgba(30, 126, 75, 0.15);
	}

	.browse-icon {
		flex-shrink: 0;
		width: 3rem;
		height: 3rem;
		display: flex;
		align-items: center;
		justify-content: center;
		background-color: var(--color-forest-50);
		border-radius: 0.75rem;
		color: var(--color-forest-600);
	}

	.browse-text {
		flex: 1;
	}

	.browse-title {
		font-weight: 600;
		font-size: 1.0625rem;
		color: var(--color-text-primary);
		margin-bottom: 0.25rem;
	}

	.browse-description {
		font-size: 0.875rem;
		color: var(--color-text-secondary);
	}

	.browse-arrow {
		flex-shrink: 0;
		width: 1.25rem;
		height: 1.25rem;
		color: var(--color-text-tertiary);
	}

	.browse-card:hover .browse-arrow {
		color: var(--color-forest-500);
	}

	.browse-card-disabled {
		cursor: default;
		opacity: 0.7;
	}

	.browse-card-disabled:hover {
		border-color: var(--color-border);
		box-shadow: var(--shadow-sm);
		transform: none;
	}

	.browse-icon-disabled {
		background-color: var(--color-stone-100);
		color: var(--color-text-tertiary);
	}

	.browse-title-disabled {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.coming-soon-badge {
		font-size: 0.6875rem;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.025em;
		padding: 0.125rem 0.5rem;
		background-color: var(--color-stone-200);
		color: var(--color-text-tertiary);
		border-radius: 9999px;
	}

	.sources-section {
		margin-bottom: 2rem;
	}

	.sources-section .section-title {
		margin-bottom: 1rem;
	}

	.sources-list {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.source-item {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.875rem 1rem;
		background-color: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: 0.5rem;
		text-decoration: none;
		transition: all 0.2s;
	}

	.source-item:hover {
		border-color: var(--color-forest-400);
		background-color: var(--color-forest-50);
	}

	.source-item:focus-visible {
		outline: none;
		border-color: var(--color-forest-600);
		box-shadow: 0 0 0 3px rgba(30, 126, 75, 0.15);
	}

	.source-info {
		display: flex;
		align-items: baseline;
		gap: 0.75rem;
	}

	.source-name {
		font-weight: 500;
		color: var(--color-forest-700);
	}

	.source-stats {
		font-size: 0.875rem;
		color: var(--color-text-tertiary);
	}

	.source-arrow {
		width: 1.25rem;
		height: 1.25rem;
		color: var(--color-text-tertiary);
		flex-shrink: 0;
	}

	.source-item:hover .source-arrow {
		color: var(--color-forest-500);
	}

	.source-item-primary {
		background-color: var(--color-forest-50);
		border-color: var(--color-forest-300);
		box-shadow: var(--shadow-sm);
	}

	.source-item-primary .source-name {
		color: var(--color-forest-800);
		font-weight: 600;
	}

	.source-item-primary:hover {
		border-color: var(--color-forest-500);
		background-color: var(--color-forest-100);
	}

	.primary-badge {
		font-size: 0.6875rem;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.025em;
		padding: 0.125rem 0.5rem;
		background-color: var(--color-forest-600);
		color: white;
		border-radius: 9999px;
	}

	.version-section {
		margin-top: 2rem;
		padding-top: 1.5rem;
		border-top: 1px solid var(--color-border);
	}

	.version-info {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		font-size: 0.75rem;
		color: var(--color-text-tertiary);
	}

	.version-label {
		font-weight: 500;
	}

	.version-value {
		font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
	}

	.refresh-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		padding: 0.25rem 0.5rem;
		margin-left: 0.5rem;
		font-size: 0.75rem;
		color: var(--color-forest-600);
		background-color: transparent;
		border: 1px solid var(--color-forest-300);
		border-radius: 0.25rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.refresh-btn:hover:not(:disabled) {
		background-color: var(--color-forest-50);
		border-color: var(--color-forest-400);
	}

	.refresh-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.animate-spin {
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		from { transform: rotate(0deg); }
		to { transform: rotate(360deg); }
	}

	@media (min-width: 640px) {
		.browse-options {
			flex-direction: row;
		}

		.browse-card {
			flex: 1;
			flex-direction: column;
			text-align: center;
			padding: 1.5rem;
		}

		.browse-icon {
			width: 4rem;
			height: 4rem;
			margin-bottom: 0.5rem;
		}

		.browse-text {
			text-align: center;
		}

		.browse-arrow {
			display: none;
		}

		.browse-title-disabled {
			justify-content: center;
		}
	}
</style>
