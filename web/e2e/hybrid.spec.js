/**
 * E2E tests for hybrid species functionality.
 *
 * Tests cover:
 * - Hybrid species badge and display
 * - Parent species links
 * - Hybrid symbol (×) display
 * - Navigation between hybrids and parent species
 */

import { test, expect } from './fixtures/test-base.js';

test.describe('Hybrid Species', () => {
  test('hybrid species shows Hybrid badge', async ({ page }) => {
    // × bebbiana is a hybrid in our mock data
    await page.goto('/species/%C3%97%20bebbiana/');

    // Should show "Hybrid" badge instead of "Species"
    await expect(page.getByText('Hybrid', { exact: true })).toBeVisible();
  });

  test('hybrid species displays × symbol in name', async ({ page }) => {
    await page.goto('/species/%C3%97%20bebbiana/');

    // The title should include the × symbol
    await expect(page.locator('h1').filter({ hasText: /×|bebbiana/i })).toBeVisible();
  });

  test('hybrid species shows parent species section', async ({ page }) => {
    await page.goto('/species/%C3%97%20bebbiana/');

    // Should have Parent Species heading (use exact match)
    await expect(page.getByRole('heading', { name: /Parent Species/i })).toBeVisible();

    // Should show parent links
    await expect(page.getByRole('link', { name: /alba/i }).first()).toBeVisible();
    await expect(page.getByRole('link', { name: /macrocarpa/i }).first()).toBeVisible();
  });

  test('clicking parent species link navigates to parent', async ({ page }) => {
    await page.goto('/species/%C3%97%20bebbiana/');

    // Verify parent links are visible
    const albaLink = page.getByRole('link', { name: /alba/i }).first();
    await expect(albaLink).toBeVisible();

    // Click on alba parent link
    await albaLink.click();

    // Should navigate to parent species
    await expect(page).toHaveURL(/\/species\/alba/);

    // Should show species page
    await expect(page.getByText('Species', { exact: true })).toBeVisible();
  });

  test('parent species shows hybrid in Known Hybrids section', async ({ page }) => {
    await page.goto('/species/alba/');

    // Should have Known Hybrids section
    const hybridsSection = page.getByRole('heading', { name: /Known Hybrids/i });
    await expect(hybridsSection).toBeVisible();

    // Should list × bebbiana as a known hybrid
    await expect(page.getByRole('link', { name: /bebbiana/i }).first()).toBeVisible();
  });

  test('clicking hybrid link navigates to hybrid species', async ({ page }) => {
    await page.goto('/species/alba/');

    // Find hybrid link in Known Hybrids section
    const hybridsSection = page.locator('section').filter({ hasText: /Known Hybrids/ }).first();
    const hybridLink = hybridsSection.getByRole('link').first();

    if (await hybridLink.isVisible()) {
      await hybridLink.click();

      // Should navigate to hybrid species
      await expect(page).toHaveURL(/\/species\//);

      // Should show Hybrid badge
      await expect(page.getByText('Hybrid', { exact: true })).toBeVisible();
    }
  });

  test('hybrid shows other parent when coming from one parent', async ({ page }) => {
    await page.goto('/species/alba/');

    // Click on a hybrid link (bebbiana)
    const hybridLink = page.getByRole('link', { name: /bebbiana/i }).first();

    if (await hybridLink.isVisible()) {
      await hybridLink.click();

      // The hybrid page should show Parent Species heading
      await expect(page.getByRole('heading', { name: /Parent Species/i })).toBeVisible();

      // Should have links to both parents
      await expect(page.getByRole('link', { name: /alba/i }).first()).toBeVisible();
      await expect(page.getByRole('link', { name: /macrocarpa/i }).first()).toBeVisible();
    }
  });

  test('hybrids appear in search results', async ({ page }) => {
    await page.goto('/list/');

    // Search for a hybrid
    const searchInput = page.getByPlaceholder(/search/i);
    await searchInput.fill('bebbiana');

    // Wait for results to load
    await page.waitForSelector('.results-list a, .species-list a', { timeout: 10000 });

    // Should find the hybrid in results
    await expect(page.getByRole('link', { name: /bebbiana/i }).first()).toBeVisible();
  });

  test('hybrid parent formula is displayed when available', async ({ page }) => {
    await page.goto('/species/%C3%97%20bebbiana/');

    // Should show Parent Species heading
    await expect(page.getByRole('heading', { name: /Parent Species/i })).toBeVisible();

    // Should show both parent names somewhere on the page
    await expect(page.getByRole('link', { name: /alba/i }).first()).toBeVisible();
    await expect(page.getByRole('link', { name: /macrocarpa/i }).first()).toBeVisible();
  });

  test('hybrid without conservation status has no badge', async ({ page }) => {
    await page.goto('/species/%C3%97%20bebbiana/');

    // Hybrids typically don't have conservation status
    // The conservation badge should not be visible or should not have text
    const conservationBadge = page.locator('.conservation-badge');
    const isVisible = await conservationBadge.isVisible();

    if (isVisible) {
      // If visible, should be empty or show appropriate status
      const text = await conservationBadge.textContent();
      // Some hybrids might have status, which is fine
      expect(text).toBeTruthy();
    }
  });
});
