// Handle errors from stale service worker / deployment mismatch
// When a new version is deployed, old cached JS files may not exist anymore

/** @type {import('@sveltejs/kit').HandleClientError} */
export function handleError({ error, event, status, message }) {
	// Check if this is a dynamic import error (stale deployment)
	const errorMessage = error?.message || message || '';
	if (
		errorMessage.includes('dynamically imported module') ||
		errorMessage.includes('Failed to fetch dynamically imported module') ||
		errorMessage.includes('error loading dynamically imported module')
	) {
		// Force a full page reload to get the new version
		console.log('Detected stale deployment, reloading page...');
		window.location.reload();
		return;
	}

	// Log other errors normally
	console.error('Client error:', error);
}
