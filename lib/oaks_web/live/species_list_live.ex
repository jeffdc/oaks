defmodule OaksWeb.SpeciesListLive do
  @moduledoc """
  LiveView for browsing all oak species.

  Supports text search and taxonomy filtering via URL parameters
  (`?q=`, `?subgenus=`, `?section=`) so results are bookmarkable.
  Uses streams for efficient rendering of 500+ species.
  """

  use OaksWeb, :live_view

  alias Oaks.Species
  alias OaksWeb.Params

  @impl true
  def mount(_params, _session, socket) do
    subgenera = Species.distinct_subgenera()
    sections = Species.distinct_sections()

    {:ok,
     socket
     |> assign(
       page_title: "Species List",
       subgenera: subgenera,
       sections: sections,
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
       hybrid_count: hybrid_count
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
          Species List
          <:meta>{@species_count - @hybrid_count} species</:meta>
          <:meta>{@hybrid_count} {if @hybrid_count == 1, do: "hybrid", else: "hybrids"}</:meta>
          <:meta><strong>{@species_count} total</strong></:meta>
          <:actions :if={@current_scope}>
            <.button navigate={~p"/species/new"} id="new-species-btn">New Species</.button>
          </:actions>
        </.header>
      </:head>

      <form id="filter-form" phx-change="filter" class="species-filters">
        <div class="species-search">
          <.icon name="hero-magnifying-glass" class="species-search-icon" />
          <input
            type="search"
            id="species-search"
            name="q"
            value={@query}
            placeholder="Search by species name..."
            aria-label="Search by species name"
            class="input input-bordered"
            phx-debounce="300"
          />
        </div>
        <select name="subgenus" class="select select-bordered" aria-label="Subgenus">
          <option value="">All Subgenera</option>
          <option :for={sg <- @subgenera} value={sg} selected={sg == @subgenus}>
            {sg}
          </option>
        </select>
        <select name="section" class="select select-bordered" aria-label="Section">
          <option value="">All Sections</option>
          <option :for={sec <- @sections} value={sec} selected={sec == @section}>
            {sec}
          </option>
        </select>
      </form>

      <div :if={@species_count == 0} class="species-empty">
        <p class="species-empty-title">No species found</p>
        <p>Try adjusting your search or filters.</p>
      </div>

      <div
        :if={@species_count > 0}
        id="species-list"
        phx-update="stream"
        class="species-rows"
      >
        <.species_row :for={{dom_id, species} <- @streams.species} id={dom_id} species={species} />
      </div>
    </.page>
    """
  end

  # -- Components --

  attr :id, :string, required: true
  attr :species, :any, required: true

  defp species_row(assigns) do
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
        <span :if={@species.subgenus} class="hidden sm:inline">
          <.sci_name name={@species.subgenus} rank="subg." size="meta" />
        </span>
        <span :if={@species.section} class="hidden md:inline">
          <.sci_name name={@species.section} rank="sect." size="meta" />
        </span>
        <.iucn_status
          :if={@species.conservation_status}
          code={@species.conservation_status}
          prefix={false}
        />
      </span>
    </.link>
    """
  end

  # -- Helpers --

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
