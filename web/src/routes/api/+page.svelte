<script>
	import { onMount } from 'svelte';
	import { browser } from '$app/environment';

	const API_DOCS_URL = 'https://api.oakcompendium.com/api/v1/docs';

	onMount(() => {
		if (browser) {
			window.location.href = API_DOCS_URL;
		}
	});
</script>

<svelte:head>
	<meta http-equiv="refresh" content="0; url={API_DOCS_URL}" />
	<title>API Documentation - Oak Compendium</title>
</svelte:head>

<div class="redirect-container">
	<p>Redirecting to API documentation...</p>
	<p><a href={API_DOCS_URL}>Click here if not redirected</a></p>
</div>

<style>
	.redirect-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 50vh;
		gap: 1rem;
	}
	a {
		color: var(--color-forest-600);
		text-decoration: underline;
	}
</style>
