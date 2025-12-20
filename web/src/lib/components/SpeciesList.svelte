<script>
	import { base } from '$app/paths';
	import { filteredSpecies, speciesCounts, getPrimarySource } from '$lib/stores/dataStore.js';

	// Check if hybrid name already has × symbol (most do)
	function needsHybridSymbol(species) {
		return species.is_hybrid && !species.name.startsWith('×');
	}

	// Get common names from the primary source
	function getCommonNames(species) {
		const source = getPrimarySource(species);
		return source?.local_names || [];
	}
</script>

<div class="species-list">
	{#if $filteredSpecies.length > 0}
		<div class="counts-bar">
			<span class="count-item">{$speciesCounts.speciesCount} species</span>
			<span class="separator">|</span>
			<span class="count-item">{$speciesCounts.hybridCount} hybrids</span>
			<span class="separator">|</span>
			<span class="count-item count-total">{$speciesCounts.total} total</span>
		</div>
	{/if}

	{#if $filteredSpecies.length === 0}
		<div class="py-20 text-center" style="background-color: var(--color-surface); border-radius: 1rem; box-shadow: var(--shadow-sm);">
			<svg class="w-16 h-16 mx-auto mb-4" style="color: var(--color-text-tertiary);" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
				<path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607zM10.5 7.5v6m3-3h-6" />
			</svg>
			<p class="text-lg font-medium mb-1" style="color: var(--color-text-secondary);">No species found</p>
			<p class="text-sm" style="color: var(--color-text-tertiary);">Try adjusting your search terms</p>
		</div>
	{:else}
		<ul class="results-list">
			{#each $filteredSpecies as species (species.name)}
				{@const commonNames = getCommonNames(species)}
				<li>
					<a
						href="{base}/species/{encodeURIComponent(species.name)}/"
						class="result-row"
					>
						<div class="result-main">
							<span class="species-name">Quercus {#if needsHybridSymbol(species)}× {/if}<span class="italic">{species.name}</span></span>
							{#if species.author}<span class="species-author">{species.author}</span>{/if}
						</div>
						{#if commonNames.length > 0}
							<div class="common-names">{commonNames.join(', ')}</div>
						{/if}
					</a>
				</li>
			{/each}
		</ul>
	{/if}
</div>

<style>
	.results-list {
		list-style: none;
		padding: 0;
		margin: 0;
		background-color: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: 0.75rem;
		box-shadow: var(--shadow-sm);
		overflow: hidden;
	}

	.results-list li {
		border-bottom: 1px solid var(--color-border);
	}

	.results-list li:last-child {
		border-bottom: none;
	}

	.result-row {
		display: block;
		padding: 0.75rem 1rem;
		text-decoration: none;
		transition: background-color 0.15s ease;
	}

	.result-row:hover {
		background-color: var(--color-forest-50);
	}

	.result-row:focus-visible {
		outline: none;
		background-color: var(--color-forest-50);
		box-shadow: inset 0 0 0 2px var(--color-forest-400);
	}

	.result-main {
		display: flex;
		flex-wrap: wrap;
		align-items: baseline;
		gap: 0.5rem;
	}

	.species-name {
		font-size: 1rem;
		font-weight: 600;
		color: var(--color-forest-800);
		font-family: var(--font-serif);
	}

	.species-author {
		font-size: 0.875rem;
		font-weight: 400;
		color: var(--color-text-secondary);
		font-family: var(--font-sans);
	}

	.common-names {
		font-size: 0.875rem;
		color: var(--color-text-tertiary);
		margin-top: 0.25rem;
	}

	.counts-bar {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem 1.5rem;
		margin-bottom: 1.5rem;
		background-color: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: 0.75rem;
		box-shadow: var(--shadow-sm);
	}

	.count-item {
		font-size: 0.875rem;
		color: var(--color-text-secondary);
		font-weight: 500;
	}

	.count-total {
		color: var(--color-forest-700);
		font-weight: 600;
	}

	.separator {
		color: var(--color-border);
		font-weight: 300;
	}
</style>
