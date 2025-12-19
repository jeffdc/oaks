// Handle errors from deployment mismatches
// When a new version is deployed, old cached JS files may not exist anymore

/** @type {import('@sveltejs/kit').HandleClientError} */
export function handleError({ error, event, status, message }) {
	const errorMessage = error?.message || message || '';
	const errorName = error?.name || '';

	// Check if this is a stale deployment error
	const isStaleDeployment =
		// Dynamic import failures (Chrome, Safari)
		errorMessage.includes('dynamically imported module') ||
		errorMessage.includes('Failed to fetch dynamically imported module') ||
		errorMessage.includes('error loading dynamically imported module') ||
		// Firefox-specific errors
		errorMessage.includes('NS_ERROR_CORRUPTED_CONTENT') ||
		errorName === 'NS_ERROR_CORRUPTED_CONTENT' ||
		// Network errors for missing chunks
		(errorMessage.includes('Failed to fetch') && errorMessage.includes('.js')) ||
		// Generic chunk loading failures
		errorMessage.includes('Loading chunk') ||
		errorMessage.includes('ChunkLoadError');

	if (isStaleDeployment) {
		console.log('Detected stale deployment, reloading page...');
		window.location.reload();
		return;
	}

	// Log other errors normally
	console.error('Client error:', error);
}
