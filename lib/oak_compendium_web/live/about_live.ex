defmodule OakCompendiumWeb.AboutLive do
  use OakCompendiumWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "About")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto prose-content">
      <h1 class="text-3xl font-bold mb-6">About the Oak Compendium</h1>

      <section class="mb-8">
        <p class="text-lg leading-relaxed text-base-content/80">
          The Oak Compendium is a comprehensive database of oak species from around the world,
          providing botanists, naturalists, and oak enthusiasts with detailed information about
          the amazing genus <em>Quercus</em>.
        </p>
      </section>

      <section class="mb-8">
        <h2 class="text-xl font-semibold mb-3">Why This Site?</h2>
        <p class="leading-relaxed text-base-content/80 mb-3">
          Almost everyone knows what an oak is, and many can even point to one in the wild.
          But getting them to species can be a huge challenge that stumps even the most seasoned
          botanist&mdash;just start looking at herbarium records to see all of the misidentified
          material! After years of frustration with the lack of a comprehensive oak identification
          resource, the Oak Compendium was born.
        </p>
        <p class="leading-relaxed text-base-content/80">
          The goal is to gather and organize information to provide the ultimate guide to
          oak identification.
        </p>
      </section>

      <section class="mb-8">
        <h2 class="text-xl font-semibold mb-3">About the Author</h2>
        <p class="leading-relaxed text-base-content/80 mb-3">
          My name is
          <a
            href="https://www.inaturalist.org/people/jeffdc"
            target="_blank"
            rel="noopener noreferrer"
            class="link link-primary"
          >
            Jeff Clark
          </a>
          and I love going out and wandering in nature and celebrating how little I know and how
          much there is to learn. I know a little about a lot and a good amount about oak galls
          and oaks. I am a bit of a fanatic about plant galls&mdash;so much so that I built <a
            href="https://www.gallformers.org"
            target="_blank"
            rel="noopener noreferrer"
            class="link link-primary"
          >Gallformers</a>,
          a website dedicated to helping catalog and identify them
          (<a
            href="https://github.com/jeffdc/gallformers"
            target="_blank"
            rel="noopener noreferrer"
            class="link link-primary"
          >source on GitHub</a>).
          If it were not for iNaturalist, the conjunction of people and events to make this possible
          likely would never have occurred.
        </p>
        <p class="leading-relaxed text-base-content/80">
          When it comes to plant galls, I learned that I had to be knowledgeable about the host
          plants as well. I also quickly learned that the coolest galls are on oaks, and that oaks
          are hard to identify to species. So I figured: why not try to become an expert at oak
          identification? I have been working on this for the past five years and have gotten
          moderately good at it. I hope one day to take all that I have learned and to write a
          Field Guide to Oaks.
        </p>
      </section>

      <section class="mb-8">
        <h2 class="text-xl font-semibold mb-3">Data Sources</h2>
        <p class="leading-relaxed text-base-content/80 mb-3">
          The taxonomic structure used in this compendium follows <a
            href="https://www.inaturalist.org/taxa/47851-Quercus"
            target="_blank"
            rel="noopener noreferrer"
            class="link link-primary"
          >iNaturalist</a>,
          which provides the authoritative hierarchy of subgenera, sections, and species.
        </p>
        <p class="leading-relaxed text-base-content/80 mb-3">
          The primary species data&mdash;descriptions, identification notes, and range
          information&mdash;comes from my own research and field observations.
          <a
            href="https://oaksoftheworld.fr"
            target="_blank"
            rel="noopener noreferrer"
            class="link link-primary"
          >
            Oaks of the World
          </a>
          serves as an important secondary source, providing additional morphological details
          and distribution data.
        </p>
        <p class="leading-relaxed text-base-content/80 mb-3">
          Conservation status data is sourced from the <a
            href="https://www.iucnredlist.org"
            target="_blank"
            rel="noopener noreferrer"
            class="link link-primary"
          >IUCN Red List of Threatened Species</a>,
          retrieved via the IUCN Red List API. Citation: IUCN 2024. IUCN Red List of Threatened
          Species. Version 2024-2.
        </p>
        <p class="leading-relaxed text-base-content/80">
          Other sources have been consulted as well; these are credited on each species page
          where applicable.
        </p>
      </section>

      <section class="mb-8">
        <h2 class="text-xl font-semibold mb-3">Data Licensing</h2>
        <p class="leading-relaxed text-base-content/80 mb-3">
          <strong>Species Data</strong>:
          <a
            href="https://github.com/jeffdc/oaks/blob/main/DATA_LICENSE"
            target="_blank"
            rel="noopener noreferrer"
            class="link link-primary"
          >
            All Rights Reserved
          </a>
          unless otherwise stated.
        </p>
        <p class="leading-relaxed text-base-content/80">
          The data incorporates information from multiple sources; see the individual species
          entries for source attributions.
        </p>
      </section>

      <section class="mb-8">
        <h2 class="text-xl font-semibold mb-3">Open Source</h2>
        <p class="leading-relaxed text-base-content/80 mb-3">
          This project is open source. View the code, report issues, or contribute on <a
            href="https://github.com/jeffdc/oaks"
            target="_blank"
            rel="noopener noreferrer"
            class="link link-primary"
          >GitHub</a>.
        </p>
        <p class="leading-relaxed text-base-content/80">
          <strong>Source Code</strong>:
          <a
            href="https://github.com/jeffdc/oaks/blob/main/LICENSE"
            target="_blank"
            rel="noopener noreferrer"
            class="link link-primary"
          >
            MIT License
          </a>
        </p>
      </section>

      <section class="mb-8">
        <h2 class="text-xl font-semibold mb-3">API</h2>
        <p class="leading-relaxed text-base-content/80">
          The Oak Compendium provides a public REST API for programmatic access to species data.
          Read operations are open to all; write operations require authentication.
        </p>
      </section>
    </div>
    """
  end
end
