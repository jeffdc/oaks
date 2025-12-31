<script>
	import LoadingSpinner from './LoadingSpinner.svelte';

	/** @type {'species' | 'taxon' | 'source' | 'species-source'} */
	export let entityType;
	/** @type {string} */
	export let entityName;
	/** @type {{ count: number, type: string } | undefined} */
	export let cascadeInfo = undefined;
	/** @type {boolean} */
	export let isDeleting = false;
	/** @type {() => void} */
	export let onConfirm;
	/** @type {() => void} */
	export let onCancel;

	// Format entity type for display
	function formatEntityType(type) {
		switch (type) {
			case 'species-source':
				return 'source data';
			default:
				return type;
		}
	}

	// Check if this is an error state (cannot delete)
	$: isError = cascadeInfo && (entityType === 'taxon' || entityType === 'source');

	// Get the appropriate title
	$: title = isError
		? `Cannot delete ${formatEntityType(entityType)}`
		: `Delete ${formatEntityType(entityType)}?`;

	// Get the entity display name (add Quercus prefix for species)
	$: displayName = entityType === 'species' || entityType === 'species-source'
		? `Quercus ${entityName}`
		: entityName;

	// Build the cascade/error message
	function getCascadeMessage() {
		if (!cascadeInfo) return null;

		const { count, type } = cascadeInfo;

		if (entityType === 'species') {
			return `This will also remove data from ${count} source${count !== 1 ? 's' : ''}.`;
		}
		if (entityType === 'taxon') {
			return `Cannot delete: ${count} species use${count === 1 ? 's' : ''} this taxon.`;
		}
		if (entityType === 'source') {
			return `Cannot delete: ${count} species have data from this source.`;
		}
		return null;
	}

	$: cascadeMessage = getCascadeMessage();

	// Handle keyboard events
	function handleKeydown(event) {
		if (event.key === 'Escape') {
			onCancel();
		}
	}
</script>

<svelte:window on:keydown={handleKeydown} />

<!-- Modal backdrop -->
<div
	class="overlay"
	role="dialog"
	aria-modal="true"
	aria-labelledby="dialog-title"
	aria-describedby="dialog-description"
>
	<div class="dialog">
		<!-- Header -->
		<h2 id="dialog-title" class="dialog-title" class:error-title={isError}>
			{title}
		</h2>

		<!-- Content -->
		<div id="dialog-description" class="dialog-content">
			<p class="entity-name">{displayName}</p>

			{#if cascadeMessage}
				<p class="cascade-message" class:error-message={isError}>
					{cascadeMessage}
				</p>
			{/if}
		</div>

		<!-- Actions -->
		<div class="dialog-actions">
			{#if isError}
				<!-- Error state: only show OK button -->
				<button
					type="button"
					class="btn btn-secondary"
					onclick={onCancel}
				>
					OK
				</button>
			{:else}
				<!-- Confirmation state: Cancel and Delete buttons -->
				<button
					type="button"
					class="btn btn-secondary"
					onclick={onCancel}
					disabled={isDeleting}
				>
					Cancel
				</button>
				<button
					type="button"
					class="btn btn-danger"
					onclick={onConfirm}
					disabled={isDeleting}
				>
					{#if isDeleting}
						<LoadingSpinner size="sm" />
						<span>Deleting...</span>
					{:else}
						Delete
					{/if}
				</button>
			{/if}
		</div>
	</div>
</div>

<style>
	.overlay {
		position: fixed;
		inset: 0;
		z-index: 100;
		display: flex;
		align-items: center;
		justify-content: center;
		background-color: rgba(0, 0, 0, 0.5);
		backdrop-filter: blur(2px);
		padding: 1rem;
	}

	.dialog {
		background-color: var(--color-surface);
		border-radius: 0.75rem;
		box-shadow: var(--shadow-xl);
		max-width: 24rem;
		width: 100%;
		padding: 1.5rem;
	}

	.dialog-title {
		margin: 0 0 1rem 0;
		font-family: var(--font-serif);
		font-size: 1.25rem;
		font-weight: 600;
		color: var(--color-text-primary);
	}

	.error-title {
		color: #991b1b;
	}

	.dialog-content {
		margin-bottom: 1.5rem;
	}

	.entity-name {
		margin: 0 0 0.5rem 0;
		font-size: 1rem;
		font-weight: 500;
		color: var(--color-text-primary);
	}

	.cascade-message {
		margin: 0;
		font-size: 0.875rem;
		color: var(--color-text-secondary);
	}

	.error-message {
		color: #991b1b;
		background-color: #fef2f2;
		border: 1px solid #fecaca;
		padding: 0.75rem;
		border-radius: 0.5rem;
	}

	.dialog-actions {
		display: flex;
		justify-content: flex-end;
		gap: 0.75rem;
	}

	.btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.625rem 1rem;
		border-radius: 0.5rem;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.15s ease;
		border: none;
	}

	.btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.btn-secondary {
		background-color: var(--color-border);
		color: var(--color-text-primary);
	}

	.btn-secondary:hover:not(:disabled) {
		background-color: #d6d3d1;
	}

	.btn-danger {
		background-color: #dc2626;
		color: white;
	}

	.btn-danger:hover:not(:disabled) {
		background-color: #b91c1c;
	}

	.btn-danger:focus-visible {
		outline: 2px solid #dc2626;
		outline-offset: 2px;
	}
</style>
