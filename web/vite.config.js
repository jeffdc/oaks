import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

// Read version from root version.json at build time
const __dirname = dirname(fileURLToPath(import.meta.url));
const versionFile = resolve(__dirname, '../version.json');
const versions = JSON.parse(readFileSync(versionFile, 'utf-8'));

export default defineConfig({
	plugins: [sveltekit()],
	define: {
		__APP_VERSION__: JSON.stringify(versions.web)
	},
	test: {
		include: ['src/**/*.{test,spec}.{js,ts}'],
		environment: 'jsdom',
		globals: true,
		setupFiles: ['src/tests/setup.js']
	}
});
