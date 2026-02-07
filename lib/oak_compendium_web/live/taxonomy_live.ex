defmodule OakCompendiumWeb.TaxonomyLive do
  @moduledoc """
  LiveView for the taxonomy browser.

  Supports hierarchical drill-down through the Quercus taxonomy
  (genus > subgenus > section > subsection > complex) with
  breadcrumbs, species counts, and species lists at each level.
  """

  use OakCompendiumWeb, :live_view

  alias OakCompendium.Species
  alias OakCompendium.Taxonomy

  # Maps path depth to the current taxon's level name
  @levels ["genus", "subgenus", "section", "subsection", "complex"]

  # Maps path depth to the child taxa level
  @child_levels ["subgenus", "section", "subsection", "complex"]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Taxonomy")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    path = params["path"] || []
    depth = length(path)

    cond do
      depth > 4 ->
        {:noreply, assign_not_found(socket, path)}

      depth == 0 ->
        {:noreply, load_genus_level(socket)}

      true ->
        {:noreply, load_taxon_level(socket, path, depth)}
    end
  end

  # -- Data loading --

  defp load_genus_level(socket) do
    child_taxa = Taxonomy.list_taxa_with_counts(%{"level" => "subgenus"})
    species = Taxonomy.get_species_in_taxon([])
    total = Species.count()

    assign(socket,
      taxonomy_path: [],
      current_level: "genus",
      child_level: "subgenus",
      current_taxon: nil,
      child_taxa: child_taxa,
      species: species,
      species_count: total,
      breadcrumbs: [],
      is_genus_level: true,
      not_found: false,
      page_title: "Taxonomy"
    )
  end

  defp load_taxon_level(socket, path, depth) do
    current_level = Enum.at(@levels, depth)
    child_level = Enum.at(@child_levels, depth)
    taxon_name = List.last(path)

    case Taxonomy.get_taxon(current_level, taxon_name) do
      nil ->
        assign_not_found(socket, path)

      current_taxon ->
        child_taxa = fetch_child_taxa(child_level, path)
        species = Taxonomy.get_species_in_taxon(path)
        breadcrumbs = build_breadcrumbs(path)

        assign(socket,
          taxonomy_path: path,
          current_level: current_level,
          child_level: child_level,
          current_taxon: current_taxon,
          child_taxa: child_taxa,
          species: species,
          species_count: length(species),
          breadcrumbs: breadcrumbs,
          is_genus_level: false,
          not_found: false,
          page_title: "#{taxon_name} — Taxonomy"
        )
    end
  end

  defp assign_not_found(socket, path) do
    assign(socket,
      taxonomy_path: path,
      current_level: nil,
      child_level: nil,
      current_taxon: nil,
      child_taxa: [],
      species: [],
      species_count: 0,
      breadcrumbs: [],
      is_genus_level: false,
      not_found: true,
      page_title: "Not Found — Taxonomy"
    )
  end

  defp fetch_child_taxa(nil, _path), do: []

  defp fetch_child_taxa(child_level, path) do
    parent = if path == [], do: nil, else: List.last(path)
    params = %{"level" => child_level}
    params = if parent, do: Map.put(params, "parent", parent), else: params
    Taxonomy.list_taxa_with_counts(params)
  end

  defp build_breadcrumbs(path) do
    root = %{name: "Quercus", level: "genus", url: ~p"/taxonomy"}

    segments =
      path
      |> Enum.with_index()
      |> Enum.map(fn {name, idx} ->
        %{
          name: name,
          level: Enum.at(@levels, idx + 1),
          url: taxonomy_url(Enum.take(path, idx + 1))
        }
      end)

    [root | segments]
  end

  defp taxonomy_url(segments) do
    encoded = Enum.map_join(segments, "/", &URI.encode_www_form/1)
    "/taxonomy/#{encoded}"
  end

  # -- Render --

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto">
      <div :if={@not_found} class="text-center py-12">
        <.icon name="hero-exclamation-triangle" class="size-12 mx-auto mb-4 text-amber-500" />
        <h1
          class="text-xl font-semibold mb-2"
          style="font-family: var(--font-serif); color: var(--color-text-primary);"
        >
          Taxon Not Found
        </h1>
        <p class="mb-4" style="color: var(--color-text-tertiary);">
          The requested taxonomy path could not be found.
        </p>
        <.link
          navigate={~p"/taxonomy"}
          class="text-sm font-medium text-forest-700 hover:text-forest-900"
        >
          &larr; Return to taxonomy browser
        </.link>
      </div>

      <div :if={not @not_found}>
        <%!-- Breadcrumbs --%>
        <.breadcrumbs :if={not @is_genus_level} crumbs={@breadcrumbs} />

        <%!-- Header --%>
        <div class="flex items-center flex-wrap gap-3 mb-2">
          <h1
            class="text-2xl font-bold"
            style="font-family: var(--font-serif); color: var(--color-forest-800);"
          >
            {if @is_genus_level, do: "Quercus", else: @current_taxon.name}
          </h1>
          <span class="badge badge-forest-dark badge-uppercase">
            {@current_level}
          </span>
        </div>

        <p class="text-sm mb-6" style="color: var(--color-text-secondary);">
          {@species_count} species
        </p>

        <%!-- Taxon content --%>
        <div
          :if={@current_taxon && @current_taxon.content}
          class="card p-4 mb-6"
        >
          <h2 class="section-title section-title-sm mb-2">
            About this {@current_level}
          </h2>
          <div class="prose-content">{@current_taxon.content}</div>
        </div>

        <%!-- Child taxa --%>
        <div :if={@child_taxa != []} class="mb-8">
          <h2 class="section-title">{level_plural(@child_level)}</h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <.taxon_card
              :for={taxon <- @child_taxa}
              taxon={taxon}
              path={@taxonomy_path}
            />
          </div>
        </div>

        <%!-- Species --%>
        <div :if={@species != []}>
          <h2 class="section-title">{species_section_title(@is_genus_level)}</h2>
          <div class="space-y-0.5">
            <.species_row :for={species <- @species} species={species} />
          </div>
        </div>

        <%!-- Empty state --%>
        <div
          :if={@child_taxa == [] and @species == []}
          class="text-center py-12"
          style="color: var(--color-text-tertiary);"
        >
          <.icon name="hero-folder-open" class="size-12 mx-auto mb-4 opacity-50" />
          <p class="text-lg mb-1">No taxa or species at this level</p>
        </div>
      </div>
    </div>
    """
  end

  # -- Components --

  attr :crumbs, :list, required: true

  defp breadcrumbs(assigns) do
    ~H"""
    <nav class="taxonomy-nav mb-4" aria-label="Taxonomy breadcrumb">
      <span class="taxonomy-label">Taxonomy:</span>
      <span :for={{crumb, idx} <- Enum.with_index(@crumbs)}>
        <span :if={idx > 0} class="taxonomy-separator">&rsaquo;</span>
        <.link navigate={crumb.url} class="taxonomy-link">
          <span class="taxonomy-name">{crumb.name}</span>
          <span class="taxonomy-level-label">({crumb.level})</span>
        </.link>
      </span>
    </nav>
    """
  end

  attr :taxon, :any, required: true
  attr :path, :list, required: true

  defp taxon_card(assigns) do
    url = taxonomy_url(assigns.path ++ [assigns.taxon.name])
    assigns = assign(assigns, :url, url)

    ~H"""
    <.link
      navigate={@url}
      class="card card-interactive p-4 flex items-center justify-between"
      style="text-decoration: none;"
    >
      <div>
        <span class="font-medium" style="color: var(--color-forest-800);">
          {@taxon.name}
        </span>
        <span
          :if={@taxon.author}
          class="text-xs ml-1"
          style="color: var(--color-text-tertiary);"
        >
          {@taxon.author}
        </span>
      </div>
      <div class="flex items-center gap-2">
        <span class="badge badge-forest text-xs">
          {@taxon.species_count} species
        </span>
        <.icon name="hero-chevron-right" class="size-4 text-base-content/40" />
      </div>
    </.link>
    """
  end

  attr :species, :any, required: true

  defp species_row(assigns) do
    ~H"""
    <.link
      navigate={~p"/species/#{@species.scientific_name}"}
      class="flex items-center justify-between p-3 rounded-lg hover:bg-base-200 transition-colors group"
      style="text-decoration: none;"
    >
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
    </.link>
    """
  end

  # -- Helpers --

  defp display_name("\u00D7" <> rest), do: rest
  defp display_name(name), do: name

  defp level_plural("subgenus"), do: "Subgenera"
  defp level_plural("section"), do: "Sections"
  defp level_plural("subsection"), do: "Subsections"
  defp level_plural("complex"), do: "Complexes"
  defp level_plural(_), do: "Taxa"

  defp species_section_title(true), do: "Species without subgenus assignment"
  defp species_section_title(false), do: "Species"
end
