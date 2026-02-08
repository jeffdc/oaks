defmodule OaksWeb.AboutLive do
  use OaksWeb, :live_view

  alias Oaks.Species

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      send(self(), :load_stats)
    end

    version = Application.spec(:oaks, :vsn) |> to_string()

    {:ok,
     assign(socket,
       page_title: "About",
       version: version,
       stats: %{species_count: 0, hybrid_count: 0, total: 0},
       is_loading: true
     )}
  end

  @impl true
  def handle_info(:load_stats, socket) do
    species_count = Species.count()
    hybrid_count = Species.count_hybrids()

    {:noreply,
     assign(socket,
       stats: %{
         species_count: species_count,
         hybrid_count: hybrid_count,
         total: species_count + hybrid_count
       },
       is_loading: false
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto">
      <h2
        class="text-3xl font-bold mb-8"
        style="font-family: var(--font-serif); color: var(--color-forest-800, #165132);"
      >
        About the Oak Compendium
      </h2>

      <section class="mb-8">
        <p class="text-lg leading-relaxed" style="color: var(--color-text-primary); line-height: 1.7;">
          The Oak Compendium is a comprehensive database of oak species from around the world,
          providing botanists, naturalists, and oak enthusiasts with detailed information about
          the amazing genus <em>Quercus</em>.
        </p>
      </section>

      <section class="mb-8">
        <h3 class="section-title">Why This Site?</h3>
        <p
          class="leading-relaxed mb-3"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          Almost everyone knows what an oak is, and many can even point to one in the wild.
          But getting them to species can be a huge challenge that stumps even the most seasoned
          botanist&mdash;just start looking at herbarium records to see all of the misidentified
          material! After years of frustration with the lack of a comprehensive oak identification
          resource, the Oak Compendium was born.
        </p>
        <p
          class="leading-relaxed"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          The goal is to gather and organize information to provide the ultimate guide to
          oak identification.
        </p>
      </section>

      <section class="mb-8">
        <h3 class="section-title">About the Author</h3>
        <p
          class="leading-relaxed mb-3"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          My name is
          <a
            href="https://www.inaturalist.org/people/jeffdc"
            target="_blank"
            rel="noopener noreferrer"
          >
            Jeff Clark
          </a>
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
        <p
          class="leading-relaxed"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          When it comes to plant galls, I learned that I had to be knowledgeable about the host
          plants as well. I also quickly learned that the coolest galls are on oaks, and that oaks
          are hard to identify to species. So I figured: why not try to become an expert at oak
          identification? I have been working on this for the past five years and have gotten
          moderately good at it. I hope one day to take all that I have learned and to write a
          Field Guide to Oaks.
        </p>
      </section>

      <section class="mb-8">
        <h3 class="section-title">Database Statistics</h3>
        <div class="grid grid-cols-3 gap-4 max-[480px]:grid-cols-1">
          <div
            class="flex flex-col items-center p-5 rounded-xl border"
            style="background-color: var(--color-surface); border-color: var(--color-border); box-shadow: var(--shadow-sm);"
          >
            <span class="text-3xl font-bold leading-none" style="color: var(--color-forest-700);">
              {if @is_loading, do: "\u2014", else: @stats.species_count}
            </span>
            <span class="text-sm mt-1.5" style="color: var(--color-text-secondary);">Species</span>
          </div>
          <div
            class="flex flex-col items-center p-5 rounded-xl border"
            style="background-color: var(--color-surface); border-color: var(--color-border); box-shadow: var(--shadow-sm);"
          >
            <span class="text-3xl font-bold leading-none" style="color: var(--color-forest-700);">
              {if @is_loading, do: "\u2014", else: @stats.hybrid_count}
            </span>
            <span class="text-sm mt-1.5" style="color: var(--color-text-secondary);">Hybrids</span>
          </div>
          <div
            class="flex flex-col items-center p-5 rounded-xl border"
            style="background-color: var(--color-surface); border-color: var(--color-border); box-shadow: var(--shadow-sm);"
          >
            <span class="text-3xl font-bold leading-none" style="color: var(--color-forest-700);">
              {if @is_loading, do: "\u2014", else: @stats.total}
            </span>
            <span class="text-sm mt-1.5" style="color: var(--color-text-secondary);">
              Total Entries
            </span>
          </div>
        </div>
      </section>

      <section class="mb-8">
        <h3 class="section-title">Data Sources</h3>
        <p
          class="leading-relaxed mb-3"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          The taxonomic structure used in this compendium follows <a
            href="https://www.inaturalist.org/taxa/47851-Quercus"
            target="_blank"
            rel="noopener noreferrer"
          >iNaturalist</a>,
          which provides the authoritative hierarchy of subgenera, sections, and species.
        </p>
        <p
          class="leading-relaxed mb-3"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          The primary species data&mdash;descriptions, identification notes, and range
          information&mdash;comes from my own research and field observations.
          <a href="https://oaksoftheworld.fr" target="_blank" rel="noopener noreferrer">
            Oaks of the World
          </a>
          serves as an important secondary source, providing additional morphological details
          and distribution data.
        </p>
        <p
          class="leading-relaxed mb-3"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          Conservation status data is sourced from the <a
            href="https://www.iucnredlist.org"
            target="_blank"
            rel="noopener noreferrer"
          >IUCN Red List of Threatened Species</a>,
          retrieved via the IUCN Red List API. Citation: IUCN 2024. IUCN Red List of Threatened
          Species. Version 2024-2 &lt;www.iucnredlist.org&gt;.
        </p>
        <p
          class="leading-relaxed"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          Other sources have been consulted as well; these are credited on each species page
          where applicable.
        </p>
      </section>

      <section class="mb-8">
        <h3 class="section-title">Data Licensing</h3>
        <p
          class="leading-relaxed mb-3"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          <strong class="text-forest-700">Species Data</strong>:
          <a
            href="https://github.com/jeffdc/oaks/blob/main/DATA_LICENSE"
            target="_blank"
            rel="noopener noreferrer"
          >
            All Rights Reserved
          </a>
          unless otherwise stated.
        </p>
        <p
          class="leading-relaxed"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          The data incorporates information from multiple sources; see the individual species
          entries for source attributions.
        </p>
      </section>

      <section class="mb-8">
        <h3 class="section-title">Open Source</h3>
        <p
          class="leading-relaxed mb-3"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          This project is open source. View the code, report issues, or contribute on <a
            href="https://github.com/jeffdc/oaks"
            target="_blank"
            rel="noopener noreferrer"
          >GitHub</a>.
        </p>
        <p
          class="leading-relaxed"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          <strong class="text-forest-700">Source Code</strong>:
          <a
            href="https://github.com/jeffdc/oaks/blob/main/LICENSE"
            target="_blank"
            rel="noopener noreferrer"
          >
            MIT License
          </a>
        </p>
      </section>

      <section class="mb-8">
        <h3 class="section-title">API</h3>
        <p
          class="leading-relaxed"
          style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
        >
          The Oak Compendium provides a public REST API for programmatic access to species data.
          Read operations are open to all; write operations require authentication.
        </p>
      </section>

      <footer
        class="mt-12 pt-6 text-center"
        style="border-top: 1px solid var(--color-border);"
      >
        <span
          class="text-xs"
          style="color: var(--color-text-tertiary); font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;"
        >
          Version {@version}
        </span>
      </footer>
    </div>
    """
  end
end
