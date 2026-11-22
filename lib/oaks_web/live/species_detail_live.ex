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
  alias OaksWeb.Params
  alias OaksWeb.SpeciesName

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
       can_add_source: false,
       selected_source: nil,
       show_delete_confirm: false,
       delete_references: [],
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
    source_id = Params.int(id_str)

    case Enum.find(socket.assigns.species_sources, &(&1.source.id == source_id)) do
      nil -> {:noreply, socket}
      selected -> {:noreply, assign(socket, selected_source: selected)}
    end
  end

  def handle_event("request_delete", _params, socket) do
    if socket.assigns[:current_scope] do
      {:noreply,
       assign(socket,
         show_delete_confirm: true,
         delete_references: Species.references_to(socket.assigns.species)
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, show_delete_confirm: false)}
  end

  def handle_event("confirm_delete", _params, socket) do
    if socket.assigns[:current_scope] do
      species = socket.assigns.species

      case Species.delete_species(species) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Species deleted.")
           |> push_navigate(to: ~p"/species")}

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
    query = Params.string(query)

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
    source_id = Params.int(id_str)

    target =
      socket.assigns[:current_scope] &&
        Enum.find(socket.assigns.species_sources, &(&1.id == source_id))

    if target do
      {:noreply, assign(socket, show_delete_source_confirm: true, delete_source_target: target)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_delete_source", _params, socket) do
    {:noreply, assign(socket, show_delete_source_confirm: false, delete_source_target: nil)}
  end

  def handle_event("confirm_delete_source", _params, socket) do
    if socket.assigns[:current_scope] do
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
        <.species_header species={@species} editor={@current_scope != nil} />

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

          <section class="card card-sm source-container full-width" aria-label="Source data">
            <.source_tabs
              :if={@species_sources != []}
              sources={@species_sources}
              selected={@selected_source}
              species_name={@species.scientific_name}
              editor={@current_scope != nil}
              can_add_source={@can_add_source}
            />
            <.source_content
              :if={@selected_source}
              source={@selected_source}
              editor={@current_scope != nil}
              species_name={@species.scientific_name}
            />
            <.section_heading :if={@species_sources == []}>Source data</.section_heading>
            <div :if={@species_sources == []} class="species-no-sources">
              <p class="oc-empty">No source data available for this species.</p>
              <.button
                :if={@current_scope}
                navigate={~p"/species/#{@species.scientific_name}/sources/new"}
                size="compact"
                class="add-source-btn"
                title="Add data from a source"
                id="empty-add-source-btn"
              >
                Add source
              </.button>
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
        references={@delete_references}
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
    <div>
      <.header>
        Species not found
        <:subtitle>The species you're looking for doesn't exist in our database.</:subtitle>
      </.header>
      <.back navigate={~p"/species"}>Back to species list</.back>
    </div>
    """
  end

  # -- Species header: the title row on a 2px rule (bridge restyle) --

  attr :species, :any, required: true
  attr :editor, :boolean, default: false

  defp species_header(assigns) do
    ~H"""
    <header class="species-header">
      <.taxonomy_breadcrumb species={@species} />
      <div class="species-current">
        <h1 class="species-title">
          <em>
            <span class="species-genus">{"Quercus "}</span><span
              :if={hybrid_sign?(@species.scientific_name, @species.is_hybrid)}
              class="sci-roman"
            >{"× "}</span>{sci_html(epithet(@species.scientific_name))}
          </em>
          <span :if={@species.author} class="author-text">{@species.author}</span>
        </h1>
        <div class="species-meta">
          <span>{if(@species.is_hybrid, do: "Hybrid", else: "Species")}</span>
          <.status_tag
            :if={@species.conservation_status}
            title={"IUCN Red List: #{conservation_label(@species.conservation_status)}"}
          >
            IUCN {@species.conservation_status}
          </.status_tag>
        </div>
        <div :if={@editor} class="species-actions">
          <.button
            navigate={~p"/species/#{@species.scientific_name}/edit"}
            size="compact"
            id="edit-species-btn"
          >
            Edit
          </.button>
          <.button
            type="button"
            phx-click="show_merge_picker"
            size="compact"
            id="merge-species-btn"
          >
            Make synonym of…
          </.button>
          <.button
            type="button"
            phx-click="request_delete"
            size="compact"
            class="species-delete-btn"
            id="delete-species-btn"
          >
            Delete
          </.button>
        </div>
      </div>
    </header>
    """
  end

  # -- Taxonomy breadcrumb --

  attr :species, :any, required: true

  defp taxonomy_breadcrumb(assigns) do
    ~H"""
    <nav
      :if={@species.subgenus || @species.section || @species.subsection || @species.complex}
      class="taxonomy-nav"
      aria-label="Taxonomy"
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
        <.link
          navigate={
            ~p"/taxonomy/#{@species.subgenus || "unknown"}/#{@species.section || "unknown"}/#{@species.subsection || "unknown"}/#{@species.complex}"
          }
          class="taxonomy-link"
        >
          <span class="taxonomy-name">{@species.complex}</span>
          <span class="taxonomy-level-label">(complex)</span>
        </.link>
      </span>
    </nav>
    """
  end

  # -- Relationship sections: names on hairlines --

  attr :species, :any, required: true

  defp parent_species_section(assigns) do
    ~H"""
    <section class="card card-sm detail-section full-width" id="species-parents">
      <.section_heading>Parent Species</.section_heading>
      <ul class="species-rows">
        <li :for={parent <- Enum.reject([@species.parent1, @species.parent2], &is_nil/1)}>
          <.link navigate={~p"/species/#{parent}"} class="species-row-link">
            <.sci name={"Quercus #{parent}"} />
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
    <section class="card card-sm detail-section full-width" id="species-hybrids">
      <.section_heading>
        Known Hybrids<:note>{length(@hybrids)} known</:note>
      </.section_heading>
      <ul class="species-rows hybrid-list">
        <li :for={hybrid <- @hybrids} class="hybrid-item">
          <.link navigate={~p"/species/#{hybrid.name}"} class="hybrid-name">
            <.sci name={"Q. #{SpeciesName.label(hybrid.name, true)}"} />
          </.link>
          <span :if={other = get_other_parent(hybrid, @species_name)} class="hybrid-with">
            with <.link navigate={~p"/species/#{other}"}><.sci name={other} /></.link>
          </span>
        </li>
      </ul>
    </section>
    """
  end

  attr :related, :list, required: true

  defp related_section(assigns) do
    ~H"""
    <section class="card card-sm detail-section full-width" id="species-related">
      <.section_heading>Closely Related</.section_heading>
      <ul class="species-rows">
        <li :for={name <- @related}>
          <.link navigate={~p"/species/#{name}"} class="species-row-link">
            <.sci name={"Quercus #{name}"} />
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  attr :items, :list, required: true

  defp subspecies_section(assigns) do
    ~H"""
    <section class="card card-sm detail-section full-width" id="species-subspecies">
      <.section_heading>Subspecies &amp; Varieties</.section_heading>
      <ul class="species-rows">
        <li :for={{name, author} <- Enum.map(@items, &name_and_authority/1)}>
          <span class="species-row-name"><.sci name={name} />{author && " " <> author}</span>
        </li>
      </ul>
    </section>
    """
  end

  attr :synonyms, :list, required: true

  defp synonyms_section(assigns) do
    ~H"""
    <section class="card card-sm detail-section full-width" id="species-synonyms">
      <.section_heading>
        Synonyms<:note>{length(@synonyms)}</:note>
      </.section_heading>
      <div class="species-synonyms flex flex-wrap gap-2">
        <span :for={{name, author} <- Enum.map(@synonyms, &name_and_authority/1)} class="pill-tag">
          <span class="species-synonym"><.sci name={name} /></span>{author && " " <> author}
        </span>
      </div>
    </section>
    """
  end

  # A scientific name in the serif: names italic, the hybrid sign and rank
  # words roman. Built as one run of HTML so no template whitespace falls
  # between the parts.
  attr :name, :string, required: true

  defp sci(assigns) do
    ~H"""
    <span class="sci">{sci_html(@name)}</span>
    """
  end

  # -- Source tabs and content --

  attr :sources, :list, required: true
  attr :selected, :any, required: true
  attr :species_name, :string, required: true
  attr :editor, :boolean, default: false
  attr :can_add_source, :boolean, default: true

  defp source_tabs(assigns) do
    ~H"""
    <div class="source-tabs-strip">
      <div class="source-tabs-list" role="tablist" aria-label="Sources">
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
            aria-label={"About #{ss.source.name}"}
            tabindex="0"
          >
            <.icon name="hero-information-circle" class="size-4" />
          </.link>
        </button>
      </div>
      <.compare_button
        :if={length(@sources) > 1}
        navigate={~p"/species/#{@species_name}/compare"}
        class="compare-sources-link"
        title="Compare all sources side-by-side"
      >
        Compare sources
      </.compare_button>
      <div :if={@editor && @can_add_source} class="add-source-wrapper">
        <.button
          navigate={~p"/species/#{@species_name}/sources/new"}
          size="compact"
          class="add-source-btn"
          title="Add data from another source"
        >
          Add source
        </.button>
      </div>
    </div>
    """
  end

  attr :source, :any, required: true
  attr :editor, :boolean, default: false
  attr :species_name, :string, required: true

  defp source_content(assigns) do
    local_names = Species.parse_name_list(assigns.source.local_names)
    assigns = assign(assigns, :local_names, local_names)

    ~H"""
    <div class="source-content">
      <div class="source-content-header">
        <h2 class="source-content-title">
          Data from {@source.source.name}
        </h2>
        <div :if={@editor} class="source-content-actions">
          <.button
            navigate={~p"/species/#{@species_name}/sources/#{@source.source.id}/edit"}
            size="compact"
          >
            Edit
          </.button>
          <.button
            type="button"
            phx-click="request_delete_source"
            phx-value-id={@source.id}
            size="compact"
          >
            Delete
          </.button>
        </div>
      </div>

      <.source_field label="Geographic Range" value={@source.range} />
      <.source_field label="Growth Habit" value={@source.growth_habit} />
      <.source_field label="Leaves" value={@source.leaves} />
      <.source_field label="Flowers" value={@source.flowers} />
      <.source_field label="Fruits" value={@source.fruits} />
      <.source_field label="Bark" value={@source.bark} />
      <.source_field label="Twigs" value={@source.twigs} />
      <.source_field label="Buds" value={@source.buds} />

      <section :if={@local_names != []} class="source-field">
        <h3 class="source-field-label">Common Names</h3>
        <div class="flex flex-wrap gap-2">
          <span :for={name <- @local_names} class="pill-tag">
            {name}
          </span>
        </div>
      </section>

      <.source_field label="Hardiness & Habitat" value={@source.hardiness_habitat} />
      <.source_field label="Additional Information" value={@source.miscellaneous} />

      <p :if={@source.url} class="source-original">
        <a href={@source.url} target="_blank" rel="noopener noreferrer" class="oc-src">
          View original source
        </a>
      </p>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, default: nil

  defp source_field(assigns) do
    ~H"""
    <section :if={@value && @value != ""} class="source-field">
      <h3 class="source-field-label">{@label}</h3>
      <div class="prose-content">{raw(Markdown.render_html(@value))}</div>
    </section>
    """
  end

  # -- External links --

  attr :links, :list, required: true

  defp external_links_section(assigns) do
    ~H"""
    <section class="card card-sm detail-section full-width" id="species-external-links">
      <.section_heading>External Links</.section_heading>
      <ul class="external-links">
        <li :for={link <- @links}>
          <a href={link.url} target="_blank" rel="noopener noreferrer" class="external-link">
            <span class="external-link-name">{link.name}</span>
            <span :if={host = link_host(link.url)} class="external-link-host">{host}</span>
          </a>
        </li>
      </ul>
    </section>
    """
  end

  # -- Delete confirmation modal --

  attr :species, :any, required: true
  attr :source_count, :integer, default: 0
  attr :references, :list, default: []

  defp delete_confirm_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 flex items-center justify-center p-s4"
      id="delete-confirm-modal"
      role="dialog"
      aria-modal="true"
      aria-labelledby="delete-confirm-title"
      phx-window-keydown="cancel_delete"
      phx-key="Escape"
    >
      <div class="oc-modal-backdrop" phx-click="cancel_delete" />
      <div class="oc-modal-panel species-dialog">
        <div class="oc-modal-head">
          <h2 id="delete-confirm-title">Delete species</h2>
        </div>
        <div class="oc-modal-body">
          <p>
            Are you sure you want to delete
            <.sci name={"Quercus #{epithet(@species.scientific_name)}"} />?
          </p>
          <p :if={@source_count > 0} class="species-dialog-warn">
            This will also remove data from {@source_count} source(s).
          </p>
          <div :if={@references != []} class="species-dialog-note" id="delete-references">
            <p>
              {length(@references)} other species mention this name. Deleting removes it from:
            </p>
            <ul class="max-h-40 overflow-y-auto pl-4 list-disc">
              <li :for={ref <- @references}>
                <.sci name={epithet(ref.species.scientific_name)} />
                <span class="text-ink-3">
                  ({Enum.map_join(ref.fields, ", ", &reference_field_label/1)})
                </span>
              </li>
            </ul>
          </div>
          <p :if={@source_count == 0} class="species-dialog-note">
            This action cannot be undone.
          </p>
        </div>
        <div class="oc-modal-actions">
          <.button type="button" phx-click="cancel_delete">Cancel</.button>
          <.button
            type="button"
            phx-click="confirm_delete"
            class="species-btn-plate"
            id="confirm-delete-btn"
          >
            Delete species
          </.button>
        </div>
      </div>
    </div>
    """
  end

  defp reference_field_label(:parent1), do: "parent"
  defp reference_field_label(:parent2), do: "parent"
  defp reference_field_label(:hybrids), do: "hybrids"
  defp reference_field_label(:closely_related_to), do: "closely related"
  defp reference_field_label(:subspecies_varieties), do: "subspecies & varieties"

  # -- Delete source confirmation modal --

  attr :species, :any, required: true
  attr :target, :any, required: true

  defp delete_source_confirm_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 flex items-center justify-center p-s4"
      id="delete-source-confirm-modal"
      role="dialog"
      aria-modal="true"
      aria-labelledby="delete-source-confirm-title"
      phx-window-keydown="cancel_delete_source"
      phx-key="Escape"
    >
      <div class="oc-modal-backdrop" phx-click="cancel_delete_source" />
      <div class="oc-modal-panel species-dialog">
        <div class="oc-modal-head">
          <h2 id="delete-source-confirm-title">Delete source data</h2>
        </div>
        <div class="oc-modal-body">
          <p>
            Are you sure you want to remove <strong>{@target.source.name}</strong>
            data from <.sci name={"Quercus #{epithet(@species.scientific_name)}"} />?
          </p>
          <p class="species-dialog-note">This action cannot be undone.</p>
        </div>
        <div class="oc-modal-actions">
          <.button type="button" phx-click="cancel_delete_source">Cancel</.button>
          <.button
            type="button"
            phx-click="confirm_delete_source"
            class="species-btn-plate"
            id="confirm-delete-source-btn"
          >
            Delete source data
          </.button>
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
      class="fixed inset-0 z-50 flex items-center justify-center p-s4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="merge-picker-title"
      phx-window-keydown="close_merge_picker"
      phx-key="Escape"
      id="merge-picker-dialog"
    >
      <div class="oc-modal-backdrop" phx-click="close_merge_picker" />
      <div class="oc-modal-panel species-dialog max-h-[80vh] flex flex-col overflow-hidden">
        <div class="oc-modal-head">
          <h2 id="merge-picker-title">Select target species</h2>
          <.button type="button" size="compact" phx-click="close_merge_picker">
            Close <kbd>Esc</kbd>
          </.button>
        </div>

        <div class="oc-modal-body flex-1 min-h-0 flex flex-col">
          <p>
            Select the species that <.sci name={"Quercus #{@species.scientific_name}"} />
            will become a synonym of.
          </p>

          <form phx-change="merge_search" phx-submit="merge_search">
            <input
              type="text"
              name="query"
              value={@query}
              placeholder="Search for a species..."
              aria-label="Search for a species"
              autofocus
              phx-debounce="300"
              class="oc-input"
            />
          </form>

          <div class="flex-1 overflow-y-auto min-h-[200px] max-h-[300px]">
            <p :if={String.length(String.trim(@query)) < 2} class="species-dialog-note py-s5">
              Type at least 2 characters to search
            </p>

            <p
              :if={String.length(String.trim(@query)) >= 2 && @results == []}
              class="species-dialog-note py-s5"
            >
              No species found matching "{@query}"
            </p>

            <ul :if={@results != []} class="merge-results">
              <li :for={species <- @results}>
                <button
                  type="button"
                  phx-click="select_merge_target"
                  phx-value-name={species.scientific_name}
                  class="merge-target-option"
                >
                  <span class="merge-target-name">
                    <.sci name={SpeciesName.label(species.scientific_name, species.is_hybrid)} />
                  </span>
                  <span :if={species.author} class="merge-target-author">
                    {species.author}
                  </span>
                  <span :if={species.section} class="merge-target-meta">
                    sect. <i>{species.section}</i>
                  </span>
                </button>
              </li>
            </ul>
          </div>
        </div>

        <div class="oc-modal-actions">
          <.button type="button" phx-click="close_merge_picker">Cancel</.button>
        </div>
      </div>
    </div>
    """
  end

  # -- Data loading --

  defp load_species(socket, species) do
    hybrids =
      species.hybrids
      |> Species.parse_name_list()
      |> Species.get_hybrids_with_parents()

    closely_related = Species.parse_name_list(species.closely_related_to)
    subspecies_varieties = Species.parse_name_list(species.subspecies_varieties)
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
       can_add_source: Sources.available_sources_for_species(species.id) != [],
       selected_source: selected_source,
       not_found: false,
       page_title: "Quercus #{epithet(species.scientific_name)}"
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

  # A synonym or variety is {name, authority}. Stored as a string, the authority is
  # whatever follows the first word that starts with a capital or "("
  # (epithets and rank words are lower case): "shumardii var. acerifolia
  # E.J.Palmer 1927" is {"shumardii var. acerifolia", "E.J.Palmer 1927"}.
  defp name_and_authority(syn) when is_binary(syn) do
    case Regex.run(~r/^(.*?)\s+([[:upper:](].*)$/u, String.trim(syn)) do
      [_, name, author] -> {name, author}
      _ -> {syn, nil}
    end
  end

  defp name_and_authority(%{"name" => name, "author" => author})
       when is_binary(author) and author != "",
       do: {name, author}

  defp name_and_authority(%{"name" => name}), do: {name, nil}
  defp name_and_authority(other), do: {inspect(other), nil}

  # The hybrid sign and rank words stay roman; everything else in a
  # scientific name is italic.
  @roman_part ~r/(×|\b(?:subsp|ssp|var|subvar|f|nothosubsp|nothovar)\.)/u

  defp sci_html(name) do
    @roman_part
    |> Regex.split(name, include_captures: true, trim: true)
    |> Enum.map(fn part ->
      text = part |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

      if Regex.match?(@roman_part, part) and String.trim(part) == part,
        do: [~s(<span class="sci-roman">), text, "</span>"],
        else: ["<i>", text, "</i>"]
    end)
    |> IO.iodata_to_binary()
    |> raw()
  end

  defp link_host(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) and host != "" ->
        String.replace_prefix(host, "www.", "")

      _ ->
        nil
    end
  end

  defp selected_tab?(source, selected) do
    selected && source.id == selected.id
  end

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
