<script>
  import { speciesCounts } from './dataStore.js';
</script>

<div class="about-page">
  <h2 class="page-title">About the Quercus Compendium</h2>

  <section class="content-section">
    <p>
      The Quercus Compendium is a comprehensive database of oak species from around the world.
      Our goal is to provide botanists, naturalists, and oak enthusiasts with detailed information
      about the diverse genus <em>Quercus</em>.
    </p>
  </section>

  <section class="content-section">
    <h3 class="section-title">Database Statistics</h3>
    <div class="stats-grid">
      <div class="stat-card">
        <span class="stat-number">{$speciesCounts.speciesCount}</span>
        <span class="stat-label">Species</span>
      </div>
      <div class="stat-card">
        <span class="stat-number">{$speciesCounts.hybridCount}</span>
        <span class="stat-label">Hybrids</span>
      </div>
      <div class="stat-card">
        <span class="stat-number">{$speciesCounts.total}</span>
        <span class="stat-label">Total Entries</span>
      </div>
    </div>
  </section>

  <section class="content-section">
    <h3 class="section-title">Data Sources</h3>
    <p>
      Species data is compiled from multiple authoritative sources including:
    </p>
    <ul class="source-list">
      <li>
        <a href="https://www.inaturalist.org/taxa/47851-Quercus" target="_blank" rel="noopener noreferrer">
          iNaturalist
        </a>
        <span class="source-desc">— Taxonomy and species classification</span>
      </li>
      <li>
        <a href="https://oaksoftheworld.fr" target="_blank" rel="noopener noreferrer">
          Oaks of the World
        </a>
        <span class="source-desc">— Morphological descriptions and distribution data</span>
      </li>
    </ul>
  </section>

  <section class="content-section">
    <h3 class="section-title">Features</h3>
    <ul class="feature-list">
      <li>Browse species alphabetically or by taxonomic hierarchy</li>
      <li>Search by species name, common name, or geographic range</li>
      <li>View detailed morphological descriptions</li>
      <li>Explore hybrid relationships between species</li>
      <li>Works offline as a Progressive Web App</li>
    </ul>
  </section>

  <section class="content-section">
    <h3 class="section-title">Open Source</h3>
    <p>
      This project is open source. View the code and contribute on
      <a href="https://github.com/jeffgravitywell/oaks" target="_blank" rel="noopener noreferrer">GitHub</a>.
    </p>
  </section>
</div>

<style>
  .about-page {
    max-width: 42rem;
    margin: 0 auto;
  }

  .page-title {
    font-family: var(--font-serif);
    font-size: 1.875rem;
    font-weight: 700;
    color: var(--color-forest-800);
    margin-bottom: 2rem;
  }

  .content-section {
    margin-bottom: 2rem;
  }

  .content-section p {
    font-size: 1.0625rem;
    line-height: 1.7;
    color: var(--color-text-primary);
  }

  .section-title {
    font-family: var(--font-serif);
    font-size: 1.25rem;
    font-weight: 600;
    color: var(--color-text-primary);
    margin-bottom: 0.75rem;
  }

  .stats-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1rem;
  }

  .stat-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 1.25rem;
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.75rem;
    box-shadow: var(--shadow-sm);
  }

  .stat-number {
    font-size: 2rem;
    font-weight: 700;
    color: var(--color-forest-700);
    line-height: 1;
  }

  .stat-label {
    font-size: 0.875rem;
    color: var(--color-text-secondary);
    margin-top: 0.375rem;
  }

  .source-list {
    list-style: none;
    padding: 0;
    margin: 1rem 0 0 0;
  }

  .source-list li {
    padding: 0.75rem 0;
    border-bottom: 1px solid var(--color-border);
  }

  .source-list li:last-child {
    border-bottom: none;
  }

  .source-list a {
    font-weight: 600;
    color: var(--color-forest-700);
    text-decoration: none;
  }

  .source-list a:hover {
    text-decoration: underline;
  }

  .source-desc {
    color: var(--color-text-secondary);
    font-size: 0.9375rem;
  }

  .feature-list {
    margin: 1rem 0 0 1.5rem;
    padding: 0;
  }

  .feature-list li {
    padding: 0.375rem 0;
    color: var(--color-text-primary);
    font-size: 1rem;
  }

  @media (max-width: 480px) {
    .stats-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
