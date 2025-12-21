<script>
  import { base } from '$app/paths';
  import { marked } from 'marked';
  import { allSpecies, getPrimarySource, getAllSources, getSourceCompleteness, formatSpeciesName } from '$lib/stores/dataStore.js';

  // Configure marked for safe rendering
  marked.setOptions({
    breaks: true,  // Convert \n to <br>
    gfm: true,     // GitHub Flavored Markdown
  });

  export let species;
  export let initialSourceId = null;

  // Source selection state
  let selectedSourceId = null;

  // Get all sources and determine selected source
  $: sources = getAllSources(species);
  $: {
    // Reset selection when species changes
    if (species) {
      // Use initialSourceId if provided and valid, otherwise fall back to primary source
      if (initialSourceId && sources.some(s => s.source_id === initialSourceId)) {
        selectedSourceId = initialSourceId;
      } else {
        const primary = getPrimarySource(species);
        selectedSourceId = primary?.source_id ?? null;
      }
    }
  }
  $: selectedSource = sources.find(s => s.source_id === selectedSourceId) || null;

  // Build species detail URL
  function getSpeciesUrl(speciesName) {
    return `${base}/species/${encodeURIComponent(speciesName)}/`;
  }

  function getOtherParent(hybrid, currentSpecies) {
    // Clean up parent names - remove Quercus prefix and × symbol
    const cleanName = (name) => name?.replace(/^Quercus\s+/, '').replace(/^×\s*/, '').trim();
    const parent1 = cleanName(hybrid.parent1);
    const parent2 = cleanName(hybrid.parent2);
    const current = cleanName(currentSpecies);

    if (parent1 && parent1.toLowerCase() !== current.toLowerCase()) {
      return parent1;
    } else if (parent2 && parent2.toLowerCase() !== current.toLowerCase()) {
      return parent2;
    }
    return null;
  }

  // Find hybrid species by name, handling × prefix variations
  function findHybridSpecies(hybridName) {
    // Try exact match first
    let found = $allSpecies.find(s => s.name === hybridName);
    if (found) return found;

    // Try with × prefix
    found = $allSpecies.find(s => s.name === `× ${hybridName}`);
    if (found) return found;

    // Try without × prefix
    const withoutPrefix = hybridName.replace(/^×\s*/, '');
    found = $allSpecies.find(s => s.name === withoutPrefix || s.name === `× ${withoutPrefix}`);
    return found || null;
  }

  // Check if hybrid name already has × symbol (most do)
  function needsHybridSymbol(s) {
    return s.is_hybrid && !s.name.startsWith('×');
  }

  // Render Markdown to HTML with sanitization
  function renderMarkdown(text) {
    if (!text) return '';
    // Use marked to parse markdown, then sanitize dangerous tags
    let html = marked.parse(text);
    // Remove script tags and on* event handlers for safety
    html = html.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
    html = html.replace(/\s*on\w+\s*=\s*["'][^"']*["']/gi, '');
    return html;
  }

  // Map conservation status codes to full names
  function getConservationStatusLabel(status) {
    const labels = {
      'LC': 'Least Concern',
      'NT': 'Near Threatened',
      'VU': 'Vulnerable',
      'EN': 'Endangered',
      'CR': 'Critically Endangered',
      'EW': 'Extinct in the Wild',
      'EX': 'Extinct',
      'DD': 'Data Deficient',
      'NE': 'Not Evaluated'
    };
    return labels[status] || status;
  }

  // Build taxonomy URL for a given level
  function getTaxonUrl(level) {
    if (!species.taxonomy) return `${base}/taxonomy/`;

    const t = species.taxonomy;
    const parts = [];

    // Build path based on the level clicked
    if (t.subgenus) {
      parts.push(t.subgenus);
      if (level === 'subgenus') return `${base}/taxonomy/${parts.map(encodeURIComponent).join('/')}/`;
    }

    if (t.section) {
      parts.push(t.section);
      if (level === 'section') return `${base}/taxonomy/${parts.map(encodeURIComponent).join('/')}/`;
    }

    if (t.subsection) {
      parts.push(t.subsection);
      if (level === 'subsection') return `${base}/taxonomy/${parts.map(encodeURIComponent).join('/')}/`;
    }

    if (t.complex) {
      parts.push(t.complex);
      if (level === 'complex') return `${base}/taxonomy/${parts.map(encodeURIComponent).join('/')}/`;
    }

    return `${base}/taxonomy/${parts.map(encodeURIComponent).join('/')}/`;
  }
