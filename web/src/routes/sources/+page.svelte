<script>
	import { base } from '$app/paths';
	import { onMount } from 'svelte';
	import { forceRefresh } from '$lib/stores/dataStore.js';
	import { canEdit } from '$lib/stores/authStore.js';
	import { toast } from '$lib/stores/toastStore.js';
	import { fetchSources, createSource, updateSource, deleteSource, fetchSourceById, ApiError } from '$lib/apiClient.js';
	import SourceEditForm from '$lib/components/SourceEditForm.svelte';
	import DeleteConfirmDialog from '$lib/components/DeleteConfirmDialog.svelte';

	let sources = $state([]);
	let isLoading = $state(true);
	let error = $state(null);

	// Edit/Delete modal state
	let showEditForm = false;
	let showDeleteDialog = false;
	let isDeleting = false;
	let editingSource = null;
	let deletingSource = null;
	let deleteCascadeInfo = null;

	onMount(async () => {
		try {
			sources = await fetchSources();
		} catch (err) {
			console.error('Failed to fetch sources:', err);
			error = err instanceof ApiError ? err.message : 'Failed to load sources';
		} finally {
			isLoading = false;
		}
	});

	// Handle create button click
	function handleCreateClick() {
		editingSource = null;
		showEditForm = true;
	}

	// Handle edit button click
	async function handleEditClick(source, event) {
		event.preventDefault();
		event.stopPropagation();

		try {
			// Fetch the full source data from API
			const sourceData = await fetchSourceById(source.source_id);
			editingSource = sourceData;
			showEditForm = true;
		} catch (error) {
			if (error instanceof ApiError) {
				toast.error(`Failed to load source: ${error.message}`);
			} else {
				toast.error('Failed to load source data');
			}
		}
	}

	// Handle delete button click
	function handleDeleteClick(source, event) {
		event.preventDefault();
		event.stopPropagation();

		deletingSource = source;
		// If there are species using this source, show error dialog
		if (source.species_count > 0) {
			deleteCascadeInfo = { count: source.species_count, type: 'species' };
		} else {
			deleteCascadeInfo = null;
		}
		showDeleteDialog = true;
	}

	// Handle save from edit form (create or update)
	async function handleSaveSource(formData) {
		try {
			if (editingSource) {
				// Update existing source
				await updateSource(editingSource.id, formData);
				toast.success('Source updated successfully');
			} else {
				// Create new source
				await createSource(formData);
				toast.success('Source created successfully');
			}
			// Refresh data to show changes
			await forceRefresh();
			sources = await getAllSourcesInfo();
			return null; // Success
		} catch (error) {
			if (error instanceof ApiError) {
				if (error.status === 400 && error.fieldErrors) {
					return error.fieldErrors;
				}
				const action = editingSource ? 'update' : 'create';
				toast.error(`Failed to ${action}: ${error.message}`);
			} else {
				const action = editingSource ? 'update' : 'create';
				toast.error(`Failed to ${action} source`);
			}
			throw error;
		}
	}

	// Handle delete confirmation
	async function handleDeleteConfirm() {
		if (!deletingSource) return;

		isDeleting = true;
		try {
			await deleteSource(deletingSource.source_id);
			toast.success('Source deleted successfully');
			showDeleteDialog = false;
			deletingSource = null;
			deleteCascadeInfo = null;
			// Refresh data to show changes
			await forceRefresh();
			sources = await getAllSourcesInfo();
		} catch (error) {
			if (error instanceof ApiError) {
				// Handle 409 Conflict - source has species data (constraint violation)
				if (error.status === 409) {
					// Update cascade info to show error state in dialog
					deleteCascadeInfo = {
						count: 0,
						type: 'species',
						message: 'Cannot delete: species have data from this source. Remove this source\'s data from all species first.'
					};
					// Dialog stays open and shows error state
				} else {
					toast.error(`Failed to delete: ${error.message}`);
				}
			} else {
				toast.error('Failed to delete source');
			}
		} finally {
			isDeleting = false;
		}
	}

	// Handle delete cancel
	function handleDeleteCancel() {
		showDeleteDialog = false;
		deletingSource = null;
		deleteCascadeInfo = null;
	}
</script>

<svelte:head>
	<title>Data Sources - Oak Compendium</title>
</svelte:head>

