<script>
  import { base } from '$app/paths';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { marked } from 'marked';
  import DOMPurify from 'dompurify';
  import { getPrimarySource, getAllSources, getSourceCompleteness, formatSpeciesName, forceRefresh } from '$lib/stores/dataStore.js';
  import { fetchSources } from '$lib/apiClient.js';
  import { canEdit } from '$lib/stores/authStore.js';
  import { toast } from '$lib/stores/toastStore.js';
  import { updateSpecies, deleteSpecies, updateSpeciesSource, createSpeciesSource, deleteSpeciesSource, ApiError } from '$lib/apiClient.js';
  import { getLogoIcon, getLinkLogoId } from '$lib/icons/index.js';
  import inaturalistLogo from '$lib/icons/inaturalist-logo.svg';
  import SpeciesEditForm from './SpeciesEditForm.svelte';
  import SpeciesSourceEditForm from './SpeciesSourceEditForm.svelte';
  import DeleteConfirmDialog from './DeleteConfirmDialog.svelte';

  // Configure marked for safe rendering
  marked.setOptions({
    breaks: true,  // Convert \n to <br>
    gfm: true,     // GitHub Flavored Markdown
  });

  export let species;
  export let initialSourceId = null;
  export let onDataChange = null;

  // Get species name (support both API format and legacy format)
  $: speciesName = species.scientific_name || species.name;

  // Source selection state
  let selectedSourceId = null;

  // Edit/Delete modal state
  let showEditForm = false;
  let showDeleteDialog = false;
  let isDeleting = false;

  // Source editing state
  let showSourceEditForm = false;
  let editingSourceId = null;

  // Add source state
  let showAddSourceDropdown = false;
  let addingSourceId = null;
  let showAddSourceForm = false;

  // Source delete state
  let showSourceDeleteDialog = false;
  let deletingSourceId = null;
  let isDeletingSource = false;

  // All available sources (fetched from API)
  let allSourcesList = [];

  // Load all sources on mount
  onMount(async () => {
    try {
      allSourcesList = await fetchSources();
    } catch (err) {
      console.warn('Failed to load sources:', err);
    }
  });

  // Get cascade info for delete (count of sources to be removed)
  $: cascadeInfo = sources.length > 0 ? { count: sources.length, type: 'sources' } : undefined;

  // Handle edit button click
  function handleEditClick() {
    showEditForm = true;
  }

  // Handle delete button click
  function handleDeleteClick() {
    showDeleteDialog = true;
  }

  // Handle save from edit form
  // Returns field errors array if validation failed, null on success
  // Throws on network/server errors to keep modal open
  async function handleSaveSpecies(formData) {
    const originalName = species.scientific_name || species.name;
    const newName = formData.name;
    const nameChanged = originalName !== newName;

    try {
      await updateSpecies(originalName, formData);

      // Success: show toast and refresh data
      toast.success(`Species "${newName}" updated successfully`);

      // Refresh data in background and notify parent
      forceRefresh();
      if (onDataChange) onDataChange();

      // Navigate if name changed
      if (nameChanged) {
        goto(`${base}/species/${encodeURIComponent(newName)}/`);
      }

      return null; // No errors - signal success to form
    } catch (err) {
      if (err instanceof ApiError) {
        // 400 with field errors - return them so form can display
        if (err.status === 400 && err.fieldErrors) {
          return err.fieldErrors;
        }

        // Other API errors - show toast
        toast.error(`Failed to update species: ${err.message}`);
      } else {
        toast.error('Failed to update species: Network error');
      }

      throw err; // Re-throw so form stays open
    }
  }

  // Handle delete confirmation
  async function handleDeleteConfirm() {
    isDeleting = true;
    try {
      await deleteSpecies(speciesName);

      // Success: show toast
      toast.success(`Species "${speciesName}" deleted successfully`);

      showDeleteDialog = false;

      // Refresh data in background
      forceRefresh();

      // Navigate back to list after delete
      goto(`${base}/list/`);
    } catch (err) {
      if (err instanceof ApiError) {
        toast.error(`Failed to delete species: ${err.message}`);
      } else {
        toast.error('Failed to delete species: Network error');
      }
    } finally {
      isDeleting = false;
    }
  }

  // Handle source edit button click
  function handleSourceEditClick(sourceId) {
    editingSourceId = sourceId;
    showSourceEditForm = true;
  }

  // Handle save from source edit form
  // Returns field errors array if validation failed, null on success
  // Throws on network/server errors to keep modal open
  async function handleSaveSource(formData) {
    try {
      await updateSpeciesSource(speciesName, editingSourceId, formData);

      // Success: show toast and refresh data
      toast.success('Source data updated successfully');

      // Refresh data in background and notify parent
      forceRefresh();
      if (onDataChange) onDataChange();

      return null; // No errors - signal success to form
    } catch (err) {
      if (err instanceof ApiError) {
        // 400 with field errors - return them so form can display
        if (err.status === 400 && err.fieldErrors) {
          return err.fieldErrors;
        }

        // Other API errors - show toast
        toast.error(`Failed to update source data: ${err.message}`);
      } else {
        toast.error('Failed to update source data: Network error');
      }

      throw err; // Re-throw so form stays open
    }
  }

  // Handle source delete button click
  function handleSourceDeleteClick(sourceId) {
    deletingSourceId = sourceId;
    showSourceDeleteDialog = true;
  }

  // Handle source delete confirmation
  async function handleSourceDeleteConfirm() {
    isDeletingSource = true;
    try {
      await deleteSpeciesSource(speciesName, deletingSourceId);

      // Success: show toast
      toast.success('Source data deleted successfully');

      showSourceDeleteDialog = false;
      deletingSourceId = null;

      // Reset selected source if we deleted the one being viewed
      if (selectedSourceId === deletingSourceId) {
        selectedSourceId = null;
      }

      // Refresh data in background and notify parent
      forceRefresh();
      if (onDataChange) onDataChange();
    } catch (err) {
      if (err instanceof ApiError) {
        toast.error(`Failed to delete source data: ${err.message}`);
      } else {
        toast.error('Failed to delete source data: Network error');
      }
    } finally {
      isDeletingSource = false;
    }
  }

  // Get source data for editing
  $: editingSource = editingSourceId ? sources.find(s => s.source_id === editingSourceId) : null;

  // Get source data for deletion dialog
  $: deletingSource = deletingSourceId ? sources.find(s => s.source_id === deletingSourceId) : null;

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

  // Compute available sources (sources not already present for this species)
  $: existingSourceIds = new Set(sources.map(s => s.source_id));
  $: availableSources = allSourcesList.filter(s => !existingSourceIds.has(s.id));

  // Get source info for adding (when user selects from dropdown)
  $: addingSource = addingSourceId
    ? { source_id: addingSourceId, source_name: allSourcesList.find(s => s.id === addingSourceId)?.name || 'Source' }
    : null;

  // Handle add source button click - toggle dropdown
  function handleAddSourceClick() {
    showAddSourceDropdown = !showAddSourceDropdown;
  }

  // Handle selecting a source from the dropdown
  function handleSelectSourceToAdd(sourceId) {
    addingSourceId = sourceId;
    showAddSourceDropdown = false;
    showAddSourceForm = true;
  }

  // Handle save from add source form
  async function handleCreateSource(formData) {
    try {
      await createSpeciesSource(speciesName, formData);

      // Success: show toast and refresh data
      toast.success('Source data added successfully');

      // Reset state
      addingSourceId = null;
      showAddSourceForm = false;

      // Refresh data in background and notify parent
      forceRefresh();
      if (onDataChange) onDataChange();

      return null; // No errors - signal success to form
    } catch (err) {
      if (err instanceof ApiError) {
        // 400 with field errors - return them so form can display
        if (err.status === 400 && err.fieldErrors) {
          return err.fieldErrors;
        }

        // Other API errors - show toast
        toast.error(`Failed to add source data: ${err.message}`);
      } else {
        toast.error('Failed to add source data: Network error');
      }

      throw err; // Re-throw so form stays open
    }
  }

  // Close dropdown when clicking outside
  function handleClickOutside(event) {
    if (showAddSourceDropdown) {
      const dropdown = event.target.closest('.add-source-wrapper');
      if (!dropdown) {
        showAddSourceDropdown = false;
      }
    }
  }

  // Build species detail URL
  function getSpeciesUrl(name) {
    return `${base}/species/${encodeURIComponent(name)}/`;
  }

  function getOtherParent(currentSpecies) {
    // Clean up parent names - remove Quercus prefix and × symbol
    const cleanName = (name) => name?.replace(/^Quercus\s+/, '').replace(/^×\s*/, '').trim();
    const parent1 = cleanName(species.parent1);
    const parent2 = cleanName(species.parent2);
    const current = cleanName(currentSpecies);

    if (parent1 && parent1.toLowerCase() !== current.toLowerCase()) {
      return parent1;
    } else if (parent2 && parent2.toLowerCase() !== current.toLowerCase()) {
      return parent2;
    }
    return null;
  }

  // Check if hybrid name already has × symbol (most do)
  function needsHybridSymbol(s) {
    const name = s.scientific_name || s.name;
    return s.is_hybrid && !name.startsWith('×');
  }

  // Render Markdown to HTML with DOMPurify sanitization
  function renderMarkdown(text) {
    if (!text) return '';
    const html = marked.parse(text);
    return DOMPurify.sanitize(html);
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

  // Official IUCN Red List colors
  // Source: https://nc.iucnredlist.org/redlist/resources/files/1646067752-FINAL_IUCN_Red_List_colour_chart.pdf
  function getConservationStatusColors(status) {
    const colors = {
      'EX': { bg: '#000000', text: '#FFFFFF' },  // Extinct - black
      'EW': { bg: '#542344', text: '#FFFFFF' },  // Extinct in Wild - dark purple
      'CR': { bg: '#D81E05', text: '#FFFFFF' },  // Critically Endangered - red
      'EN': { bg: '#FC7F3F', text: '#000000' },  // Endangered - orange
      'VU': { bg: '#F9E814', text: '#000000' },  // Vulnerable - yellow
      'NT': { bg: '#CCE226', text: '#000000' },  // Near Threatened - lime
      'LC': { bg: '#60C659', text: '#000000' },  // Least Concern - green
      'DD': { bg: '#D1D1C6', text: '#000000' },  // Data Deficient - gray
      'NE': { bg: '#FFFFFF', text: '#000000', border: '#D1D1C6' }   // Not Evaluated - white with border
    };
    return colors[status] || { bg: '#D1D1C6', text: '#000000' };
  }

  // Build sorted list of all external links
  function getSortedExternalLinks(species) {
    const links = [];

    // Add links from species.external_links
    if (species.external_links && species.external_links.length > 0) {
      for (const link of species.external_links) {
        links.push({
          name: link.name,
          url: link.url,
          logoId: getLinkLogoId(link),
        });
      }
    }

    // Add iNaturalist (uses full logo image instead of icon)
    const name = species.scientific_name || species.name;
    links.push({
      name: 'iNaturalist',
      url: `https://www.inaturalist.org/search?q=${encodeURIComponent('Quercus ' + name)}`,
      isInaturalist: true,
    });

    // Add Wikipedia
    links.push({
      name: 'Wikipedia',
      url: `https://en.wikipedia.org/wiki/Quercus_${name.replace(/ /g, '_')}`,
      logoId: 'wikipedia',
    });

    // Sort alphabetically by name
    links.sort((a, b) => a.name.localeCompare(b.name));

    return links;
  }

  $: sortedExternalLinks = getSortedExternalLinks(species);

  // Build taxonomy URL for a given level
  // Supports both flat taxonomy (API format) and nested taxonomy (legacy format)
  function getTaxonUrl(level) {
    // Get taxonomy fields - support both flat (API) and nested (legacy) format
    const subgenus = species.subgenus || species.taxonomy?.subgenus;
    const section = species.section || species.taxonomy?.section;
    const subsection = species.subsection || species.taxonomy?.subsection;
    const complex = species.complex || species.taxonomy?.complex;

    if (!subgenus) return `${base}/taxonomy/`;

    const parts = [];

    // Build path based on the level clicked
    if (subgenus) {
      parts.push(subgenus);
      if (level === 'subgenus') return `${base}/taxonomy/${parts.map(encodeURIComponent).join('/')}/`;
    }

    if (section) {
      parts.push(section);
      if (level === 'section') return `${base}/taxonomy/${parts.map(encodeURIComponent).join('/')}/`;
    }

    if (subsection) {
      parts.push(subsection);
      if (level === 'subsection') return `${base}/taxonomy/${parts.map(encodeURIComponent).join('/')}/`;
    }

    if (complex) {
      parts.push(complex);
      if (level === 'complex') return `${base}/taxonomy/${parts.map(encodeURIComponent).join('/')}/`;
    }

    return `${base}/taxonomy/${parts.map(encodeURIComponent).join('/')}/`;
  }

  // Helper to check if species has taxonomy data (flat or nested)
  $: hasTaxonomy = species.subgenus || species.taxonomy?.subgenus;
</script>

<div class="species-detail">
  <!-- Combined header with species name and taxonomy -->
  <header class="species-header-box">
    <!-- Species name and badges -->
    <div class="species-current">
      <div class="species-current-left">
        <span class="badge badge-uppercase badge-forest">{species.is_hybrid ? 'Hybrid' : 'Species'}</span>
        <h1 class="species-title">
          <em>Quercus {#if needsHybridSymbol(species)}× {/if}{speciesName}</em>
          {#if species.author}<span class="author-text">{species.author}</span>{/if}
        </h1>
      </div>
      {#if species.conservation_status}
        {@const statusColors = getConservationStatusColors(species.conservation_status)}
        <span
          class="conservation-badge"
          title={getConservationStatusLabel(species.conservation_status)}
          style="background-color: {statusColors.bg}; color: {statusColors.text}; {statusColors.border ? `border-color: ${statusColors.border};` : ''}"
        >
          {species.conservation_status}
        </span>
      {/if}

      <!-- Edit/Delete buttons -->
      <div class="species-actions">
        {#if $canEdit}
          <button
            type="button"
            class="action-btn action-btn-edit"
            title="Edit species"
            on:click={handleEditClick}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
              <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
            </svg>
            <span>Edit</span>
          </button>
          <button
            type="button"
            class="action-btn action-btn-delete"
            title="Delete species"
            on:click={handleDeleteClick}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="3,6 5,6 21,6" />
              <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
              <line x1="10" y1="11" x2="10" y2="17" />
              <line x1="14" y1="11" x2="14" y2="17" />
            </svg>
            <span>Delete</span>
          </button>
        {/if}
      </div>
    </div>

    <!-- Taxonomy path (serves as both navigation and taxonomy display) -->
    <!-- Supports both flat taxonomy (API format) and nested taxonomy (legacy format) -->
    {#if hasTaxonomy}
      {@const subgenus = species.subgenus || species.taxonomy?.subgenus}
      {@const section = species.section || species.taxonomy?.section}
      {@const subsection = species.subsection || species.taxonomy?.subsection}
      {@const complex = species.complex || species.taxonomy?.complex}
      <nav class="taxonomy-nav" aria-label="Taxonomy breadcrumb">
        <span class="taxonomy-label" aria-hidden="true">Taxonomy:</span>
        <a href="{base}/taxonomy/" class="taxonomy-link">
          <span class="taxonomy-name">Quercus</span>
          <span class="taxonomy-level-label">(genus)</span>
        </a>
        {#if subgenus}
          <span class="taxonomy-separator">›</span>
          <a href="{getTaxonUrl('subgenus')}" class="taxonomy-link">
            <span class="taxonomy-name">{subgenus}</span>
            <span class="taxonomy-level-label">(subgenus)</span>
          </a>
        {/if}
        {#if section}
          <span class="taxonomy-separator">›</span>
          <a href="{getTaxonUrl('section')}" class="taxonomy-link">
            <span class="taxonomy-name">{section}</span>
            <span class="taxonomy-level-label">(section)</span>
          </a>
        {/if}
        {#if subsection}
          <span class="taxonomy-separator">›</span>
          <a href="{getTaxonUrl('subsection')}" class="taxonomy-link">
            <span class="taxonomy-name">{subsection}</span>
            <span class="taxonomy-level-label">(subsection)</span>
          </a>
        {/if}
        {#if complex}
          <span class="taxonomy-separator">›</span>
          <a href="{getTaxonUrl('complex')}" class="taxonomy-link">
            <span class="taxonomy-name">Q. {complex}</span>
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
      <section class="card card-sm detail-section full-width">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
          <span>Parent Species</span>
        </h2>
        <div class="space-y-3">
          {#if species.parent_formula}
            <p class="prose-content italic font-medium" style="color: var(--color-forest-700);">{species.parent_formula}</p>
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
      <section class="card card-sm detail-section full-width">
        <h2 class="section-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
          </svg>
          <span>Known Hybrids ({species.hybrids.length})</span>
        </h2>
        <div class="hybrids-grid">
          {#each species.hybrids as hybridName}
            {@const otherParent = getOtherParent(speciesName)}
            {@const displayName = hybridName.startsWith('×') ? hybridName : `× ${hybridName}`}
            <div class="hybrid-item">
              <a
                href="{getSpeciesUrl(hybridName)}"
                class="species-link font-semibold"
              >
                Q. {displayName}
              </a>
              {#if otherParent}
                <span class="text-sm" style="color: var(--color-text-secondary);">
                  (with <a href="{getSpeciesUrl(otherParent)}" class="species-link">Q. {otherParent}</a>)
                </span>
              {/if}
            </div>
          {/each}
        </div>
      </section>
    {/if}

    {#if species.closely_related_to && species.closely_related_to.length > 0}
      <section class="card card-sm detail-section full-width">
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
      <section class="card card-sm detail-section full-width">
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
      <section class="card card-sm detail-section full-width">
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
      <section class="card card-sm source-container full-width">
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
              <span
                class="source-tab-link"
                role="link"
                tabindex="0"
                title="View source details"
                on:click|stopPropagation={() => goto(`${base}/sources/${source.source_id}/`)}
                on:keydown|stopPropagation={(e) => e.key === 'Enter' && goto(`${base}/sources/${source.source_id}/`)}
              >
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </span>
            </button>
          {/each}
          {#if sources.length > 1}
            <a
              href="{base}/compare/{encodeURIComponent(speciesName)}/"
              class="compare-sources-link"
              title="Compare all sources side-by-side"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 17V7m0 10a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h2a2 2 0 012 2m0 10a2 2 0 002 2h2a2 2 0 002-2M9 7a2 2 0 012-2h2a2 2 0 012 2m0 10V7m0 10a2 2 0 002 2h2a2 2 0 002-2V7a2 2 0 00-2-2h-2a2 2 0 00-2 2" />
              </svg>
              <span>Compare</span>
            </a>
          {/if}
          {#if $canEdit && availableSources.length > 0}
            <div class="add-source-wrapper">
              <button
                type="button"
                class="add-source-btn"
                title="Add data from another source"
                on:click={handleAddSourceClick}
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <line x1="12" y1="5" x2="12" y2="19" />
                  <line x1="5" y1="12" x2="19" y2="12" />
                </svg>
                <span>Add Source</span>
              </button>
              {#if showAddSourceDropdown}
                <div class="add-source-dropdown">
                  <div class="add-source-dropdown-header">Select a source to add</div>
                  {#each availableSources as source}
                    <button
                      type="button"
                      class="add-source-dropdown-item"
                      on:click={() => handleSelectSourceToAdd(source.id)}
                    >
                      {source.name}
                    </button>
                  {/each}
                </div>
              {/if}
            </div>
          {/if}
        </div>

        <!-- Source content -->
        <div class="source-content" role="tabpanel">
          <!-- Source header with Edit/Delete buttons -->
          <div class="source-content-header">
            <span class="source-content-title">Data from {selectedSource?.source_name || 'source'}</span>
            {#if $canEdit && selectedSource}
              <div class="source-actions">
                <button
                  type="button"
                  class="source-edit-btn"
                  title="Edit source data"
                  on:click={() => handleSourceEditClick(selectedSource.source_id)}
                >
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
                    <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
                  </svg>
                  <span>Edit</span>
                </button>
                <button
                  type="button"
                  class="source-delete-btn"
                  title="Delete source data"
                  on:click={() => handleSourceDeleteClick(selectedSource.source_id)}
                >
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="3,6 5,6 21,6" />
                    <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
                    <line x1="10" y1="11" x2="10" y2="17" />
                    <line x1="14" y1="11" x2="14" y2="17" />
                  </svg>
                  <span>Delete</span>
                </button>
              </div>
            {/if}
          </div>

          {#if selectedSource?.range}
            <section class="source-field">
              <h3 class="field-header">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
                <span>Geographic Range</span>
              </h3>
              <div class="prose-content">{@html renderMarkdown(selectedSource.range)}</div>
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
              <div class="prose-content">{@html renderMarkdown(selectedSource.growth_habit)}</div>
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
              <div class="prose-content">{@html renderMarkdown(selectedSource.leaves)}</div>
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
              <div class="prose-content">{@html renderMarkdown(selectedSource.fruits)}</div>
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
              <div class="prose-content">{@html renderMarkdown(selectedSource.flowers)}</div>
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
              <div class="prose-content">{@html renderMarkdown(selectedSource.bark)}</div>
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
              <div class="prose-content">{@html renderMarkdown(selectedSource.twigs)}</div>
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
              <div class="prose-content">{@html renderMarkdown(selectedSource.buds)}</div>
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
              <div class="prose-content">{@html renderMarkdown(selectedSource.hardiness_habitat)}</div>
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
              <div class="prose-content">{@html renderMarkdown(selectedSource.miscellaneous)}</div>
            </section>
          {/if}
        </div>
      </section>
    {/if}

    <section class="card card-sm detail-section full-width">
      <h2 class="section-header">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
        </svg>
        <span>External Links</span>
      </h2>
      <div class="external-links-container">
        {#each sortedExternalLinks as link}
          <a
            href={link.url}
            target="_blank"
            rel="noopener noreferrer"
            class="external-link"
          >
            {#if link.isInaturalist}
              <img src={inaturalistLogo} alt="iNaturalist" class="inaturalist-logo" />
            {:else}
              <span class="external-link-icon">{@html getLogoIcon(link.logoId)}</span>
              <span>{link.name}</span>
            {/if}
          </a>
        {/each}
      </div>
    </section>
  </div>
</div>

<!-- Edit Species Modal -->
{#if showEditForm}
  <SpeciesEditForm
    {species}
    isOpen={showEditForm}
    onClose={() => showEditForm = false}
    onSave={handleSaveSpecies}
  />
{/if}

<!-- Delete Confirmation Dialog -->
{#if showDeleteDialog}
  <DeleteConfirmDialog
    entityType="species"
    entityName={speciesName}
    {cascadeInfo}
    {isDeleting}
    onConfirm={handleDeleteConfirm}
    onCancel={() => showDeleteDialog = false}
  />
{/if}

<!-- Edit Source Data Modal -->
{#if showSourceEditForm && editingSource}
  <SpeciesSourceEditForm
    speciesName={speciesName}
    sourceData={editingSource}
    isOpen={showSourceEditForm}
    onClose={() => { showSourceEditForm = false; editingSourceId = null; }}
    onSave={handleSaveSource}
  />
{/if}

<!-- Delete Source Data Confirmation Dialog -->
{#if showSourceDeleteDialog && deletingSource}
  <DeleteConfirmDialog
    entityType="species-source"
    entityName="This will delete the {deletingSource.source_name} information for Quercus {speciesName}."
    isDeleting={isDeletingSource}
    onConfirm={handleSourceDeleteConfirm}
    onCancel={() => { showSourceDeleteDialog = false; deletingSourceId = null; }}
  />
{/if}

<!-- Add Source Data Modal -->
{#if showAddSourceForm && addingSource}
  <SpeciesSourceEditForm
    speciesName={speciesName}
    sourceData={addingSource}
    isOpen={showAddSourceForm}
    isCreateMode={true}
    onClose={() => { showAddSourceForm = false; addingSourceId = null; }}
    onSave={handleCreateSource}
  />
{/if}

<!-- Click outside handler for dropdown -->
<svelte:window on:click={handleClickOutside} />

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
    border: 1px solid transparent;
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

  .external-link-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 1.25rem;
    height: 1.25rem;
    flex-shrink: 0;
  }

  .external-link-icon :global(svg) {
    width: 100%;
    height: 100%;
    color: var(--color-forest-600);
  }

  .inaturalist-logo {
    height: 1.25rem;
    width: auto;
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
    cursor: pointer;
  }

  .source-tab-link:hover {
    color: var(--color-forest-600);
    background-color: var(--color-forest-100);
  }

  .source-tab-link svg {
    width: 0.875rem;
    height: 0.875rem;
  }

  .compare-sources-link {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.5rem 0.875rem;
    margin-left: auto;
    border: none;
    background: transparent;
    color: var(--color-forest-600);
    font-size: 0.8125rem;
    font-weight: 500;
    cursor: pointer;
    border-radius: 0.375rem;
    transition: all 0.15s ease;
    text-decoration: none;
  }

  .compare-sources-link:hover {
    background-color: var(--color-forest-100);
    color: var(--color-forest-800);
  }

  .compare-sources-link svg {
    width: 1rem;
    height: 1rem;
  }

  /* Add source button and dropdown */
  .add-source-wrapper {
    position: relative;
    margin-left: 0.5rem;
  }

  .add-source-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.5rem 0.875rem;
    border: 1px dashed var(--color-forest-300);
    background: transparent;
    color: var(--color-forest-600);
    font-size: 0.8125rem;
    font-weight: 500;
    cursor: pointer;
    border-radius: 0.375rem;
    transition: all 0.15s ease;
  }

  .add-source-btn:hover {
    background-color: var(--color-forest-50);
    border-color: var(--color-forest-400);
    color: var(--color-forest-700);
  }

  .add-source-btn:focus-visible {
    outline: 2px solid var(--color-forest-500);
    outline-offset: 2px;
  }

  .add-source-btn svg {
    flex-shrink: 0;
  }

  .add-source-dropdown {
    position: absolute;
    top: 100%;
    right: 0;
    margin-top: 0.25rem;
    min-width: 200px;
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.5rem;
    box-shadow: var(--shadow-lg);
    z-index: 100;
    overflow: hidden;
  }

  .add-source-dropdown-header {
    padding: 0.625rem 0.875rem;
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--color-text-tertiary);
    text-transform: uppercase;
    letter-spacing: 0.025em;
    border-bottom: 1px solid var(--color-border);
    background-color: var(--color-forest-50);
  }

  .add-source-dropdown-item {
    display: block;
    width: 100%;
    padding: 0.625rem 0.875rem;
    text-align: left;
    font-size: 0.875rem;
    color: var(--color-text-primary);
    background: none;
    border: none;
    cursor: pointer;
    transition: background-color 0.1s ease;
  }

  .add-source-dropdown-item:hover {
    background-color: var(--color-forest-50);
  }

  .add-source-dropdown-item:focus-visible {
    outline: none;
    background-color: var(--color-forest-100);
  }

  .source-content {
    padding: 1rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .source-content-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-bottom: 0.75rem;
    border-bottom: 1px solid var(--color-border-light, var(--color-border));
  }

  .source-content-title {
    font-size: 0.8125rem;
    font-weight: 500;
    color: var(--color-text-secondary);
  }

  .source-edit-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.375rem 0.625rem;
    border-radius: 0.375rem;
    font-size: 0.8125rem;
    font-weight: 500;
    color: var(--color-forest-700);
    background-color: var(--color-forest-50);
    border: 1px solid var(--color-forest-200);
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .source-edit-btn:hover {
    background-color: var(--color-forest-100);
    border-color: var(--color-forest-300);
  }

  .source-edit-btn:focus-visible {
    outline: 2px solid var(--color-forest-500);
    outline-offset: 2px;
  }

  .source-edit-btn svg {
    flex-shrink: 0;
  }

  .source-actions {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .source-delete-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.375rem 0.625rem;
    border-radius: 0.375rem;
    font-size: 0.8125rem;
    font-weight: 500;
    color: #dc2626;
    background-color: #fef2f2;
    border: 1px solid #fecaca;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .source-delete-btn:hover {
    background-color: #fee2e2;
    border-color: #fca5a5;
  }

  .source-delete-btn:focus-visible {
    outline: 2px solid #dc2626;
    outline-offset: 2px;
  }

  .source-delete-btn svg {
    flex-shrink: 0;
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

  .external-links-container {
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
  }

  /* Edit/Delete action buttons */
  .species-actions {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-left: auto;
    flex-shrink: 0;
  }

  .action-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.5rem 0.75rem;
    border-radius: 0.5rem;
    font-size: 0.875rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.15s ease;
    border: 1px solid transparent;
  }

  .action-btn svg {
    flex-shrink: 0;
  }

  .action-btn-edit {
    color: var(--color-forest-700);
    background-color: var(--color-forest-100);
    border-color: var(--color-forest-200);
  }

  .action-btn-edit:hover {
    background-color: var(--color-forest-200);
    border-color: var(--color-forest-300);
  }

  .action-btn-edit:focus-visible {
    outline: 2px solid var(--color-forest-500);
    outline-offset: 2px;
  }

  .action-btn-delete {
    color: #dc2626;
    background-color: #fef2f2;
    border-color: #fecaca;
  }

  .action-btn-delete:hover {
    background-color: #fee2e2;
    border-color: #fca5a5;
  }

  .action-btn-delete:focus-visible {
    outline: 2px solid #dc2626;
    outline-offset: 2px;
  }

  /* Hide button text on small screens */
  @media (max-width: 640px) {
    .action-btn span {
      display: none;
    }

    .action-btn {
      /* Minimum 44x44px touch target */
      min-width: 2.75rem;
      min-height: 2.75rem;
      padding: 0.75rem;
    }

    .action-btn svg {
      width: 20px;
      height: 20px;
    }
  }

</style>
