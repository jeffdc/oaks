<script>
	/** @type {'sm' | 'md' | 'lg'} */
	export let size = 'md';
	/** @type {boolean} */
	export let overlay = false;
	/** @type {string | undefined} */
	export let message = undefined;

	const sizeClasses = {
		sm: 'spinner-sm',
		md: 'spinner-md',
		lg: 'spinner-lg'
	};
</script>

{#if overlay}
	<div class="overlay" role="status" aria-busy="true" aria-live="polite">
		<div class="overlay-content">
			<div class="spinner {sizeClasses[size]}" aria-label={message || 'Loading'}></div>
			{#if message}
				<p class="message">{message}</p>
			{/if}
		</div>
	</div>
{:else}
	<span class="inline-spinner" role="status" aria-busy="true" aria-live="polite">
		<span class="spinner {sizeClasses[size]}" aria-label={message || 'Loading'}></span>
		{#if message}
			<span class="sr-only">{message}</span>
		{/if}
	</span>
{/if}

<style>
	.spinner {
		border: 3px solid var(--color-border);
		border-top-color: var(--color-forest-600);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	.spinner-sm {
		width: 1rem;
		height: 1rem;
		border-width: 2px;
	}

	.spinner-md {
		width: 2rem;
		height: 2rem;
		border-width: 3px;
	}

	.spinner-lg {
		width: 3rem;
		height: 3rem;
		border-width: 4px;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	/* Inline spinner for buttons */
	.inline-spinner {
		display: inline-flex;
		align-items: center;
		justify-content: center;
	}

	/* Full-screen overlay */
	.overlay {
		position: fixed;
		inset: 0;
		z-index: 50;
		display: flex;
		align-items: center;
		justify-content: center;
		background-color: rgba(0, 0, 0, 0.5);
		backdrop-filter: blur(2px);
	}

	.overlay-content {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
		padding: 2rem;
		background-color: var(--color-background);
		border-radius: 0.75rem;
		box-shadow: var(--shadow-xl);
	}

	.message {
		margin: 0;
		font-size: 0.9375rem;
		color: var(--color-text-secondary);
	}

	/* Screen reader only */
	.sr-only {
		position: absolute;
		width: 1px;
		height: 1px;
		padding: 0;
		margin: -1px;
		overflow: hidden;
		clip: rect(0, 0, 0, 0);
		white-space: nowrap;
		border: 0;
	}
</style>
