<script>
  /**
   * SpeciesMergeScreen - Side-by-side view for merging a synonym into a target species
   *
   * Displays both species, allows editing the target, and shows referencing species.
   */

  import { base } from '$app/paths';
  import { goto } from '$app/navigation';
  import {
    fetchSpeciesFull,
    fetchSpeciesReferences,
    updateSpecies,
    createSpeciesSource,
    updateSpeciesSource,
    deleteSpecies,
    ApiError
  } from '$lib/apiClient.js';
  import { toast } from '$lib/stores/toastStore.js';
  import LoadingSpinner from './LoadingSpinner.svelte';
  import MergeFieldRow from './MergeFieldRow.svelte';
  import MergeDataLossWarning from './MergeDataLossWarning.svelte';
  import MergeSelfReferenceWarning from './MergeSelfReferenceWarning.svelte';

  /** @type {{ synonymName: string, targetName: string }} */
  let { synonymName, targetName } = $props();

  // State
  let synonymData = $state(null);
  let targetData = $state(null);
  let referencingSpecies = $state([]);
  let loading = $state(true);
  let error = $state(null);

  // Editable target fields (bound to MergeFieldRow)
  let editedTarget = $state({
    author: null,
    conservation_status: null,
    subgenus: null,
    section: null,
    subsection: null,
    complex: null,
    parent1: null,
    parent2: null
  });

  // Collapsible state for references section
  let referencesExpanded = $state(true);

  // Group references by type for display
  let groupedReferences = $derived(() => {
    const asParent = [];
    const inHybrids = [];
    const inCloselyRelated = [];

    for (const ref of referencingSpecies) {
      switch (ref.reference_type) {
        case 'parent1':
        case 'parent2':
          asParent.push({ ...ref, parentField: ref.reference_type });
          break;
        case 'hybrids':
          inHybrids.push(ref);
          break;
        case 'closely_related_to':
          inCloselyRelated.push(ref);
          break;
      }
    }

    return { asParent, inHybrids, inCloselyRelated };
  });

  // Total reference count (exported for confirmation dialog)
  let referenceCount = $derived(referencingSpecies.length);

  // Track which sources have been unchecked for data loss warning
  // Format: { [sourceId]: boolean } - true if unchecked (data loss)
  let uncheckedSourceIds = $state({});

  // Save operation state
  let showConfirmDialog = $state(false);
  let saving = $state(false);
  let saveError = $state(null);
  let completedSteps = $state([]);

  // Dirty state tracking for cancel confirmation
  let initialState = $state(null);
  let showDiscardDialog = $state(false);

  // Compute list of unchecked source names for the warning
  let uncheckedSources = $derived(() => {
    if (!synonymData?.sources) return [];

    // Find sources that only exist on the synonym (not on target)
    const targetSourceIds = new Set((targetData?.sources || []).map(s => s.source_id));

    return synonymData.sources
      .filter(source => {
        // Only warn about sources that are synonym-only AND unchecked
        const isSynonymOnly = !targetSourceIds.has(source.source_id);
        const isUnchecked = uncheckedSourceIds[source.source_id] === true;
        return isSynonymOnly && isUnchecked;
      })
      .map(source => source.source_name || `Source ${source.source_id}`);
  });

  // Detect self-reference issues
  // Check if target's hybrids, closely_related_to, parent1, parent2 contain the synonym name
  let selfReferenceIssues = $derived(() => {
    if (!synonymData || !targetData) return [];

    const issues = [];
    const synonymNameLower = synonymName.toLowerCase().replace(/^×\s*/, '');

    // Helper to check if a name matches the synonym (case-insensitive)
    const matchesSynonym = (name) => {
      if (!name) return false;
      const normalizedName = name.toLowerCase().replace(/^×\s*/, '');
      return normalizedName === synonymNameLower;
    };

    // Check hybrids array (read from target data, not editable yet)
    if (targetData.hybrids) {
      for (const hybrid of targetData.hybrids) {
        if (matchesSynonym(hybrid)) {
          issues.push({
            field: 'hybrids',
            value: hybrid,
            hint: 'Edit the target\'s hybrids field to remove before merging'
          });
        }
      }
    }

    // Check closely_related_to array (read from target data, not editable yet)
    if (targetData.closely_related_to) {
      for (const related of targetData.closely_related_to) {
        if (matchesSynonym(related)) {
          issues.push({
            field: 'closely_related_to',
            value: related,
            hint: 'Edit the target\'s closely related species to remove before merging'
          });
        }
      }
    }

    // Check parent1 (from editable field)
    if (matchesSynonym(editedTarget.parent1)) {
      issues.push({
        field: 'parent1',
        value: editedTarget.parent1,
        hint: 'Clear the parent1 field above before saving'
      });
    }

    // Check parent2 (from editable field)
    if (matchesSynonym(editedTarget.parent2)) {
      issues.push({
        field: 'parent2',
        value: editedTarget.parent2,
        hint: 'Clear the parent2 field above before saving'
      });
    }

    return issues;
  });

  // Compute sources that will be transferred (synonym-only sources that are checked)
  let sourcesToTransfer = $derived(() => {
    if (!synonymData?.sources) return [];

    const targetSourceIds = new Set((targetData?.sources || []).map(s => s.source_id));

    return synonymData.sources.filter(source => {
      const isSynonymOnly = !targetSourceIds.has(source.source_id);
      const isChecked = uncheckedSourceIds[source.source_id] !== true;
      return isSynonymOnly && isChecked;
    });
  });

  // Compute synonyms that will be added to target
  let synonymsToAdd = $derived(() => {
    if (!synonymData) return [];

    const existingSynonyms = new Set(
      (targetData?.synonyms || []).map(s => s.toLowerCase())
    );

    const newSynonyms = [];

    // Add the synonym species name itself
    if (!existingSynonyms.has(synonymData.scientific_name.toLowerCase())) {
      newSynonyms.push(synonymData.scientific_name);
    }

    // Add the synonym's existing synonyms
    for (const syn of synonymData.synonyms || []) {
      if (!existingSynonyms.has(syn.toLowerCase())) {
        newSynonyms.push(syn);
      }
    }

    return newSynonyms;
  });

  // Format species name for display (handle hybrids)
  function formatName(name, isHybrid) {
    if (!name) return '';
    // Remove any existing × prefix to avoid duplication
    const cleanName = name.replace(/^×\s*/, '');
    const prefix = isHybrid ? '\u00d7 ' : '';
    return prefix + cleanName;
  }

  // Get current form state for dirty checking
  function getCurrentFormState() {
    return {
      editedTarget: {
        author: editedTarget.author,
        conservation_status: editedTarget.conservation_status,
        subgenus: editedTarget.subgenus,
        section: editedTarget.section,
        subsection: editedTarget.subsection,
        complex: editedTarget.complex,
        parent1: editedTarget.parent1,
        parent2: editedTarget.parent2
      },
      uncheckedSourceIds: { ...uncheckedSourceIds }
    };
  }

  // Check if form has unsaved changes
  function isDirty() {
    if (!initialState) return false;
    const current = getCurrentFormState();
    return JSON.stringify(current) !== JSON.stringify(initialState);
  }

  // Load data on mount
  $effect(() => {
    loadData();
  });

  // Warn on browser back/refresh if there are unsaved changes
  $effect(() => {
    function handleBeforeUnload(e) {
      if (isDirty()) {
        e.preventDefault();
        // Modern browsers ignore custom messages, but returnValue is still required
        e.returnValue = '';
      }
    }

    window.addEventListener('beforeunload', handleBeforeUnload);

    return () => {
      window.removeEventListener('beforeunload', handleBeforeUnload);
    };
  });

  async function loadData() {
    loading = true;
    error = null;

    try {
      // Fetch synonym first to check if it was already merged
      let synonymResult;
      try {
        synonymResult = await fetchSpeciesFull(synonymName);
      } catch (synonymErr) {
        // If synonym returns a redirect (already merged), redirect to target
        if (synonymErr instanceof ApiError &&
            synonymErr.status === 404 &&
            synonymErr.code === 'SYNONYM_REDIRECT' &&
            synonymErr.details?.synonym_of) {
          // The synonym was already merged, redirect to the target species
          goto(`${base}/species/${encodeURIComponent(targetName)}/`, {
            replaceState: true
          });
          return;
        }
        throw synonymErr;
      }

      // Fetch target and references
      const [targetResult, refsResult] = await Promise.all([
        fetchSpeciesFull(targetName),
        fetchSpeciesReferences(synonymName)
      ]);

      synonymData = synonymResult;
      targetData = targetResult;
      referencingSpecies = refsResult.data || [];

      // Initialize editable fields from target
      editedTarget = {
        author: targetData.author || null,
        conservation_status: targetData.conservation_status || null,
        subgenus: targetData.subgenus || null,
        section: targetData.section || null,
        subsection: targetData.subsection || null,
        complex: targetData.complex || null,
        parent1: targetData.parent1 || null,
        parent2: targetData.parent2 || null
      };

      // Snapshot state for dirty checking (after auto-population)
      initialState = getCurrentFormState();
    } catch (err) {
      console.error('Failed to load merge data:', err);
      if (err instanceof ApiError && err.status === 404) {
        error = `Species not found: ${err.message}`;
      } else {
        error = err instanceof ApiError ? err.message : 'Failed to load species data';
      }
    } finally {
      loading = false;
    }
  }

  function handleCancel() {
    if (isDirty()) {
      showDiscardDialog = true;
      return;
    }
    // Navigate immediately if no changes
    goto(`${base}/species/${encodeURIComponent(synonymName)}/`);
  }

  function handleDiscardCancel() {
    showDiscardDialog = false;
  }

  function handleDiscardConfirm() {
    showDiscardDialog = false;
    goto(`${base}/species/${encodeURIComponent(synonymName)}/`);
  }

  function handleSaveClick() {
    // Show confirmation dialog
    saveError = null;
    completedSteps = [];
    showConfirmDialog = true;
  }

  function handleConfirmCancel() {
    showConfirmDialog = false;
  }

  async function handleConfirmMerge() {
    saving = true;
    saveError = null;
    completedSteps = [];

    try {
      // Step 1: Update target species
      const updatedSynonyms = [
        ...(targetData.synonyms || []),
        ...synonymsToAdd()
      ];

      const speciesUpdate = {
        name: targetData.scientific_name,
        author: editedTarget.author,
        is_hybrid: targetData.is_hybrid,
        conservation_status: editedTarget.conservation_status,
        taxonomy: {
          subgenus: editedTarget.subgenus,
          section: editedTarget.section,
          subsection: editedTarget.subsection,
          complex: editedTarget.complex
        },
        parent1: editedTarget.parent1,
        parent2: editedTarget.parent2,
        synonyms: updatedSynonyms,
        hybrids: targetData.hybrids || [],
        closely_related_to: targetData.closely_related_to || [],
        subspecies_varieties: targetData.subspecies_varieties || [],
        external_links: targetData.external_links || []
      };

      await updateSpecies(targetName, speciesUpdate);
      completedSteps = [...completedSteps, 'Updated target species'];

      // Step 2: Transfer source records
      const targetSourceIds = new Set((targetData?.sources || []).map(s => s.source_id));
      const sourcesToCreate = sourcesToTransfer();

      for (const source of sourcesToCreate) {
        const sourceData = {
          source_id: source.source_id,
          local_names: source.local_names || [],
          range: source.range || null,
          growth_habit: source.growth_habit || null,
          leaves: source.leaves || null,
          flowers: source.flowers || null,
          fruits: source.fruits || null,
          bark: source.bark || null,
          twigs: source.twigs || null,
          buds: source.buds || null,
          hardiness_habitat: source.hardiness_habitat || null,
          miscellaneous: source.miscellaneous || null,
          url: source.url || null,
          is_preferred: false  // New sources are not preferred
        };

        await createSpeciesSource(targetName, sourceData);
        completedSteps = [...completedSteps, `Transferred source: ${source.source_name || `Source ${source.source_id}`}`];
      }

      // Step 3: Update parent references
      const parentRefs = groupedReferences().asParent;
      for (const ref of parentRefs) {
        // Fetch the species, update the parent field, save
        const refSpecies = await fetchSpeciesFull(ref.scientific_name);
        const refUpdate = {
          name: refSpecies.scientific_name,
          author: refSpecies.author,
          is_hybrid: refSpecies.is_hybrid,
          conservation_status: refSpecies.conservation_status,
          taxonomy: {
            subgenus: refSpecies.subgenus,
            section: refSpecies.section,
            subsection: refSpecies.subsection,
            complex: refSpecies.complex
          },
          parent1: ref.parentField === 'parent1' ? targetData.scientific_name : refSpecies.parent1,
          parent2: ref.parentField === 'parent2' ? targetData.scientific_name : refSpecies.parent2,
          synonyms: refSpecies.synonyms || [],
          hybrids: refSpecies.hybrids || [],
          closely_related_to: refSpecies.closely_related_to || [],
          subspecies_varieties: refSpecies.subspecies_varieties || [],
          external_links: refSpecies.external_links || []
        };

        await updateSpecies(ref.scientific_name, refUpdate);
        completedSteps = [...completedSteps, `Updated ${ref.parentField} reference in ${ref.scientific_name}`];
      }

      // Step 4: Update array references (hybrids, closely_related_to)
      const hybridRefs = groupedReferences().inHybrids;
      for (const ref of hybridRefs) {
        const refSpecies = await fetchSpeciesFull(ref.scientific_name);
        const updatedHybrids = (refSpecies.hybrids || []).map(h =>
          h.toLowerCase() === synonymData.scientific_name.toLowerCase() ? targetData.scientific_name : h
        );

        const refUpdate = {
          name: refSpecies.scientific_name,
          author: refSpecies.author,
          is_hybrid: refSpecies.is_hybrid,
          conservation_status: refSpecies.conservation_status,
          taxonomy: {
            subgenus: refSpecies.subgenus,
            section: refSpecies.section,
            subsection: refSpecies.subsection,
            complex: refSpecies.complex
          },
          parent1: refSpecies.parent1,
          parent2: refSpecies.parent2,
          synonyms: refSpecies.synonyms || [],
          hybrids: updatedHybrids,
          closely_related_to: refSpecies.closely_related_to || [],
          subspecies_varieties: refSpecies.subspecies_varieties || [],
          external_links: refSpecies.external_links || []
        };

        await updateSpecies(ref.scientific_name, refUpdate);
        completedSteps = [...completedSteps, `Updated hybrids array in ${ref.scientific_name}`];
      }

      const relatedRefs = groupedReferences().inCloselyRelated;
      for (const ref of relatedRefs) {
        const refSpecies = await fetchSpeciesFull(ref.scientific_name);
        const updatedRelated = (refSpecies.closely_related_to || []).map(r =>
          r.toLowerCase() === synonymData.scientific_name.toLowerCase() ? targetData.scientific_name : r
        );

        const refUpdate = {
          name: refSpecies.scientific_name,
          author: refSpecies.author,
          is_hybrid: refSpecies.is_hybrid,
          conservation_status: refSpecies.conservation_status,
          taxonomy: {
            subgenus: refSpecies.subgenus,
            section: refSpecies.section,
            subsection: refSpecies.subsection,
            complex: refSpecies.complex
          },
          parent1: refSpecies.parent1,
          parent2: refSpecies.parent2,
          synonyms: refSpecies.synonyms || [],
          hybrids: refSpecies.hybrids || [],
          closely_related_to: updatedRelated,
          subspecies_varieties: refSpecies.subspecies_varieties || [],
          external_links: refSpecies.external_links || []
        };

        await updateSpecies(ref.scientific_name, refUpdate);
        completedSteps = [...completedSteps, `Updated closely_related_to array in ${ref.scientific_name}`];
      }

      // Step 5: Delete synonym species (MUST BE LAST)
      await deleteSpecies(synonymName);
      completedSteps = [...completedSteps, 'Deleted synonym species'];

      // Success! Show toast and redirect
      const displayName = formatName(synonymData.scientific_name, synonymData.is_hybrid);
      const displayTarget = formatName(targetData.scientific_name, targetData.is_hybrid);
      toast.success(`Successfully merged ${displayName} into ${displayTarget}`);

      // Redirect to target species page
      await goto(`${base}/species/${encodeURIComponent(targetName)}/`, { replaceState: true });

    } catch (err) {
      console.error('Merge failed:', err);
      saveError = {
        message: err instanceof ApiError ? err.message : 'An unexpected error occurred',
        completedSteps: [...completedSteps]
      };
    } finally {
      saving = false;
    }
  }
