defmodule OaksWeb.AboutLive do
  use OaksWeb, :live_view

  alias Oaks.Species
  alias Oaks.Version

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      send(self(), :load_stats)
    end

    {:ok,
     assign(socket,
       page_title: "About",
       app_version: Version.app_version(),
       api_version: Version.api_version(),
       stats: %{species_count: 0, hybrid_count: 0, total: 0},
       is_loading: true
     )}
  end

  @impl true
  def handle_info(:load_stats, socket) do
    total = Species.count()
    hybrid_count = Species.count_hybrids()

    {:noreply,
     assign(socket,
       stats: %{
         species_count: total - hybrid_count,
         hybrid_count: hybrid_count,
         total: total
       },
       is_loading: false
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-read">
      <.header>About the Oak Compendium</.header>

      <section class="prose-content page-lead">
        <p>
          The Oak Compendium is a comprehensive database of oak species from around the world,
          providing botanists, naturalists, and oak enthusiasts with detailed information about
          the amazing genus <em>Quercus</em>.
        </p>
      </section>

      <section>
        <.section_heading>Why This Site?</.section_heading>
        <div class="prose-content">
          <p>
            Almost everyone knows what an oak is, and many can even point to one in the wild.
            But getting them to species can be a huge challenge that stumps even the most seasoned
            botanist&mdash;just start looking at herbarium records to see all of the misidentified
            material! After years of frustration with the lack of a comprehensive oak identification
            resource, the Oak Compendium was born.
          </p>
          <p>
            The goal is to gather and organize information to provide the ultimate guide to
            oak identification.
          </p>
        </div>
      </section>

      <section>
        <.section_heading>About the Author</.section_heading>
        <div class="prose-content">
          <p>
            My name is
            <a
              href="https://www.inaturalist.org/people/jeffdc"
              target="_blank"
              rel="noopener noreferrer"
            >Jeff Clark</a>
            and I love going out and wandering in nature and celebrating how little I know and how
            much there is to learn. I know a little about a lot and a good amount about oak galls
            and oaks. I am a bit of a fanatic about plant galls&mdash;so much so that I built <a
              href="https://www.gallformers.org"
              target="_blank"
              rel="noopener noreferrer"
            >Gallformers</a>,
            a website dedicated to helping catalog and identify them
            (<a
              href="https://github.com/jeffdc/gallformers"
              target="_blank"
              rel="noopener noreferrer"
            >source on GitHub</a>).
            If it were not for iNaturalist, the conjunction of people and events to make this possible
            likely would never have occurred.
          </p>
          <p>
            When it comes to plant galls, I learned that I had to be knowledgeable about the host
            plants as well. I also quickly learned that the coolest galls are on oaks, and that oaks
            are hard to identify to species. So I figured: why not try to become an expert at oak
            identification? I have been working on this for the past five years and have gotten
            moderately good at it. I hope one day to take all that I have learned and to write a
            Field Guide to Oaks.
          </p>
        </div>
      </section>

      <section>
        <.section_heading>Database Statistics</.section_heading>
        <dl class="page-figures" id="about-stats">
          <div>
            <dt>Species</dt>
            <dd>{if @is_loading, do: "\u2014", else: @stats.species_count}</dd>
          </div>
          <div>
            <dt>Hybrids</dt>
            <dd>{if @is_loading, do: "\u2014", else: @stats.hybrid_count}</dd>
          </div>
          <div>
            <dt>Total Entries</dt>
            <dd>{if @is_loading, do: "\u2014", else: @stats.total}</dd>
          </div>
        </dl>
      </section>

      <section>
        <.section_heading>Data Sources</.section_heading>
        <div class="prose-content">
          <p>
            The taxonomic structure used in this compendium follows <a
              href="https://www.inaturalist.org/taxa/47851-Quercus"
              target="_blank"
              rel="noopener noreferrer"
            >iNaturalist</a>,
            which provides the authoritative hierarchy of subgenera, sections, and species.
          </p>
          <p>
            The primary species data&mdash;descriptions, identification notes, and range
            information&mdash;comes from my own research and field observations.
            <a href="https://oaksoftheworld.fr" target="_blank" rel="noopener noreferrer">Oaks of the World</a>
            serves as an important secondary source, providing additional morphological details
            and distribution data.
          </p>
          <p>
            Conservation status data is sourced from the <a
              href="https://www.iucnredlist.org"
              target="_blank"
              rel="noopener noreferrer"
            >IUCN Red List of Threatened Species</a>,
            retrieved via the IUCN Red List API. Citation: IUCN 2024. IUCN Red List of Threatened
            Species. Version 2024-2 &lt;www.iucnredlist.org&gt;.
          </p>
          <p>
            Other sources have been consulted as well; these are credited on each species page
            where applicable.
          </p>
        </div>
      </section>

      <section>
        <.section_heading>Data Licensing</.section_heading>
        <div class="prose-content">
          <p>
            <strong>Species Data</strong>:
            <a
              href="https://github.com/jeffdc/oaks/blob/main/DATA_LICENSE"
              target="_blank"
              rel="noopener noreferrer"
            >All Rights Reserved</a>
            unless otherwise stated.
          </p>
          <p>
            The data incorporates information from multiple sources; see the individual species
            entries for source attributions.
          </p>
        </div>
      </section>

      <section>
        <.section_heading>Open Source</.section_heading>
        <div class="prose-content">
          <p>
            This project is open source. View the code, report issues, or contribute on <a
              href="https://github.com/jeffdc/oaks"
              target="_blank"
              rel="noopener noreferrer"
            >GitHub</a>.
          </p>
          <p>
            <strong>Source Code</strong>:
            <a
              href="https://github.com/jeffdc/oaks/blob/main/LICENSE"
              target="_blank"
              rel="noopener noreferrer"
            >MIT License</a>
          </p>
        </div>
      </section>

      <section>
        <.section_heading>API</.section_heading>
        <div class="prose-content">
          <p>
            The Oak Compendium provides a public REST API for programmatic access to species data.
            Read operations are open to all; write operations require authentication.
          </p>
        </div>
      </section>

      <section>
        <.section_heading>Privacy &amp; Analytics</.section_heading>
        <div class="prose-content">
          <p>
            We use a custom, self-hosted, privacy-respecting analytics system &mdash;
            no third-party trackers, no cookies for visitors, no personal data collected.
            View the live data on the <a href="/analytics">analytics page</a>
            or read the full <a href="/privacy">privacy policy</a>
            for details on what is and isn't collected.
          </p>
        </div>
      </section>

      <footer class="page-foot">
        <span>App: {@app_version} | API: {@api_version}</span>
        <span aria-hidden="true">&middot;</span>
        <a
          href="https://github.com/jeffdc/oaks/releases"
          target="_blank"
          rel="noreferrer"
          id="release-notes-link"
        >Release Notes</a>
      </footer>
    </div>
    """
  end
end
