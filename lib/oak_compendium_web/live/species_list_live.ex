defmodule OakCompendiumWeb.SpeciesListLive do
  @moduledoc """
  LiveView for browsing all oak species.

  Supports text search and taxonomy filtering via URL parameters
  (`?q=`, `?subgenus=`, `?section=`) so results are bookmarkable.
  Uses streams for efficient rendering of 500+ species.
  """

  use OakCompendiumWeb, :live_view

  alias OakCompendium.Species

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
    query = params["q"] || ""
    subgenus = params["subgenus"] || ""
    section = params["section"] || ""

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
    query = params["q"] || ""
    subgenus = params["subgenus"] || ""
    section = params["section"] || ""

    {:noreply, push_patch(socket, to: list_path(query, subgenus, section))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto">
      <h1
        class="text-2xl font-bold mb-2"
        style="font-family: var(--font-serif); color: var(--color-forest-800);"
      >
        Species List
      </h1>

      <.counts_bar
        species_count={@species_count}
        hybrid_count={@hybrid_count}
      />

      <form id="filter-form" phx-change="filter" class="mb-6">
        <div class="flex flex-col sm:flex-row gap-3">
          <div class="relative flex-1">
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <.icon name="hero-magnifying-glass" class="size-5 text-base-content/40" />
            </div>
            <input
              type="search"
              id="species-search"
              name="q"
              value={@query}
              placeholder="Search by species name..."
              class="w-full input input-bordered pl-10"
              phx-debounce="300"
            />
          </div>
          <select name="subgenus" class="select select-bordered">
            <option value="">All Subgenera</option>
            <option :for={sg <- @subgenera} value={sg} selected={sg == @subgenus}>
              {sg}
            </option>
          </select>
          <select name="section" class="select select-bordered">
            <option value="">All Sections</option>
            <option :for={sec <- @sections} value={sec} selected={sec == @section}>
              {sec}
            </option>
          </select>
        </div>
      </form>

      <div
        :if={@species_count == 0}
        class="text-center py-12"
        style="color: var(--color-text-tertiary);"
      >
        <.icon name="hero-magnifying-glass" class="size-12 mx-auto mb-4 opacity-50" />
        <p class="text-lg mb-1">No species found</p>
        <p class="text-sm">Try adjusting your search or filters.</p>
      </div>

      <div
        :if={@species_count > 0}
        id="species-list"
        phx-update="stream"
        class="space-y-0.5"
      >
        <.species_row :for={{dom_id, species} <- @streams.species} id={dom_id} species={species} />
      </div>
    </div>
    """
  end

  # -- Components --

  attr :species_count, :integer, required: true
  attr :hybrid_count, :integer, required: true

  defp counts_bar(assigns) do
    non_hybrid = assigns.species_count - assigns.hybrid_count
    assigns = assign(assigns, :non_hybrid, non_hybrid)

    ~H"""
    <div class="flex flex-wrap gap-3 mb-4 text-sm" style="color: var(--color-text-secondary);">
      <span>{@non_hybrid} species</span>
      <span style="color: var(--color-text-tertiary);">|</span>
      <span>{@hybrid_count} hybrids</span>
      <span style="color: var(--color-text-tertiary);">|</span>
      <span class="font-medium">{@species_count} total</span>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :species, :any, required: true

  defp species_row(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={~p"/species/#{@species.scientific_name}"}
      class="flex items-center justify-between p-3 rounded-lg hover:bg-base-200 transition-colors group"
      style="text-decoration: none;"
    >
      <div class="flex items-center gap-2">
        <span class="font-medium group-hover:text-primary transition-colors">
          Quercus{" "}
          <span :if={@species.is_hybrid}>&times;</span>
          <em>{display_name(@species.scientific_name)}</em>
        </span>
        <span
          :if={@species.author}
          class="text-sm hidden sm:inline"
          style="color: var(--color-text-tertiary);"
        >
          {@species.author}
        </span>
      </div>
      <div class="flex items-center gap-2 text-xs">
        <span
          :if={@species.subgenus}
          class="badge badge-sm badge-ghost hidden sm:inline-flex"
        >
          {@species.subgenus}
        </span>
        <span
          :if={@species.section}
          class="badge badge-sm badge-ghost hidden md:inline-flex"
        >
          sect. {@species.section}
        </span>
        <span
          :if={@species.conservation_status}
          class={["badge badge-sm border", conservation_classes(@species.conservation_status)]}
        >
          {@species.conservation_status}
        </span>
      </div>
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
      p when p == %{} -> ~p"/list"
      p -> ~p"/list?#{p}"
    end
  end

  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp display_name("\u00D7" <> rest), do: rest
  defp display_name(name), do: name

  defp conservation_classes("LC"), do: "bg-green-100 text-green-800 border-green-300"
  defp conservation_classes("NT"), do: "bg-lime-100 text-lime-800 border-lime-300"
  defp conservation_classes("VU"), do: "bg-yellow-100 text-yellow-800 border-yellow-300"
  defp conservation_classes("EN"), do: "bg-orange-100 text-orange-800 border-orange-300"
  defp conservation_classes("CR"), do: "bg-red-100 text-red-800 border-red-300"
  defp conservation_classes("EW"), do: "bg-purple-100 text-purple-800 border-purple-300"
  defp conservation_classes("EX"), do: "bg-gray-800 text-white border-gray-900"
  defp conservation_classes("DD"), do: "bg-gray-100 text-gray-600 border-gray-300"
  defp conservation_classes("NE"), do: "bg-white text-gray-500 border-gray-300"
  defp conservation_classes(_), do: "bg-gray-100 text-gray-600 border-gray-300"
end
