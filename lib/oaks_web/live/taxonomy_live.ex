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
           put_flash(socket, :error, "Can't delete: #{usage_text(usage)} #{still_use(usage)} it.")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete taxon.")}
      end
    else
      {:noreply, socket}
    end
  end

  # -- Data loading --

  defp load_genus_level(socket) do
    genus = Taxonomy.get_genus()
    child_taxa = if genus, do: Taxonomy.get_children(genus), else: []
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
      band_current: %{level: "genus", name: genus.name, hybrid: false},
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
            <.edit_menu id="taxon-edit-menu">
              <:item navigate={create_taxon_path(@child_level, @current_taxon)} id="create-taxon-btn">
                Create taxon
              </:item>
              <:item
                :if={not @is_genus_level && @current_taxon}
                navigate={~p"/taxonomy/#{@current_taxon.id}/edit"}
                id="edit-taxon-btn"
              >
                Edit {@current_level}
              </:item>
              <:item
                :if={not @is_genus_level && @current_taxon}
                click="request_delete_taxon"
                values={%{id: @current_taxon.id}}
                id="delete-taxon-btn"
              >
                Delete {@current_level}
              </:item>
            </.edit_menu>
          </:actions>
        </.header>
      </:head>

      <div>
        <%!-- Taxon content --%>
        <section :if={@current_taxon && @current_taxon.content} class="taxon-section">
          <.section_heading>
            About this {@current_level}
            <:note :if={@current_taxon.content_updated_at}>
              Updated {@current_taxon.content_updated_at}
            </:note>
          </.section_heading>
          <div class="oc-prose">{raw(Markdown.render_html(@current_taxon.content))}</div>
        </section>

        <%!-- Child taxa --%>
        <section :if={@child_taxa != []} class="taxon-section">
          <.section_heading>{children_heading(@child_taxa)}</.section_heading>
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
          <.section_heading>
            {species_section_title(@is_genus_level, length(@species))}
          </.section_heading>
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
      <.edit_menu
        :if={@editor}
        id={"taxon-#{@taxon.id}-menu"}
        quiet
        aria_label={"Edit #{SpeciesName.taxon_label(@taxon.level, @taxon.name)}"}
      >
        <:item navigate={~p"/taxonomy/#{@taxon.id}/edit"}>Edit {@taxon.level}</:item>
        <:item click="request_delete_taxon" values={%{id: @taxon.id}}>
          Delete {@taxon.level}
        </:item>
      </.edit_menu>
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
    assigns = assign(assigns, :in_use, in_use?(assigns.usage))

    ~H"""
    <.modal
      id="delete-taxon-modal"
      show
      on_cancel={JS.push("cancel_delete_taxon")}
      cancel={if @in_use, do: "Close", else: "Cancel"}
    >
      <:title>
        {if @in_use, do: "Can't delete #{@taxon.level}", else: "Delete #{@taxon.level}"}
      </:title>
      <p :if={!@in_use}>
        Delete the {@taxon.level}
        <.sci_name name={@taxon.name} level={@taxon.level} weight="regular" />?
      </p>
      <p :if={@in_use} id="delete-taxon-in-use">
        {usage_text(@usage)} {still_use(@usage)} the {@taxon.level}
        <.sci_name name={@taxon.name} level={@taxon.level} weight="regular" />.
      </p>
      <:note :if={@in_use}>Move or delete them first.</:note>
      <:note :if={!@in_use}><strong>This can't be undone.</strong></:note>
      <:actions :if={!@in_use}>
        <.button variant="danger" phx-click="confirm_delete_taxon" id="confirm-delete-taxon-btn">
          Delete {@taxon.level}
        </.button>
      </:actions>
    </.modal>
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

  # "1 species still uses", "2 species still use", "1 species and 1 child taxon still use"
  defp still_use(%{species: species, children: children}) when species + children == 1,
    do: "still uses"

  defp still_use(_usage), do: "still use"

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
        Map.put(params, :parent_id, current_taxon.id)
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
