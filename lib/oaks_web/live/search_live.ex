defmodule OaksWeb.SearchLive do
  @moduledoc """
  LiveView for unified search across species, taxa, and sources.

  Search query is stored in the URL as `?q=...` so results are
  bookmarkable and shareable. The header search input is synced
  via the SearchSync hook, which debounces at 300ms.
  """

  use OaksWeb, :live_view

  alias Oaks.Search
  alias OaksWeb.Params

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
    query = Params.string(params["q"])

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
    {:noreply, push_patch(socket, to: search_path(Params.string(query)))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page id="search-sync" phx-hook="SearchSync" data-query={@query}>
      <div :if={@query == ""} class="search-start">
        <h1 class="search-title">Search</h1>
        <p class="search-empty">
          Find species, taxa and sources by name, common name or synonym in the search field above.
          <span class="search-key-hint">Press <kbd>/</kbd> to go to it from any page.</span>
        </p>
      </div>
      <div :if={@query != "" && @results}>
        <h1 class="sr-only">Search results for {@query}</h1>
        <.counts_bar counts={@results.counts} editor={@current_scope != nil} />
        <.no_results :if={@results.counts.total == 0} query={@query} />
        <div :if={@results.counts.total > 0}>
          <.taxa_results :if={@results.taxa != []} taxa={@results.taxa} />
          <.source_results :if={@results.sources != []} sources={@results.sources} />
          <.species_results :if={@results.species != []} species={@results.species} />
        </div>
      </div>
    </.page>
    """
  end

  # -- Components --

  attr :counts, :map, required: true
  attr :editor, :boolean, default: false

  defp counts_bar(assigns) do
    ~H"""
    <div class="search-counts-bar">
      <span :if={@counts.taxa > 0} class="search-count-item">
        <b>{@counts.taxa}</b> {if(@counts.taxa == 1, do: "taxon", else: "taxa")}
      </span>
      <span :if={@counts.taxa > 0} class="search-separator" aria-hidden="true"></span>
      <span class="search-count-item">
        <b>{@counts.sources}</b> {if(@counts.sources == 1, do: "source", else: "sources")}
      </span>
      <span class="search-separator" aria-hidden="true"></span>
      <span class="search-count-item">
        <b>{@counts.species}</b> species
      </span>
      <span class="search-separator" aria-hidden="true"></span>
      <span class="search-count-total">
        <b>{@counts.total}</b> total
      </span>
      <.button
        :if={@editor}
        navigate={~p"/species/new"}
        size="compact"
        class="search-add-species-btn"
      >
        Add Species
      </.button>
    </div>
    """
  end

  attr :query, :string, required: true

  defp no_results(assigns) do
    ~H"""
    <div class="search-no-results">
      <p class="search-empty">No results found for <b>{@query}</b>.</p>
      <p class="search-empty-hint">
        Try adjusting your search term or using a different spelling.
      </p>
    </div>
    """
  end

  attr :taxa, :list, required: true

  defp taxa_results(assigns) do
    ~H"""
    <section class="search-section">
      <h2 class="search-section-label">Taxa</h2>
      <ul class="search-results-list" id="taxa-results">
        <li :for={taxon <- @taxa}>
          <.link navigate={taxonomy_path(taxon)} class="search-result-row">
            <span class="search-result-main">
              <i class="search-result-name search-result-name-taxon">{taxon.name}</i>
              <span class="search-taxon-level">{taxon.level}</span>
            </span>
            <span :if={taxon.species_count > 0} class="search-result-meta">
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
    <section class="search-section">
      <h2 class="search-section-label">Sources</h2>
      <ul class="search-results-list" id="source-results">
        <li :for={source <- @sources}>
          <.link navigate={~p"/sources/#{source.id}"} class="search-result-row">
            <span class="search-result-main">
              <span class="search-result-name search-result-name-source">{source.name}</span>
              <span :if={source.author} class="search-result-author">{source.author}</span>
            </span>
            <span :if={source.year} class="search-result-meta">{source.year}</span>
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  attr :species, :list, required: true

  defp species_results(assigns) do
    ~H"""
    <section class="search-section">
      <h2 class="search-section-label">Species</h2>
      <ul class="search-results-list" id="species-results">
        <li :for={species <- @species}>
          <.link navigate={~p"/species/#{species.scientific_name}"} class="search-result-row">
            <span class="search-result-main">
              <i class="search-result-name search-result-name-species">
                <span class="search-result-genus">Quercus</span>
                <span
                  :if={hybrid_sign?(species.scientific_name, species.is_hybrid)}
                  class="not-italic"
                >
                  &times;
                </span>
                <span :for={{part, i} <- Enum.with_index(formula_parts(species.scientific_name))}><span
                  :if={i > 0}
                  class="not-italic"
                >{" × "}</span>{part}</span>
              </i>
              <span :if={species.author} class="search-result-author">{species.author}</span>
            </span>
            <span :if={species.section} class="search-result-meta">
              Section <i>{species.section}</i>
            </span>
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  # -- Helpers --

  defp perform_search(socket, "") do
    assign(socket, query: "", results: nil, page_title: "Search")
  end

  defp perform_search(socket, query) do
    results = Search.search(query)
    assign(socket, query: query, results: results, page_title: "Search: #{query}")
  end

  # A hybrid formula's parts, so its sign can be set roman between them
  defp formula_parts(scientific_name) do
    scientific_name |> epithet() |> String.split(~r/\s*×\s*/u)
  end

  defp search_path(""), do: ~p"/search"
  defp search_path(query), do: ~p"/search?#{%{q: query}}"

  defp taxonomy_path(%{path: path}) when is_list(path) and path != [] do
    "/taxonomy/" <> Enum.join(path, "/")
  end

  defp taxonomy_path(%{name: name}) do
    "/taxonomy/#{name}"
  end
end
