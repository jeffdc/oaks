defmodule OaksWeb.SpeciesListLive do
  @moduledoc """
  LiveView for browsing all oak species.

  Supports text search and taxonomy filtering via URL parameters
  (`?q=`, `?subgenus=`, `?section=`) so results are bookmarkable.
  Uses streams for efficient rendering of 500+ species.
  """

  use OaksWeb, :live_view

  alias Oaks.Species
  alias Oaks.Taxonomy
  alias OaksWeb.Params

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Species list",
       subgenera: taxon_names("subgenus"),
       sections: taxon_names("section"),
       ancestry: ancestry(),
       query: "",
       subgenus: "",
       section: "",
       species_count: 0,
       hybrid_count: 0
     )
     |> stream(:species, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = Params.string(params["q"])
    subgenus = Params.string(params["subgenus"])
    section = Params.string(params["section"])

    filters =
      %{}
      |> maybe_put("search", query)
      |> maybe_put("subgenus", subgenus)
      |> maybe_put("section", section)

    species = Species.list_all_species(filters)
    species_count = length(species)
    hybrid_count = Enum.count(species, & &1.is_hybrid)

    {:noreply,
     socket
     |> assign(
       query: query,
       subgenus: subgenus,
       section: section,
       species_count: species_count,
       hybrid_count: hybrid_count,
       ancestry: ancestry()
     )
     |> stream(:species, species, reset: true)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    query = Params.string(params["q"])
    subgenus = Params.string(params["subgenus"])
    section = Params.string(params["section"])

    {:noreply, push_patch(socket, to: list_path(query, subgenus, section))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page>
      <:head>
        <.header id="species-list-title">
          Species list
          <:meta>{@species_count - @hybrid_count} species</:meta>
          <:meta>{@hybrid_count} {if @hybrid_count == 1, do: "hybrid", else: "hybrids"}</:meta>
          <:meta><strong>{@species_count} total</strong></:meta>
          <:actions :if={@current_scope}>
            <.edit_menu id="species-list-edit-menu">
              <:item navigate={~p"/species/new"} id="new-species-btn">New species</:item>
            </.edit_menu>
          </:actions>
        </.header>
      </:head>

      <form id="filter-form" phx-change="filter" class="species-filters">
        <div class="species-search">
          <.icon name="hero-magnifying-glass" class="species-search-icon" />
          <.input
            type="search"
            id="species-search"
            name="q"
            value={@query}
            placeholder="Search by species name..."
            aria-label="Search by species name"
            phx-debounce="300"
          />
        </div>
        <.input
          type="select"
          id="species-subgenus"
          name="subgenus"
          value={@subgenus}
          options={@subgenera}
          prompt="All Subgenera"
          aria-label="Subgenus"
        />
        <.input
          type="select"
          id="species-section"
          name="section"
          value={@section}
          options={@sections}
          prompt="All Sections"
          aria-label="Section"
        />
      </form>

      <div :if={@species_count == 0} class="species-empty">
        <p class="species-empty-title">No species found</p>
        <p>Try adjusting your search or filters.</p>
      </div>

      <div
        :if={@species_count > 0}
        id="species-list"
        phx-update="stream"
        class="species-rows species-index"
      >
        <.species_row
          :for={{dom_id, species} <- @streams.species}
          id={dom_id}
          species={species}
          ancestry={@ancestry}
        />
      </div>
    </.page>
    """
  end

  # -- Components --

  attr :id, :string, required: true
  attr :species, :any, required: true
  attr :ancestry, :map, required: true

  defp species_row(assigns) do
    assigns =
      assign(assigns,
        subgenus: ancestor_name(assigns.ancestry, assigns.species.taxon_id, "subgenus"),
        section: ancestor_name(assigns.ancestry, assigns.species.taxon_id, "section")
      )

    ~H"""
    <.link
      id={@id}
      navigate={~p"/species/#{@species.scientific_name}"}
      class="species-row"
    >
      <span class="species-row-name">
        <.sci_name
          name={@species.scientific_name}
          hybrid={@species.is_hybrid}
          author={@species.author}
          size="title"
        />
      </span>
      <span class="species-row-meta">
        <span class="hidden sm:block">
          <.sci_name :if={@subgenus} name={@subgenus} rank="subg." size="meta" />
        </span>
        <span class="hidden md:block">
          <.sci_name :if={@section} name={@section} rank="sect." size="meta" />
        </span>
        <span class="species-row-status">
          <.iucn_status
            :if={@species.conservation_status}
            code={@species.conservation_status}
            prefix={false}
          />
        </span>
      </span>
    </.link>
    """
  end

  # -- Helpers --

  defp taxon_names(level) do
    level
    |> Taxonomy.list_taxa_by_level()
    |> Enum.map(& &1.name)
    |> Enum.sort()
  end

  # Each taxon's ancestry (the genus down to itself), from the taxonomy
  # context rather than a walk of its own.
  defp ancestry do
    Taxonomy.list_taxa_with_ancestors()
    |> Map.new(fn %{taxon: taxon, ancestors: ancestors} -> {taxon.id, ancestors ++ [taxon]} end)
  end

  defp ancestor_name(_ancestry, nil, _level), do: nil

  defp ancestor_name(ancestry, id, level) do
    ancestry
    |> Map.get(id, [])
    |> Enum.find_value(fn taxon -> taxon.level == level && taxon.name end)
  end

  defp list_path(query, subgenus, section) do
    params =
      %{}
      |> maybe_put("q", query)
      |> maybe_put("subgenus", subgenus)
      |> maybe_put("section", section)

    case params do
      p when p == %{} -> ~p"/species"
      p -> ~p"/species?#{p}"
    end
  end

  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
