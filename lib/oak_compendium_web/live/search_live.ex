defmodule OakCompendiumWeb.SearchLive do
  @moduledoc """
  LiveView for unified search across species, taxa, and sources.

  Search query is stored in the URL as `?q=...` so results are
  bookmarkable and shareable. The header search input is synced
  via the SearchSync hook, which debounces at 300ms.
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
    <div id="search-sync" phx-hook="SearchSync" data-query={@query}>
      <div :if={@query != "" && @results}>
        <.counts_bar counts={@results.counts} authenticated={assigns[:authenticated]} />
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
  attr :authenticated, :boolean, default: false

  defp counts_bar(assigns) do
    ~H"""
    <div class="card search-counts-bar">
      <span :if={@counts.taxa > 0} class="search-count-item">
        {@counts.taxa} {if(@counts.taxa == 1, do: "taxon", else: "taxa")}
      </span>
      <span :if={@counts.taxa > 0} class="search-separator">|</span>
      <span class="search-count-item">
        {@counts.sources} {if(@counts.sources == 1, do: "source", else: "sources")}
      </span>
      <span class="search-separator">|</span>
      <span class="search-count-item">
        {@counts.species} species
      </span>
      <span class="search-separator">|</span>
      <span class="search-count-total">
        {@counts.total} total
      </span>
      <.link
        :if={@authenticated}
        navigate={~p"/species/new"}
        class="search-add-species-btn"
      >
        <svg
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
        </svg>
        Add Species
      </.link>
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
    <div class="search-section">
      <h3 class="search-section-label">Taxa</h3>
      <ul class="card search-results-list" id="taxa-results">
        <li :for={taxon <- @taxa}>
          <.link
            navigate={taxonomy_path(taxon)}
            class="search-result-row"
          >
            <div class="search-result-main">
              <span class="search-result-icon search-result-icon-taxon">
                <.icon name="hero-squares-2x2" class="size-4" />
              </span>
              <span class="search-result-name search-result-name-taxon">{taxon.name}</span>
              <span class="search-taxon-level">{taxon.level}</span>
            </div>
            <div :if={taxon.species_count > 0} class="search-result-meta">
              {taxon.species_count} species
            </div>
          </.link>
        </li>
      </ul>
    </div>
    """
  end

  attr :sources, :list, required: true

  defp source_results(assigns) do
    ~H"""
    <div class="search-section">
      <h3 class="search-section-label">Sources</h3>
      <ul class="card search-results-list" id="source-results">
        <li :for={source <- @sources}>
          <.link
            navigate={~p"/sources/#{source.id}"}
            class="search-result-row"
          >
            <div class="search-result-main">
              <span class="search-result-icon search-result-icon-source">
                <.icon name="hero-book-open" class="size-4" />
              </span>
              <span class="search-result-name search-result-name-source">{source.name}</span>
              <span :if={source.author} class="search-result-author">{source.author}</span>
            </div>
            <div :if={source.year} class="search-result-meta">
              {source.year}
            </div>
          </.link>
        </li>
      </ul>
    </div>
    """
  end

  attr :species, :list, required: true

  defp species_results(assigns) do
    ~H"""
    <div class="search-section">
      <h3 class="search-section-label">Species</h3>
      <ul class="card search-results-list" id="species-results">
        <li :for={species <- @species}>
          <.link
            navigate={~p"/species/#{species.scientific_name}"}
            class="search-result-row"
          >
            <div class="search-result-main">
              <span class="search-result-icon search-result-icon-species">
                <.icon name="hero-check" class="size-4" />
              </span>
              <span class="search-result-name search-result-name-species">
                Quercus <span :if={species.is_hybrid} class="mr-0.5">&times;</span>
                <em>{display_name(species.scientific_name)}</em>
              </span>
              <span :if={species.author} class="search-result-author">
                {species.author}
              </span>
            </div>
            <div :if={species.section} class="search-result-meta">
              {species.section}
            </div>
          </.link>
        </li>
      </ul>
    </div>
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
