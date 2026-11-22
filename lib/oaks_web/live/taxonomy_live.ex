defmodule OaksWeb.TaxonomyLive do
  @moduledoc """
  LiveView for the taxonomy browser.

  Supports hierarchical drill-down through the Quercus taxonomy
  (genus > subgenus > section > subsection > complex) with the
  taxonomy band, species counts, and species lists at each level. A path
  that names no taxon raises `OaksWeb.NotFoundError`, a real 404.
  """

  use OaksWeb, :live_view

  alias Oaks.Markdown
  alias Oaks.Species
  alias Oaks.Taxonomy
  alias OaksWeb.Params
  alias OaksWeb.SpeciesName
  alias OaksWeb.TaxonPath

  # The level a new child taxon gets when created from a taxon's page
  @child_levels %{"subgenus" => "section", "section" => "subsection", "subsection" => "complex"}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Taxonomy",
       show_delete_taxon_confirm: false,
       delete_taxon_target: nil,
       delete_taxon_usage: nil
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    path = params["path"] || []
    depth = length(path)

    cond do
      depth > 4 ->
        raise OaksWeb.NotFoundError, kind: :taxon, query: List.last(path)

      depth == 0 ->
        {:noreply, load_genus_level(socket)}

      true ->
        {:noreply, load_taxon_level(socket, path)}
    end
  end

  @impl true
  def handle_event("request_delete_taxon", %{"id" => id_str}, socket) do
    id = Params.int(id_str)
    taxon = socket.assigns[:current_scope] && id && Taxonomy.get_taxon_by_id(id)

    if taxon do
      {:noreply,
       assign(socket,
         show_delete_taxon_confirm: true,
         delete_taxon_target: taxon,
         delete_taxon_usage: Taxonomy.taxon_usage(taxon)
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_delete_taxon", _params, socket) do
    {:noreply, assign(socket, show_delete_taxon_confirm: false, delete_taxon_target: nil)}
  end

  def handle_event("confirm_delete_taxon", _params, socket) do
    taxon = socket.assigns.delete_taxon_target

    if socket.assigns[:current_scope] && taxon do
      socket = assign(socket, show_delete_taxon_confirm: false, delete_taxon_target: nil)

      case Taxonomy.delete_taxon(taxon) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Taxon deleted.")
           |> push_navigate(to: ~p"/taxonomy")}

        {:error, {:in_use, usage}} ->
          {:noreply,
           put_flash(socket, :error, "Can't delete: #{usage_text(usage)} still use it.")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete taxon.")}
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
      band_ranks: [],
      band_current: %{level: "genus", name: "Quercus", hybrid: false},
      is_genus_level: true,
      page_title: "Taxonomy"
    )
  end

  defp load_taxon_level(socket, path) do
    case Taxonomy.resolve_path(path) do
      :error ->
        raise OaksWeb.NotFoundError, kind: :taxon, query: List.last(path)

      {:ok, taxa} ->
        current_taxon = List.last(taxa)
        taxon_name = SpeciesName.taxon_label(current_taxon.level, current_taxon.name)
        child_taxa = Taxonomy.get_children(current_taxon)
        species = Taxonomy.get_species_in_taxon(path)

        steps =
          taxa
          |> Enum.map(&%{level: &1.level, name: &1.name, hybrid: false})
          |> TaxonPath.ranks()

        assign(socket,
          taxonomy_path: path,
          current_level: current_taxon.level,
          child_level: Map.get(@child_levels, current_taxon.level),
          current_taxon: current_taxon,
          child_taxa: child_taxa,
          species: species,
          # Everything in the taxon, matching the count on its card one level up.
          species_count: Taxonomy.taxon_usage(current_taxon).species,
          band_ranks: Enum.drop(steps, -1),
          band_current: steps |> List.last() |> Map.delete(:path),
          is_genus_level: false,
          page_title: "#{taxon_name} — Taxonomy"
        )
    end
  end

  # -- Render --

  @impl true
  def render(assigns) do
    ~H"""
    <.page>
      <:bleed><.taxonomy_band ranks={@band_ranks} current={@band_current} /></:bleed>
      <:head>
        <.header id="taxon-title">
          <.sci_name name={current_name(@current_taxon)} level={@current_level} size="display" />
          <:meta>{level_label(@current_level)}</:meta>
          <:meta>{@species_count} species</:meta>
          <:actions :if={@current_scope}>
            <.button
              navigate={create_taxon_path(@child_level, @current_taxon)}
              id="create-taxon-btn"
              size="compact"
            >
              Create Taxon
            </.button>
            <.button
              :if={not @is_genus_level && @current_taxon}
              navigate={~p"/taxonomy/#{@current_taxon.id}/edit"}
              size="compact"
            >
              Edit
            </.button>
            <.button
              :if={not @is_genus_level && @current_taxon}
              phx-click="request_delete_taxon"
              phx-value-id={@current_taxon.id}
              size="compact"
            >
              Delete
            </.button>
          </:actions>
        </.header>
      </:head>

      <div>
        <%!-- Taxon content --%>
        <section :if={@current_taxon && @current_taxon.content} class="taxon-section">
          <div class="flex flex-wrap items-center justify-between gap-2 mb-s4">
            <h2 class="section-title section-title-sm">About this {@current_level}</h2>
            <div class="flex items-center gap-s3">
              <span :if={@current_taxon.content_updated_at} class="taxon-section-note">
                Updated {@current_taxon.content_updated_at}
              </span>
              <.button
                :if={@current_scope}
                navigate={~p"/taxonomy/#{@current_taxon.id}/edit"}
                size="compact"
              >
                Edit
              </.button>
            </div>
          </div>
          <div class="prose-content">{raw(Markdown.render_html(@current_taxon.content))}</div>
        </section>

        <%!-- Empty content prompt for logged-in users --%>
        <section
          :if={@current_scope && @current_taxon && !@current_taxon.content && !@is_genus_level}
          class="taxon-section"
        >
          <div class="flex flex-wrap items-center justify-between gap-2 mb-s4">
            <h2 class="section-title section-title-sm">About this {@current_level}</h2>
            <.button navigate={~p"/taxonomy/#{@current_taxon.id}/edit"} size="compact">
              Add Content
            </.button>
          </div>
          <p class="taxon-empty">No description of this {@current_level} yet.</p>
        </section>

        <%!-- Child taxa --%>
        <section :if={@child_taxa != []} class="taxon-section">
          <h2 class="section-title section-title-sm">{children_heading(@child_taxa)}</h2>
          <ul class="taxon-index">
            <.taxon_card
              :for={taxon <- @child_taxa}
              taxon={taxon}
              path={@taxonomy_path}
              editor={@current_scope != nil}
            />
          </ul>
        </section>

        <%!-- Species --%>
        <section :if={@species != []} class="taxon-section">
          <h2 class="section-title section-title-sm">
            {species_section_title(@is_genus_level, length(@species))}
          </h2>
          <ul class="species-index">
            <li :for={species <- @species}><.species_card species={species} /></li>
          </ul>
        </section>

        <%!-- Empty state --%>
        <p :if={@child_taxa == [] and @species == []} class="taxon-empty">
          No taxa or species at this level.
        </p>
      </div>

      <.delete_taxon_modal
        :if={@show_delete_taxon_confirm && @delete_taxon_target}
        taxon={@delete_taxon_target}
        usage={@delete_taxon_usage}
      />
    </.page>
    """
  end

  # -- Components --

  attr :taxon, :any, required: true
  attr :path, :list, required: true
  attr :editor, :boolean, default: false

  defp taxon_card(assigns) do
    url = TaxonPath.taxonomy_path(assigns.path ++ [assigns.taxon.name])
    assigns = assign(assigns, :url, url)

    ~H"""
    <li class="taxon-card-wrapper">
      <.link navigate={@url} class="taxon-card">
        <.sci_name name={@taxon.name} level={@taxon.level} size="title" />
        <span class="taxon-card-count">{@taxon.species_count} species</span>
      </.link>
      <div :if={@editor} class="taxon-card-actions">
        <.link
          navigate={~p"/taxonomy/#{@taxon.id}/edit"}
          class="taxon-action-icon"
          title={"Edit #{SpeciesName.taxon_label(@taxon.level, @taxon.name)}"}
          aria-label={"Edit #{SpeciesName.taxon_label(@taxon.level, @taxon.name)}"}
        >
          <.icon name="hero-pencil-square" class="size-3.5" />
        </.link>
        <button
          phx-click="request_delete_taxon"
          phx-value-id={@taxon.id}
          class="taxon-action-icon taxon-action-delete"
          title={"Delete #{SpeciesName.taxon_label(@taxon.level, @taxon.name)}"}
          aria-label={"Delete #{SpeciesName.taxon_label(@taxon.level, @taxon.name)}"}
        >
          <.icon name="hero-trash" class="size-3.5" />
        </button>
      </div>
    </li>
    """
  end

  attr :species, :any, required: true

  defp species_card(assigns) do
    ~H"""
    <.link navigate={~p"/species/#{@species.scientific_name}"} class="species-card">
      <.sci_name
        name={@species.scientific_name}
        hybrid={@species.is_hybrid}
        author={@species.author}
        size="title"
      />
    </.link>
    """
  end

  # -- Delete taxon modal --

  attr :taxon, :any, required: true
  attr :usage, :map, default: nil

  defp delete_taxon_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 flex items-center justify-center"
      id="delete-taxon-modal"
      phx-window-keydown="cancel_delete_taxon"
      phx-key="Escape"
    >
      <div class="oc-modal-backdrop" phx-click="cancel_delete_taxon" />
      <div
        class="relative oc-modal-panel max-w-md mx-4"
        role="dialog"
        aria-modal="true"
        aria-labelledby="delete-taxon-title"
      >
        <div class="oc-modal-head">
          <h2 id="delete-taxon-title">Delete Taxon</h2>
        </div>
        <div class="oc-modal-body">
          <p class="taxon-modal-text">
            Are you sure you want to delete
            <.sci_name name={@taxon.name} level={@taxon.level} weight="regular" /> ({@taxon.level})?
          </p>
          <p :if={in_use?(@usage)} class="taxon-modal-in-use" id="delete-taxon-in-use">
            {usage_text(@usage)} still use this taxon. Move or delete them first.
          </p>
        </div>
        <div class="oc-modal-actions">
          <.button phx-click="cancel_delete_taxon">Cancel</.button>
          <.button
            :if={!in_use?(@usage)}
            phx-click="confirm_delete_taxon"
            class="taxon-delete-confirm"
            id="confirm-delete-taxon-btn"
          >
            Delete Taxon
          </.button>
        </div>
      </div>
    </div>
    """
  end

  # -- Helpers --

  defp in_use?(%{species: species, children: children}), do: species + children > 0
  defp in_use?(_usage), do: false

  defp usage_text(%{species: species, children: children}) do
    [
      species > 0 && "#{species} species",
      children > 0 && "#{children} child #{if children == 1, do: "taxon", else: "taxa"}"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" and ")
  end

  defp level_label(nil), do: nil
  defp level_label(level), do: String.capitalize(level)

  defp current_name(nil), do: "Quercus"
  defp current_name(taxon), do: taxon.name

  defp level_plural("subgenus"), do: "Subgenera"
  defp level_plural("section"), do: "Sections"
  defp level_plural("subsection"), do: "Subsections"
  defp level_plural("complex"), do: "Complexes"
  defp level_plural(_), do: "Taxa"

  defp children_heading(child_taxa) do
    child_taxa
    |> Enum.map(& &1.level)
    |> Enum.uniq()
    |> Enum.map_join(" & ", &level_plural/1)
  end

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
