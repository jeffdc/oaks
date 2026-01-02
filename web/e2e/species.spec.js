/**
 * E2E tests for species detail view.
 *
 * Tests cover:
 * - Basic species detail display
 * - Taxonomy breadcrumb on species page
 * - Source tabs functionality
 * - Related species navigation
 * - External links section
 */

import { test, expect } from './fixtures/test-base.js';

test.describe('Species Detail View', () => {
  test('species page displays basic information', async ({ page }) => {
    await page.goto('/species/alba/');

    // Should show species name
    await expect(page.locator('h1').filter({ hasText: /alba/i })).toBeVisible();

    // Should show author
    await expect(page.getByText('L.', { exact: true }).first()).toBeVisible();

    // Should show "Species" badge (not hybrid)
    await expect(page.getByText('Species', { exact: true })).toBeVisible();
  });

  test('species page shows taxonomy breadcrumb', async ({ page }) => {
    await page.goto('/species/alba/');

    // Should have taxonomy navigation
    const taxonomyNav = page.locator('.taxonomy-nav');
    await expect(taxonomyNav).toBeVisible();

    // Should show Quercus genus link
    await expect(taxonomyNav.getByText('Quercus', { exact: false }).first()).toBeVisible();

    // Should show subgenus
    await expect(taxonomyNav.getByText(/subgenus/i)).toBeVisible();
  });

  test('clicking taxonomy breadcrumb navigates to taxon', async ({ page }) => {
    await page.goto('/species/alba/');

    // Click on genus link in breadcrumb
    await page.locator('.taxonomy-nav').getByRole('link').first().click();

    // Should navigate to taxonomy page
    await expect(page).toHaveURL(/\/taxonomy/);
  });

  test('source tabs allow switching between sources', async ({ page }) => {
    await page.goto('/species/alba/');

    // Should have source tabs
    const sourceTabs = page.locator('.source-tabs');
    await expect(sourceTabs).toBeVisible();

    // Should have at least one source tab
    const tabs = sourceTabs.locator('.source-tab');
    const tabCount = await tabs.count();
    expect(tabCount).toBeGreaterThan(0);

    // First tab should be active (preferred source)
    await expect(tabs.first()).toHaveClass(/active/);
  });

  test('source content displays morphological data', async ({ page }) => {
    await page.goto('/species/alba/');

    // Should show source content sections
    await expect(page.getByText(/Geographic Range|Leaves|Fruits|Growth Habit/i).first()).toBeVisible();

    // Should show common names
    await expect(page.getByText(/white oak/i).first()).toBeVisible();
  });

  test('external links section is present', async ({ page }) => {
    await page.goto('/species/alba/');

    // Should have external links section
    await expect(page.getByText('External Links', { exact: false })).toBeVisible();

    // Should have iNaturalist and Wikipedia links
    await expect(page.getByRole('link', { name: /iNaturalist|Wikipedia/i }).first()).toBeVisible();
  });

  test('external links open in new tab', async ({ page }) => {
    await page.goto('/species/alba/');

    // Find an external link
    const externalLink = page.locator('.external-link').first();
    await expect(externalLink).toBeVisible();

    // Should have target="_blank" and rel="noopener noreferrer"
    await expect(externalLink).toHaveAttribute('target', '_blank');
    await expect(externalLink).toHaveAttribute('rel', /noopener/);
  });

  test('conservation status badge is displayed when present', async ({ page }) => {
    await page.goto('/species/alba/');

    // Alba has LC (Least Concern) status
    const conservationBadge = page.locator('.conservation-badge');
    await expect(conservationBadge).toBeVisible();
    await expect(conservationBadge).toHaveText('LC');
  });

  test('related species section shows links when present', async ({ page }) => {
    await page.goto('/species/alba/');

    // Check for closely related species section
    const relatedSection = page.getByText('Closely Related Species', { exact: false });

    if (await relatedSection.isVisible()) {
      // Should have links to related species
      const relatedLinks = page.locator('.related-species-list a, section:has-text("Closely Related") a');
      const count = await relatedLinks.count();
      expect(count).toBeGreaterThan(0);
    }
  });

  test('clicking related species navigates to that species', async ({ page }) => {
    await page.goto('/species/alba/');

    // Look for related species links
    const relatedLink = page.locator('.related-species-list a').first();

    if (await relatedLink.isVisible()) {
      const href = await relatedLink.getAttribute('href');
      await relatedLink.click();

      // Should navigate to that species
      await expect(page).toHaveURL(/\/species\//);
    }
  });

  test('known hybrids section shows links when present', async ({ page }) => {
    await page.goto('/species/alba/');

    // Check for known hybrids section
    const hybridsSection = page.getByText('Known Hybrids', { exact: false });

    if (await hybridsSection.isVisible()) {
      // Should have links to hybrids
      const hybridLinks = page.locator('.hybrids-grid a, section:has-text("Known Hybrids") a');
      const count = await hybridLinks.count();
      expect(count).toBeGreaterThan(0);
    }
  });

  test('synonyms section displays when present', async ({ page }) => {
    await page.goto('/species/alba/');

    // Check for synonyms section
    const synonymsSection = page.getByText('Synonyms', { exact: false });

    if (await synonymsSection.isVisible()) {
      // Should have synonym pills
      const synonymPills = page.locator('.pill-tag');
      const count = await synonymPills.count();
      expect(count).toBeGreaterThan(0);
    }
  });

  test('non-existent species shows 404 message', async ({ page }) => {
    await page.goto('/species/this-species-does-not-exist-xyz/');

    // Should show not found message
    await expect(page.getByText(/not found/i)).toBeVisible();
  });
});
