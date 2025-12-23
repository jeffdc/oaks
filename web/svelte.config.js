import adapter from '@sveltejs/adapter-static';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	kit: {
		adapter: adapter({
			pages: 'dist',
			assets: 'dist',
			fallback: '404.html',
			precompress: false,
			strict: true
		}),
		paths: {
			base: ''
		},
		prerender: {
			handleHttpError: 'warn'
		},
		version: {
			// Check for new app version every 5 minutes
			pollInterval: 5 * 60 * 1000
		}
	}
};

export default config;
