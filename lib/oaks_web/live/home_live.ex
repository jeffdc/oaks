defmodule OaksWeb.HomeLive do
  @moduledoc """
  The home page, set as a book's title page (item 1900, the Bookplate
  sketch Jeff picked): the masthead's ink continues into the title page
  with the big search hanging across its ochre edge and the counts below
  it, then the contents of the site, an oak at random and the sources.

  Built only from library components: `page/1` with the title page in its
  bleed, `title_page/1`, `chapter_heading/1`, `contents/1`, `specimen/1`
  (with `sci_name/1`, the inline `taxonomy_band/1` and `button/1`) and
  `colophon/1` (with `work_title/1` and `status_tag/1`).
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
    # Everything loads in both renders, so the static page is the whole page
    # (for readers without JavaScript too) and nothing fills in late. The
    # static render picks the oak and hands it to the live mount as a
    # connect param (data-connect-key on the specimen), so both show the
    # same one.
    sources = list_sources()
    oaks = Enum.reject(Species.list_all_species(), & &1.is_hybrid)
    picked = connected?(socket) && get_connect_params(socket)["featured"]

    {:ok,
     assign(socket,
       page_title: "Oak Compendium - A Database of the World's Oak Species",
       page_description:
         "A comprehensive guide to oak species (genus Quercus) featuring detailed information on taxonomy, morphology, distribution, and hybrid relationships.",
       counts: count_all(sources),
       sources: sources,
       oaks: oaks
     )
     |> feature(first_oak(oaks, picked))}
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

  # The oak the static render picked, or a random one.
  defp first_oak([], _picked), do: nil

  defp first_oak(oaks, picked) when is_binary(picked) do
    Enum.find(oaks, &(&1.scientific_name == picked)) || Enum.random(oaks)
  end

  defp first_oak(oaks, _picked), do: Enum.random(oaks)

  # Show another: a different non-hybrid oak when there is one.
  defp feature_random(socket) do
    case Enum.reject(socket.assigns.oaks, &(&1 == socket.assigns.featured)) do
      [] -> socket
      others -> feature(socket, Enum.random(others))
    end
  end

  # The featured oak with its hybrids and each named hybrid's other parent.
  defp feature(socket, nil), do: assign(socket, featured: nil, featured_hybrids: [])

  defp feature(socket, featured) do
    hybrids =
      featured.hybrids
      |> Species.parse_name_list()
      |> Species.get_hybrids_with_parents()
      |> Enum.map(&Map.put(&1, :other, other_parent(&1, featured.scientific_name)))

    assign(socket, featured: featured, featured_hybrids: hybrids)
  end

  # A formula name ("agrifolia × parvula") already names both parents.
  defp other_parent(%{name: hybrid} = parents, name) do
    if OaksWeb.SpeciesName.hybrid_sign?(hybrid, true), do: other_of(parents, name)
  end

  defp other_of(%{parent1: name, parent2: other}, name), do: other
  defp other_of(%{parent1: other, parent2: name}, name), do: other
  defp other_of(_hybrid, _name), do: nil

  # Where the species sits, outermost first: each rank with its path under
  # /taxonomy.
  defp ranks(species) do
    [
      {"subg.", "subgenus", species.subgenus},
      {"sect.", "section", species.section},
      {"subsect.", "subsection", species.subsection},
      {"complex", "complex", species.complex}
    ]
    |> Enum.reject(fn {_rank, _level, name} -> name in [nil, ""] end)
    |> Enum.map_reduce([], fn {rank, level, name}, path ->
      path = path ++ [name]
      {%{rank: rank, level: level, name: name, path: taxonomy_path(path)}, path}
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
    <.page width="frame">
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

      <.specimen
        :if={@featured}
        id="oak-at-random"
        heading="An oak at random"
        data-connect-key="featured"
        data-connect-value={@featured.scientific_name}
      >
        <:name><.sci_name name={@featured.scientific_name} /></:name>
        <:author :if={@featured.author}>{@featured.author}</:author>
        <:band :if={ranks(@featured) != []}>
          <.taxonomy_band id="random-band" label="Where it sits" inline>
            <:rank navigate={~p"/taxonomy"}><.sci_name name="Quercus" level="genus" /></:rank>
            <:rank
              :for={rank <- ranks(@featured)}
              navigate={rank.path}
              rank={rank.rank}
              rank_after={rank.rank == "complex"}
            >
              <.sci_name name={rank.name} level={rank.level} />
            </:rank>
          </.taxonomy_band>
        </:band>
        <:about :if={@featured_hybrids != []}>
          Hybrids
          <%= for {hybrid, i} <- Enum.with_index(@featured_hybrids) do %>
            {" "}<span class="whitespace-nowrap"><.link navigate={~p"/species/#{hybrid.name}"}><.sci_name
              name={hybrid.name}
              hybrid
              abbreviate
            /></.link><span :if={hybrid.other}>
                with <.sci_name name={hybrid.other} genus={nil} weight="regular" /></span>{list_joint(
              i,
              length(@featured_hybrids)
            )}</span>
          <% end %>
        </:about>
        <:actions>
          <.button variant="primary" navigate={~p"/species/#{@featured.scientific_name}"}>
            Open the page
          </.button>
          <.button phx-click="shuffle">Show another</.button>
        </:actions>
      </.specimen>

      <.colophon :if={@sources != []} id="home-sources" label="Sources">
        <:item :for={source <- @sources}>
          <.link navigate={~p"/sources/#{source.id}"}><.work_title title={source.name} /></.link><.status_tag :if={
            primary?(source)
          }>
            Primary
          </.status_tag>
        </:item>
      </.colophon>
    </.page>
    """
  end
end
