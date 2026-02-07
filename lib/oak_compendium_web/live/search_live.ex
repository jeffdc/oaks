defmodule OakCompendiumWeb.SearchLive do
  @moduledoc """
  LiveView for unified search across species, taxa, and sources.

  Search query is stored in the URL as `?q=...` so results are
  bookmarkable and shareable. Input is debounced at 300ms to
  avoid excessive queries.
  """

  use OakCompendiumWeb, :live_view

  alias OakCompendium.Search

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Search",
       query: "",
       results: nil,
       loading: false
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = params["q"] || ""

    socket =
      if query != socket.assigns.query do
        perform_search(socket, query)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: search_path(query))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <h1 class="text-2xl font-bold mb-6">Search</h1>

      <form id="search-form" phx-change="search" class="mb-8">
        <div class="relative">
          <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <.icon name="hero-magnifying-glass" class="size-5 text-base-content/40" />
          </div>
          <input
            type="search"
            id="search-input"
            name="q"
            value={@query}
            placeholder="Search by name, author, synonym, or common name..."
            class="w-full input input-bordered pl-10"
            phx-debounce="300"
            autofocus
          />
        </div>
      </form>

      <div :if={@query == ""} class="text-center py-12 text-base-content/50">
        <.icon name="hero-magnifying-glass" class="size-12 mx-auto mb-4" />
        <p class="text-lg">Enter a search term to find species, taxa, or sources.</p>
      </div>

      <div :if={@query != "" && @results}>
        <.counts_bar counts={@results.counts} />
        <.no_results :if={@results.counts.total == 0} query={@query} />
        <div :if={@results.counts.total > 0}>
          <.taxa_results :if={@results.taxa != []} taxa={@results.taxa} />
          <.source_results :if={@results.sources != []} sources={@results.sources} />
          <.species_results :if={@results.species != []} species={@results.species} />
        </div>
      </div>
    </div>
    """
  end

  # -- Components --

  attr :counts, :map, required: true

  defp counts_bar(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-3 mb-6 text-sm text-base-content/70">
      <span :if={@counts.taxa > 0}>{@counts.taxa} taxa</span>
      <span
        :if={@counts.taxa > 0 && (@counts.sources > 0 || @counts.species > 0)}
        class="text-base-content/30"
      >
        |
      </span>
      <span :if={@counts.sources > 0}>{@counts.sources} sources</span>
      <span :if={@counts.sources > 0 && @counts.species > 0} class="text-base-content/30">|</span>
      <span :if={@counts.species > 0}>{@counts.species} species</span>
      <span class="text-base-content/30">|</span>
      <span class="font-medium">{@counts.total} total</span>
    </div>
    """
  end

  attr :query, :string, required: true

  defp no_results(assigns) do
    ~H"""
    <div class="text-center py-12 text-base-content/50">
      <.icon name="hero-magnifying-glass" class="size-12 mx-auto mb-4 opacity-50" />
      <p class="text-lg mb-2">No results found for "{@query}"</p>
      <p class="text-sm">Try adjusting your search term or using a different spelling.</p>
    </div>
    """
  end

  attr :taxa, :list, required: true

  defp taxa_results(assigns) do
    ~H"""
    <section class="mb-8">
      <h2 class="text-lg font-semibold mb-3 flex items-center gap-2">
        <span class="w-8 h-8 rounded-lg bg-success/10 flex items-center justify-center">
          <.icon name="hero-squares-2x2" class="size-4 text-success" />
        </span>
        Taxa
      </h2>
      <ul class="space-y-1" id="taxa-results">
        <li :for={taxon <- @taxa}>
          <.link
            navigate={taxonomy_path(taxon)}
            class="flex items-center justify-between p-3 rounded-lg hover:bg-base-200 transition-colors group"
          >
            <div class="flex items-center gap-3">
              <span class="font-medium group-hover:text-primary transition-colors">
                {taxon.name}
              </span>
              <span class="badge badge-sm badge-ghost">{taxon.level}</span>
            </div>
            <span :if={taxon.species_count > 0} class="text-sm text-base-content/50">
              {taxon.species_count} species
            </span>
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  attr :sources, :list, required: true

  defp source_results(assigns) do
    ~H"""
    <section class="mb-8">
      <h2 class="text-lg font-semibold mb-3 flex items-center gap-2">
        <span class="w-8 h-8 rounded-lg bg-warning/10 flex items-center justify-center">
          <.icon name="hero-book-open" class="size-4 text-warning" />
        </span>
        Sources
      </h2>
      <ul class="space-y-1" id="source-results">
        <li :for={source <- @sources}>
          <.link
            navigate={~p"/sources/#{source.id}"}
            class="flex items-center justify-between p-3 rounded-lg hover:bg-base-200 transition-colors group"
          >
            <div>
              <span class="font-medium group-hover:text-primary transition-colors">
                {source.name}
              </span>
              <span :if={source.author} class="text-sm text-base-content/50 ml-2">
                {source.author}
              </span>
            </div>
            <span :if={source.source_type} class="badge badge-sm badge-ghost">
              {source.source_type}
            </span>
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  attr :species, :list, required: true

  defp species_results(assigns) do
    ~H"""
    <section class="mb-8">
      <h2 class="text-lg font-semibold mb-3 flex items-center gap-2">
        <span class="w-8 h-8 rounded-lg bg-success/10 flex items-center justify-center">
          <.icon name="hero-check" class="size-4 text-success" />
        </span>
        Species
      </h2>
      <ul class="space-y-1" id="species-results">
        <li :for={species <- @species}>
          <.link
            navigate={~p"/species/#{species.scientific_name}"}
            class="flex items-center justify-between p-3 rounded-lg hover:bg-base-200 transition-colors group"
          >
            <div class="flex items-center gap-2">
              <span class="font-medium group-hover:text-primary transition-colors">
                Quercus <span :if={species.is_hybrid} class="mr-0.5">&times;</span>
                <em>{display_name(species.scientific_name)}</em>
              </span>
              <span :if={species.author} class="text-sm text-base-content/50">
                {species.author}
              </span>
            </div>
            <div class="flex items-center gap-2 text-sm text-base-content/50">
              <span :if={species.section}>{species.section}</span>
            </div>
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  # -- Helpers --

  defp perform_search(socket, "") do
    assign(socket, query: "", results: nil)
  end

  defp perform_search(socket, query) do
    results = Search.search(query)
    assign(socket, query: query, results: results, page_title: "Search: #{query}")
  end

  defp search_path(""), do: ~p"/search"
  defp search_path(query), do: ~p"/search?#{%{q: query}}"

  defp taxonomy_path(%{path: path}) when is_list(path) and path != [] do
    "/taxonomy/" <> Enum.join(path, "/")
  end

  defp taxonomy_path(%{name: name}) do
    "/taxonomy/#{name}"
  end

  defp display_name("×" <> rest), do: rest
  defp display_name(name), do: name
end
