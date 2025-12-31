<script>
	import { authStore, isAuthenticated } from '$lib/stores/authStore.js';
	import { verifyApiKey, ApiError } from '$lib/apiClient.js';

	let apiKeyInput = $state('');
	let showPassword = $state(false);
	let isVerifying = $state(false);
	let error = $state('');
	let success = $state('');

	// Check if already authenticated on mount
	$effect(() => {
		if ($isAuthenticated) {
			// Mask the stored key for display
			apiKeyInput = '••••••••••••••••';
		}
	});

	async function handleSave() {
		// Don't save if it's the masked placeholder
		if (apiKeyInput === '••••••••••••••••') {
			return;
		}

		if (!apiKeyInput.trim()) {
			error = 'Please enter an API key';
			success = '';
			return;
		}

		isVerifying = true;
		error = '';
		success = '';

		try {
			const isValid = await verifyApiKey(apiKeyInput.trim());

			if (isValid) {
				authStore.setKey(apiKeyInput.trim());
				success = 'API key verified and saved';
				apiKeyInput = '••••••••••••••••';
			} else {
				error = 'Invalid API key';
			}
		} catch (err) {
			if (err instanceof ApiError) {
				if (err.code === 'NETWORK_ERROR') {
					error = 'Unable to reach the API server. Check your connection.';
				} else if (err.code === 'TIMEOUT') {
					error = 'Request timed out. Please try again.';
				} else {
					error = err.message;
				}
			} else {
				error = 'An unexpected error occurred';
			}
		} finally {
			isVerifying = false;
		}
	}

	function handleClear() {
		authStore.clearKey();
		apiKeyInput = '';
		error = '';
		success = 'API key cleared';
	}

	function handleInputFocus() {
		// Clear the masked placeholder when user focuses
		if (apiKeyInput === '••••••••••••••••') {
			apiKeyInput = '';
		}
	}
</script>

<svelte:head>
	<title>Settings - Oak Compendium</title>
</svelte:head>