</script>

<div class="species-detail">
  <!-- Combined header with species name and taxonomy -->
  <header class="species-header-box">
    <!-- Species name and badges -->
    <div class="species-current">
      <div class="species-current-left">
        <span class="species-level">{species.is_hybrid ? 'Hybrid' : 'Species'}</span>
        <h1 class="species-title">
          <em>Quercus {#if needsHybridSymbol(species)}× {/if}{species.name}</em>
          {#if species.author}<span class="author-text">{species.author}</span>{/if}
        </h1>
      </div>
      {#if species.conservation_status}
        <span class="conservation-badge" title={getConservationStatusLabel(species.conservation_status)}>
          {species.conservation_status}
        </span>
      {/if}
    </div>

    <!-- Taxonomy path (serves as both navigation and taxonomy display) -->
    {#if species.taxonomy}
      <nav class="taxonomy-nav">
        <span class="taxonomy-label">Taxonomy:</span>
        <a href="{base}/taxonomy/" class="taxonomy-link">
          <span class="taxonomy-name">Quercus</span>
          <span class="taxonomy-level-label">(genus)</span>
        </a>
        {#if species.taxonomy.subgenus}
          <span class="taxonomy-separator">›</span>
          <a href="{getTaxonUrl('subgenus')}" class="taxonomy-link">
            <span class="taxonomy-name">{species.taxonomy.subgenus}</span>
            <span class="taxonomy-level-label">(subgenus)</span>
          </a>
        {/if}
        {#if species.taxonomy.section}
          <span class="taxonomy-separator">›</span>
          <a href="{getTaxonUrl('section')}" class="taxonomy-link">
            <span class="taxonomy-name">{species.taxonomy.section}</span>
            <span class="taxonomy-level-label">(section)</span>
          </a>
        {/if}
        {#if species.taxonomy.subsection}
          <span class="taxonomy-separator">›</span>
          <a href="{getTaxonUrl('subsection')}" class="taxonomy-link">
            <span class="taxonomy-name">{species.taxonomy.subsection}</span>
            <span class="taxonomy-level-label">(subsection)</span>
          </a>
        {/if}
        {#if species.taxonomy.complex}
          <span class="taxonomy-separator">›</span>
          <a href="{getTaxonUrl('complex')}" class="taxonomy-link">
            <span class="taxonomy-name">Q. {species.taxonomy.complex}</span>
            <span class="taxonomy-level-label">(complex)</span>
          </a>
        {/if}
      </nav>
    {/if}
  </header>

  <!-- Content -->
  <div class="content-grid" style="background-color: var(--color-background);">
    <!-- SPECIES-INTRINSIC DATA (not source-dependent) -->

    {#if species.is_hybrid && (species.parent1 || species.parent2)}
      <section class="detail-section full-width">
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
                <a
                  href="{getSpeciesUrl(species.parent1.replace('Quercus ', ''))}"
                  class="species-link"
                >
                  {species.parent1}
                </a>
              </li>
            {/if}
            {#if species.parent2}
              <li class="parent-link-item">
                <a
                  href="{getSpeciesUrl(species.parent2.replace('Quercus ', ''))}"
                  class="species-link"
                >
                  {species.parent2}
                </a>
              </li>
            {/if}
          </ul>
        </div>
      </section>
    {/if}

    {#if species.hybrids && species.hybrids.length > 0}
      <section class="detail-section full-width">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
          </svg>
          <span>Known Hybrids ({species.hybrids.length})</span>
        </h2>
        <div class="hybrids-grid">
          {#each species.hybrids as hybridName}
            {@const hybridSpecies = findHybridSpecies(hybridName)}
            {@const otherParent = hybridSpecies ? getOtherParent(hybridSpecies, species.name) : null}
            <div class="hybrid-item">
              <a
                href="{getSpeciesUrl(hybridSpecies?.name || hybridName)}"
                class="species-link font-semibold"
              >
                Q. {hybridSpecies?.name?.startsWith('×') ? '' : '× '}{hybridSpecies?.name || hybridName}
              </a>
              {#if otherParent}
                <span class="text-sm" style="color: var(--color-text-secondary);">
                  (with Q. {otherParent})
                </span>
              {/if}
            </div>
          {/each}
        </div>
      </section>
    {/if}

    {#if species.closely_related_to && species.closely_related_to.length > 0}
      <section class="detail-section full-width">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01" />
          </svg>
          <span>Closely Related Species</span>
        </h2>
        <ul class="related-species-list">
          {#each species.closely_related_to as relatedName}
            <li>
              <a
                href="{getSpeciesUrl(relatedName)}"
                class="species-link"
              >
                Quercus {relatedName}
              </a>
            </li>
          {/each}
        </ul>
      </section>
    {/if}

    {#if species.subspecies_varieties && species.subspecies_varieties.length > 0}
      <section class="detail-section full-width">
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

    {#if species.synonyms && species.synonyms.length > 0}
      <section class="detail-section full-width">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z" />
          </svg>
          <span>Synonyms ({species.synonyms.length})</span>
        </h2>
        <ul class="flex flex-wrap gap-2">
          {#each species.synonyms as synonym}
            <li class="pill-tag">
              <span class="italic">{synonym.name || synonym}</span>{#if synonym.author} <span class="text-xs opacity-70">{synonym.author}</span>{/if}
            </li>
          {/each}
        </ul>
      </section>
    {/if}

    <!-- SOURCE-DEPENDENT DATA -->

    {#if sources.length > 0}
      <section class="source-container full-width">
        <!-- Source tabs -->
        <div class="source-tabs" role="tablist">
          {#each sources as source}
            <button
              class="source-tab"
              class:active={selectedSourceId === source.source_id}
              role="tab"
              aria-selected={selectedSourceId === source.source_id}
              on:click={() => selectedSourceId = source.source_id}
            >
              <span class="source-tab-name">{source.source_name}</span>
              {#if source.is_preferred}
                <span class="preferred-badge" title="Preferred source">★</span>
              {/if}
              {#if source.license}
                <span class="license-icon" title={source.license === "All Rights Reserved" ? "All Rights Reserved" : source.license}>©</span>
              {/if}
              {#if source.source_url}
                <a
                  href={source.source_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="source-tab-link"
                  title="Visit source"
                  on:click|stopPropagation
                >
                  <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                  </svg>
                </a>
              {/if}
            </button>
          {/each}
        </div>

        <!-- Source content -->
        <div class="source-content" role="tabpanel">
          {#if selectedSource?.range}
            <section class="source-field">
              <h3 class="field-header">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
                <span>Geographic Range</span>
              </h3>
              <div class="field-text">{@html renderMarkdown(selectedSource.range)}</div>
            </section>
          {/if}

          {#if selectedSource?.growth_habit}
            <section class="source-field">
              <h3 class="field-header">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3 21h18M3 10h18M3 7l9-4 9 4M4 10v11M20 10v11M8 14h.01M12 14h.01M16 14h.01M8 17h.01M12 17h.01M16 17h.01" />
                </svg>
                <span>Growth Habit</span>
              </h3>
              <div class="field-text">{@html renderMarkdown(selectedSource.growth_habit)}</div>
            </section>
          {/if}

          {#if selectedSource?.leaves}
            <section class="source-field">
              <h3 class="field-header">
                <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M17,8C8,10 5.9,16.17 3.82,21.34L5.71,22L6.66,19.7C7.14,19.87 7.64,20 8,20C19,20 22,3 22,3C21,5 14,5.25 9,6.25C4,7.25 2,11.5 2,13.5C2,15.5 3.75,17.25 3.75,17.25C7,8 17,8 17,8Z" />
                </svg>
                <span>Leaves</span>
              </h3>
              <div class="field-text">{@html renderMarkdown(selectedSource.leaves)}</div>
            </section>
          {/if}

          {#if selectedSource?.fruits}
            <section class="source-field">
              <h3 class="field-header">
                <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12,2C12.5,2 13,2.19 13.41,2.59C13.8,3 14,3.5 14,4C14,4.5 13.8,5 13.41,5.41C13,5.8 12.5,6 12,6C11.5,6 11,5.8 10.59,5.41C10.2,5 10,4.5 10,4C10,3.5 10.2,3 10.59,2.59C11,2.19 11.5,2 12,2M12,6C13.1,6 14,6.9 14,8V9.5C15.72,9.5 17.17,10.6 17.71,12.13C18.14,13.38 18.13,14.77 17.66,16C17.19,17.26 16.32,18.23 15.19,18.74C14.06,19.25 12.78,19.25 11.65,18.74C10.5,18.23 9.63,17.26 9.16,16C8.69,14.77 8.68,13.38 9.11,12.13C9.65,10.6 11.1,9.5 12.83,9.5H12V8C12,6.9 12.9,6 12,6M12.13,11.5C11.41,11.5 10.81,11.89 10.54,12.5C10.27,13.11 10.39,13.82 10.85,14.3C11.31,14.78 12,14.94 12.63,14.7C13.26,14.46 13.7,13.86 13.7,13.17C13.7,12.64 13.5,12.13 13.13,11.76C12.76,11.39 12.26,11.5 12.13,11.5Z" />
                </svg>
                <span>Fruits</span>
              </h3>
              <div class="field-text">{@html renderMarkdown(selectedSource.fruits)}</div>
            </section>
          {/if}

          {#if selectedSource?.flowers}
            <section class="source-field">
              <h3 class="field-header">
                <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12,22A10,10 0 0,1 2,12A10,10 0 0,1 12,2A10,10 0 0,1 22,12A10,10 0 0,1 12,22M12,4A8,8 0 0,0 4,12A8,8 0 0,0 12,20A8,8 0 0,0 20,12A8,8 0 0,0 12,4M15,10.59V9L12.5,6.5L10,9V10.59L11.29,11.88L10.59,14.59L12,14L13.41,14.59L12.71,11.88L15,10.59Z" />
                </svg>
                <span>Flowers</span>
              </h3>
              <div class="field-text">{@html renderMarkdown(selectedSource.flowers)}</div>
            </section>
          {/if}

          {#if selectedSource?.bark}
            <section class="source-field">
              <h3 class="field-header">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
                </svg>
                <span>Bark</span>
              </h3>
              <div class="field-text">{@html renderMarkdown(selectedSource.bark)}</div>
            </section>
          {/if}

          {#if selectedSource?.twigs}
            <section class="source-field">
              <h3 class="field-header">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
                </svg>
                <span>Twigs</span>
              </h3>
              <div class="field-text">{@html renderMarkdown(selectedSource.twigs)}</div>
            </section>
          {/if}

          {#if selectedSource?.buds}
            <section class="source-field">
              <h3 class="field-header">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
                </svg>
                <span>Buds</span>
              </h3>
              <div class="field-text">{@html renderMarkdown(selectedSource.buds)}</div>
            </section>
          {/if}

          {#if selectedSource?.local_names && selectedSource.local_names.length > 0}
            <section class="source-field">
              <h3 class="field-header">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" />
                </svg>
                <span>Common Names</span>
              </h3>
              <ul class="flex flex-wrap gap-2">
                {#each selectedSource.local_names as localName}
                  <li class="pill-tag">{localName}</li>
                {/each}
              </ul>
            </section>
          {/if}

          {#if selectedSource?.hardiness_habitat}
            <section class="source-field">
              <h3 class="field-header">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span>Hardiness & Habitat</span>
              </h3>
              <div class="field-text">{@html renderMarkdown(selectedSource.hardiness_habitat)}</div>
            </section>
          {/if}

          {#if selectedSource?.miscellaneous}
            <section class="source-field">
              <h3 class="field-header">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span>Additional Information</span>
              </h3>
              <div class="field-text">{@html renderMarkdown(selectedSource.miscellaneous)}</div>
            </section>
          {/if}
        </div>
      </section>
    {/if}

    <section class="detail-section full-width">
      <h2 class="section-header">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
        </svg>
        <span>External Links</span>
      </h2>
      <div class="external-links-container">
        {#if selectedSource?.url}
          <a
            href={selectedSource.url}
            target="_blank"
            rel="noopener noreferrer"
            class="external-link"
          >
            {selectedSource.source_name || 'Source'}
          </a>
        {/if}
        <a
          href={`https://www.inaturalist.org/search?q=${encodeURIComponent('Quercus ' + species.name)}`}
          target="_blank"
          rel="noopener noreferrer"
          class="external-link"
        >
          iNaturalist
        </a>
      </div>
    </section>
  </div>
</div>

<style>
  .species-detail {
    background-color: var(--color-surface);
    padding: 1rem;
  }

  .content-grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: 1.5rem;
  }

  /* Two columns on large screens */
  @media (min-width: 1024px) {
    .content-grid {
      grid-template-columns: 1fr 1fr;
      gap: 1.25rem;
    }
  }

  .detail-section {
    padding: 1rem;
    border-radius: 0.5rem;
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    box-shadow: var(--shadow-sm);
  }

  /* Full-width sections span both columns */
  .detail-section.full-width {
    grid-column: 1 / -1;
  }

  .section-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 1rem;
    font-weight: 600;
    margin-bottom: 0.75rem;
    color: var(--color-forest-800);
    font-family: var(--font-serif);
  }

  .section-header svg {
    width: 1.125rem;
    height: 1.125rem;
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

  .conservation-badge {
    display: inline-flex;
    padding: 0.5rem 1rem;
    border-radius: 9999px;
    font-size: 0.875rem;
    font-weight: 600;
    background-color: var(--color-status-warning-bg);
    color: var(--color-status-warning-text);
    border: 1px solid var(--color-status-warning-border);
    flex-shrink: 0;
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

  /* Combined navigation header (matching TaxonView) */
  .species-header-box {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    padding: 1rem 1.5rem;
    margin-bottom: 1.5rem;
    background: linear-gradient(135deg, var(--color-forest-50) 0%, var(--color-forest-100) 100%);
    border: 1px solid var(--color-forest-200);
    border-radius: 0.75rem;
  }

  /* Taxonomy navigation (below species name) */
  .taxonomy-nav {
    display: flex;
    align-items: baseline;
    flex-wrap: wrap;
    gap: 0.5rem;
    font-size: 0.875rem;
    margin-top: 0.25rem;
  }

  .taxonomy-nav .taxonomy-label {
    font-weight: 600;
    color: var(--color-forest-700);
    margin-right: 0.25rem;
  }

  .taxonomy-nav .taxonomy-link {
    display: inline-flex;
    align-items: baseline;
    gap: 0.25rem;
    text-decoration: none;
    transition: color 0.15s ease;
    border-bottom: none;
  }

  .taxonomy-nav .taxonomy-link:hover {
    text-decoration: underline;
    text-decoration-color: var(--color-forest-400);
  }

  .taxonomy-name {
    font-style: italic;
    font-weight: 500;
    color: var(--color-forest-700);
  }

  .taxonomy-nav .taxonomy-link:hover .taxonomy-name {
    color: var(--color-forest-900);
  }

  .taxonomy-level-label {
    font-size: 0.75rem;
    font-style: normal;
    font-weight: 400;
    color: var(--color-text-tertiary);
  }

  .taxonomy-separator {
    color: var(--color-forest-400);
  }

  /* Current species row */
  .species-current {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
  }

  .species-current-left {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    flex-wrap: wrap;
  }

  .species-level {
    display: inline-block;
    padding: 0.25rem 0.625rem;
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--color-forest-700);
    background-color: var(--color-forest-200);
    border-radius: 9999px;
  }

  .species-title {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: 0.5rem;
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--color-forest-900);
    font-family: var(--font-serif);
    margin: 0;
  }

  .author-text {
    font-size: 1rem;
    font-weight: 400;
    font-style: normal;
    color: var(--color-text-secondary);
    font-family: var(--font-sans);
  }

  /* Hybrids two-column grid */
  .hybrids-grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: 0.75rem;
  }

  @media (min-width: 640px) {
    .hybrids-grid {
      grid-template-columns: 1fr 1fr;
    }
  }

  /* Pill tag styling for synonyms and common names */
  .pill-tag {
    display: inline-flex;
    align-items: center;
    padding: 0.375rem 0.875rem;
    border-radius: 9999px;
    font-size: 0.875rem;
    font-weight: 500;
    background-color: var(--color-forest-100);
    color: var(--color-forest-900);
    border: 1px solid var(--color-forest-200);
  }

  /* Source container and tabs */
  .source-container {
    border-radius: 0.5rem;
    border: 1px solid var(--color-border);
    background-color: var(--color-surface);
    box-shadow: var(--shadow-sm);
    overflow: hidden;
  }

  .source-container.full-width {
    grid-column: 1 / -1;
  }

  .source-tabs {
    display: flex;
    flex-wrap: wrap;
    gap: 0;
    background-color: var(--color-forest-50);
    border-bottom: 1px solid var(--color-border);
    padding: 0.5rem 0.5rem 0;
  }

  .source-tab {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.625rem 1rem;
    border: none;
    background: transparent;
    color: var(--color-text-secondary);
    font-size: 0.875rem;
    font-weight: 500;
    cursor: pointer;
    border-radius: 0.375rem 0.375rem 0 0;
    transition: all 0.15s ease;
    position: relative;
    margin-bottom: -1px;
  }

  .source-tab:hover:not(.active) {
    background-color: var(--color-forest-100);
    color: var(--color-text-primary);
  }

  .source-tab.active {
    background-color: var(--color-surface);
    color: var(--color-forest-800);
    border: 1px solid var(--color-border);
    border-bottom-color: var(--color-surface);
  }

  .source-tab-name {
    white-space: nowrap;
  }

  .preferred-badge {
    color: var(--color-oak-brown);
    font-size: 0.75rem;
  }

  .license-icon {
    font-size: 0.875rem;
    color: var(--color-text-tertiary);
    cursor: help;
  }

  .source-tab-link {
    display: inline-flex;
    align-items: center;
    color: var(--color-text-tertiary);
    padding: 0.125rem;
    border-radius: 0.25rem;
    transition: all 0.15s ease;
  }

  .source-tab-link:hover {
    color: var(--color-forest-600);
    background-color: var(--color-forest-100);
  }

  .source-tab-link svg {
    width: 0.875rem;
    height: 0.875rem;
  }

  .source-content {
    padding: 1rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .source-field {
    padding-bottom: 1rem;
    border-bottom: 1px solid var(--color-border-light, var(--color-border));
  }

  .source-field:last-child {
    padding-bottom: 0;
    border-bottom: none;
  }

  .field-header {
    display: flex;
    align-items: center;
    gap: 0.375rem;
    font-size: 0.875rem;
    font-weight: 600;
    margin-bottom: 0.5rem;
    color: var(--color-forest-700);
  }

  .field-header svg {
    width: 1rem;
    height: 1rem;
    color: var(--color-forest-500);
    flex-shrink: 0;
  }

  .field-text {
    color: var(--color-text-primary);
    line-height: 1.6;
    font-size: 0.9375rem;
  }

  /* Apply same markdown styles to field-text */
  .field-text :global(p) {
    margin: 0 0 0.75rem 0;
  }

  .field-text :global(p:last-child) {
    margin-bottom: 0;
  }

  .field-text :global(ul) {
    margin: 0.5rem 0;
    padding-left: 1.5rem;
    list-style-type: disc;
  }

  .field-text :global(ol) {
    margin: 0.5rem 0;
    padding-left: 1.5rem;
    list-style-type: decimal;
  }

  .field-text :global(li) {
    margin: 0.25rem 0;
  }

  .field-text :global(a) {
    color: var(--color-forest-700);
    text-decoration: underline;
    text-decoration-color: var(--color-forest-300);
    transition: all 0.15s ease;
  }

  .field-text :global(a:hover) {
    color: var(--color-forest-600);
    text-decoration-color: var(--color-forest-600);
  }

  .field-text :global(strong) {
    font-weight: 600;
  }

  .field-text :global(em) {
    font-style: italic;
  }

  .external-links-container {
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
  }

  /* Markdown content styling */
  .detail-text :global(p) {
    margin: 0 0 0.75rem 0;
  }

  .detail-text :global(p:last-child) {
    margin-bottom: 0;
  }

  .detail-text :global(ul) {
    margin: 0.5rem 0;
    padding-left: 1.5rem;
    list-style-type: disc;
  }

  .detail-text :global(ol) {
    margin: 0.5rem 0;
    padding-left: 1.5rem;
    list-style-type: decimal;
  }

  .detail-text :global(li) {
    margin: 0.25rem 0;
  }

  .detail-text :global(a) {
    color: var(--color-forest-700);
    text-decoration: underline;
    text-decoration-color: var(--color-forest-300);
    transition: all 0.15s ease;
  }

  .detail-text :global(a:hover) {
    color: var(--color-forest-600);
    text-decoration-color: var(--color-forest-600);
  }

  .detail-text :global(strong) {
    font-weight: 600;
  }

  .detail-text :global(em) {
    font-style: italic;
  }

  .detail-text :global(code) {
    font-family: monospace;
    background-color: var(--color-forest-50);
    padding: 0.125rem 0.25rem;
    border-radius: 0.25rem;
    font-size: 0.875em;
  }
</style>
