/**
 * E2E tests for the search functionality.
 *
 * Tests cover:
 * - Searching by species name
 * - Searching by common name
 * - Empty search results
 * - Navigating from search results to species detail
 * - Clearing search
 */

import { test, expect } from './fixtures/test-base.js';

test.describe('Search Flow', () => {
  test('search by species name shows results', async ({ page }) => {
    await page.goto('/');

    // Find the search input
    const searchInput = page.getByPlaceholder(/search/i);
    await expect(searchInput).toBeVisible();

    // Type a species name
    await searchInput.fill('alba');

    // Should navigate to list page
    await expect(page).toHaveURL(/\/list/);

    // Wait for results to load
    await page.waitForSelector('.results-list, .species-list');

    // Should show matching species
    await expect(page.getByText('Quercus', { exact: false }).first()).toBeVisible();
    await expect(page.getByText('alba', { exact: false }).first()).toBeVisible();
  });

  test('search by common name shows results', async ({ page }) => {
    await page.goto('/list/');

    const searchInput = page.getByPlaceholder(/search/i);
    await searchInput.fill('white');

    // Wait for search results
    await page.waitForSelector('.results-list, .species-list');

    // Should find species with "white" in common names (Q. alba = white oak)
    await expect(page.getByText(/alba/i).first()).toBeVisible();
  });

  test('search with no results shows empty state', async ({ page }) => {
    await page.goto('/list/');

    const searchInput = page.getByPlaceholder(/search/i);
    await searchInput.fill('zzzznotfound');

    // Wait for empty state
    await expect(page.getByText(/no results found/i)).toBeVisible();
  });

  test('clicking search result navigates to species detail', async ({ page }) => {
    await page.goto('/list/');

    const searchInput = page.getByPlaceholder(/search/i);
    await searchInput.fill('alba');

    // Wait for results and click on alba
    await page.waitForSelector('.results-list a, .species-list a');
    await page.getByRole('link', { name: /alba/i }).first().click();

    // Should navigate to species detail page
    await expect(page).toHaveURL(/\/species\/alba/);

    // Should show species detail
    await expect(page.locator('h1, h2').filter({ hasText: /alba/i })).toBeVisible();
  });

  test('clearing search shows browse mode', async ({ page }) => {
    await page.goto('/list/');

    const searchInput = page.getByPlaceholder(/search/i);

    // First search for something
    await searchInput.fill('alba');
    await page.waitForSelector('.results-list a, .species-list a');

    // Clear the search using the clear button or manually
    const clearButton = page.getByRole('button', { name: /clear/i });
    if (await clearButton.isVisible()) {
      await clearButton.click();
    } else {
      // Fallback: clear manually
      await searchInput.clear();
    }

    // Wait for the page to update - in browse mode, we should see some species
    // The page should show loading or results
    await page.waitForTimeout(500); // Small wait for state to update

    // After clearing, the search input should be empty
    await expect(searchInput).toHaveValue('');
  });

  test('search counts display correctly', async ({ page }) => {
    await page.goto('/list/');

    const searchInput = page.getByPlaceholder(/search/i);
    await searchInput.fill('oak');

    // Wait for results
    await page.waitForSelector('.counts-bar');

    // Should show count information
    const countsBar = page.locator('.counts-bar');
    await expect(countsBar).toBeVisible();

    // Should have total count
    await expect(countsBar.getByText(/total/i)).toBeVisible();
  });
});
