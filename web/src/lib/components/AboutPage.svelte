<script>
    import { speciesCounts } from "$lib/stores/dataStore.js";
</script>

<div class="about-page">
    <h2 class="page-title">About the Quercus Compendium</h2>

    <section class="content-section">
        <p>
            The Quercus Compendium is a comprehensive database of oak species from around the world, providing
            botanists, naturalists, and oak enthusiasts with detailed information about the amazing genus <em
                >Quercus</em
            >.
        </p>
    </section>

    <section class="content-section">
        <h3 class="section-title">Why This Site?</h3>
        <p>
            Almost everyone knows what an oak is, and many can even point to one in the wild. But getting them to
            species can be a huge challenge that stumps even the most seasoned botanist—just start looking at herbarium
            records to see all of the misidentified material! After years of frustration with the lack of a
            comprehensive oak identification resource, the Quercus Compendium was born.
        </p>
        <p>The goal is to gather and organize information to provide the ultimate guide to oak identification.</p>
    </section>

    <section class="content-section">
        <h3 class="section-title">About the Author</h3>
        <p>
            My name is <a href="https://www.inaturalist.org/people/jeffdc" target="_blank" rel="nopener noreferrer"
                >Jeff Clark</a
            >
            and I love going out and wandering in nature and celebrating how little I know and how much there is to learn.
            I know a little about a lot and a good amount about oak galls and oaks. I am a bit of a fanatic about plant galls—so
            much so that I built
            <a href="https://www.gallformers.org" target="_blank" rel="noopener noreferrer">Gallformers</a>, a website
            dedicated to helping catalog and identify them (<a
                href="https://github.com/jeffdc/gallformers"
                target="_blank"
                rel="noopener noreferrer">source on GitHub</a
            >). If it were not for iNaturalist, the conjunction of people and events to make this possible likely would
            never have occurred.
        </p>
        <p>
            When it comes to plant galls, I learned that I had to be knowledgeable about the host plants as well. I also
            quickly learned that the coolest galls are on oaks, and that oaks are hard to identify to species. So I
            figured: why not try to become an expert at oak identification? I have been working on this for the past
            five years and have gotten moderately good at it. I hope one day to take all that I have learned and to
            write a Field Guide to Oaks.
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
            The taxonomic structure used in this compendium follows
            <a href="https://www.inaturalist.org/taxa/47851-Quercus" target="_blank" rel="noopener noreferrer"
                >iNaturalist</a
            >, which provides the authoritative hierarchy of subgenera, sections, and species.
        </p>
        <p>
            The primary species data—descriptions, identification notes, and range information—comes from my own
            research and field observations. <a
                href="https://oaksoftheworld.fr"
                target="_blank"
                rel="noopener noreferrer">Oaks of the World</a
            >
            serves as an important secondary source, providing additional morphological details and distribution data.
        </p>
        <p>Other sources have been consulted as well; these are credited on each species page where applicable.</p>
    </section>

    <section class="content-section">
        <h3 class="section-title">Data Licensing</h3>
        <ul class="license-list">
            <li>
                <strong>Species Data</strong>:
                <a
                    href="https://github.com/jeffdc/oaks/blob/main/DATA_LICENSE"
                    target="_blank"
                    rel="noopener noreferrer">All Rights Reserved</a
                > unless otherwise stated.
            </li>
        </ul>
        <p>
            The data incorporates information from multiple sources; see the individual species entries for source
            attributions.
        </p>
    </section>

    <section class="content-section">
        <h3 class="section-title">Open Source</h3>
        <p>
            This project is open source. View the code, report issues, or contribute on
            <a href="https://github.com/jeffdc/oaks" target="_blank" rel="noopener noreferrer">GitHub</a>.
        </p>
        <p>
            <strong>Source Code</strong>:
            <a href="https://github.com/jeffdc/oaks/blob/main/LICENSE" target="_blank" rel="noopener noreferrer"
                >MIT License</a
            >
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

    .content-section p + p {
        margin-top: 1rem;
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

    .license-list {
        list-style: none;
        padding: 0;
        margin: 1rem 0;
    }

    .license-list li {
        padding: 0.5rem 0;
        color: var(--color-text-primary);
        font-size: 1rem;
    }

    .license-list strong {
        color: var(--color-forest-700);
    }

    @media (max-width: 480px) {
        .stats-grid {
            grid-template-columns: 1fr;
        }
    }
</style>
