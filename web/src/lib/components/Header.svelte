<script>
	import { base } from '$app/paths';
	import Search from './Search.svelte';
	import { isOnline } from '$lib/stores/dataStore.js';
	import { isAuthenticated } from '$lib/stores/authStore.js';
</script>

<header class="sticky top-0 z-40" role="banner" style="background: linear-gradient(135deg, var(--color-forest-800) 0%, var(--color-forest-700) 100%); box-shadow: var(--shadow-lg);">
	<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
		<div class="flex flex-wrap items-center gap-4">
			<!-- Logo and title -->
			<a
				href="{base}/"
				class="flex items-center gap-3 hover:opacity-90 transition-opacity no-underline"
				aria-label="Oak Compendium home"
			>
				<img src="{base}/oak-leaf-outline.svg" alt="" class="w-7 h-10 brightness-0 invert opacity-90" aria-hidden="true" />
				<span class="text-xl font-bold text-white" style="font-family: var(--font-serif); letter-spacing: 0.01em;">Oak Compendium</span>
			</a>

			<!-- Offline indicator (only shown when offline) -->
			{#if !$isOnline}
				<span class="offline-badge" role="status" aria-live="polite">
					Offline
				</span>
			{/if}

			<!-- Admin mode indicator (only shown when authenticated) -->
			{#if $isAuthenticated}
				<a
					href="{base}/settings/"
					class="admin-badge"
					title="Editing enabled. Click to manage settings."
					aria-label="Admin mode active. Go to settings."
				>
					<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="admin-icon" aria-hidden="true">
						<path fill-rule="evenodd" d="M8.34 1.804A1 1 0 019.32 1h1.36a1 1 0 01.98.804l.295 1.473c.497.144.971.342 1.416.587l1.25-.834a1 1 0 011.262.125l.962.962a1 1 0 01.125 1.262l-.834 1.25c.245.445.443.919.587 1.416l1.473.295a1 1 0 01.804.98v1.36a1 1 0 01-.804.98l-1.473.295a6.95 6.95 0 01-.587 1.416l.834 1.25a1 1 0 01-.125 1.262l-.962.962a1 1 0 01-1.262.125l-1.25-.834a6.953 6.953 0 01-1.416.587l-.295 1.473a1 1 0 01-.98.804H9.32a1 1 0 01-.98-.804l-.295-1.473a6.957 6.957 0 01-1.416-.587l-1.25.834a1 1 0 01-1.262-.125l-.962-.962a1 1 0 01-.125-1.262l.834-1.25a6.957 6.957 0 01-.587-1.416l-1.473-.295A1 1 0 011 10.68V9.32a1 1 0 01.804-.98l1.473-.295c.144-.497.342-.971.587-1.416l-.834-1.25a1 1 0 01.125-1.262l.962-.962A1 1 0 015.38 3.03l1.25.834a6.957 6.957 0 011.416-.587l.295-1.473zM13 10a3 3 0 11-6 0 3 3 0 016 0z" clip-rule="evenodd" />
					</svg>
					Admin
				</a>
			{/if}

			<!-- Search -->
			<div class="flex-1 max-w-md ml-auto" role="search" aria-label="Search species">
				<Search />
			</div>

			<!-- Navigation (desktop) -->
			<nav class="hidden sm:flex items-center gap-1" aria-label="Main navigation">
				{#if !$isAuthenticated}
					<a href="{base}/settings/" class="nav-link">Settings</a>
				{/if}
				<a href="{base}/about/" class="nav-link">About</a>
			</nav>

			<!-- Navigation (mobile) -->
			<nav class="flex sm:hidden items-center w-full justify-end gap-1" aria-label="Main navigation">
				{#if !$isAuthenticated}
					<a href="{base}/settings/" class="nav-link">Settings</a>
				{/if}
				<a href="{base}/about/" class="nav-link">About</a>
			</nav>
		</div>
	</div>
</header>

<style>
	a {
		text-decoration: none;
	}

	.nav-link {
		padding: 0.5rem 1rem;
		font-size: 0.9375rem;
		font-weight: 500;
		color: var(--color-white-85);
		border-radius: 0.375rem;
		transition: all 0.15s;
		text-decoration: none;
	}

	.nav-link:hover {
		background-color: var(--color-white-10);
		color: white;
	}

	.nav-link:focus-visible {
		outline: none;
		background-color: var(--color-white-15);
		box-shadow: 0 0 0 2px var(--color-white-30);
	}

	.offline-badge {
		display: inline-flex;
		align-items: center;
		padding: 0.25rem 0.625rem;
		font-size: 0.75rem;
		font-weight: 500;
		color: #fef3c7;
		background-color: rgba(217, 119, 6, 0.3);
		border: 1px solid rgba(217, 119, 6, 0.5);
		border-radius: 9999px;
		letter-spacing: 0.025em;
	}

	.admin-badge {
		display: inline-flex;
		align-items: center;
		gap: 0.375rem;
		padding: 0.25rem 0.625rem;
		font-size: 0.75rem;
		font-weight: 500;
		color: #bfdbfe;
		background-color: rgba(59, 130, 246, 0.25);
		border: 1px solid rgba(59, 130, 246, 0.5);
		border-radius: 9999px;
		letter-spacing: 0.025em;
		text-decoration: none;
		transition: all 0.15s;
	}

	.admin-badge:hover {
		background-color: rgba(59, 130, 246, 0.4);
		color: #dbeafe;
	}

	.admin-badge:focus-visible {
		outline: none;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.5);
	}

	.admin-icon {
		width: 0.875rem;
		height: 0.875rem;
	}
</style>
