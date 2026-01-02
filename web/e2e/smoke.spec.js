/**
 * Smoke tests to verify E2E test infrastructure works.
 *
 * These tests verify:
 * - App loads successfully
 * - API mocking is working
 * - Basic navigation functions
 */

import { test, expect } from './fixtures/test-base.js';

test.describe('Smoke Tests', () => {
  test('landing page loads with content', async ({ page }) => {
    await page.goto('/');

    // Check page title
    await expect(page).toHaveTitle(/Oak Compendium/i);

    // Check that the welcome section is visible
    await expect(page.getByRole('heading', { name: /Explore the World of Oaks/i })).toBeVisible();

    // Stats should load from mocked API - look for the stats section
    // The welcome subtitle should show species count after loading
    await expect(page.locator('.welcome-subtitle')).toBeVisible();
  });

  test('can navigate to species list via taxonomy', async ({ page }) => {
    await page.goto('/');

    // Click the Taxonomy Tree link
    await page.getByRole('link', { name: /Taxonomy Tree/i }).click();

    // Should be on taxonomy page
    await expect(page).toHaveURL(/\/taxonomy/);

    // Should see subgenera from mock data - use first() to avoid ambiguity
    await expect(page.getByRole('link', { name: /Quercus.*species/i }).first()).toBeVisible();
  });

  test('can navigate to species detail', async ({ page }) => {
    await page.goto('/species/alba/');

    // Should see species name in the title area
    await expect(page.locator('h1, h2').filter({ hasText: /alba/i })).toBeVisible();

    // Should see author
    await expect(page.getByText('L.', { exact: true }).first()).toBeVisible();

    // Should see content from mock source data - use first() for multiple matches
    await expect(page.getByText('white oak', { exact: true }).first()).toBeVisible();
  });

  test('can navigate to taxonomy view', async ({ page }) => {
    await page.goto('/taxonomy/');

    // Should see the "Genus" badge and Quercus heading
    await expect(page.getByText('Genus', { exact: true })).toBeVisible();
    await expect(page.locator('h1').filter({ hasText: 'Quercus' })).toBeVisible();

    // Should see subgenera links from mock data
    await expect(page.getByRole('link', { name: /Lobatae.*species/i })).toBeVisible();
  });

  test('can navigate to about page', async ({ page }) => {
    await page.goto('/about/');

    // Should have about heading - the about page uses h2 not h1
    await expect(page.getByRole('heading', { name: /About/i }).first()).toBeVisible();
  });

  test('search input is visible in header', async ({ page }) => {
    await page.goto('/');

    // Search input should be visible
    const searchInput = page.getByRole('searchbox').or(page.getByPlaceholder(/search/i));
    await expect(searchInput).toBeVisible();
  });

  test('404 page for unknown species', async ({ page }) => {
    await page.goto('/species/nonexistent-species-xyz/');

    // Should show not found message
    await expect(page.getByText(/not found/i)).toBeVisible();
  });
});