<div class="sources-page">
	<header class="page-header">
		<div class="page-header-row">
			<h1 class="page-title">Data Sources</h1>
			{#if $canEdit}
				<button
					type="button"
					class="create-btn"
					on:click={handleCreateClick}
				>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
						<line x1="12" y1="5" x2="12" y2="19" />
						<line x1="5" y1="12" x2="19" y2="12" />
					</svg>
					Create Source
				</button>
			{/if}
		</div>
		<p class="page-subtitle">
			The Oak Compendium draws from multiple sources to provide comprehensive information about oak species.
		</p>
	</header>

	{#if isLoading}
		<div class="loading">
			<div class="loading-spinner"></div>
			<p>Loading sources...</p>
		</div>
	{:else if error}
		<div class="error-state">
			<p>{error}</p>
		</div>
	{:else if sources.length === 0}
		<p class="empty-state">No sources found.</p>
	{:else}
		<div class="sources-grid">
			{#each sources as source}
				<a href="{base}/sources/{source.id}/" class="source-card" class:can-edit={$canEdit}>
					<div class="source-content">
						<h2 class="source-name">{source.name}</h2>
						{#if source.description}
							<p class="source-description">{source.description}</p>
						{/if}
						{#if source.source_type}
							<span class="type-badge">{source.source_type}</span>
						{/if}
					</div>
					{#if $canEdit}
						<div class="source-actions">
							<button
								type="button"
								class="source-action-btn source-action-edit"
								title="Edit source"
								onclick={(e) => handleEditClick(source, e)}
							>
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
									<path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
								</svg>
							</button>
							<button
								type="button"
								class="source-action-btn source-action-delete"
								title="Delete source"
								onclick={(e) => handleDeleteClick(source, e)}
							>
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<polyline points="3,6 5,6 21,6" />
									<path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
									<line x1="10" y1="11" x2="10" y2="17" />
									<line x1="14" y1="11" x2="14" y2="17" />
								</svg>
							</button>
						</div>
					{:else}
						<div class="card-arrow">
							<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
								<path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
							</svg>
						</div>
					{/if}
				</a>
			{/each}
		</div>
	{/if}
</div>

<!-- Create/Edit Source Modal -->
{#if showEditForm}
	<SourceEditForm
		source={editingSource}
		isOpen={showEditForm}
		onClose={() => { showEditForm = false; editingSource = null; }}
		onSave={handleSaveSource}
	/>
{/if}

<!-- Delete Confirmation Dialog -->
{#if showDeleteDialog && deletingSource}
	<DeleteConfirmDialog
		entityType="source"
		entityName={deletingSource.source_name}
		cascadeInfo={deleteCascadeInfo}
		{isDeleting}
		onConfirm={handleDeleteConfirm}
		onCancel={handleDeleteCancel}
	/>
{/if}

<style>
	.sources-page {
		max-width: 48rem;
		margin: 0 auto;
	}

	.page-header {
		margin-bottom: 2rem;
	}

	.page-header-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		margin-bottom: 0.5rem;
	}

	.page-title {
		font-family: var(--font-serif);
		font-size: 1.875rem;
		font-weight: 700;
		color: var(--color-forest-800);
		margin: 0;
	}

	.create-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.375rem;
		padding: 0.5rem 0.875rem;
		font-size: 0.875rem;
		font-weight: 500;
		color: white;
		background-color: var(--color-forest-600);
		border: none;
		border-radius: 0.5rem;
		cursor: pointer;
		transition: background-color 0.15s ease;
		white-space: nowrap;
	}

	.create-btn:hover {
		background-color: var(--color-forest-700);
	}

	.create-btn:focus-visible {
		outline: 2px solid var(--color-forest-500);
		outline-offset: 2px;
	}

	.create-btn svg {
		flex-shrink: 0;
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

	.error-state {
		text-align: center;
		padding: 3rem;
		color: var(--color-error, #dc2626);
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
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		padding: 1.5rem;
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

	.source-content {
		flex: 1;
		min-width: 0;
	}

	.source-name {
		font-family: var(--font-serif);
		font-size: 1.25rem;
		font-weight: 600;
		color: var(--color-forest-800);
		margin-bottom: 0.5rem;
	}

	.source-description {
		font-size: 0.9375rem;
		color: var(--color-text-secondary);
		line-height: 1.5;
		margin-bottom: 0.75rem;
	}

	/* Source action buttons */
	.source-actions {
		display: flex;
		gap: 0.25rem;
		flex-shrink: 0;
		opacity: 0;
		transition: opacity 0.15s ease;
	}

	/* Show on hover (desktop) */
	.source-card.can-edit:hover .source-actions {
		opacity: 1;
	}

	.source-action-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 1.75rem;
		height: 1.75rem;
		padding: 0;
		border: none;
		border-radius: 0.375rem;
		cursor: pointer;
		transition: all 0.15s ease;
	}

	.source-action-btn svg {
		flex-shrink: 0;
	}

	.source-action-edit {
		color: var(--color-forest-700);
		background-color: var(--color-forest-100);
	}

	.source-action-edit:hover {
		background-color: var(--color-forest-200);
	}

	.source-action-edit:focus-visible {
		outline: 2px solid var(--color-forest-500);
		outline-offset: 1px;
	}

	.source-action-delete {
		color: #dc2626;
		background-color: #fef2f2;
	}

	.source-action-delete:hover {
		background-color: #fee2e2;
	}

	.source-action-delete:focus-visible {
		outline: 2px solid #dc2626;
		outline-offset: 1px;
	}

	/* Mobile: always show action buttons when canEdit */
	@media (max-width: 640px) {
		.source-card.can-edit .source-actions {
			opacity: 1;
		}

		.source-action-btn {
			/* Minimum 44x44px touch target */
			width: 2.75rem;
			height: 2.75rem;
		}

		.source-action-btn svg {
			width: 18px;
			height: 18px;
		}
	}

	.type-badge {
		display: inline-block;
		font-size: 0.75rem;
		font-weight: 500;
		padding: 0.1875rem 0.5rem;
		background-color: var(--color-stone-100);
		color: var(--color-text-secondary);
		border-radius: 9999px;
		text-transform: capitalize;
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
