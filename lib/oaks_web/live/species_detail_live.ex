defmodule OaksWeb.SpeciesDetailLive do
  @moduledoc """
  LiveView for displaying detailed information about a single species.

  Shows species taxonomy, relationships (hybrids, related species, synonyms),
  and per-source descriptive data with tab-based source selection.
  A synonym's address redirects to its species; an unknown name raises
  `OaksWeb.NotFoundError`, a real 404 (the not-found page).

  Editors add photos from iNaturalist and manage them in two dialogs
  (`OaksWeb.SpeciesPhotos.AddPhotos` and `OaksWeb.SpeciesPhotos.ManagePhotos`),
  opened from the Edit menu; while a page is open to an editor it follows
  the species' photo changes (`Oaks.Images.subscribe/1`).
  """

  use OaksWeb, :live_view

  alias Oaks.Images
  alias Oaks.Markdown
  alias Oaks.Sources
  alias Oaks.Species
  alias OaksWeb.Params
  alias OaksWeb.SpeciesName
  alias OaksWeb.SpeciesPhotos
  alias OaksWeb.TaxonPath

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Species",
       species: nil,
       band_ranks: [],
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
       delete_photo_count: 0,
       show_delete_source_confirm: false,
       delete_source_target: nil,
       show_merge_picker: false,
       merge_search_query: "",
       merge_search_results: [],
       photo_dialog: nil,
       photo_counts: %{},
       subscribed_species_id: nil
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

  def handle_event("open_photo_dialog", %{"dialog" => dialog}, socket)
      when dialog in ["add", "manage"] do
    if socket.assigns[:current_scope] do
      {:noreply, assign(socket, photo_dialog: String.to_existing_atom(dialog))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_photo_dialog", _params, socket) do
    {:noreply, socket |> assign(photo_dialog: nil) |> assign_photo_counts()}
  end

  def handle_event("request_delete", _params, socket) do
    if socket.assigns[:current_scope] do
      {:noreply,
       assign(socket,
         show_delete_confirm: true,
         delete_references: Species.references_to(socket.assigns.species),
         delete_photo_count:
           socket.assigns.species |> Images.count_by_status() |> Map.values() |> Enum.sum()
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
    <.page class="species-detail">
      <:bleed :if={@species}>
        <.taxonomy_band ranks={@band_ranks} current={TaxonPath.current(@species)} />
      </:bleed>
      <:head :if={@species}>
        <.species_title
          species={@species}
          editor={@current_scope != nil}
          can_add_source={@can_add_source}
          failed_photos={Map.get(@photo_counts, "failed", 0)}
        />
      </:head>

      <div :if={@species}>
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

          <section class="source-container full-width" aria-label="Source data">
            <.tab_strip
              :if={@species_sources != []}
              sources={@species_sources}
              selected={@selected_source}
              species_name={@species.scientific_name}
            />
            <.source_content
              :if={@selected_source}
              source={@selected_source}
              editor={@current_scope != nil}
              species_name={@species.scientific_name}
            />
            <.section_heading :if={@species_sources == []}>Source data</.section_heading>
            <p :if={@species_sources == []} class="oc-empty">
              No source data available for this species.
            </p>
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
        photo_count={@delete_photo_count}
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

      <.live_component
        :if={@species && @current_scope && @photo_dialog == :add}
        module={SpeciesPhotos.AddPhotos}
        id={photo_dialog_id(:add)}
        species={@species}
        current_scope={@current_scope}
      />

      <.live_component
        :if={@species && @current_scope && @photo_dialog == :manage}
        module={SpeciesPhotos.ManagePhotos}
        id={photo_dialog_id(:manage)}
        species={@species}
        current_scope={@current_scope}
      />
    </.page>
    """
  end

  # -- Title row --

  attr :species, :any, required: true
  attr :editor, :boolean, default: false
  attr :can_add_source, :boolean, default: false
  attr :failed_photos, :integer, default: 0

  defp species_title(assigns) do
    ~H"""
    <.header id="species-title">
      <.sci_name
        name={@species.scientific_name}
        hybrid={@species.is_hybrid}
        author={@species.author}
        size="display"
      />
      <:meta>{kind_word(@species)}</:meta>
      <:meta :if={@species.conservation_status}>
        <.iucn_status code={@species.conservation_status} />
      </:meta>
      <:actions :if={@editor}>
        <.edit_menu id="species-edit-menu">
          <:item navigate={~p"/species/#{@species.scientific_name}/edit"} id="edit-species-btn">
            Edit {String.downcase(kind_word(@species))}
          </:item>
          <:item
            :if={@can_add_source}
            navigate={~p"/species/#{@species.scientific_name}/sources/new"}
            id="add-source-btn"
          >
            Add source data
          </:item>
          <:item click="open_photo_dialog" values={%{dialog: "add"}} id="add-photos-btn">
            Add photos from iNaturalist…
          </:item>
          <:item
            click="open_photo_dialog"
            values={%{dialog: "manage"}}
            id="manage-photos-btn"
            note={if @failed_photos > 0, do: "#{@failed_photos} failed"}
          >
            Manage photos…
          </:item>
          <:item click="show_merge_picker" id="merge-species-btn">Make synonym of…</:item>
          <:item click="request_delete" id="delete-species-btn">
            Delete {String.downcase(kind_word(@species))}
          </:item>
        </.edit_menu>
      </:actions>
    </.header>
    """
  end

  defp kind_word(%{is_hybrid: true}), do: "Hybrid"
  defp kind_word(_species), do: "Species"

  # -- Relationship sections: names on hairlines --

  attr :species, :any, required: true

  defp parent_species_section(assigns) do
    ~H"""
    <section class="detail-section full-width" id="species-parents">
      <.section_heading>Parent Species</.section_heading>
      <ul class="species-rows">
        <li :for={parent <- Enum.reject([@species.parent1, @species.parent2], &is_nil/1)}>
          <.link navigate={~p"/species/#{parent}"} class="species-row-link">
            <.sci_name name={parent} abbreviate size="title" />
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
    <section class="detail-section full-width" id="species-hybrids">
      <.section_heading>
        Known Hybrids<:note>{length(@hybrids)} known</:note>
      </.section_heading>
      <ul class="species-rows hybrid-list">
        <li :for={hybrid <- @hybrids} class="hybrid-item">
          <.link navigate={~p"/species/#{hybrid.name}"} class="hybrid-name">
            <.sci_name name={hybrid.name} hybrid abbreviate size="title" />
          </.link>
          <span :if={other = get_other_parent(hybrid, @species_name)} class="hybrid-with">
            with
            <.link navigate={~p"/species/#{other}"}>
              <.sci_name name={other} genus={nil} weight="regular" />
            </.link>
          </span>
        </li>
      </ul>
    </section>
    """
  end

  attr :related, :list, required: true

  defp related_section(assigns) do
    ~H"""
    <section class="detail-section full-width" id="species-related">
      <.section_heading>Closely Related</.section_heading>
      <ul class="species-rows">
        <li :for={name <- @related}>
          <.link navigate={~p"/species/#{name}"} class="species-row-link">
            <.sci_name name={name} abbreviate size="title" />
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  attr :items, :list, required: true

  defp subspecies_section(assigns) do
    ~H"""
    <section class="detail-section full-width" id="species-subspecies">
      <.section_heading>Subspecies &amp; Varieties</.section_heading>
      <ul class="species-rows">
        <li :for={{name, author} <- Enum.map(@items, &name_and_authority/1)}>
          <span class="species-row-name">
            <.sci_name name={name} author={author} abbreviate size="title" />
          </span>
        </li>
      </ul>
    </section>
    """
  end

  attr :synonyms, :list, required: true

  defp synonyms_section(assigns) do
    ~H"""
    <section class="detail-section full-width" id="species-synonyms">
      <.section_heading>
        Synonyms<:note>{count_label(length(@synonyms), "name")}</:note>
      </.section_heading>
      <p class="species-synonyms">
        <span
          :for={
            {{name, author}, i} <- @synonyms |> Enum.map(&name_and_authority/1) |> Enum.with_index(1)
          }
          class="species-synonym"
        ><.sci_name name={name} author={author} abbreviate />{if i < length(@synonyms),
          do: ", "}</span>
      </p>
    </section>
    """
  end

  # -- Source tabs and content --

  attr :sources, :list, required: true
  attr :selected, :any, required: true
  attr :species_name, :string, required: true

  defp tab_strip(assigns) do
    ~H"""
    <div class="source-tabs-strip">
      <div class="source-tabs-list" role="tablist" aria-label="Sources">
        <div
          :for={ss <- @sources}
          class={["source-tab", selected_tab?(ss, @selected) && "active"]}
          role="presentation"
        >
          <button
            type="button"
            phx-click="select_source"
            phx-value-id={ss.source.id}
            role="tab"
            aria-selected={to_string(selected_tab?(ss, @selected))}
          >
            <span class="source-tab-name">{ss.source.name}</span>
            <span :if={ss.is_preferred} class="source-tab-note">preferred</span>
          </button>
          <.link
            navigate={~p"/sources/#{ss.source.id}"}
            class="source-tab-link"
            title="View source details"
            aria-label={"About #{ss.source.name}"}
          >
            <.icon name="hero-information-circle" class="size-4" />
          </.link>
        </div>
      </div>
      <.compare_button
        :if={length(@sources) > 1}
        navigate={~p"/species/#{@species_name}/compare"}
        class="compare-sources-link"
        title="Compare all sources side-by-side"
      >
        Compare sources
      </.compare_button>
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
        <.edit_menu
          :if={@editor}
          id="source-data-menu"
          quiet
          aria_label={"Edit the data from #{@source.source.name}"}
        >
          <:item
            navigate={~p"/species/#{@species_name}/sources/#{@source.source.id}/edit"}
            id="edit-source-data-btn"
          >
            Edit source data
          </:item>
          <:item click="request_delete_source" values={%{id: @source.id}} id="delete-source-data-btn">
            Delete source data
          </:item>
        </.edit_menu>
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
        <p class="source-names">{Enum.join(@local_names, ", ")}</p>
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
      <div class="oc-prose">{raw(Markdown.render_html(@value))}</div>
    </section>
    """
  end

  # -- External links --

  attr :links, :list, required: true

  defp external_links_section(assigns) do
    ~H"""
    <section class="detail-section full-width" id="species-external-links">
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
  attr :photo_count, :integer, default: 0
  attr :references, :list, default: []

  defp delete_confirm_modal(assigns) do
    assigns = assign(assigns, :kind, String.downcase(kind_word(assigns.species)))

    ~H"""
    <.modal id="delete-confirm-modal" show on_cancel={JS.push("cancel_delete")}>
      <:title>Delete {@kind}</:title>
      <p>
        Delete
        <.sci_name name={@species.scientific_name} hybrid={@species.is_hybrid} weight="regular" />
        from the Compendium?
      </p>
      <:note :if={@source_count > 0}>
        Its data from {count_label(@source_count, "source")} goes with it.
      </:note>
      <:note :if={@photo_count > 0}>
        {photos_note(@photo_count)}
      </:note>
      <:note :if={@references != []}>
        <div id="delete-references">
          <p>{references_lead(length(@references))}</p>
          <ul>
            <li :for={ref <- @references}>
              <.sci_name
                name={ref.species.scientific_name}
                hybrid={ref.species.is_hybrid}
                abbreviate
                weight="regular"
              /> ({Enum.map_join(ref.fields, ", ", &reference_field_label/1)})
            </li>
          </ul>
        </div>
      </:note>
      <:note><strong>This can't be undone.</strong></:note>
      <:actions>
        <.button
          type="button"
          variant="danger"
          phx-click="confirm_delete"
          id="confirm-delete-btn"
        >
          Delete {@kind}
        </.button>
      </:actions>
    </.modal>
    """
  end

  defp photos_note(1), do: "Its photo goes with it, and its files are removed from storage."

  defp photos_note(n),
    do: "Its #{n} photos go with it, and their files are removed from storage."

  defp references_lead(1), do: "1 other species names it; deleting takes it out of:"
  defp references_lead(n), do: "#{n} other species name it; deleting takes it out of:"

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
    <.modal id="delete-source-confirm-modal" show on_cancel={JS.push("cancel_delete_source")}>
      <:title>Delete source data</:title>
      <p>
        Delete the data from <strong>{@target.source.name}</strong>
        on <.sci_name name={@species.scientific_name} hybrid={@species.is_hybrid} weight="regular" />?
      </p>
      <:note>The source itself stays.</:note>
      <:note><strong>This can't be undone.</strong></:note>
      <:actions>
        <.button
          type="button"
          variant="danger"
          phx-click="confirm_delete_source"
          id="confirm-delete-source-btn"
        >
          Delete source data
        </.button>
      </:actions>
    </.modal>
    """
  end

  # -- Merge picker dialog --

  attr :species, :any, required: true
  attr :query, :string, required: true
  attr :results, :list, required: true

  defp merge_picker_dialog(assigns) do
    ~H"""
    <.modal id="merge-picker-dialog" show on_cancel={JS.push("close_merge_picker")}>
      <:title>Make synonym of…</:title>
      <p>
        Choose the species
        <.sci_name name={@species.scientific_name} hybrid={@species.is_hybrid} weight="regular" />
        will become a synonym of. You'll see the merge before anything changes.
      </p>

      <form phx-change="merge_search" phx-submit="merge_search">
        <input
          type="text"
          name="query"
          value={@query}
          placeholder="Search for a species"
          aria-label="Search for a species"
          autocomplete="off"
          phx-debounce="300"
          class="oc-input"
        />
      </form>

      <div class="h-[min(300px,40dvh)] overflow-y-auto">
        <p :if={String.length(String.trim(@query)) < 2} class="oc-empty py-s4">
          Type at least 2 letters of a name.
        </p>

        <p
          :if={String.length(String.trim(@query)) >= 2 && @results == []}
          class="oc-empty py-s4"
        >
          No species found matching “{@query}”.
        </p>

        <ul :if={@results != []} class="merge-results">
          <li :for={species <- @results}>
            <button
              type="button"
              phx-click="select_merge_target"
              phx-value-name={species.scientific_name}
              class="merge-target-option"
            >
              <.sci_name
                name={species.scientific_name}
                hybrid={species.is_hybrid}
                author={species.author}
                size="title"
              />
              <span :if={species.section} class="merge-target-meta">
                <.sci_name name={species.section} rank="sect." size="meta" />
              </span>
            </button>
          </li>
        </ul>
      </div>
    </.modal>
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
       band_ranks: species |> Species.placement() |> TaxonPath.ranks(),
       hybrids: hybrids,
       closely_related: closely_related,
       subspecies_varieties: subspecies_varieties,
       synonyms: synonyms,
       external_links: external_links,
       computed_external_links: computed_external_links,
       species_sources: species_sources,
       can_add_source: Sources.available_sources_for_species(species.id) != [],
       selected_source: selected_source,
       page_title: SpeciesName.full_name(species.scientific_name, species.is_hybrid)
     )
     |> follow_photos()}
  end

  @impl true
  def handle_info({:species_images_changed, species_id}, socket) do
    if socket.assigns.species && socket.assigns.species.id == species_id do
      for {dialog, module} <- [add: SpeciesPhotos.AddPhotos, manage: SpeciesPhotos.ManagePhotos],
          socket.assigns.photo_dialog == dialog do
        send_update(module, id: photo_dialog_id(dialog), refresh: true)
      end

      {:noreply, assign_photo_counts(socket)}
    else
      {:noreply, socket}
    end
  end

  defp photo_dialog_id(:add), do: "add-photos"
  defp photo_dialog_id(:manage), do: "manage-photos"

  # An editor's page follows the species' photos: it counts the failed
  # imports for the Edit menu and refreshes an open photo dialog.
  defp follow_photos(socket) do
    species = socket.assigns.species

    if socket.assigns[:current_scope] && connected?(socket) &&
         socket.assigns.subscribed_species_id != species.id do
      :ok = Images.subscribe(species)
      socket |> assign(subscribed_species_id: species.id) |> assign_photo_counts()
    else
      assign_photo_counts(socket)
    end
  end

  defp assign_photo_counts(%{assigns: %{species: %{} = species}} = socket) do
    if socket.assigns[:current_scope],
      do: assign(socket, photo_counts: Images.count_by_status(species)),
      else: socket
  end

  defp assign_photo_counts(socket), do: socket

  defp handle_not_found(socket, name) do
    case Species.find_synonym(name) do
      nil ->
        raise OaksWeb.NotFoundError, kind: :species, query: name

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

  # A synonym or variety is {name, authority}. Stored as a string, it keeps
  # its authority in the name, which sci_name splits off itself.
  defp name_and_authority(syn) when is_binary(syn), do: {syn, nil}

  defp name_and_authority(%{"name" => name, "author" => author})
       when is_binary(author) and author != "",
       do: {name, author}

  defp name_and_authority(%{"name" => name}), do: {name, nil}
  defp name_and_authority(other), do: {inspect(other), nil}

  defp link_host(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) and host != "" ->
        String.replace_prefix(host, "www.", "")

      _ ->
        nil
    end
  end

  defp count_label(1, noun), do: "1 #{noun}"
  defp count_label(n, noun), do: "#{n} #{noun}s"

  defp selected_tab?(source, selected) do
    selected && source.id == selected.id
  end
end
