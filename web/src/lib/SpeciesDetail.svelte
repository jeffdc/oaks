<script>
  import { allSpecies } from './dataStore.js';

  export let species;
  export let onClose;
  export let onNavigate;

  function handleNavigate(speciesName) {
    const targetSpecies = $allSpecies.find(s => s.name === speciesName);
    if (targetSpecies) {
      onNavigate(targetSpecies);
    }
  }

  function getOtherParent(hybrid, currentSpecies) {
    const parent1 = hybrid.parent1?.replace('Quercus ', '').replace('× ', '').trim();
    const parent2 = hybrid.parent2?.replace('Quercus ', '').replace('× ', '').trim();

    if (parent1 && parent1.toLowerCase() !== currentSpecies.toLowerCase()) {
      return parent1;
    } else if (parent2 && parent2.toLowerCase() !== currentSpecies.toLowerCase()) {
      return parent2;
    }
    return null;
  }
</script>

<div class="species-detail">
  <!-- Header -->
  <div class="px-6 py-6" style="background: linear-gradient(135deg, var(--color-forest-50) 0%, var(--color-forest-100) 100%); border-bottom: 2px solid var(--color-forest-200);">
    <div class="flex items-start justify-between gap-4">
      <div class="flex-1">
        <div class="flex items-center gap-2 mb-2">
          {#if species.is_hybrid}
            <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium" style="background-color: var(--color-forest-200); color: var(--color-forest-900);">
              Hybrid
            </span>
          {:else}
            <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium" style="background-color: var(--color-forest-300); color: var(--color-forest-900);">
              Species
            </span>
          {/if}
        </div>
        <h1 class="text-3xl font-bold leading-tight" style="color: var(--color-forest-900); font-family: var(--font-serif);">
          Quercus {#if species.is_hybrid}×{/if} <span class="italic">{species.name}</span>
        </h1>
      </div>
      <button
        on:click={onClose}
        class="close-button flex-shrink-0 p-2 rounded-lg transition-colors duration-200 focus:outline-none"
        aria-label="Close"
      >
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
  </div>

  <!-- Content -->
  <div class="px-6 py-6 space-y-8" style="background-color: var(--color-background);">
    {#if species.author}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
          </svg>
          <span>Authority</span>
        </h2>
        <p class="detail-text">{species.author}</p>
      </section>
    {/if}

    {#if species.is_hybrid && (species.parent1 || species.parent2)}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
          <span>Parent Species</span>
        </h2>
        <div class="space-y-3">
          {#if species.parent_formula}
            <p class="detail-text italic font-medium" style="color: var(--color-forest-700);">{species.parent_formula}</p>
          {/if}
          <ul class="space-y-2">
            {#if species.parent1}
              <li class="parent-link-item">
                <button
                  on:click={() => handleNavigate(species.parent1.replace('Quercus ', ''))}
                  class="species-link"
                >
                  {species.parent1}
                </button>
              </li>
            {/if}
            {#if species.parent2}
              <li class="parent-link-item">
                <button
                  on:click={() => handleNavigate(species.parent2.replace('Quercus ', ''))}
                  class="species-link"
                >
                  {species.parent2}
                </button>
              </li>
            {/if}
          </ul>
        </div>
      </section>
    {/if}

    {#if species.range}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
          <span>Geographic Range</span>
        </h2>
        <p class="detail-text">{species.range}</p>
      </section>
    {/if}

    {#if species.growth_habit}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3 21h18M3 10h18M3 7l9-4 9 4M4 10v11M20 10v11M8 14h.01M12 14h.01M16 14h.01M8 17h.01M12 17h.01M16 17h.01" />
          </svg>
          <span>Growth Habit</span>
        </h2>
        <p class="detail-text">{species.growth_habit}</p>
      </section>
    {/if}

    {#if species.leaves}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
            <path d="M17,8C8,10 5.9,16.17 3.82,21.34L5.71,22L6.66,19.7C7.14,19.87 7.64,20 8,20C19,20 22,3 22,3C21,5 14,5.25 9,6.25C4,7.25 2,11.5 2,13.5C2,15.5 3.75,17.25 3.75,17.25C7,8 17,8 17,8Z" />
          </svg>
          <span>Leaves</span>
        </h2>
        <p class="detail-text">{species.leaves}</p>
      </section>
    {/if}

    {#if species.fruits}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
            <path d="M12,2C12.5,2 13,2.19 13.41,2.59C13.8,3 14,3.5 14,4C14,4.5 13.8,5 13.41,5.41C13,5.8 12.5,6 12,6C11.5,6 11,5.8 10.59,5.41C10.2,5 10,4.5 10,4C10,3.5 10.2,3 10.59,2.59C11,2.19 11.5,2 12,2M12,6C13.1,6 14,6.9 14,8V9.5C15.72,9.5 17.17,10.6 17.71,12.13C18.14,13.38 18.13,14.77 17.66,16C17.19,17.26 16.32,18.23 15.19,18.74C14.06,19.25 12.78,19.25 11.65,18.74C10.5,18.23 9.63,17.26 9.16,16C8.69,14.77 8.68,13.38 9.11,12.13C9.65,10.6 11.1,9.5 12.83,9.5H12V8C12,6.9 12.9,6 12,6M12.13,11.5C11.41,11.5 10.81,11.89 10.54,12.5C10.27,13.11 10.39,13.82 10.85,14.3C11.31,14.78 12,14.94 12.63,14.7C13.26,14.46 13.7,13.86 13.7,13.17C13.7,12.64 13.5,12.13 13.13,11.76C12.76,11.39 12.26,11.5 12.13,11.5Z" />
          </svg>
          <span>Fruits</span>
        </h2>
        <p class="detail-text">{species.fruits}</p>
      </section>
    {/if}

    {#if species.flowers}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
            <path d="M12,22A10,10 0 0,1 2,12A10,10 0 0,1 12,2A10,10 0 0,1 22,12A10,10 0 0,1 12,22M12,4A8,8 0 0,0 4,12A8,8 0 0,0 12,20A8,8 0 0,0 20,12A8,8 0 0,0 12,4M15,10.59V9L12.5,6.5L10,9V10.59L11.29,11.88L10.59,14.59L12,14L13.41,14.59L12.71,11.88L15,10.59Z" />
          </svg>
          <span>Flowers</span>
        </h2>
        <p class="detail-text">{species.flowers}</p>
      </section>
    {/if}

    {#if species.bark_twigs_buds}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
          </svg>
          <span>Bark, Twigs & Buds</span>
        </h2>
        <p class="detail-text">{species.bark_twigs_buds}</p>
      </section>
    {/if}

    {#if species.hardiness_habitat}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span>Hardiness & Habitat</span>
        </h2>
        <p class="detail-text">{species.hardiness_habitat}</p>
      </section>
    {/if}

    {#if species.taxonomy}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <span>Taxonomy</span>
        </h2>
        <dl class="taxonomy-grid">
          {#if species.taxonomy.subgenus}
            <dt>Subgenus:</dt>
            <dd>{species.taxonomy.subgenus}</dd>
          {/if}
          {#if species.taxonomy.section}
            <dt>Section:</dt>
            <dd>{species.taxonomy.section}</dd>
          {/if}
          {#if species.taxonomy.subsection}
            <dt>Subsection:</dt>
            <dd>{species.taxonomy.subsection}</dd>
          {/if}
          {#if species.taxonomy.series}
            <dt>Series:</dt>
            <dd>{species.taxonomy.series}</dd>
          {/if}
        </dl>
      </section>
    {/if}

    {#if species.hybrids && species.hybrids.length > 0}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
          </svg>
          <span>Known Hybrids ({species.hybrids.length})</span>
        </h2>
        <ul class="space-y-3">
          {#each species.hybrids as hybridName}
            {@const hybridSpecies = $allSpecies.find(s => s.name === hybridName)}
            {@const otherParent = hybridSpecies ? getOtherParent(hybridSpecies, species.name) : null}
            <li class="hybrid-item">
              <button
                on:click={() => handleNavigate(hybridName)}
                class="species-link font-semibold"
              >
                Quercus × {hybridName}
              </button>
              {#if otherParent}
                <span class="text-sm" style="color: var(--color-text-secondary);">
                  (with
                  <button
                    on:click={() => handleNavigate(otherParent)}
                    class="species-link-inline"
                  >
                    Quercus {otherParent}
                  </button>)
                </span>
              {/if}
            </li>
          {/each}
        </ul>
      </section>
    {/if}

    {#if species.closely_related_to && species.closely_related_to.length > 0}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01" />
          </svg>
          <span>Closely Related Species</span>
        </h2>
        <ul class="related-species-list">
          {#each species.closely_related_to as relatedName}
            <li>
              <button
                on:click={() => handleNavigate(relatedName)}
                class="species-link"
              >
                Quercus {relatedName}
              </button>
            </li>
          {/each}
        </ul>
      </section>
    {/if}

    {#if species.synonyms && species.synonyms.length > 0}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z" />
          </svg>
          <span>Synonyms ({species.synonyms.length})</span>
        </h2>
        <ul class="space-y-2">
          {#each species.synonyms as synonym}
            <li class="text-sm" style="color: var(--color-text-secondary);">
              <span class="italic font-medium" style="color: var(--color-text-primary);">{synonym.name || synonym}</span>
              {#if synonym.author}
                <span style="color: var(--color-text-tertiary);"> {synonym.author}</span>
              {/if}
            </li>
          {/each}
        </ul>
      </section>
    {/if}

    {#if species.local_names && species.local_names.length > 0}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" />
          </svg>
          <span>Common Names</span>
        </h2>
        <ul class="flex flex-wrap gap-2">
          {#each species.local_names as localName}
            <li class="common-name-tag">
              {localName}
            </li>
          {/each}
        </ul>
      </section>
    {/if}

    {#if species.subspecies_varieties && species.subspecies_varieties.length > 0}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
          </svg>
          <span>Subspecies & Varieties</span>
        </h2>
        <ul class="space-y-2">
          {#each species.subspecies_varieties as variety}
            <li class="text-sm italic" style="color: var(--color-text-secondary);">{variety}</li>
          {/each}
        </ul>
      </section>
    {/if}

    {#if species.conservation_status}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
          </svg>
          <span>Conservation Status</span>
        </h2>
        <span class="conservation-badge">
          {species.conservation_status}
        </span>
      </section>
    {/if}

    {#if species.miscellaneous}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span>Additional Information</span>
        </h2>
        <p class="detail-text text-sm">{species.miscellaneous}</p>
      </section>
    {/if}

    {#if species.url}
      <section class="detail-section">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
          </svg>
          <span>External Links</span>
        </h2>
        <a
          href={species.url}
          target="_blank"
          rel="noopener noreferrer"
          class="external-link"
        >
          Oaks of the World
        </a>
        <a
          href={`https://www.inaturalist.org/search?q=${encodeURIComponent('Quercus ' + species.name)}`}
          target="_blank"
          rel="noopener noreferrer"
          class="external-link"
        >
          iNaturalist
        </a>
      </section>
    {/if}
  </div>
</div>

<style>
  .species-detail {
    background-color: var(--color-surface);
  }

  .detail-section {
    padding: 1.25rem;
    border-radius: 0.75rem;
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    box-shadow: var(--shadow-sm);
  }

  .section-header {
    display: flex;
    align-items: center;
    gap: 0.625rem;
    font-size: 1.125rem;
    font-weight: 600;
    margin-bottom: 1rem;
    color: var(--color-forest-800);
    font-family: var(--font-serif);
  }

  .section-header svg {
    color: var(--color-forest-600);
    flex-shrink: 0;
  }

  .detail-text {
    color: var(--color-text-primary);
    line-height: 1.7;
    font-size: 0.9375rem;
  }

  .species-link {
    color: var(--color-forest-700);
    font-weight: 500;
    text-decoration: none;
    transition: all 0.15s ease;
    border-bottom: 1px solid transparent;
  }

  .species-link:hover {
    color: var(--color-forest-600);
    border-bottom-color: var(--color-forest-400);
  }

  .species-link-inline {
    color: var(--color-forest-700);
    font-weight: 500;
    text-decoration: underline;
    text-decoration-color: var(--color-forest-300);
    transition: all 0.15s ease;
  }

  .species-link-inline:hover {
    color: var(--color-forest-600);
    text-decoration-color: var(--color-forest-500);
  }

  .parent-link-item {
    padding-left: 1rem;
    border-left: 3px solid var(--color-forest-300);
    padding-top: 0.5rem;
    padding-bottom: 0.5rem;
    background: linear-gradient(90deg, var(--color-forest-50) 0%, transparent 100%);
    border-radius: 0.25rem;
  }

  .hybrid-item {
    padding: 0.75rem;
    padding-left: 1rem;
    border-left: 4px solid var(--color-forest-500);
    background: linear-gradient(90deg, var(--color-forest-50) 0%, transparent 100%);
    border-radius: 0.375rem;
  }

  .related-species-list {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
  }

  .taxonomy-grid {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: 0.75rem 1.5rem;
    font-size: 0.9375rem;
  }

  .taxonomy-grid dt {
    font-weight: 500;
    color: var(--color-text-tertiary);
  }

  .taxonomy-grid dd {
    color: var(--color-text-primary);
    font-weight: 500;
  }

  .common-name-tag {
    padding: 0.5rem 1rem;
    border-radius: 9999px;
    font-size: 0.875rem;
    font-weight: 500;
    background-color: var(--color-forest-100);
    color: var(--color-forest-900);
    border: 1px solid var(--color-forest-200);
  }

  .conservation-badge {
    display: inline-flex;
    padding: 0.5rem 1rem;
    border-radius: 9999px;
    font-size: 0.875rem;
    font-weight: 600;
    background-color: #fef3c7;
    color: #92400e;
    border: 1px solid #fcd34d;
  }

  .external-link {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1.25rem;
    border-radius: 0.5rem;
    font-size: 0.9375rem;
    font-weight: 500;
    color: var(--color-forest-700);
    background-color: var(--color-forest-50);
    border: 1.5px solid var(--color-forest-300);
    transition: all 0.2s ease;
    text-decoration: none;
  }

  .external-link:hover {
    background-color: var(--color-forest-100);
    border-color: var(--color-forest-400);
    transform: translateY(-1px);
    box-shadow: var(--shadow-sm);
  }

  .close-button {
    color: var(--color-text-secondary);
    background-color: var(--color-surface);
  }

  .close-button:hover {
    background-color: var(--color-forest-200);
    color: var(--color-forest-900);
  }
</style>
