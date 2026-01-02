<script>
	import { base } from '$app/paths';
	import Search from './Search.svelte';
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

			<!-- Search -->
			<div class="flex-1 max-w-md ml-auto" role="search" aria-label="Search species">
				<Search />
			</div>

			<!-- Navigation (desktop) -->
			<nav class="hidden sm:block" aria-label="Main navigation">
				<a href="{base}/about/" class="nav-link">About</a>
			</nav>

			<!-- Navigation (mobile) -->
			<nav class="flex sm:hidden items-center w-full justify-end" aria-label="Main navigation">
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
</style>
