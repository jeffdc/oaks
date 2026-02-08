defmodule OaksWeb.SpeciesDetailLive do
  @moduledoc """
  LiveView for displaying detailed information about a single species.

  Shows species taxonomy, relationships (hybrids, related species, synonyms),
  and per-source descriptive data with tab-based source selection.
  Handles synonym redirects and 404 for unknown species.
  """

  use OaksWeb, :live_view

  alias Oaks.Markdown
  alias Oaks.Sources
  alias Oaks.Species

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Species",
       species: nil,
       not_found: false,
       hybrids: [],
       closely_related: [],
       subspecies_varieties: [],
       synonyms: [],
       external_links: [],
       computed_external_links: [],
       species_sources: [],
       selected_source: nil,
       show_delete_confirm: false,
       show_delete_source_confirm: false,
       delete_source_target: nil,
       show_merge_picker: false,
       merge_search_query: "",
       merge_search_results: []
     )}
  end

  @impl true
  def handle_params(%{"name" => name}, _uri, socket) do
    case Species.get_species_full(name) do
      nil ->
        handle_not_found(socket, name)

      species ->
        load_species(socket, species)
    end
  end

  @impl true
  def handle_event("select_source", %{"id" => id_str}, socket) do
    source_id = String.to_integer(id_str)

    selected =
      Enum.find(socket.assigns.species_sources, fn ss ->
        ss.source.id == source_id
      end)

    {:noreply, assign(socket, selected_source: selected)}
  end

  def handle_event("request_delete", _params, socket) do
    if socket.assigns[:authenticated] do
      {:noreply, assign(socket, show_delete_confirm: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, show_delete_confirm: false)}
  end

  def handle_event("confirm_delete", _params, socket) do
    if socket.assigns[:authenticated] do
      species = socket.assigns.species

      case Species.delete_species(species) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Species deleted.")
           |> push_navigate(to: ~p"/list")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> assign(show_delete_confirm: false)
           |> put_flash(:error, "Failed to delete species.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("show_merge_picker", _params, socket) do
    {:noreply,
     assign(socket, show_merge_picker: true, merge_search_query: "", merge_search_results: [])}
  end

  def handle_event("close_merge_picker", _params, socket) do
    {:noreply, assign(socket, show_merge_picker: false)}
  end

  def handle_event("merge_search", %{"query" => query}, socket) do
    results =
      if String.length(String.trim(query)) >= 2 do
        Species.search_species(query, 20)
        |> Enum.reject(&(&1.scientific_name == socket.assigns.species.scientific_name))
      else
        []
      end

    {:noreply, assign(socket, merge_search_query: query, merge_search_results: results)}
  end

  def handle_event("select_merge_target", %{"name" => target_name}, socket) do
    source_name = socket.assigns.species.scientific_name

    {:noreply,
     socket
     |> assign(show_merge_picker: false)
     |> push_navigate(to: ~p"/species/#{source_name}/merge/#{target_name}")}
  end

  def handle_event("request_delete_source", %{"id" => id_str}, socket) do
    if socket.assigns[:authenticated] do
      source_id = String.to_integer(id_str)

      target =
        Enum.find(socket.assigns.species_sources, fn ss -> ss.id == source_id end)

      {:noreply, assign(socket, show_delete_source_confirm: true, delete_source_target: target)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_delete_source", _params, socket) do
    {:noreply, assign(socket, show_delete_source_confirm: false, delete_source_target: nil)}
  end

  def handle_event("confirm_delete_source", _params, socket) do
    if socket.assigns[:authenticated] do
      target = socket.assigns.delete_source_target

      case Sources.delete_species_source(target) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Source data deleted.")
           |> push_navigate(to: ~p"/species/#{socket.assigns.species.scientific_name}")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> assign(show_delete_source_confirm: false, delete_source_target: nil)
           |> put_flash(:error, "Failed to delete source data.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="species-detail">
      <.not_found_view :if={@not_found} />

      <div :if={@species}>
        <.species_header species={@species} authenticated={@authenticated} />

        <div class="content-grid">
          <.parent_species_section
            :if={@species.is_hybrid && (@species.parent1 || @species.parent2)}
            species={@species}
          />
          <.hybrids_section
            :if={@hybrids != []}
            hybrids={@hybrids}
            species_name={@species.scientific_name}
          />
          <.related_section :if={@closely_related != []} related={@closely_related} />
          <.subspecies_section
            :if={@subspecies_varieties != []}
            items={@subspecies_varieties}
          />
          <.synonyms_section :if={@synonyms != []} synonyms={@synonyms} />

          <section class="card card-sm source-container full-width">
            <.source_tabs
              :if={@species_sources != []}
              sources={@species_sources}
              selected={@selected_source}
              species_name={@species.scientific_name}
              authenticated={@authenticated}
            />
            <.source_content
              :if={@selected_source}
              source={@selected_source}
              authenticated={@authenticated}
              species_name={@species.scientific_name}
            />
            <div
              :if={@species_sources == []}
              class="p-8 text-center"
              style="color: var(--color-text-tertiary);"
            >
              <.icon name="hero-document-text" class="size-12 mx-auto mb-3 opacity-40" />
              <p class="italic">No source data available for this species.</p>
            </div>
          </section>

          <.external_links_section
            :if={@computed_external_links != []}
            links={@computed_external_links}
          />
        </div>
      </div>

      <.delete_confirm_modal
        :if={@show_delete_confirm}
        species={@species}
        source_count={length(@species_sources)}
      />

      <.merge_picker_dialog
        :if={@show_merge_picker}
        species={@species}
        query={@merge_search_query}
        results={@merge_search_results}
      />

      <.delete_source_confirm_modal
        :if={@show_delete_source_confirm && @delete_source_target}
        species={@species}
        target={@delete_source_target}
      />
    </div>
    """
  end

  # -- Page sections --

  defp not_found_view(assigns) do
    ~H"""
    <div class="text-center py-16">
      <.icon name="hero-exclamation-circle" class="size-16 mx-auto mb-4 text-base-content/30" />
      <h1 class="text-2xl font-bold mb-2">Species Not Found</h1>
      <p class="mb-6" style="color: var(--color-text-secondary);">
        The species you're looking for doesn't exist in our database.
      </p>
      <.link
        navigate={~p"/list"}
        class="inline-flex items-center gap-2 px-4 py-2 rounded-lg text-white"
        style="background-color: var(--color-forest-600); text-decoration: none;"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to Species List
      </.link>
    </div>
    """
  end

  # -- Species header (green gradient card, compact V1 layout) --

  attr :species, :any, required: true
  attr :authenticated, :boolean, default: false

  defp species_header(assigns) do
    ~H"""
    <header style="background: linear-gradient(135deg, var(--color-forest-50) 0%, var(--color-forest-100) 100%); border: 1px solid var(--color-forest-200); border-radius: 0.75rem; padding: 1rem 1.5rem; margin-bottom: 1.5rem;">
      <div class="species-current">
        <div class="species-current-left">
          <span class="badge badge-uppercase badge-forest">
            {if(@species.is_hybrid, do: "Hybrid", else: "Species")}
          </span>
          <h1 class="species-title">
            <em>
              Quercus{" "}
              <span :if={@species.is_hybrid} style="font-style: normal;">&times;</span>
              {display_name(@species.scientific_name)}
            </em>
            <span :if={@species.author} class="author-text">{@species.author}</span>
          </h1>
        </div>
        <.conservation_badge
          :if={@species.conservation_status}
          status={@species.conservation_status}
        />
        <div :if={@authenticated} class="species-actions">
          <.link
            navigate={~p"/species/#{@species.scientific_name}/edit"}
            class="action-btn action-btn-edit"
            style="text-decoration: none;"
            id="edit-species-btn"
          >
            <.icon name="hero-pencil-square" class="size-4" />
            <span>Edit</span>
          </.link>
          <button
            phx-click="show_merge_picker"
            class="action-btn action-btn-synonym"
            id="merge-species-btn"
          >
            <.icon name="hero-arrows-right-left" class="size-4" />
            <span>Make Synonym Of...</span>
          </button>
          <button
            phx-click="request_delete"
            class="action-btn action-btn-delete"
            id="delete-species-btn"
          >
            <.icon name="hero-trash" class="size-4" />
            <span>Delete</span>
          </button>
        </div>
      </div>
      <.taxonomy_breadcrumb species={@species} />
    </header>
    """
  end

  # -- Taxonomy breadcrumb --

  attr :species, :any, required: true

  defp taxonomy_breadcrumb(assigns) do
    ~H"""
    <nav
      :if={@species.subgenus || @species.section || @species.subsection || @species.complex}
      class="taxonomy-nav mt-1"
    >
      <span class="taxonomy-label">Taxonomy:</span>
      <.link navigate={~p"/taxonomy"} class="taxonomy-link">
        <span class="taxonomy-name">Quercus</span>
        <span class="taxonomy-level-label">(genus)</span>
      </.link>
      <span :if={@species.subgenus}>
        <span class="taxonomy-separator">&rsaquo;</span>
        <.link navigate={~p"/taxonomy/#{@species.subgenus}"} class="taxonomy-link">
          <span class="taxonomy-name">{@species.subgenus}</span>
          <span class="taxonomy-level-label">(subgenus)</span>
        </.link>
      </span>
      <span :if={@species.section}>
        <span class="taxonomy-separator">&rsaquo;</span>
        <.link
          navigate={~p"/taxonomy/#{@species.subgenus || "unknown"}/#{@species.section}"}
          class="taxonomy-link"
        >
          <span class="taxonomy-name">{@species.section}</span>
          <span class="taxonomy-level-label">(section)</span>
        </.link>
      </span>
      <span :if={@species.subsection}>
        <span class="taxonomy-separator">&rsaquo;</span>
        <.link
          navigate={
            ~p"/taxonomy/#{@species.subgenus || "unknown"}/#{@species.section || "unknown"}/#{@species.subsection}"
          }
          class="taxonomy-link"
        >
          <span class="taxonomy-name">{@species.subsection}</span>
          <span class="taxonomy-level-label">(subsection)</span>
        </.link>
      </span>
      <span :if={@species.complex}>
        <span class="taxonomy-separator">&rsaquo;</span>
        <span class="taxonomy-link">
          <span class="taxonomy-name">{@species.complex}</span>
          <span class="taxonomy-level-label">(complex)</span>
        </span>
      </span>
    </nav>
    """
  end

  # -- Conservation status badge --

  attr :status, :string, required: true

  defp conservation_badge(assigns) do
    colors = conservation_colors(assigns.status)
    border_style = if colors[:border], do: "border: 1px solid #{colors.border};", else: ""
    assigns = assign(assigns, colors: colors, border_style: border_style)

    ~H"""
    <span
      class="conservation-badge badge-uppercase"
      title={conservation_label(@status)}
      style={"background-color: #{@colors.bg}; color: #{@colors.text}; #{@border_style}"}
    >
      {@status}
    </span>
    """
  end

  # -- Relationship sections --

  attr :species, :any, required: true

  defp parent_species_section(assigns) do
    ~H"""
    <section class="card card-sm detail-section full-width">
      <h2 class="section-title section-title-sm mb-3">
        <.icon name="hero-arrow-path" class="size-4 inline-block" /> Parent Species
      </h2>
      <ul class="space-y-1">
        <li :if={@species.parent1}>
          <.link
            navigate={~p"/species/#{@species.parent1}"}
            class="flex items-center gap-2 p-2 rounded hover:bg-base-200 transition-colors"
          >
            <.icon name="hero-link" class="size-4 text-forest-600" />
            <span class="species-name font-medium">Quercus {@species.parent1}</span>
          </.link>
        </li>
        <li :if={@species.parent2}>
          <.link
            navigate={~p"/species/#{@species.parent2}"}
            class="flex items-center gap-2 p-2 rounded hover:bg-base-200 transition-colors"
          >
            <.icon name="hero-link" class="size-4 text-forest-600" />
            <span class="species-name font-medium">Quercus {@species.parent2}</span>
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  attr :hybrids, :list, required: true
  attr :species_name, :string, required: true

  defp hybrids_section(assigns) do
    ~H"""
    <section class="card card-sm detail-section full-width">
      <h2 class="section-title section-title-sm mb-3">
        <.icon name="hero-link" class="size-4 inline-block" /> Known Hybrids ({length(@hybrids)})
      </h2>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div :for={hybrid <- @hybrids} class="hybrid-item">
          <.link
            navigate={~p"/species/#{hybrid.name}"}
            class="species-link font-semibold"
          >
            Q. {format_hybrid_display(hybrid.name)}
          </.link>
          <span
            :if={other = get_other_parent(hybrid, @species_name)}
            class="text-sm"
            style="color: var(--color-text-secondary);"
          >
            (with <.link
              navigate={~p"/species/#{other}"}
              class="species-link"
            >Q. {other}</.link>)
          </span>
        </div>
      </div>
    </section>
    """
  end

  attr :related, :list, required: true

  defp related_section(assigns) do
    ~H"""
    <section class="card card-sm detail-section full-width">
      <h2 class="section-title section-title-sm mb-3">
        <.icon name="hero-puzzle-piece" class="size-4 inline-block" /> Closely Related
      </h2>
      <ul class="space-y-1">
        <li :for={name <- @related}>
          <.link
            navigate={~p"/species/#{name}"}
            class="flex items-center gap-2 p-2 rounded hover:bg-base-200 transition-colors"
          >
            <.icon name="hero-link" class="size-4 text-forest-600" />
            <span class="species-name font-medium">Quercus {name}</span>
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  attr :items, :list, required: true

  defp subspecies_section(assigns) do
    ~H"""
    <section class="card card-sm detail-section full-width">
      <h2 class="section-title section-title-sm mb-3">
        <.icon name="hero-rectangle-stack" class="size-4 inline-block" /> Subspecies &amp; Varieties
      </h2>
      <ul class="space-y-1">
        <li :for={item <- @items} class="p-2">
          <span class="species-name" style="color: var(--color-text-secondary);">{item}</span>
        </li>
      </ul>
    </section>
    """
  end

  attr :synonyms, :list, required: true

  defp synonyms_section(assigns) do
    ~H"""
    <section class="card card-sm detail-section full-width">
      <h2 class="section-title section-title-sm mb-3">
        <.icon name="hero-chat-bubble-bottom-center-text" class="size-4 inline-block" />
        Synonyms ({length(@synonyms)})
      </h2>
      <div class="flex flex-wrap gap-2">
        <span :for={syn <- @synonyms} class="pill-tag" style="font-style: italic;">
          {format_synonym(syn)}
        </span>
      </div>
    </section>
    """
  end

  # -- Source tabs and content --

  attr :sources, :list, required: true
  attr :selected, :any, required: true
  attr :species_name, :string, required: true
  attr :authenticated, :boolean, default: false

  defp source_tabs(assigns) do
    ~H"""
    <div class="source-tabs-strip" role="tablist">
      <button
        :for={ss <- @sources}
        phx-click="select_source"
        phx-value-id={ss.source.id}
        class={["source-tab", selected_tab?(ss, @selected) && "active"]}
        role="tab"
        aria-selected={to_string(selected_tab?(ss, @selected))}
      >
        <span class="source-tab-name">{ss.source.name}</span>
        <span :if={ss.is_preferred} class="preferred-star" title="Preferred source">&#9733;</span>
        <.link
          navigate={~p"/sources/#{ss.source.id}"}
          class="source-tab-link"
          title="View source details"
          tabindex="0"
        >
          <.icon name="hero-information-circle" class="size-3.5" />
        </.link>
      </button>
      <.link
        :if={length(@sources) > 1}
        navigate={~p"/species/#{@species_name}/compare"}
        class="compare-sources-link"
        title="Compare all sources side-by-side"
      >
        <.icon name="hero-arrows-right-left" class="size-4" />
        <span>Compare</span>
      </.link>
      <div :if={@authenticated} class="add-source-wrapper">
        <.link
          navigate={~p"/species/#{@species_name}/sources/new"}
          class="add-source-btn"
          style="text-decoration: none;"
          title="Add data from another source"
        >
          <.icon name="hero-plus" class="size-3.5" />
          <span>Add Source</span>
        </.link>
      </div>
    </div>
    """
  end

  attr :source, :any, required: true
  attr :authenticated, :boolean, default: false
  attr :species_name, :string, required: true

  defp source_content(assigns) do
    local_names = Species.parse_json_array(assigns.source.local_names)
    assigns = assign(assigns, :local_names, local_names)

    ~H"""
    <div class="source-content">
      <div class="source-content-header">
        <span class="source-content-title">
          Data from {@source.source.name}
        </span>
        <div :if={@authenticated} class="flex items-center gap-2">
          <.link
            navigate={~p"/species/#{@species_name}/sources/#{@source.source.id}/edit"}
            class="action-btn action-btn-edit"
            style="text-decoration: none;"
          >
            <.icon name="hero-pencil-square" class="size-3.5" /> Edit
          </.link>
          <button
            phx-click="request_delete_source"
            phx-value-id={@source.id}
            class="action-btn action-btn-delete"
          >
            <.icon name="hero-trash" class="size-3.5" /> Delete
          </button>
        </div>
      </div>

      <.source_field label="Geographic Range" value={@source.range} icon="hero-map-pin" />
      <.source_field label="Growth Habit" value={@source.growth_habit} icon="hero-building-office-2" />
      <.source_field label="Leaves" value={@source.leaves} icon="leaf" />
      <.source_field label="Flowers" value={@source.flowers} icon="flower" />
      <.source_field label="Fruits" value={@source.fruits} icon="acorn" />
      <.source_field label="Bark" value={@source.bark} icon="hero-sparkles" />
      <.source_field label="Twigs" value={@source.twigs} icon="hero-sparkles" />
      <.source_field label="Buds" value={@source.buds} icon="hero-sparkles" />

      <section :if={@local_names != []} class="source-field">
        <h4
          class="flex items-center gap-1.5 text-sm font-semibold mb-2"
          style="color: var(--color-forest-700);"
        >
          <span style="color: var(--color-forest-500);">
            <.icon name="hero-language" class="size-4 flex-shrink-0" />
          </span>
          Common Names
        </h4>
        <div class="flex flex-wrap gap-2">
          <span :for={name <- @local_names} class="pill-tag">
            {name}
          </span>
        </div>
      </section>

      <.source_field
        label="Hardiness & Habitat"
        value={@source.hardiness_habitat}
        icon="hero-globe-americas"
      />
      <.source_field
        label="Additional Information"
        value={@source.miscellaneous}
        icon="hero-information-circle"
      />

      <div
        :if={@source.url}
        class="mt-4 pt-4"
        style="border-top: 1px solid var(--color-border-light);"
      >
        <a
          href={@source.url}
          target="_blank"
          rel="noopener noreferrer"
          class="text-sm inline-flex items-center gap-1"
          style="color: var(--color-forest-700);"
        >
          View original source <.icon name="hero-arrow-top-right-on-square" class="size-3.5" />
        </a>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, default: nil
  attr :icon, :string, default: nil

  defp source_field(assigns) do
    ~H"""
    <section :if={@value && @value != ""} class="source-field">
      <h4
        class="flex items-center gap-1.5 text-sm font-semibold mb-1"
        style="color: var(--color-forest-700);"
      >
        <.field_icon :if={@icon} name={@icon} />
        {@label}
      </h4>
      <div class="prose-content">{raw(Markdown.render_html(@value))}</div>
    </section>
    """
  end

  attr :name, :string, required: true

  defp field_icon(%{name: "leaf"} = assigns) do
    ~H"""
    <svg
      class="size-4 flex-shrink-0"
      style="color: var(--color-forest-500);"
      fill="currentColor"
      viewBox="0 0 24 24"
    >
      <path d="M17,8C8,10 5.9,16.17 3.82,21.34L5.71,22L6.66,19.7C7.14,19.87 7.64,20 8,20C19,20 22,3 22,3C21,5 14,5.25 9,6.25C4,7.25 2,11.5 2,13.5C2,15.5 3.75,17.25 3.75,17.25C7,8 17,8 17,8Z" />
    </svg>
    """
  end

  defp field_icon(%{name: "flower"} = assigns) do
    ~H"""
    <svg
      class="size-4 flex-shrink-0"
      style="color: var(--color-forest-500);"
      fill="currentColor"
      viewBox="0 0 24 24"
    >
      <path d="M12,22A10,10 0 0,1 2,12A10,10 0 0,1 12,2A10,10 0 0,1 22,12A10,10 0 0,1 12,22M12,4A8,8 0 0,0 4,12A8,8 0 0,0 12,20A8,8 0 0,0 20,12A8,8 0 0,0 12,4M15,10.59V9L12.5,6.5L10,9V10.59L11.29,11.88L10.59,14.59L12,14L13.41,14.59L12.71,11.88L15,10.59Z" />
    </svg>
    """
  end

  defp field_icon(%{name: "acorn"} = assigns) do
    ~H"""
    <svg
      class="size-4 flex-shrink-0"
      style="color: var(--color-forest-500);"
      fill="currentColor"
      viewBox="0 0 24 24"
    >
      <path d="M12,2C12.5,2 13,2.19 13.41,2.59C13.8,3 14,3.5 14,4C14,4.5 13.8,5 13.41,5.41C13,5.8 12.5,6 12,6C11.5,6 11,5.8 10.59,5.41C10.2,5 10,4.5 10,4C10,3.5 10.2,3 10.59,2.59C11,2.19 11.5,2 12,2M12,6C13.1,6 14,6.9 14,8V9.5C15.72,9.5 17.17,10.6 17.71,12.13C18.14,13.38 18.13,14.77 17.66,16C17.19,17.26 16.32,18.23 15.19,18.74C14.06,19.25 12.78,19.25 11.65,18.74C10.5,18.23 9.63,17.26 9.16,16C8.69,14.77 8.68,13.38 9.11,12.13C9.65,10.6 11.1,9.5 12.83,9.5H12V8C12,6.9 12.9,6 12,6M12.13,11.5C11.41,11.5 10.81,11.89 10.54,12.5C10.27,13.11 10.39,13.82 10.85,14.3C11.31,14.78 12,14.94 12.63,14.7C13.26,14.46 13.7,13.86 13.7,13.17C13.7,12.64 13.5,12.13 13.13,11.76C12.76,11.39 12.26,11.5 12.13,11.5Z" />
    </svg>
    """
  end

  defp field_icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span style="color: var(--color-forest-500);">
      <.icon name={@name} class="size-4 flex-shrink-0" />
    </span>
    """
  end

  # -- External links --

  attr :links, :list, required: true

  defp external_links_section(assigns) do
    ~H"""
    <section class="card card-sm detail-section full-width">
      <h2 class="section-title section-title-sm mb-3">
        <.icon name="hero-arrow-top-right-on-square" class="size-4 inline-block" /> External Links
      </h2>
      <div class="flex flex-wrap gap-3">
        <a
          :for={link <- @links}
          href={link.url}
          target="_blank"
          rel="noopener noreferrer"
          class="external-link-btn"
        >
          <%= if link.name == "iNaturalist" do %>
            <.ext_link_icon name={link.name} logo={link[:logo]} />
          <% else %>
            <.ext_link_icon name={link.name} logo={link[:logo]} />
            {link.name}
          <% end %>
        </a>
      </div>
    </section>
    """
  end

  attr :name, :string, required: true
  attr :logo, :string, default: nil

  defp ext_link_icon(assigns) do
    logo = assigns.logo || infer_logo(assigns.name)

    # iNaturalist uses the full logo (larger), others use small icons
    {icon_file, icon_class} =
      if logo == "inaturalist",
        do: {"inaturalist-logo.svg", "h-5"},
        else: {"#{logo || "generic"}.svg", "size-4 flex-shrink-0"}

    assigns = assigns |> assign(:icon_file, icon_file) |> assign(:icon_class, icon_class)

    ~H"""
    <img src={~p"/images/#{@icon_file}"} alt="" class={@icon_class} />
    """
  end

  defp infer_logo(name) do
    name_lower = String.downcase(name)

    cond do
      String.contains?(name_lower, "flora of north america") -> "fna"
      String.contains?(name_lower, "fire effects") -> "feis"
      String.contains?(name_lower, "usda") -> "usda"
      String.contains?(name_lower, "gbif") -> "gbif"
      String.contains?(name_lower, "powo") -> "powo"
      String.contains?(name_lower, "wikipedia") -> "wikipedia"
      String.contains?(name_lower, "inaturalist") -> "inaturalist"
      true -> nil
    end
  end

  # -- Delete confirmation modal --

  attr :species, :any, required: true
  attr :source_count, :integer, default: 0

  defp delete_confirm_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 flex items-center justify-center"
      id="delete-confirm-modal"
      phx-window-keydown="cancel_delete"
      phx-key="Escape"
    >
      <div class="fixed inset-0 bg-black/50" phx-click="cancel_delete" />
      <div class="relative bg-white rounded-xl shadow-xl max-w-md w-full mx-4 p-6">
        <h3 class="text-lg font-bold text-red-800 mb-2">Delete Species</h3>
        <p class="mb-2" style="color: var(--color-text-secondary);">
          Are you sure you want to delete <strong class="species-name">
            Quercus {display_name(@species.scientific_name)}
          </strong>?
        </p>
        <p :if={@source_count > 0} class="text-sm text-red-600 mb-4">
          This will also remove data from {@source_count} source(s).
        </p>
        <p :if={@source_count == 0} class="text-sm mb-4" style="color: var(--color-text-tertiary);">
          This action cannot be undone.
        </p>
        <div class="flex justify-end gap-3">
          <button
            phx-click="cancel_delete"
            class="px-4 py-2 rounded-lg text-sm font-medium"
            style="color: var(--color-text-secondary);"
          >
            Cancel
          </button>
          <button
            phx-click="confirm_delete"
            class="px-4 py-2 rounded-lg text-sm font-medium text-white bg-red-600 hover:bg-red-700 transition-colors"
            id="confirm-delete-btn"
          >
            Delete Species
          </button>
        </div>
      </div>
    </div>
    """
  end

  # -- Delete source confirmation modal --

  attr :species, :any, required: true
  attr :target, :any, required: true

  defp delete_source_confirm_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 flex items-center justify-center"
      id="delete-source-confirm-modal"
      phx-window-keydown="cancel_delete_source"
      phx-key="Escape"
    >
      <div class="fixed inset-0 bg-black/50" phx-click="cancel_delete_source" />
      <div class="relative bg-white rounded-xl shadow-xl max-w-md w-full mx-4 p-6">
        <h3 class="text-lg font-bold text-red-800 mb-2">Delete Source Data</h3>
        <p class="mb-4" style="color: var(--color-text-secondary);">
          Are you sure you want to remove <strong>{@target.source.name}</strong>
          data from <strong class="species-name">
            Quercus {display_name(@species.scientific_name)}
          </strong>?
        </p>
        <p class="text-sm mb-4" style="color: var(--color-text-tertiary);">
          This action cannot be undone.
        </p>
        <div class="flex justify-end gap-3">
          <button
            phx-click="cancel_delete_source"
            class="px-4 py-2 rounded-lg text-sm font-medium"
            style="color: var(--color-text-secondary);"
          >
            Cancel
          </button>
          <button
            phx-click="confirm_delete_source"
            class="px-4 py-2 rounded-lg text-sm font-medium text-white bg-red-600 hover:bg-red-700 transition-colors"
            id="confirm-delete-source-btn"
          >
            Delete Source Data
          </button>
        </div>
      </div>
    </div>
    """
  end

  # -- Merge picker dialog --

  attr :species, :any, required: true
  attr :query, :string, required: true
  attr :results, :list, required: true

  defp merge_picker_dialog(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 flex items-center justify-center p-4"
      style="background-color: rgba(0, 0, 0, 0.5);"
      phx-window-keydown="close_merge_picker"
      phx-key="Escape"
      id="merge-picker-dialog"
    >
      <div class="card max-w-lg w-full max-h-[80vh] flex flex-col overflow-hidden">
        <div
          class="flex items-center justify-between p-4 border-b"
          style="background-color: var(--color-forest-50); border-color: var(--color-border);"
        >
          <h2
            class="text-lg font-semibold"
            style="font-family: var(--font-serif); color: var(--color-forest-800);"
          >
            Select Target Species
          </h2>
          <button
            phx-click="close_merge_picker"
            class="p-1.5 rounded-lg hover:bg-white/50 transition-colors"
            style="color: var(--color-text-secondary);"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>

        <p
          class="px-4 py-3 text-sm border-b"
          style="color: var(--color-text-secondary); border-color: var(--color-border);"
        >
          Select the species that
          <span class="species-name" style="color: var(--color-forest-700);">
            Quercus {@species.scientific_name}
          </span>
          will become a synonym of.
        </p>

        <div class="p-4">
          <form phx-change="merge_search">
            <input
              type="text"
              name="query"
              value={@query}
              placeholder="Search for a species..."
              autofocus
              phx-debounce="300"
              class="w-full px-3 py-2 rounded-lg text-sm"
              style="border: 1px solid var(--color-border); background-color: var(--color-surface);"
            />
          </form>
        </div>

        <div class="flex-1 overflow-y-auto px-4 pb-4 min-h-[200px] max-h-[300px]">
          <p
            :if={String.length(String.trim(@query)) < 2}
            class="text-center py-8 text-sm"
            style="color: var(--color-text-secondary);"
          >
            Type at least 2 characters to search
          </p>

          <p
            :if={String.length(String.trim(@query)) >= 2 && @results == []}
            class="text-center py-8 text-sm"
            style="color: var(--color-text-secondary);"
          >
            No species found matching "{@query}"
          </p>

          <ul :if={@results != []} class="space-y-2">
            <li :for={species <- @results}>
              <button
                phx-click="select_merge_target"
                phx-value-name={species.scientific_name}
                class="w-full text-left p-3 rounded-lg transition-colors"
                style="background-color: var(--color-background); border: 1px solid var(--color-border);"
                onmouseover="this.style.backgroundColor='var(--color-forest-50)';this.style.borderColor='var(--color-forest-300)'"
                onmouseout="this.style.backgroundColor='var(--color-background)';this.style.borderColor='var(--color-border)'"
              >
                <div class="flex items-baseline gap-2">
                  <span class="species-name font-semibold" style="color: var(--color-forest-800);">
                    <span
                      :if={species.is_hybrid}
                      style="font-style: normal; color: var(--color-forest-600);"
                    >
                      &times;
                    </span>
                    {species.scientific_name}
                  </span>
                  <span
                    :if={species.author}
                    class="text-xs"
                    style="color: var(--color-text-secondary); font-style: normal;"
                  >
                    {species.author}
                  </span>
                </div>
                <div :if={species.section} class="mt-1">
                  <span
                    class="text-xs px-2 py-0.5 rounded-full"
                    style="background-color: var(--color-forest-100); color: var(--color-forest-700);"
                  >
                    sect. {species.section}
                  </span>
                </div>
              </button>
            </li>
          </ul>
        </div>

        <div
          class="flex justify-end p-4 border-t"
          style="border-color: var(--color-border); background-color: var(--color-background);"
        >
          <button
            phx-click="close_merge_picker"
            class="px-4 py-2 rounded-lg text-sm font-medium"
            style="color: var(--color-text-primary); border: 1px solid var(--color-border);"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
    """
  end

  # -- Data loading --

  defp load_species(socket, species) do
    hybrids =
      species.hybrids
      |> Species.parse_json_array()
      |> Species.get_hybrids_with_parents()

    closely_related = Species.parse_json_array(species.closely_related_to)
    subspecies_varieties = Species.parse_json_array(species.subspecies_varieties)
    synonyms = Species.parse_json_array(species.synonyms)
    external_links = Species.parse_json_array(species.external_links)
    computed_external_links = build_external_links(species.scientific_name, external_links)
    species_sources = species.species_sources
    selected_source = List.first(species_sources)

    {:noreply,
     assign(socket,
       species: species,
       hybrids: hybrids,
       closely_related: closely_related,
       subspecies_varieties: subspecies_varieties,
       synonyms: synonyms,
       external_links: external_links,
       computed_external_links: computed_external_links,
       species_sources: species_sources,
       selected_source: selected_source,
       not_found: false,
       page_title: "Quercus #{display_name(species.scientific_name)}"
     )}
  end

  defp handle_not_found(socket, name) do
    case Species.find_synonym(name) do
      nil ->
        {:noreply,
         assign(socket,
           species: nil,
           not_found: true,
           page_title: "Species Not Found"
         )}

      canonical ->
        {:noreply, push_navigate(socket, to: ~p"/species/#{canonical.scientific_name}")}
    end
  end

  # -- Helpers --

  defp display_name("\u00D7" <> rest), do: rest
  defp display_name(name), do: name

  defp get_other_parent(%{parent1: p1, parent2: p2}, current_name) do
    clean = fn name ->
      (name || "")
      |> String.replace(~r/^Quercus\s+/, "")
      |> String.replace(~r/^×\s*/, "")
      |> String.trim()
    end

    current = current_name |> clean.() |> String.downcase()
    c1 = if p1, do: clean.(p1), else: nil
    c2 = if p2, do: clean.(p2), else: nil

    cond do
      c1 && String.downcase(c1) != current -> c1
      c2 && String.downcase(c2) != current -> c2
      true -> nil
    end
  end

  defp build_external_links(species_name, db_links) do
    custom =
      Enum.flat_map(db_links, fn
        %{"name" => name, "url" => url, "logo" => logo} -> [%{name: name, url: url, logo: logo}]
        %{"name" => name, "url" => url} -> [%{name: name, url: url, logo: nil}]
        _ -> []
      end)

    auto = [
      %{
        name: "iNaturalist",
        url: "https://www.inaturalist.org/search?q=#{URI.encode("Quercus #{species_name}")}",
        logo: "inaturalist"
      },
      %{
        name: "Wikipedia",
        url: "https://en.wikipedia.org/wiki/Quercus_#{String.replace(species_name, " ", "_")}",
        logo: "wikipedia"
      }
    ]

    # Sort all links alphabetically by name (case-insensitive, matching V1 localeCompare)
    (custom ++ auto) |> Enum.sort_by(&String.downcase(&1.name))
  end

  defp format_hybrid_display(name) do
    if String.starts_with?(name, "\u00D7"),
      do: name,
      else: "\u00D7 #{name}"
  end

  defp format_synonym(syn) when is_binary(syn), do: syn

  defp format_synonym(%{"name" => name, "author" => author}) when author != "" do
    "#{name} #{author}"
  end

  defp format_synonym(%{"name" => name}), do: name
  defp format_synonym(other), do: inspect(other)

  defp selected_tab?(source, selected) do
    selected && source.id == selected.id
  end

  defp conservation_colors("EX"), do: %{bg: "#000000", text: "#FFFFFF"}
  defp conservation_colors("EW"), do: %{bg: "#542344", text: "#FFFFFF"}
  defp conservation_colors("CR"), do: %{bg: "#D81E05", text: "#FFFFFF"}
  defp conservation_colors("EN"), do: %{bg: "#FC7F3F", text: "#000000"}
  defp conservation_colors("VU"), do: %{bg: "#F9E814", text: "#000000"}
  defp conservation_colors("NT"), do: %{bg: "#CCE226", text: "#000000"}
  defp conservation_colors("LC"), do: %{bg: "#60C659", text: "#000000"}
  defp conservation_colors("DD"), do: %{bg: "#D1D1C6", text: "#000000"}
  defp conservation_colors("NE"), do: %{bg: "#FFFFFF", text: "#000000", border: "#D1D1C6"}
  defp conservation_colors(_), do: %{bg: "#D1D1C6", text: "#000000"}

  defp conservation_label("LC"), do: "Least Concern"
  defp conservation_label("NT"), do: "Near Threatened"
  defp conservation_label("VU"), do: "Vulnerable"
  defp conservation_label("EN"), do: "Endangered"
  defp conservation_label("CR"), do: "Critically Endangered"
  defp conservation_label("EW"), do: "Extinct in the Wild"
  defp conservation_label("EX"), do: "Extinct"
  defp conservation_label("DD"), do: "Data Deficient"
  defp conservation_label("NE"), do: "Not Evaluated"
  defp conservation_label(_), do: "Unknown"
end