<div class="settings-container">
	<h1 class="settings-title">Settings</h1>

	<section class="settings-section">
		<h2 class="section-title">API Authentication</h2>
		<p class="section-description">
			Enter your API key to enable editing features. Keys are validated before saving.
		</p>

		<div class="form-group">
			<label for="api-key" class="form-label">API Key</label>
			<div class="input-wrapper">
				<input
					id="api-key"
					type={showPassword ? 'text' : 'password'}
					bind:value={apiKeyInput}
					onfocus={handleInputFocus}
					placeholder="Enter your API key"
					class="form-input"
					disabled={isVerifying}
					autocomplete="off"
				/>
				<button
					type="button"
					onclick={() => showPassword = !showPassword}
					class="toggle-visibility"
					aria-label={showPassword ? 'Hide API key' : 'Show API key'}
				>
					{#if showPassword}
						<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon">
							<path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/>
							<line x1="1" y1="1" x2="23" y2="23"/>
						</svg>
					{:else}
						<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon">
							<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
							<circle cx="12" cy="12" r="3"/>
						</svg>
					{/if}
				</button>
			</div>
		</div>

		{#if error}
			<div class="message error" role="alert">
				{error}
			</div>
		{/if}

		{#if success}
			<div class="message success" role="status">
				{success}
			</div>
		{/if}

		<div class="button-group">
			<button
				onclick={handleSave}
				disabled={isVerifying || apiKeyInput === '••••••••••••••••'}
				class="btn btn-primary"
			>
				{#if isVerifying}
					<span class="loading-spinner"></span>
					Verifying...
				{:else}
					Save
				{/if}
			</button>

			{#if $isAuthenticated}
				<button
					onclick={handleClear}
					disabled={isVerifying}
					class="btn btn-secondary"
				>
					Clear API Key
				</button>
			{/if}
		</div>

		<div class="info-box">
			<h3 class="info-title">Session Information</h3>
			<dl class="info-list">
				<div class="info-item">
					<dt>Status</dt>
					<dd>
						{#if $isAuthenticated}
							<span class="status-badge authenticated">Authenticated</span>
						{:else}
							<span class="status-badge not-authenticated">Not authenticated</span>
						{/if}
					</dd>
				</div>
				<div class="info-item">
					<dt>Session Timeout</dt>
					<dd>24 hours (server-side)</dd>
				</div>
			</dl>
		</div>

		<div class="security-note">
			<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="note-icon">
				<circle cx="12" cy="12" r="10"/>
				<line x1="12" y1="16" x2="12" y2="12"/>
				<line x1="12" y1="8" x2="12.01" y2="8"/>
			</svg>
			<div>
				<strong>Security Note:</strong> Your API key is stored in your browser's localStorage.
				It persists across sessions but is only accessible from this device and domain.
				Clear your browser data or use the "Clear API Key" button to remove it.
			</div>
		</div>
	</section>
</div>

<style>
	.settings-container {
		max-width: 40rem;
		margin: 0 auto;
		padding: 2rem 1rem;
	}

	.settings-title {
		font-family: var(--font-serif);
		font-size: 2rem;
		font-weight: 600;
		color: var(--color-text-primary);
		margin-bottom: 2rem;
	}

	.settings-section {
		background: white;
		border: 1px solid var(--color-border);
		border-radius: 0.75rem;
		padding: 1.5rem;
		box-shadow: var(--shadow-sm);
	}

	.section-title {
		font-family: var(--font-serif);
		font-size: 1.25rem;
		font-weight: 600;
		color: var(--color-text-primary);
		margin: 0 0 0.5rem 0;
	}

	.section-description {
		color: var(--color-text-secondary);
		font-size: 0.9375rem;
		margin: 0 0 1.5rem 0;
	}

	.form-group {
		margin-bottom: 1rem;
	}

	.form-label {
		display: block;
		font-size: 0.875rem;
		font-weight: 500;
		color: var(--color-text-primary);
		margin-bottom: 0.5rem;
	}

	.input-wrapper {
		position: relative;
		display: flex;
		align-items: center;
	}

	.form-input {
		width: 100%;
		padding: 0.625rem 2.5rem 0.625rem 0.875rem;
		font-size: 0.9375rem;
		border: 1px solid var(--color-border);
		border-radius: 0.5rem;
		background: white;
		color: var(--color-text-primary);
		transition: border-color 0.15s, box-shadow 0.15s;
	}

	.form-input:focus {
		outline: none;
		border-color: var(--color-forest-500);
		box-shadow: 0 0 0 3px rgba(34, 139, 34, 0.1);
	}

	.form-input:disabled {
		background: var(--color-background-subtle);
		cursor: not-allowed;
	}

	.toggle-visibility {
		position: absolute;
		right: 0.5rem;
		padding: 0.375rem;
		background: none;
		border: none;
		color: var(--color-text-muted);
		cursor: pointer;
		border-radius: 0.25rem;
		transition: color 0.15s;
	}

	.toggle-visibility:hover {
		color: var(--color-text-secondary);
	}

	.icon {
		width: 1.25rem;
		height: 1.25rem;
	}

	.message {
		padding: 0.75rem 1rem;
		border-radius: 0.5rem;
		font-size: 0.875rem;
		margin-bottom: 1rem;
	}

	.message.error {
		background: #fef2f2;
		color: #b91c1c;
		border: 1px solid #fecaca;
	}

	.message.success {
		background: #f0fdf4;
		color: #15803d;
		border: 1px solid #bbf7d0;
	}

	.button-group {
		display: flex;
		gap: 0.75rem;
		margin-bottom: 1.5rem;
	}

	.btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.625rem 1.25rem;
		font-size: 0.9375rem;
		font-weight: 500;
		border-radius: 0.5rem;
		cursor: pointer;
		transition: all 0.15s;
	}

	.btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.btn-primary {
		background: var(--color-forest-600);
		color: white;
		border: none;
	}

	.btn-primary:hover:not(:disabled) {
		background: var(--color-forest-700);
	}

	.btn-secondary {
		background: white;
		color: var(--color-text-primary);
		border: 1px solid var(--color-border);
	}

	.btn-secondary:hover:not(:disabled) {
		background: var(--color-background-subtle);
	}

	.info-box {
		background: var(--color-background-subtle);
		border-radius: 0.5rem;
		padding: 1rem;
		margin-bottom: 1rem;
	}

	.info-title {
		font-size: 0.875rem;
		font-weight: 600;
		color: var(--color-text-primary);
		margin: 0 0 0.75rem 0;
	}

	.info-list {
		margin: 0;
	}

	.info-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.375rem 0;
		font-size: 0.875rem;
	}

	.info-item dt {
		color: var(--color-text-secondary);
	}

	.info-item dd {
		margin: 0;
		color: var(--color-text-primary);
	}

	.status-badge {
		display: inline-flex;
		align-items: center;
		padding: 0.25rem 0.625rem;
		font-size: 0.75rem;
		font-weight: 500;
		border-radius: 9999px;
	}

	.status-badge.authenticated {
		background: #dcfce7;
		color: #15803d;
	}

	.status-badge.not-authenticated {
		background: #f3f4f6;
		color: #6b7280;
	}

	.security-note {
		display: flex;
		gap: 0.75rem;
		padding: 1rem;
		background: #fffbeb;
		border: 1px solid #fde68a;
		border-radius: 0.5rem;
		font-size: 0.8125rem;
		color: #92400e;
		line-height: 1.5;
	}

	.note-icon {
		flex-shrink: 0;
		width: 1.25rem;
		height: 1.25rem;
		color: #d97706;
	}
</style>
