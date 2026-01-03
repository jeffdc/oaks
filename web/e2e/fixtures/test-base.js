/**
 * Base test fixture with API mocking for E2E tests.
 *
 * All tests should import from this file instead of '@playwright/test' directly.
 * This ensures API calls are intercepted and return predictable mock data.
 *
 * Usage:
 *   import { test, expect } from './fixtures/test-base.js';
 *
 *   test('my test', async ({ page }) => {
 *     await page.goto('/');
 *     // API calls are automatically mocked
 *   });
 */

import { test as base, expect } from '@playwright/test';
import { getMockResponse, mockStats, mockSpeciesList, mockSpeciesFull, mockSources } from './mock-data.js';

// Extend base test with API mocking
export const test = base.extend({
  // Auto-setup API mocking for every test
  page: async ({ page }, use) => {
    // Intercept all API requests to the API server
    await page.route('**/api.oakcompendium.com/**', async (route) => {
      const url = route.request().url();
      const mockData = getMockResponse(url);

      if (mockData) {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify(mockData)
        });
      } else {
        // Return 404 for unmatched API routes
        await route.fulfill({
          status: 404,
          contentType: 'application/json',
          body: JSON.stringify({ error: 'Not found' })
        });
      }
    });

    // Also intercept localhost API for local dev testing
    await page.route('**/localhost:8080/**', async (route) => {
      const url = route.request().url();
      // Convert localhost URL to match our getMockResponse expectations
      const mockUrl = url.replace('http://localhost:8080', 'https://api.oakcompendium.com');
      const mockData = getMockResponse(mockUrl);

      if (mockData) {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify(mockData)
        });
      } else {
        await route.fulfill({
          status: 404,
          contentType: 'application/json',
          body: JSON.stringify({ error: 'Not found' })
        });
      }
    });

    // Intercept health check
    await page.route('**/health', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ status: 'ok' })
      });
    });

    await use(page);
  }
});

// Re-export expect for convenience
export { expect };

// Export mock data for tests that need direct access
export { mockStats, mockSpeciesList, mockSpeciesFull, mockSources };
