<script>
    import { taxonomyTree, sortTaxonomyKeys, formatSpeciesName, speciesCounts } from "./dataStore.js";

    export let onSelectSpecies;

    // Local expansion state - resets on view change
    let expanded = {};

    function toggleExpand(key) {
        // Reassign to trigger Svelte reactivity
        expanded = { ...expanded, [key]: !expanded[key] };
    }

    // Sort species: non-hybrids first (alphabetically), then hybrids (alphabetically)
    function sortSpecies(species) {
        return [...species].sort((a, b) => {
            // Hybrids sort after non-hybrids
            if (a.is_hybrid !== b.is_hybrid) {
                return a.is_hybrid ? 1 : -1;
            }
            // Within same type, sort alphabetically
            return a.name.localeCompare(b.name);
        });
    }

    // Separate subgenera from species without subgenus
    $: subgenera = sortTaxonomyKeys(Object.keys($taxonomyTree)).filter((k) => k && k !== "null");
    $: noSubgenusData = $taxonomyTree["null"] || $taxonomyTree[null];
</script>

<div class="taxonomy-tree">
    <!-- Genus header -->
    <div class="genus-header">
        <h2 class="genus-title">Genus <em>Quercus</em></h2>
        <p class="genus-subtitle">{$speciesCounts.total} species and hybrids</p>
    </div>

    <!-- Subgenera section -->
    <div class="subgenera-section">
        {#each subgenera as subgenus}
            {@const subgenusData = $taxonomyTree[subgenus]}
            {@const subgenusKey = subgenus}
            <!-- Subgenus Level -->
            <div class="tree-node subgenus-node">
                <button class="node-header" on:click={() => toggleExpand(subgenusKey)}>
                    <span class="expand-icon">{expanded[subgenusKey] ? "▼" : "▶"}</span>
                    <span class="node-label">Subgenus {subgenus}</span>
                    <span class="node-count">({subgenusData.count})</span>
                </button>

                {#if expanded[subgenusKey]}
                    <div class="node-children">
                        {#each sortTaxonomyKeys(Object.keys(subgenusData.sections)) as section}
                            {@const sectionData = subgenusData.sections[section]}
                            {@const sectionKey = `${subgenus}/${section}`}
                            {@const hasSection = section && section !== "null"}

                            {#if hasSection}
                                <!-- Section Level -->
                                <div class="tree-node section-node">
                                    <button class="node-header" on:click={() => toggleExpand(sectionKey)}>
                                        <span class="expand-icon">{expanded[sectionKey] ? "▼" : "▶"}</span>
                                        <span class="node-label">Section {section}</span>
                                        <span class="node-count">({sectionData.count})</span>
                                    </button>

                                    {#if expanded[sectionKey]}
                                        <div class="node-children">
                                            {#each sortTaxonomyKeys(Object.keys(sectionData.subsections)) as subsection}
                                                {@const subsectionData = sectionData.subsections[subsection]}
                                                {@const subsectionKey = `${sectionKey}/${subsection}`}
                                                {@const hasSubsection = subsection && subsection !== "null"}

                                                {#if hasSubsection}
                                                    <!-- Subsection Level (when present) -->
                                                    <div class="tree-node subsection-node">
                                                        <button
                                                            class="node-header"
                                                            on:click={() => toggleExpand(subsectionKey)}
                                                        >
                                                            <span class="expand-icon"
                                                                >{expanded[subsectionKey] ? "▼" : "▶"}</span
                                                            >
                                                            <span class="node-label">Subsection {subsection}</span>
                                                            <span class="node-count">({subsectionData.count})</span>
                                                        </button>

                                                        {#if expanded[subsectionKey]}
                                                            <div class="node-children">
                                                                {#each sortTaxonomyKeys(Object.keys(subsectionData.complexes)) as complex}
                                                                    {@const complexData =
                                                                        subsectionData.complexes[complex]}
                                                                    {@const complexKey = `${subsectionKey}/${complex}`}
                                                                    {@const hasComplex = complex && complex !== "null"}

                                                                    {#if hasComplex}
                                                                        <!-- Complex Level (when present) -->
                                                                        <div class="tree-node complex-node">
                                                                            <button
                                                                                class="node-header"
                                                                                on:click={() =>
                                                                                    toggleExpand(complexKey)}
                                                                            >
                                                                                <span class="expand-icon"
                                                                                    >{expanded[complexKey]
                                                                                        ? "▼"
                                                                                        : "▶"}</span
                                                                                >
                                                                                <span class="node-label"
                                                                                    >Complex Q. {complex}</span
                                                                                >
                                                                                <span class="node-count"
                                                                                    >({complexData.species
                                                                                        .length})</span
                                                                                >
                                                                            </button>

                                                                            {#if expanded[complexKey]}
                                                                                <div class="node-children">
                                                                                    {#each sortSpecies(complexData.species) as species}
                                                                                        <button
                                                                                            class="species-leaf"
                                                                                            on:click={() =>
                                                                                                onSelectSpecies(
                                                                                                    species,
                                                                                                )}
                                                                                        >
                                                                                            <span class="species-name">
                                                                                                {formatSpeciesName(
                                                                                                    species,
                                                                                                    {
                                                                                                        abbreviated: true,
                                                                                                    },
                                                                                                )}
                                                                                            </span>
                                                                                        </button>
                                                                                    {/each}
                                                                                </div>
                                                                            {/if}
                                                                        </div>
                                                                    {:else}
                                                                        <!-- Species without complex - show directly under subsection -->
                                                                        {#each sortSpecies(complexData.species) as species}
                                                                            <button
                                                                                class="species-leaf"
                                                                                on:click={() =>
                                                                                    onSelectSpecies(species)}
                                                                            >
                                                                                <span class="species-name">
                                                                                    {formatSpeciesName(species, {
                                                                                        abbreviated: true,
                                                                                    })}
                                                                                </span>
                                                                            </button>
                                                                        {/each}
                                                                    {/if}
                                                                {/each}
                                                            </div>
                                                        {/if}
                                                    </div>
                                                {:else}
                                                    <!-- Species without subsection - show directly under section -->
                                                    {#each sortTaxonomyKeys(Object.keys(subsectionData.complexes)) as complex}
                                                        {@const complexData = subsectionData.complexes[complex]}
                                                        {#each sortSpecies(complexData.species) as species}
                                                            <button
                                                                class="species-leaf"
                                                                on:click={() => onSelectSpecies(species)}
                                                            >
                                                                <span class="species-name">
                                                                    {formatSpeciesName(species, { abbreviated: true })}
                                                                </span>
                                                            </button>
                                                        {/each}
                                                    {/each}
                                                {/if}
                                            {/each}
                                        </div>
                                    {/if}
                                </div>
                            {:else}
                                <!-- Species without section - show directly under subgenus -->
                                {#each sortTaxonomyKeys(Object.keys(sectionData.subsections)) as subsection}
                                    {@const subsectionData = sectionData.subsections[subsection]}
                                    {#each sortTaxonomyKeys(Object.keys(subsectionData.complexes)) as complex}
                                        {@const complexData = subsectionData.complexes[complex]}
                                        {#each sortSpecies(complexData.species) as species}
                                            <button class="species-leaf" on:click={() => onSelectSpecies(species)}>
                                                <span class="species-name">
                                                    {formatSpeciesName(species, { abbreviated: true })}
                                                </span>
                                            </button>
                                        {/each}
                                    {/each}
                                {/each}
                            {/if}
                        {/each}
                    </div>
                {/if}
            </div>
        {/each}
    </div>

    <!-- Species without subgenus assignment -->
    {#if noSubgenusData}
        <div class="other-species-section">
            <div class="other-species-header">
                <span class="other-species-count">{noSubgenusData.count} species that are not part of a Subgenus</span>
            </div>
            <div class="other-species-list">
                {#each sortTaxonomyKeys(Object.keys(noSubgenusData.sections)) as section}
                    {@const sectionData = noSubgenusData.sections[section]}
                    {#each sortTaxonomyKeys(Object.keys(sectionData.subsections)) as subsection}
                        {@const subsectionData = sectionData.subsections[subsection]}
                        {#each sortTaxonomyKeys(Object.keys(subsectionData.complexes)) as complex}
                            {@const complexData = subsectionData.complexes[complex]}
                            {#each sortSpecies(complexData.species) as species}
                                <button class="species-leaf-flat" on:click={() => onSelectSpecies(species)}>
                                    {formatSpeciesName(species, { abbreviated: true })}
                                </button>
                            {/each}
                        {/each}
                    {/each}
                {/each}
            </div>
        </div>
    {/if}
</div>

<style>
    .taxonomy-tree {
        padding: 1rem;
    }

    /* Genus header */
    .genus-header {
        text-align: center;
        padding: 1.5rem 2rem;
        margin-bottom: 1.5rem;
        background: linear-gradient(135deg, var(--color-forest-50) 0%, var(--color-forest-100) 100%);
        border: 1px solid var(--color-forest-200);
        border-radius: 1rem;
    }

    .genus-title {
        font-family: var(--font-serif);
        font-size: 1.75rem;
        font-weight: 700;
        color: var(--color-forest-900);
        margin: 0 0 0.375rem 0;
    }

    .genus-subtitle {
        font-size: 0.9375rem;
        color: var(--color-text-secondary);
        margin: 0;
    }

    /* Subgenera section */
    .subgenera-section {
        background-color: var(--color-surface);
        border: 1px solid var(--color-border);
        border-radius: 0.75rem;
        padding: 1rem;
        box-shadow: var(--shadow-sm);
        margin-bottom: 1.5rem;
    }

    /* Other species section (without subgenus) */
    .other-species-section {
        background-color: var(--color-background);
        border: 1px dashed var(--color-border);
        border-radius: 0.75rem;
        padding: 1rem;
    }

    .other-species-header {
        padding: 0.5rem 0.75rem;
        margin-bottom: 0.75rem;
    }

    .other-species-count {
        font-size: 0.875rem;
        font-weight: 500;
        color: var(--color-text-tertiary);
    }

    .other-species-list {
        display: flex;
        flex-wrap: wrap;
        gap: 0.5rem;
    }

    .species-leaf-flat {
        padding: 0.375rem 0.75rem;
        font-size: 0.875rem;
        font-style: italic;
        color: var(--color-forest-700);
        background-color: var(--color-surface);
        border: 1px solid var(--color-border);
        border-radius: 0.375rem;
        cursor: pointer;
        transition: all 0.15s ease;
        font-family: inherit;
    }

    .species-leaf-flat:hover {
        background-color: var(--color-forest-50);
        border-color: var(--color-forest-300);
    }

    .tree-node {
        margin-left: 0;
    }

    .node-children {
        margin-left: 1.5rem;
        border-left: 1px solid var(--color-border);
        padding-left: 0.75rem;
    }

    .node-header {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        width: 100%;
        padding: 0.5rem 0.75rem;
        text-align: left;
        border-radius: 0.375rem;
        transition: background-color 0.15s ease;
        background: none;
        border: none;
        cursor: pointer;
        font-family: inherit;
        font-size: inherit;
    }

    .node-header:hover {
        background-color: var(--color-forest-50);
    }

    .expand-icon {
        font-size: 0.625rem;
        color: var(--color-text-tertiary);
        width: 1rem;
        flex-shrink: 0;
    }

    .node-label {
        font-weight: 500;
        color: var(--color-text-primary);
    }

    .subgenus-node > .node-header .node-label {
        font-weight: 600;
        color: var(--color-forest-800);
        font-family: var(--font-serif);
    }

    .section-node > .node-header .node-label {
        color: var(--color-forest-700);
    }

    .subsection-node > .node-header .node-label {
        font-style: italic;
        color: var(--color-text-secondary);
    }

    .complex-node > .node-header .node-label {
        font-style: italic;
        font-weight: 400;
        color: var(--color-text-secondary);
    }

    .node-count {
        font-size: 0.75rem;
        color: var(--color-text-tertiary);
        font-weight: 400;
    }

    .species-leaf {
        display: block;
        width: 100%;
        padding: 0.375rem 0.75rem;
        padding-left: 2rem;
        text-align: left;
        border-radius: 0.375rem;
        transition: all 0.15s ease;
        background: none;
        border: none;
        cursor: pointer;
        font-family: inherit;
        font-size: inherit;
    }

    .species-leaf:hover {
        background-color: var(--color-forest-100);
    }

    .species-name {
        font-style: italic;
        color: var(--color-forest-700);
        font-size: 0.9375rem;
    }
</style>
