defmodule OaksWeb.SpeciesDetailLive do
  @moduledoc """
  LiveView for a species' page: the species page for today's data
  (docs/species-photos-plan.md, Phase 4 decisions; design/prototype/
  species-today.html).

  The taxonomy band with the siblings menu; the title row with the common
  name the source order picks (`Oaks.Species.common_name/1`) and, for a
  hybrid, its parents; the not-covered notice when the Oak Compendium has no
  text for it; then its photos beside its text by source, in tabs in the
  source order (`Oaks.Species.ordered_sources/1`), opening on the first
  with any text unless the address names one (`?source=<source id>`); then its
  synonyms, subspecies and varieties, hybrids, external links, sources and
  the cite line, each only when it has data.

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

  # The siblings menu lists this many, around the species, and links to
  # the rest.
  @siblings_shown 12

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Species",
       species: nil,
       band_ranks: [],
       siblings: nil,
       images: [],
       hybrids: [],
       subspecies_varieties: [],
       synonyms: [],
       external_links: [],
       sources: [],
       common_name: nil,
       covered: false,
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
  def handle_params(%{"name" => name} = params, _uri, socket) do
    case socket.assigns.species do
      %{scientific_name: ^name} ->
        {:noreply, select_source(socket, params["source"])}

      _ ->
        case Species.get_species_full(name) do
          nil ->
            handle_not_found(socket, name)

          species ->
            {:noreply, socket |> load_species(species) |> select_source(params["source"])}
        end
    end
  end

  @impl true
  def handle_event("select_source", %{"id" => id}, socket) do
    case find_source(socket.assigns.sources, id) do
      nil -> {:noreply, socket}
      ss -> {:noreply, push_patch(socket, to: source_path(socket.assigns.species, ss))}
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
        Enum.find(socket.assigns.sources, &(&1.id == source_id))

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
    <.page width="frame">
      <:bleed :if={@species}>
        <.taxonomy_band ranks={@band_ranks} current={TaxonPath.current(@species)}>
          <:siblings :if={@siblings} label={@siblings.label}>
            <li :for={name <- @siblings.shown}>
              <span :if={name == @species.scientific_name} aria-current="page">
                <.sci_name name={name} abbreviate />
              </span>
              <.link :if={name != @species.scientific_name} navigate={~p"/species/#{name}"}>
                <.sci_name name={name} abbreviate />
              </.link>
            </li>
            <li :if={@siblings.all_path}>
              <.link navigate={@siblings.all_path}>
                All {@siblings.total} in
                <.sci_name name={@siblings.group} level={@siblings.level} />{if @siblings.level ==
                                                                                  "complex",
                                                                                do: " complex"}
              </.link>
            </li>
          </:siblings>
        </.taxonomy_band>
      </:bleed>
      <:head :if={@species}>
        <.species_title
          species={@species}
          common_name={@common_name}
          editor={@current_scope != nil}
          can_add_source={@can_add_source}
          failed_photos={Map.get(@photo_counts, "failed", 0)}
        />
      </:head>

      <div :if={@species}>
        <.not_covered_notice :if={!@covered} id="not-covered">
          {if @sources != [],
            do: "Everything on this page comes from the sources listed, shown as they wrote it."}
        </.not_covered_notice>

        <.photo_columns id="species-main">
          <:photos>
            <.species_photos id="species-photos" images={@images} name={@page_title} />
          </:photos>
          <.source_tabs
            :if={@selected_source}
            id="source-tabs"
            selected={@selected_source.source_id}
            on_select="select_source"
          >
            <:tab
              :for={ss <- @sources}
              id={ss.source_id}
              name={ss.source.name}
              original={ss.url}
              about={~p"/sources/#{ss.source.id}"}
            />
            <:action :if={@current_scope}>
              <.edit_menu
                id="source-data-menu"
                quiet
                aria_label={"Edit the data from #{@selected_source.source.name}"}
              >
                <:item
                  navigate={
                    ~p"/species/#{@species.scientific_name}/sources/#{@selected_source.source.id}/edit"
                  }
                  id="edit-source-data-btn"
                >
                  Edit {@selected_source.source.name} data
                </:item>
                <:item
                  click="request_delete_source"
                  values={%{id: @selected_source.id}}
                  id="delete-source-data-btn"
                >
                  Delete {@selected_source.source.name} data
                </:item>
              </.edit_menu>
            </:action>
            <:action :if={length(@sources) > 1}>
              <.compare_button
                navigate={~p"/species/#{@species.scientific_name}/compare"}
                id="compare-sources-link"
              >
                Compare sources
              </.compare_button>
            </:action>
            <:field
              :for={{label, value} <- source_fields(@selected_source)}
              label={label}
            >
              <%= case value do %>
                <% {:names, names} -> %>
                  {Enum.join(names, ", ")}
                <% text -> %>
                  <div class="oc-prose">{raw(Markdown.render_html(text))}</div>
              <% end %>
            </:field>
          </.source_tabs>
          <section :if={@sources == []} id="source-tabs" aria-label="Source data">
            <.section_heading>Source data</.section_heading>
            <p class="oc-empty">No source data for this oak yet.</p>
          </section>
        </.photo_columns>

        <div class="mt-s8 grid gap-s7">
          <section :if={@synonyms != []} id="species-synonyms">
            <.section_heading>
              Synonyms<:note>{count_label(length(@synonyms), "name")}</:note>
            </.section_heading>
            <.comma_list>
              <:item :for={{name, author} <- @synonyms}>
                <.sci_name
                  name={name}
                  author={author}
                  abbreviate
                />
              </:item>
            </.comma_list>
          </section>

          <section :if={@subspecies_varieties != []} id="species-subspecies">
            <.section_heading>Subspecies and varieties</.section_heading>
            <.ruled_rows>
              <:row :for={{name, author} <- @subspecies_varieties}>
                <.sci_name name={name} author={author} abbreviate size="title" />
              </:row>
            </.ruled_rows>
          </section>

          <section :if={@hybrids != []} id="species-hybrids">
            <.section_heading>
              Hybrids<:note>{length(@hybrids)} known</:note>
            </.section_heading>
            <.hybrid_rows hybrids={@hybrids} />
          </section>

          <section id="species-external-links">
            <.section_heading>External links</.section_heading>
            <.ruled_rows>
              <:row :for={link <- @external_links} href={link.url} note={link_host(link.url)}>
                {link.name}
              </:row>
            </.ruled_rows>
          </section>

          <section :if={@sources != []} id="species-sources">
            <.section_heading>Sources</.section_heading>
            <.ruled_rows columns={1}>
              <:row :for={ss <- @sources}>
                <.link navigate={~p"/sources/#{ss.source.id}"}>
                  <.work_title title={ss.source.name} />
                </.link>
                <.source_mark :if={present?(ss.url)} href={ss.url}>original page</.source_mark>
              </:row>
            </.ruled_rows>
          </section>

          <.cite_line id="species-cite">
            Oak Compendium.
            <.sci_name
              name={@species.scientific_name}
              hybrid={@species.is_hybrid}
              author={@species.author}
            />. {cite_url(@species)} (accessed {Date.utc_today()}).
          </.cite_line>
        </div>
      </div>

      <.delete_confirm_modal
        :if={@show_delete_confirm}
        species={@species}
        source_count={length(@sources)}
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
  attr :common_name, :any, default: nil
  attr :editor, :boolean, default: false
  attr :can_add_source, :boolean, default: false
  attr :failed_photos, :integer, default: 0

  defp species_title(assigns) do
    assigns =
      assign(assigns,
        parents: Enum.reject([assigns.species.parent1, assigns.species.parent2], &blank?/1)
      )

    ~H"""
    <.header id="species-title">
      <.sci_name
        name={@species.scientific_name}
        hybrid={@species.is_hybrid}
        author={@species.author}
        size="display"
      />
      <:common_name :if={@common_name}>
        {elem(@common_name, 0)}
        <.source_mark
          patch={source_path(@species, elem(@common_name, 1))}
          title={"Open #{elem(@common_name, 1).source.name}"}
        >
          <.work_title title={elem(@common_name, 1).source.name} />
        </.source_mark>
      </:common_name>
      <:meta>{kind_word(@species)}</:meta>
      <:meta :if={@species.conservation_status}>
        <.iucn_status code={@species.conservation_status} />
      </:meta>
      <:subtitle :if={@species.is_hybrid}>
        <span id="species-parents">
          Hybrid of
          <%= case @parents do %>
            <% [p1, p2] -> %>
              <.parent_link name={p1} /> and <.parent_link name={p2} />
            <% [p] -> %>
              <.parent_link name={p} /> and an unrecorded parent
            <% [] -> %>
              unrecorded parents
          <% end %>
        </span>
      </:subtitle>
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

  attr :name, :string, required: true

  defp parent_link(assigns) do
    ~H"""
    <.link navigate={~p"/species/#{@name}"}><.sci_name
      name={@name}
      abbreviate
      weight="regular"
    /></.link>
    """
  end

  defp kind_word(%{is_hybrid: true}), do: "Hybrid"
  defp kind_word(_species), do: "Species"

  # The open source's nonempty fields, in today's order and labels.
  @field_labels [
    range: "Geographic range",
    growth_habit: "Growth habit",
    leaves: "Leaves",
    flowers: "Flowers",
    fruits: "Fruits",
    bark: "Bark",
    twigs: "Twigs",
    buds: "Buds",
    hardiness_habitat: "Hardiness and habitat",
    miscellaneous: "Additional information"
  ]

  defp source_fields(ss) do
    names =
      case Species.common_names(ss) do
        [] -> []
        names -> [{"Common names", {:names, names}}]
      end

    names ++
      for {field, label} <- @field_labels,
          value = Map.get(ss, field),
          present?(value),
          do: {label, value}
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

      <form id="merge-search-form" phx-change="merge_search" phx-submit="merge_search">
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
    sources = Species.ordered_sources(species.species_sources)
    band_ranks = species |> Species.placement() |> TaxonPath.ranks()

    socket
    |> assign(
      species: species,
      band_ranks: band_ranks,
      siblings: siblings_menu(species, band_ranks),
      images: Images.list_for_species(species),
      hybrids: Species.hybrids_with_other_parent(species),
      subspecies_varieties:
        species.subspecies_varieties
        |> Species.parse_name_list()
        |> Enum.map(&name_and_authority/1),
      synonyms: species.synonyms |> Species.parse_json_array() |> Enum.map(&name_and_authority/1),
      external_links: external_links(species),
      sources: sources,
      common_name: Species.common_name(sources),
      covered: Species.covered?(sources),
      can_add_source: Sources.available_sources_for_species(species.id) != [],
      page_title: SpeciesName.full_name(species.scientific_name, species.is_hybrid)
    )
    |> follow_photos()
  end

  # The tab the address names (?source=<source id>), else the first with
  # any text.
  defp select_source(socket, source_id) do
    sources = socket.assigns.sources

    assign(socket,
      selected_source: find_source(sources, source_id) || Species.default_source(sources)
    )
  end

  defp find_source(_sources, nil), do: nil

  defp find_source(sources, id) do
    id = Params.int(id)
    Enum.find(sources, &(&1.source_id == id))
  end

  defp source_path(species, ss),
    do: ~p"/species/#{species.scientific_name}?source=#{ss.source_id}"

  # The siblings menu: up to @siblings_shown names around the species, and
  # a link to its group's page when there are more.
  defp siblings_menu(species, band_ranks) do
    case Species.siblings(species) do
      nil ->
        nil

      %{level: level, name: group, names: names} ->
        total = length(names)
        shown = window(names, species.scientific_name, @siblings_shown)
        more? = total > length(shown) and level != "species"

        %{
          label: siblings_label(level, group, total),
          shown: shown,
          all_path: more? && List.last(band_ranks).path,
          total: total,
          group: group,
          level: level
        }
    end
  end

  defp siblings_label("complex", group, total),
    do: "#{group} complex · #{count_label(total, "species")}"

  defp siblings_label("species", group, total), do: "#{group} · #{count_label(total, "taxon")}"
  defp siblings_label(_level, group, total), do: "#{group} · #{count_label(total, "species")}"

  # `count` names from `names` that include `current` when it is among them.
  defp window(names, current, count) do
    index = Enum.find_index(names, &(&1 == current)) || 0
    start = index |> Kernel.-(div(count, 2)) |> max(0) |> min(max(length(names) - count, 0))
    Enum.slice(names, start, count)
  end

  @impl true
  def handle_info({:species_images_changed, species_id}, socket) do
    if socket.assigns.species && socket.assigns.species.id == species_id do
      for {dialog, module} <- [add: SpeciesPhotos.AddPhotos, manage: SpeciesPhotos.ManagePhotos],
          socket.assigns.photo_dialog == dialog do
        send_update(module, id: photo_dialog_id(dialog), refresh: true)
      end

      {:noreply,
       socket
       |> assign(images: Images.list_for_species(socket.assigns.species))
       |> assign_photo_counts()}
    else
      {:noreply, socket}
    end
  end

  defp photo_dialog_id(:add), do: "add-photos"
  defp photo_dialog_id(:manage), do: "manage-photos"

  # An editor's page follows the species' photos: it counts the failed
  # imports for the Edit menu, refreshes an open photo dialog and the
  # photos column.
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

  # The species' stored links, then iNaturalist and Wikipedia, by name.
  defp external_links(species) do
    stored =
      species.external_links
      |> Species.parse_json_array()
      |> Enum.flat_map(fn
        %{"name" => name, "url" => url} when is_binary(name) and is_binary(url) ->
          [%{name: name, url: url}]

        _ ->
          []
      end)

    auto = [
      %{
        name: "iNaturalist",
        url:
          "https://www.inaturalist.org/search?q=#{URI.encode("Quercus #{species.scientific_name}")}"
      },
      %{
        name: "Wikipedia",
        url:
          "https://en.wikipedia.org/wiki/Quercus_#{String.replace(species.scientific_name, " ", "_")}"
      }
    ]

    Enum.sort_by(stored ++ auto, &String.downcase(&1.name))
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

  # The page's address as a reader would copy it: only spaces encoded, so
  # a hybrid's sign stays legible (…/species/×%20fontana).
  defp cite_url(species),
    do: url(~p"/species") <> "/" <> String.replace(species.scientific_name, " ", "%20")

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
  defp blank?(value), do: not present?(value)

  defp count_label(1, noun), do: "1 #{noun}"
  defp count_label(n, "species"), do: "#{n} species"
  defp count_label(n, "taxon"), do: "#{n} taxa"
  defp count_label(n, noun), do: "#{n} #{noun}s"
end
