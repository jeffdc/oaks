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
       synonyms: %{},
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
      <:head>
        <.header :if={@query == ""}>Search</.header>
        <.header :if={@query != "" && @results} id="search-title">
          Results for “{@query}”
          <:meta :if={@results.counts.taxa > 0}>
            {count_label(@results.counts.taxa, "taxon", "taxa")}
          </:meta>
          <:meta :if={@results.counts.sources > 0}>
            {count_label(@results.counts.sources, "source", "sources")}
          </:meta>
          <:meta :if={@results.counts.species > 0}>{@results.counts.species} species</:meta>
          <:meta :if={kinds_found(@results.counts) > 1}>
            <strong>{@results.counts.total} total</strong>
          </:meta>
          <:actions :if={@current_scope}>
            <.button navigate={~p"/species/new"} id="search-add-species">Add Species</.button>
          </:actions>
        </.header>
      </:head>
      <div :if={@query == ""}>
        <p class="search-empty">
          Find species, taxa and sources by name, common name or synonym in the search field above.
          <span class="search-key-hint">Press <kbd>/</kbd> to go to it from any page.</span>
        </p>
      </div>
      <div :if={@query != "" && @results}>
        <.no_results :if={@results.counts.total == 0} query={@query} />
        <div :if={@results.counts.total > 0}>
          <.taxa_results :if={@results.taxa != []} taxa={@results.taxa} />
          <.source_results :if={@results.sources != []} sources={@results.sources} />
          <.species_results
            :if={@results.species != []}
            species={@results.species}
            synonyms={@synonyms}
          />
        </div>
      </div>
    </.page>
    """
  end

  # -- Components --

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
      <.section_heading>Taxa</.section_heading>
      <ul class="search-results-list" id="taxa-results">
        <.result_row :for={taxon <- @taxa} navigate={taxonomy_path(taxon)}>
          <.sci_name name={taxon.name} level={taxon.level} size="title" />
          <span class="search-taxon-level">{taxon.level}</span>
          <:meta :if={taxon.species_count > 0}>{taxon.species_count} species</:meta>
        </.result_row>
      </ul>
    </section>
    """
  end

  attr :sources, :list, required: true

  defp source_results(assigns) do
    ~H"""
    <section class="search-section">
      <.section_heading>Sources</.section_heading>
      <ul class="search-results-list" id="source-results">
        <.result_row :for={source <- @sources} navigate={~p"/sources/#{source.id}"}>
          <span class="search-result-name"><.work_title title={source.name} /></span>
          <span :if={source.author} class="search-result-author">{source.author}</span>
          <:meta :if={source.year}>{source.year}</:meta>
        </.result_row>
      </ul>
    </section>
    """
  end

  attr :species, :list, required: true
  attr :synonyms, :map, required: true, doc: "species id => the synonym it was found through"

  defp species_results(assigns) do
    ~H"""
    <section class="search-section">
      <.section_heading>Species</.section_heading>
      <ul class="search-results-list" id="species-results">
        <.result_row
          :for={species <- @species}
          navigate={~p"/species/#{species.scientific_name}"}
          id={"species-result-#{species.id}"}
        >
          <.sci_name
            name={species.scientific_name}
            hybrid={species.is_hybrid}
            author={species.author}
            size="title"
          />
          <:note :if={@synonyms[species.id]}>
            via
            <.sci_name
              name={@synonyms[species.id].name}
              author={@synonyms[species.id].author}
              abbreviate
              size="meta"
            />
          </:note>
          <:meta :if={species.section}>
            <.sci_name name={species.section} rank="sect." size="meta" />
          </:meta>
        </.result_row>
      </ul>
    </section>
    """
  end

  # One result: the name, then a details line (a note on why it matched,
  # then its meta). The details stand beside the name, the meta at the
  # right, and drop under the name on phones.
  attr :navigate, :string, required: true
  attr :id, :string, default: nil
  slot :inner_block, required: true
  slot :note
  slot :meta

  defp result_row(assigns) do
    ~H"""
    <li id={@id}>
      <.link navigate={@navigate} class="search-result-row">
        <span class="search-result-main">{render_slot(@inner_block)}</span>
        <span :if={@note != [] || @meta != []} class="search-result-details">
          <span :for={note <- @note} class="search-result-note">{render_slot(note)}</span>
          <span :for={meta <- @meta} class="search-result-meta">{render_slot(meta)}</span>
        </span>
      </.link>
    </li>
    """
  end

  # -- Helpers --

  defp perform_search(socket, "") do
    assign(socket, query: "", results: nil, synonyms: %{}, page_title: "Search")
  end

  defp perform_search(socket, query) do
    results = Search.search(query)

    assign(socket,
      query: query,
      results: results,
      synonyms: Search.synonym_matches(results.species, query),
      page_title: "Search: #{query}"
    )
  end

  defp count_label(1, singular, _plural), do: "1 #{singular}"
  defp count_label(n, _singular, plural), do: "#{n} #{plural}"

  # How many kinds of result (taxa, sources, species) were found; the
  # total is worth showing only beside two or more.
  defp kinds_found(counts) do
    Enum.count([counts.taxa, counts.sources, counts.species], &(&1 > 0))
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
