defmodule OaksWeb.HomeLive do
  @moduledoc """
  The home page, set as a book's title page (item 1900, the Bookplate
  sketch Jeff picked): the masthead's ink continues into the title page
  with the big search hanging across its ochre edge and the counts below
  it, then the contents of the site, an oak at random and the sources.

  Built only from library components (`page/1` with the title page in its
  bleed, `title_page/1`, `chapter_heading/1`, `contents/1`, `sci_name/1`,
  the inline `taxonomy_band/1`, `button/1`, `section_heading/1`,
  `status_tag/1`) and design tokens.
  """
  use OaksWeb, :live_view

  alias Oaks.Sources
  alias Oaks.Species
  alias Oaks.Taxonomy

  # iNaturalist is the taxonomic backbone, not a source the home page lists.
  @inaturalist_id 1
  # Jeff's own observations: the primary source, listed first.
  @primary_source_id 3

  @impl true
  def mount(_params, _session, socket) do
    # The counts and sources are a handful of small queries, so both renders
    # have them and the title page never fills in late. The species list for
    # the random oak loads once connected, so the pick doesn't change between
    # the two renders.
    if connected?(socket), do: send(self(), :load_species)

    sources = list_sources()

    {:ok,
     assign(socket,
       page_title: "Oak Compendium - A Database of the World's Oak Species",
       page_description:
         "A comprehensive guide to oak species (genus Quercus) featuring detailed information on taxonomy, morphology, distribution, and hybrid relationships.",
       counts: count_all(sources),
       sources: sources,
       all_species: [],
       featured: nil,
       featured_hybrids: []
     )}
  end

  @impl true
  def handle_info(:load_species, socket) do
    socket = assign(socket, all_species: Species.list_all_species())
    {:noreply, feature_random(socket)}
  end

  @impl true
  def handle_event("shuffle", _params, socket) do
    {:noreply, feature_random(socket)}
  end

  defp count_all(sources) do
    hybrids = Species.count_hybrids()

    # Species.count/0 includes hybrids; the counts list them separately.
    %{
      species: Species.count() - hybrids,
      hybrids: hybrids,
      sections: length(Taxonomy.list_taxa_by_level("section")),
      sources: length(sources)
    }
  end

  defp list_sources do
    Sources.list_sources()
    |> Enum.reject(&(&1.id == @inaturalist_id))
    |> Enum.sort_by(&{&1.id != @primary_source_id, &1.name})
  end

  defp primary?(source), do: source.id == @primary_source_id

  # A non-hybrid species at random, with its hybrids and each one's other
  # parent. Show another never repeats the oak on screen when it can help it.
  defp feature_random(socket) do
    current = socket.assigns.featured

    candidates =
      Enum.filter(socket.assigns.all_species, &(!&1.is_hybrid and &1 != current))

    case candidates do
      [] ->
        socket

      _ ->
        featured = Enum.random(candidates)

        hybrids =
          featured.hybrids
          |> Species.parse_name_list()
          |> Species.get_hybrids_with_parents()
          |> Enum.map(&Map.put(&1, :other, other_parent(&1, featured.scientific_name)))

        assign(socket, featured: featured, featured_hybrids: hybrids)
    end
  end

  defp other_parent(%{parent1: name, parent2: other}, name), do: other
  defp other_parent(%{parent1: other, parent2: name}, name), do: other
  defp other_parent(_hybrid, _name), do: nil

  # Where the species sits, outermost first: each rank with its path under
  # /taxonomy.
  defp ranks(species) do
    [
      {"subg.", species.subgenus},
      {"sect.", species.section},
      {"subsect.", species.subsection},
      {"complex", species.complex}
    ]
    |> Enum.reject(fn {_rank, name} -> name in [nil, ""] end)
    |> Enum.map_reduce([], fn {rank, name}, path ->
      path = path ++ [name]
      {%{rank: rank, name: name, path: taxonomy_path(path)}, path}
    end)
    |> elem(0)
  end

  defp taxonomy_path(segments) do
    "/taxonomy/" <>
      Enum.map_join(segments, "/", fn s -> URI.encode(s, &URI.char_unreserved?/1) end)
  end

  # The joining words of a run of hybrids: "a, b and c".
  defp list_joint(index, count) when index == count - 2, do: " and"
  defp list_joint(index, count) when index < count - 2, do: ","
  defp list_joint(_index, _count), do: ""

  @impl true
  def render(assigns) do
    ~H"""
    <.page>
      <:bleed>
        <.title_page search={~p"/search"}>
          Oak <em>Compendium</em>
          <:subtitle>Oaks, their varieties and their hybrids, and how to tell them apart</:subtitle>
          <:count>{@counts.species} species</:count>
          <:count>{@counts.hybrids} hybrids</:count>
          <:count>{@counts.sections} sections</:count>
          <:count>{@counts.sources} sources</:count>
        </.title_page>
      </:bleed>

      <.chapter_heading id="contents-heading" mark class="mt-s6">Contents</.chapter_heading>
      <.contents labelledby="contents-heading">
        <:entry title="Species" navigate={~p"/species"} count={@counts.species}>
          Every oak, A to Z, each on its own page: its names, its place in the taxonomy, its hybrids and what each source says.
        </:entry>
        <:entry title="Hybrids" navigate={~p"/species"} count={@counts.hybrids}>
          Named hybrids and formula names such as
          <.sci_name name="agrifolia × parvula" genus={nil} weight="regular" />, each between its two parents.
        </:entry>
        <:entry
          title="Taxonomy"
          navigate={~p"/taxonomy"}
          count={@counts.sections}
          count_label="sections"
        >
          Two subgenera, <.sci_name name="Quercus" weight="regular" /> and
          <.sci_name name="Cerris" genus={nil} weight="regular" />, their sections and subsections, every rank linked.
        </:entry>
        <:entry title="Identify" status="In preparation">
          A trait filter that narrows the oaks by what you can see, and a helper for hybrids.
        </:entry>
        <:entry title="Sources" navigate={~p"/sources"} count={@counts.sources}>
          Jeff Clark’s notes first; Oaks of the World, the Sibley guide and the literature behind them.
        </:entry>
        <:entry title="About" navigate={~p"/about"}>
          What the Compendium is, how its facts are sourced, and who keeps it.
        </:entry>
      </.contents>

      <section
        :if={@featured}
        id="oak-at-random"
        aria-labelledby="random-heading"
        class="mt-[88px] text-center max-md:mt-s8"
      >
        <.chapter_heading id="random-heading">An oak at random</.chapter_heading>
        <p class="mt-s6 font-serif text-[clamp(44px,5.6vw,80px)] leading-none tracking-[-0.02em]">
          <.sci_name name={@featured.scientific_name} />
        </p>
        <p :if={@featured.author} class="mt-s3 font-serif text-2xl text-ink-3 max-md:text-xl">
          {@featured.author}
        </p>
        <div :if={ranks(@featured) != []} class="mt-s5">
          <.taxonomy_band id="random-band" label="Where it sits" inline>
            <:rank navigate={~p"/taxonomy"}><.sci_name name="Quercus" /></:rank>
            <:rank
              :for={rank <- ranks(@featured)}
              navigate={rank.path}
              rank={rank.rank}
              rank_after={rank.rank == "complex"}
            >
              <.sci_name name={rank.name} genus={nil} />
            </:rank>
          </.taxonomy_band>
        </div>
        <p
          :if={@featured_hybrids != []}
          class="mt-s5 inline-block max-w-[60ch] font-frame text-[15px] leading-[1.6] text-ink-2 text-balance"
        >
          Hybrids
          <%= for {hybrid, i} <- Enum.with_index(@featured_hybrids) do %>
            {" "}<span class="whitespace-nowrap"><.link
              navigate={~p"/species/#{hybrid.name}"}
              class="font-serif text-lg text-ink no-underline hover:underline"
            ><.sci_name name={hybrid.name} hybrid abbreviate /></.link><span :if={hybrid.other}>
                with
                <.sci_name
                  name={hybrid.other}
                  genus={nil}
                  weight="regular"
                  class="text-[17px] text-ink"
                /></span>{list_joint(
              i,
              length(@featured_hybrids)
            )}</span>
          <% end %>
        </p>
        <div class="mt-s5 flex flex-wrap justify-center gap-s3">
          <.button variant="primary" navigate={~p"/species/#{@featured.scientific_name}"}>
            Open the page
          </.button>
          <.button phx-click="shuffle">Show another</.button>
        </div>
      </section>

      <section
        :if={@sources != []}
        id="home-sources"
        aria-labelledby="sources-heading"
        class="mt-[88px] text-center max-md:mt-s8"
      >
        <.section_heading id="sources-heading" align="center">Sources</.section_heading>
        <ul class="mt-s4 flex flex-wrap justify-center gap-x-s5 gap-y-s2 font-serif text-lg text-ink-2">
          <li :for={source <- @sources}>
            <.link
              navigate={~p"/sources/#{source.id}"}
              class="text-ink decoration-ink/35 hover:decoration-ink"
            >
              {source.name}
            </.link>
            <.status_tag :if={primary?(source)} class="ml-s1 align-[3px]">
              Primary
            </.status_tag>
          </li>
        </ul>
      </section>
    </.page>
    """
  end
end
