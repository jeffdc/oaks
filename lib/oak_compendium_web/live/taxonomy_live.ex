defmodule OakCompendiumWeb.TaxonomyLive do
  @moduledoc """
  LiveView for the taxonomy browser.

  Supports hierarchical drill-down through the Quercus taxonomy
  (genus > subgenus > section > subsection > complex) with
  breadcrumbs, species counts, and species lists at each level.
  """

  use OakCompendiumWeb, :live_view

  alias OakCompendium.Markdown
  alias OakCompendium.Species
  alias OakCompendium.Taxonomy

  # Maps path depth to the current taxon's level name
  @levels ["genus", "subgenus", "section", "subsection", "complex"]

  # Maps path depth to the child taxa level
  @child_levels ["subgenus", "section", "subsection", "complex"]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Taxonomy",
       show_delete_taxon_confirm: false,
       delete_taxon_target: nil
     )}
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

  @impl true
  def handle_event("request_delete_taxon", %{"id" => id_str}, socket) do
    if socket.assigns[:authenticated] do
      id = String.to_integer(id_str)
      taxon = Taxonomy.get_taxon_by_id(id)
      {:noreply, assign(socket, show_delete_taxon_confirm: true, delete_taxon_target: taxon)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_delete_taxon", _params, socket) do
    {:noreply, assign(socket, show_delete_taxon_confirm: false, delete_taxon_target: nil)}
  end

  def handle_event("confirm_delete_taxon", _params, socket) do
    if socket.assigns[:authenticated] do
      taxon = socket.assigns.delete_taxon_target

      case Taxonomy.delete_taxon(taxon) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(show_delete_taxon_confirm: false, delete_taxon_target: nil)
           |> put_flash(:info, "Taxon deleted.")
           |> push_navigate(to: ~p"/taxonomy")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> assign(show_delete_taxon_confirm: false, delete_taxon_target: nil)
           |> put_flash(:error, "Failed to delete taxon.")}
      end
    else
      {:noreply, socket}
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
    <div class="max-w-7xl mx-auto">
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
        <%!-- Header card with gradient --%>
        <div
          class="mb-6"
          style="background: linear-gradient(135deg, var(--color-forest-50) 0%, var(--color-forest-100) 100%); border: 1px solid var(--color-forest-200); border-radius: 0.75rem; padding: 1rem 1.5rem;"
        >
          <div class="flex items-center justify-between flex-wrap gap-3">
            <div class="flex items-center gap-3">
              <span class="badge badge-forest badge-uppercase">
                {@current_level}
              </span>
              <h1
                class="text-2xl font-bold"
                style="font-family: var(--font-serif); color: var(--color-forest-800);"
              >
                <.taxon_display_name
                  is_genus={@is_genus_level}
                  level={@current_level}
                  taxon={@current_taxon}
                />
              </h1>
            </div>
            <div class="flex items-center gap-4">
              <.link
                :if={@authenticated}
                navigate={create_taxon_path(@child_level, @current_taxon)}
                class="create-taxon-btn"
                style="text-decoration: none;"
                id="create-taxon-btn"
              >
                <.icon name="hero-plus" class="size-4" /> Create Taxon
              </.link>
              <span class="text-sm font-medium" style="color: var(--color-text-secondary);">
                {@species_count} species
              </span>
            </div>
          </div>
          <.breadcrumbs :if={not @is_genus_level} crumbs={@breadcrumbs} />
          <div
            :if={@authenticated && not @is_genus_level && @current_taxon}
            class="flex items-center gap-2 mt-2"
          >
            <.link
              navigate={~p"/taxonomy/#{@current_taxon.id}/edit"}
              class="action-btn action-btn-edit"
              style="text-decoration: none;"
            >
              <.icon name="hero-pencil-square" class="size-3.5" /> Edit
            </.link>
            <button
              phx-click="request_delete_taxon"
              phx-value-id={@current_taxon.id}
              class="action-btn action-btn-delete"
            >
              <.icon name="hero-trash" class="size-3.5" /> Delete
            </button>
          </div>
        </div>

        <%!-- Taxon content --%>
        <div
          :if={@current_taxon && @current_taxon.content}
          class="card p-4 mb-6"
        >
          <h2 class="section-title section-title-sm mb-2">
            About this {@current_level}
          </h2>
          <div class="prose-content">{raw(Markdown.render_html(@current_taxon.content))}</div>
          <p
            :if={@current_taxon.content_updated_at}
            class="text-xs mt-3"
            style="color: var(--color-text-tertiary);"
          >
            Updated {@current_taxon.content_updated_at}
          </p>
        </div>

        <%!-- Child taxa --%>
        <section :if={@child_taxa != []} class="card mb-6" style="padding: 1.5rem;">
          <h2 class="section-title section-title-sm mb-3">{level_plural(@child_level)}</h2>
          <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 0.75rem;">
            <.taxon_card
              :for={taxon <- @child_taxa}
              taxon={taxon}
              path={@taxonomy_path}
              authenticated={@authenticated}
            />
          </div>
        </section>

        <%!-- Species --%>
        <section :if={@species != []} class="card" style="padding: 1.5rem;">
          <h2 class="section-title section-title-sm mb-3">
            {species_section_title(@is_genus_level, length(@species))}
          </h2>
          <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 0.75rem;">
            <.species_card :for={species <- @species} species={species} />
          </div>
        </section>

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

      <.delete_taxon_modal
        :if={@show_delete_taxon_confirm && @delete_taxon_target}
        taxon={@delete_taxon_target}
      />
    </div>
    """
  end

  # -- Components --

  attr :crumbs, :list, required: true

  defp breadcrumbs(assigns) do
    ~H"""
    <nav class="taxonomy-nav mt-2" aria-label="Taxonomy breadcrumb">
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
  attr :authenticated, :boolean, default: false

  defp taxon_card(assigns) do
    url = taxonomy_url(assigns.path ++ [assigns.taxon.name])
    assigns = assign(assigns, :url, url)

    ~H"""
    <div class="taxon-card-wrapper">
      <.link
        navigate={@url}
        class="taxon-card flex flex-col items-start p-4"
      >
        <span class="font-semibold" style="color: var(--color-forest-800); font-size: 0.9375rem;">
          {@taxon.name}
        </span>
        <span class="text-xs mt-1" style="color: var(--color-text-tertiary);">
          {@taxon.species_count} species
        </span>
      </.link>
      <div :if={@authenticated} class="taxon-card-actions">
        <.link
          navigate={~p"/taxonomy/#{@taxon.id}/edit"}
          class="taxon-action-icon"
          title={"Edit #{@taxon.name}"}
          style="text-decoration: none;"
        >
          <.icon name="hero-pencil-square" class="size-3.5" />
        </.link>
        <button
          phx-click="request_delete_taxon"
          phx-value-id={@taxon.id}
          class="taxon-action-icon taxon-action-delete"
          title={"Delete #{@taxon.name}"}
        >
          <.icon name="hero-trash" class="size-3.5" />
        </button>
      </div>
    </div>
    """
  end

  attr :is_genus, :boolean, required: true
  attr :level, :string, required: true
  attr :taxon, :any, required: true

  defp taxon_display_name(assigns) do
    ~H"""
    <span :if={@is_genus}><em>Quercus</em></span>
    <span :if={not @is_genus and @level == "complex"}>
      Q. {@taxon.name}
    </span>
    <span :if={not @is_genus and @level != "complex"}>
      {@taxon.name}
    </span>
    """
  end

  attr :species, :any, required: true

  defp species_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/species/#{@species.scientific_name}"}
      class="species-card p-4"
      style="display: flex; flex-wrap: wrap; align-items: baseline; gap: 0.375rem;"
    >
      <span style="font-style: italic; font-weight: 500; color: var(--color-forest-700); font-size: 0.9375rem;">
        Quercus{" "}
        <span :if={@species.is_hybrid} style="font-style: normal;">&times;</span>
        {display_name(@species.scientific_name)}
      </span>
      <span
        :if={@species.author}
        style="font-size: 0.8125rem; color: var(--color-text-tertiary); font-weight: 400;"
      >
        {@species.author}
      </span>
    </.link>
    """
  end

  # -- Delete taxon modal --

  attr :taxon, :any, required: true

  defp delete_taxon_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 flex items-center justify-center"
      id="delete-taxon-modal"
      phx-window-keydown="cancel_delete_taxon"
      phx-key="Escape"
    >
      <div class="fixed inset-0 bg-black/50" phx-click="cancel_delete_taxon" />
      <div class="relative bg-white rounded-xl shadow-xl max-w-md w-full mx-4 p-6">
        <h3 class="text-lg font-bold text-red-800 mb-2">Delete Taxon</h3>
        <p class="mb-4" style="color: var(--color-text-secondary);">
          Are you sure you want to delete <strong>{@taxon.name}</strong> ({@taxon.level})?
        </p>
        <p class="text-sm mb-4" style="color: var(--color-text-tertiary);">
          This will fail if species or child taxa reference it.
        </p>
        <div class="flex justify-end gap-3">
          <button
            phx-click="cancel_delete_taxon"
            class="px-4 py-2 rounded-lg text-sm font-medium"
            style="color: var(--color-text-secondary);"
          >
            Cancel
          </button>
          <button
            phx-click="confirm_delete_taxon"
            class="px-4 py-2 rounded-lg text-sm font-medium text-white bg-red-600 hover:bg-red-700 transition-colors"
            id="confirm-delete-taxon-btn"
          >
            Delete Taxon
          </button>
        </div>
      </div>
    </div>
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

  defp species_section_title(true, count), do: "Species without subgenus assignment (#{count})"
  defp species_section_title(false, _count), do: "Species"

  defp create_taxon_path(child_level, current_taxon) do
    params =
      if child_level do
        %{level: child_level}
      else
        %{}
      end

    params =
      if current_taxon do
        Map.put(params, :parent, current_taxon.name)
      else
        params
      end

    query = URI.encode_query(params)

    if query == "" do
      ~p"/taxonomy/new"
    else
      "/taxonomy/new?#{query}"
    end
  end
end