</script>

<div class="merge-screen">
  {#if loading}
    <div class="loading-container">
      <LoadingSpinner size="lg" message="Loading species data..." />
    </div>
  {:else if error}
    <div class="error-container">
      <svg class="error-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
      </svg>
      <p class="error-title">Unable to load species</p>
      <p class="error-message">{error}</p>
      <a href="{base}/list/" class="back-link">&larr; Back to species list</a>
    </div>
  {:else if synonymData && targetData}
    <!-- Header -->
    <header class="merge-header">
      <h1 class="merge-title">
        Merge:
        <span class="species-name synonym-name">
          {formatName(synonymData.scientific_name, synonymData.is_hybrid)}
        </span>
        <span class="arrow">&rarr;</span>
        <span class="species-name target-name">
          {formatName(targetData.scientific_name, targetData.is_hybrid)}
        </span>
      </h1>
      <p class="merge-subtitle">
        The synonym will be deleted and its data merged into the target species.
      </p>
    </header>

    <!-- Column headers -->
    <div class="column-headers">
      <div class="column-header synonym-header">
        <span class="column-label">Synonym (Read-only)</span>
        <span class="species-link">
          <a href="{base}/species/{encodeURIComponent(synonymName)}/">
            {formatName(synonymData.scientific_name, synonymData.is_hybrid)}
          </a>
        </span>
      </div>
      <div class="spacer"></div>
      <div class="column-header target-header">
        <span class="column-label">Target (Editable)</span>
        <span class="species-link">
          <a href="{base}/species/{encodeURIComponent(targetName)}/">
            {formatName(targetData.scientific_name, targetData.is_hybrid)}
          </a>
        </span>
      </div>
    </div>

    <!-- Field rows -->
    <section class="merge-fields">
      <h2 class="section-title">Species Fields</h2>

      <MergeFieldRow
        label="Author"
        synonymValue={synonymData.author}
        bind:targetValue={editedTarget.author}
        type="text"
      />

      <MergeFieldRow
        label="Conservation Status"
        synonymValue={synonymData.conservation_status}
        bind:targetValue={editedTarget.conservation_status}
        type="text"
      />

      <h3 class="subsection-title">Taxonomy</h3>

      <MergeFieldRow
        label="Subgenus"
        synonymValue={synonymData.subgenus}
        bind:targetValue={editedTarget.subgenus}
        type="text"
      />

      <MergeFieldRow
        label="Section"
        synonymValue={synonymData.section}
        bind:targetValue={editedTarget.section}
        type="text"
      />

      <MergeFieldRow
        label="Subsection"
        synonymValue={synonymData.subsection}
        bind:targetValue={editedTarget.subsection}
        type="text"
      />

      <MergeFieldRow
        label="Complex"
        synonymValue={synonymData.complex}
        bind:targetValue={editedTarget.complex}
        type="text"
      />

      {#if synonymData.is_hybrid || targetData.is_hybrid}
        <h3 class="subsection-title">Hybrid Parents</h3>

        <MergeFieldRow
          label="Parent 1"
          synonymValue={synonymData.parent1}
          bind:targetValue={editedTarget.parent1}
          type="text"
        />

        <MergeFieldRow
          label="Parent 2"
          synonymValue={synonymData.parent2}
          bind:targetValue={editedTarget.parent2}
          type="text"
        />
      {/if}
    </section>

    <!-- Referencing species -->
    <section class="references-section">
      <button
        type="button"
        class="references-header"
        onclick={() => referencesExpanded = !referencesExpanded}
        aria-expanded={referencesExpanded}
      >
        <svg
          class="chevron-icon"
          class:chevron-expanded={referencesExpanded}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
          stroke-width="2"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
        </svg>
        <h2 class="section-title-inline">
          References to Update
          <span class="reference-count">({referenceCount} {referenceCount === 1 ? 'species' : 'species'})</span>
        </h2>
      </button>

      {#if referencesExpanded}
        <div class="references-content">
          {#if referenceCount === 0}
            <p class="no-references">
              No other species reference "{synonymData.scientific_name}"
            </p>
          {:else}
            <p class="references-note">
              These species will be updated to reference "{targetData.scientific_name}" instead.
            </p>

            {#if groupedReferences().asParent.length > 0}
              <div class="reference-group">
                <h3 class="reference-group-title">
                  As Parent ({groupedReferences().asParent.length})
                </h3>
                <ul class="references-list">
                  {#each groupedReferences().asParent as ref}
                    <li class="reference-item">
                      <span class="bullet">&bull;</span>
                      <span class="reference-name">
                        {#if ref.scientific_name.startsWith('×') || ref.scientific_name.includes(' × ')}
                          × {ref.scientific_name.replace(/^×\s*/, '')}
                        {:else}
                          {ref.scientific_name}
                        {/if}
                      </span>
                      <span class="reference-detail">({ref.parentField})</span>
                    </li>
                  {/each}
                </ul>
              </div>
            {/if}

            {#if groupedReferences().inHybrids.length > 0}
              <div class="reference-group">
                <h3 class="reference-group-title">
                  In Hybrids ({groupedReferences().inHybrids.length})
                </h3>
                <ul class="references-list">
                  {#each groupedReferences().inHybrids as ref}
                    <li class="reference-item">
                      <span class="bullet">&bull;</span>
                      <span class="reference-name">{ref.scientific_name}</span>
                    </li>
                  {/each}
                </ul>
              </div>
            {/if}

            {#if groupedReferences().inCloselyRelated.length > 0}
              <div class="reference-group">
                <h3 class="reference-group-title">
                  In Closely Related ({groupedReferences().inCloselyRelated.length})
                </h3>
                <ul class="references-list">
                  {#each groupedReferences().inCloselyRelated as ref}
                    <li class="reference-item">
                      <span class="bullet">&bull;</span>
                      <span class="reference-name">{ref.scientific_name}</span>
                    </li>
                  {/each}
                </ul>
              </div>
            {/if}
          {/if}
        </div>
      {/if}
    </section>

    <!-- Warnings section -->
    {#if uncheckedSources().length > 0 || selfReferenceIssues().length > 0}
      <section class="warnings-section">
        <MergeDataLossWarning uncheckedSources={uncheckedSources()} />
        <MergeSelfReferenceWarning issues={selfReferenceIssues()} />
      </section>
    {/if}

    <!-- Action bar -->
    <footer class="action-bar">
      <button type="button" class="btn btn-secondary" onclick={handleCancel} disabled={saving}>
        Cancel
      </button>
      <button type="button" class="btn btn-primary" onclick={handleSaveClick} disabled={saving || selfReferenceIssues().length > 0}>
        {#if saving}
          <span class="btn-spinner"></span>
          Saving...
        {:else}
          Save Merge
        {/if}
      </button>
    </footer>
  {/if}

  <!-- Confirmation Dialog -->
  {#if showConfirmDialog}
    <div class="dialog-overlay" onclick={handleConfirmCancel}>
      <div class="dialog" onclick={(e) => e.stopPropagation()}>
        {#if saveError}
          <!-- Error state -->
          <h2 class="dialog-title dialog-title-error">Merge Partially Failed</h2>
          <div class="dialog-content">
            <div class="completed-steps">
              {#each saveError.completedSteps as step}
                <div class="step step-success">
                  <svg class="step-icon" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clip-rule="evenodd" />
                  </svg>
                  <span>{step}</span>
                </div>
              {/each}
              <div class="step step-error">
                <svg class="step-icon" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M4.28 4.28a.75.75 0 011.06 0L10 8.94l4.66-4.66a.75.75 0 111.06 1.06L11.06 10l4.66 4.66a.75.75 0 11-1.06 1.06L10 11.06l-4.66 4.66a.75.75 0 01-1.06-1.06L8.94 10 4.28 5.34a.75.75 0 010-1.06z" clip-rule="evenodd" />
                </svg>
                <span>Failed: {saveError.message}</span>
              </div>
            </div>
            <p class="error-note">
              The synonym "{formatName(synonymData.scientific_name, synonymData.is_hybrid)}" was NOT deleted.
              You can fix the issue and try again, or refresh to start over.
            </p>
          </div>
          <div class="dialog-actions">
            <button type="button" class="btn btn-secondary" onclick={handleConfirmCancel}>
              Close
            </button>
          </div>
        {:else if saving}
          <!-- Saving state -->
          <h2 class="dialog-title">Merging Species...</h2>
          <div class="dialog-content">
            <div class="saving-spinner">
              <LoadingSpinner size="md" />
            </div>
            <div class="completed-steps">
              {#each completedSteps as step}
                <div class="step step-success">
                  <svg class="step-icon" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clip-rule="evenodd" />
                  </svg>
                  <span>{step}</span>
                </div>
              {/each}
            </div>
          </div>
        {:else}
          <!-- Confirmation state -->
          <h2 class="dialog-title">Confirm Merge</h2>
          <div class="dialog-content">
            <p class="confirm-intro">
              You are about to merge "{formatName(synonymData.scientific_name, synonymData.is_hybrid)}"
              into "{formatName(targetData.scientific_name, targetData.is_hybrid)}". This will:
            </p>
            <ul class="confirm-list">
              {#if synonymsToAdd().length > 0}
                <li class="confirm-item confirm-item-add">
                  <svg class="confirm-icon" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clip-rule="evenodd" />
                  </svg>
                  <span>Add {synonymsToAdd().length} {synonymsToAdd().length === 1 ? 'synonym' : 'synonyms'} to {targetData.scientific_name}</span>
                </li>
              {/if}
              <li class="confirm-item confirm-item-add">
                <svg class="confirm-icon" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clip-rule="evenodd" />
                </svg>
                <span>Update {targetData.scientific_name} with merged field values</span>
              </li>
              {#if sourcesToTransfer().length > 0}
                <li class="confirm-item confirm-item-add">
                  <svg class="confirm-icon" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clip-rule="evenodd" />
                  </svg>
                  <span>Transfer {sourcesToTransfer().length} source {sourcesToTransfer().length === 1 ? 'record' : 'records'} to {targetData.scientific_name}</span>
                </li>
              {/if}
              {#if referenceCount > 0}
                <li class="confirm-item confirm-item-add">
                  <svg class="confirm-icon" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clip-rule="evenodd" />
                  </svg>
                  <span>Update {referenceCount} other {referenceCount === 1 ? 'species' : 'species'} that reference {synonymData.scientific_name}</span>
                </li>
              {/if}
              <li class="confirm-item confirm-item-delete">
                <svg class="confirm-icon" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M4.28 4.28a.75.75 0 011.06 0L10 8.94l4.66-4.66a.75.75 0 111.06 1.06L11.06 10l4.66 4.66a.75.75 0 11-1.06 1.06L10 11.06l-4.66 4.66a.75.75 0 01-1.06-1.06L8.94 10 4.28 5.34a.75.75 0 010-1.06z" clip-rule="evenodd" />
                </svg>
                <span>Delete "{formatName(synonymData.scientific_name, synonymData.is_hybrid)}" permanently</span>
              </li>
            </ul>
            <div class="confirm-warning">
              <svg class="warning-icon" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd" />
              </svg>
              <span>This action cannot be undone.</span>
            </div>
          </div>
          <div class="dialog-actions">
            <button type="button" class="btn btn-secondary" onclick={handleConfirmCancel}>
              Cancel
            </button>
            <button type="button" class="btn btn-danger" onclick={handleConfirmMerge}>
              Confirm Merge
            </button>
          </div>
        {/if}
      </div>
    </div>
  {/if}

  <!-- Discard Changes Dialog -->
  {#if showDiscardDialog}
    <div class="dialog-overlay" onclick={handleDiscardCancel}>
      <div class="dialog" onclick={(e) => e.stopPropagation()}>
        <h2 class="dialog-title">Discard Changes?</h2>
        <div class="dialog-content">
          <p class="discard-message">
            You have unsaved changes. Are you sure you want to discard them and return to
            <span class="discard-species-name">{formatName(synonymData?.scientific_name, synonymData?.is_hybrid)}</span>?
          </p>
        </div>
        <div class="dialog-actions">
          <button type="button" class="btn btn-secondary" onclick={handleDiscardCancel}>
            Keep Editing
          </button>
          <button type="button" class="btn btn-danger" onclick={handleDiscardConfirm}>
            Discard Changes
          </button>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .merge-screen {
    max-width: 1200px;
    margin: 0 auto;
    padding: 1.5rem;
  }

  /* Loading state */
  .loading-container {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 400px;
    background-color: var(--color-surface);
    border-radius: 1rem;
    box-shadow: var(--shadow-sm);
  }

  /* Error state */
  .error-container {
    padding: 5rem 1.5rem;
    text-align: center;
    background-color: var(--color-surface);
    border-radius: 1rem;
    box-shadow: var(--shadow-sm);
  }

  .error-icon {
    width: 4rem;
    height: 4rem;
    color: var(--color-error, #dc2626);
    margin: 0 auto 1rem;
  }

  .error-title {
    font-size: 1.125rem;
    font-weight: 500;
    color: var(--color-text-primary);
    margin-bottom: 0.25rem;
  }

  .error-message {
    font-size: 0.875rem;
    color: var(--color-text-secondary);
    margin-bottom: 1rem;
  }

  .back-link {
    display: inline-flex;
    align-items: center;
    color: var(--color-forest-600);
    font-weight: 500;
    text-decoration: none;
    transition: color 0.15s ease;
  }

  .back-link:hover {
    color: var(--color-forest-700);
  }

  /* Header */
  .merge-header {
    margin-bottom: 1.5rem;
    padding: 1.5rem;
    background-color: var(--color-surface);
    border-radius: 1rem;
    box-shadow: var(--shadow-sm);
  }

  .merge-title {
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--color-text-primary);
    margin: 0 0 0.5rem 0;
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 0.5rem;
  }

  .species-name {
    font-style: italic;
    font-family: var(--font-serif);
  }

  .synonym-name {
    color: var(--color-text-secondary);
  }

  .target-name {
    color: var(--color-forest-700);
  }

  .arrow {
    color: var(--color-text-tertiary);
    font-style: normal;
  }

  .merge-subtitle {
    font-size: 0.9375rem;
    color: var(--color-text-secondary);
    margin: 0;
  }

  /* Column headers */
  .column-headers {
    display: grid;
    grid-template-columns: 1fr auto 1fr;
    gap: 0.75rem;
    margin-bottom: 1rem;
    padding: 0 0.75rem;
  }

  .column-header {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .column-label {
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--color-text-tertiary);
  }

  .synonym-header .column-label {
    color: var(--color-text-tertiary);
  }

  .target-header .column-label {
    color: var(--color-forest-600);
  }

  .species-link a {
    font-size: 0.875rem;
    font-style: italic;
    font-family: var(--font-serif);
    color: var(--color-forest-600);
    text-decoration: none;
  }

  .species-link a:hover {
    text-decoration: underline;
  }

  .spacer {
    width: 2rem;
  }

  /* Fields section */
  .merge-fields {
    background-color: var(--color-surface);
    border-radius: 1rem;
    box-shadow: var(--shadow-sm);
    padding: 1.5rem;
    margin-bottom: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .section-title {
    font-size: 1.125rem;
    font-weight: 600;
    color: var(--color-text-primary);
    margin: 0 0 0.5rem 0;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid var(--color-border);
  }

  .subsection-title {
    font-size: 0.9375rem;
    font-weight: 600;
    color: var(--color-text-secondary);
    margin: 1rem 0 0.5rem 0;
  }

  /* References section */
  .references-section {
    background-color: var(--color-surface);
    border-radius: 1rem;
    box-shadow: var(--shadow-sm);
    margin-bottom: 1.5rem;
    border: 1px solid var(--color-border);
  }

  .references-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    width: 100%;
    padding: 1rem 1.5rem;
    background: none;
    border: none;
    cursor: pointer;
    text-align: left;
    border-radius: 1rem;
  }

  .references-header:hover {
    background-color: var(--color-background);
    border-radius: 1rem;
  }

  .references-header[aria-expanded="true"] {
    border-radius: 1rem 1rem 0 0;
  }

  .references-header[aria-expanded="true"]:hover {
    border-radius: 1rem 1rem 0 0;
  }

  .chevron-icon {
    width: 1rem;
    height: 1rem;
    color: var(--color-text-tertiary);
    transition: transform 0.2s ease;
    flex-shrink: 0;
  }

  .chevron-expanded {
    transform: rotate(90deg);
  }

  .section-title-inline {
    font-size: 1rem;
    font-weight: 600;
    color: var(--color-text-secondary);
    margin: 0;
  }

  .reference-count {
    font-weight: 400;
    color: var(--color-text-tertiary);
  }

  .references-content {
    padding: 0 1.5rem 1.5rem 1.5rem;
    border-top: 1px solid var(--color-border);
  }

  .no-references {
    font-size: 0.875rem;
    color: var(--color-text-tertiary);
    font-style: italic;
    margin: 1rem 0 0 0;
  }

  .references-note {
    font-size: 0.875rem;
    color: var(--color-text-secondary);
    margin: 1rem 0;
  }

  .reference-group {
    margin-top: 1rem;
  }

  .reference-group-title {
    font-size: 0.8125rem;
    font-weight: 600;
    color: var(--color-text-secondary);
    margin: 0 0 0.5rem 0;
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }

  .references-list {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .reference-item {
    display: flex;
    align-items: baseline;
    gap: 0.5rem;
    padding: 0.25rem 0;
    font-size: 0.9375rem;
  }

  .bullet {
    color: var(--color-text-tertiary);
    flex-shrink: 0;
  }

  .reference-name {
    font-style: italic;
    font-family: var(--font-serif);
    color: var(--color-text-primary);
  }

  .reference-detail {
    font-size: 0.75rem;
    color: var(--color-text-tertiary);
    font-style: normal;
    font-family: var(--font-sans);
  }

  /* Warnings section */
  .warnings-section {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    margin-bottom: 1.5rem;
  }

  /* Action bar */
  .action-bar {
    position: sticky;
    bottom: 0;
    display: flex;
    justify-content: flex-end;
    gap: 0.75rem;
    padding: 1rem 1.5rem;
    background-color: var(--color-surface);
    border-radius: 1rem;
    box-shadow: var(--shadow-lg);
  }

  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 0.625rem 1.25rem;
    font-size: 0.9375rem;
    font-weight: 500;
    border-radius: 0.5rem;
    cursor: pointer;
    transition: all 0.15s ease;
    border: none;
  }

  .btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-secondary {
    background-color: var(--color-background);
    color: var(--color-text-primary);
    border: 1px solid var(--color-border);
  }

  .btn-secondary:hover:not(:disabled) {
    background-color: var(--color-border);
  }

  .btn-primary {
    background-color: var(--color-forest-600);
    color: white;
  }

  .btn-primary:hover:not(:disabled) {
    background-color: var(--color-forest-700);
  }

  /* Button spinner */
  .btn-spinner {
    width: 1rem;
    height: 1rem;
    border: 2px solid currentColor;
    border-top-color: transparent;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    margin-right: 0.5rem;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  /* Danger button */
  .btn-danger {
    background-color: var(--color-error, #dc2626);
    color: white;
  }

  .btn-danger:hover:not(:disabled) {
    background-color: #b91c1c;
  }

  /* Dialog overlay */
  .dialog-overlay {
    position: fixed;
    inset: 0;
    background-color: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    padding: 1rem;
  }

  .dialog {
    background-color: var(--color-surface);
    border-radius: 1rem;
    box-shadow: var(--shadow-xl);
    max-width: 500px;
    width: 100%;
    max-height: 90vh;
    overflow-y: auto;
  }

  .dialog-title {
    font-size: 1.25rem;
    font-weight: 600;
    color: var(--color-text-primary);
    margin: 0;
    padding: 1.5rem 1.5rem 0;
  }

  .dialog-title-error {
    color: var(--color-error, #dc2626);
  }

  .dialog-content {
    padding: 1rem 1.5rem;
  }

  .dialog-actions {
    display: flex;
    justify-content: flex-end;
    gap: 0.75rem;
    padding: 0 1.5rem 1.5rem;
  }

  /* Confirmation list */
  .confirm-intro {
    font-size: 0.9375rem;
    color: var(--color-text-secondary);
    margin: 0 0 1rem 0;
    line-height: 1.5;
  }

  .confirm-list {
    list-style: none;
    padding: 0;
    margin: 0 0 1rem 0;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .confirm-item {
    display: flex;
    align-items: flex-start;
    gap: 0.5rem;
    font-size: 0.9375rem;
    line-height: 1.4;
  }

  .confirm-icon {
    width: 1.25rem;
    height: 1.25rem;
    flex-shrink: 0;
    margin-top: 0.125rem;
  }

  .confirm-item-add .confirm-icon {
    color: var(--color-forest-600);
  }

  .confirm-item-delete .confirm-icon {
    color: var(--color-error, #dc2626);
  }

  .confirm-item-delete {
    color: var(--color-error, #dc2626);
  }

  .confirm-warning {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1rem;
    background-color: rgba(234, 179, 8, 0.1);
    border-radius: 0.5rem;
    font-size: 0.875rem;
    font-weight: 500;
    color: #a16207;
  }

  .warning-icon {
    width: 1.25rem;
    height: 1.25rem;
    color: #ca8a04;
    flex-shrink: 0;
  }

  /* Saving state */
  .saving-spinner {
    display: flex;
    justify-content: center;
    margin-bottom: 1rem;
  }

  .completed-steps {
    display: flex;
    flex-direction: column;
    gap: 0.375rem;
  }

  .step {
    display: flex;
    align-items: flex-start;
    gap: 0.5rem;
    font-size: 0.875rem;
    line-height: 1.4;
  }

  .step-icon {
    width: 1rem;
    height: 1rem;
    flex-shrink: 0;
    margin-top: 0.125rem;
  }

  .step-success .step-icon {
    color: var(--color-forest-600);
  }

  .step-error {
    color: var(--color-error, #dc2626);
  }

  .step-error .step-icon {
    color: var(--color-error, #dc2626);
  }

  .error-note {
    font-size: 0.875rem;
    color: var(--color-text-secondary);
    margin: 1rem 0 0 0;
    padding: 0.75rem 1rem;
    background-color: var(--color-background);
    border-radius: 0.5rem;
    line-height: 1.5;
  }

  /* Discard dialog */
  .discard-message {
    font-size: 0.9375rem;
    color: var(--color-text-secondary);
    margin: 0;
    line-height: 1.6;
  }

  .discard-species-name {
    font-style: italic;
    font-family: var(--font-serif);
    color: var(--color-text-primary);
  }

  /* Responsive */
  @media (max-width: 768px) {
    .merge-screen {
      padding: 1rem;
    }

    .column-headers {
      display: none;
    }

    .merge-title {
      font-size: 1.25rem;
    }

    .dialog {
      max-width: 100%;
      margin: 1rem;
    }
  }
</style>
