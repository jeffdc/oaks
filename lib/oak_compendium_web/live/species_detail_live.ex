defmodule OakCompendiumWeb.SpeciesDetailLive do
  @moduledoc """
  LiveView for displaying detailed information about a single species.

  Shows species taxonomy, relationships (hybrids, related species, synonyms),
  and per-source descriptive data with tab-based source selection.
  Handles synonym redirects and 404 for unknown species.
  """

  use OakCompendiumWeb, :live_view

  alias OakCompendium.Species

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
       species_sources: [],
       selected_source: nil,
       has_relationships: false,
       show_delete_confirm: false,
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto">
      <.not_found_view :if={@not_found} />

      <div :if={@species}>
        <.species_header species={@species} authenticated={@authenticated} />

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div :if={@has_relationships} class="space-y-6">
            <.parent_species_section
              :if={@species.is_hybrid && (@species.parent1 || @species.parent2)}
              species={@species}
            />
            <.hybrids_section :if={@hybrids != []} hybrids={@hybrids} />
            <.related_section :if={@closely_related != []} related={@closely_related} />
            <.subspecies_section
              :if={@subspecies_varieties != []}
              items={@subspecies_varieties}
            />
            <.synonyms_section :if={@synonyms != []} synonyms={@synonyms} />
          </div>

          <div class={[@has_relationships && "lg:col-span-2", !@has_relationships && "lg:col-span-3"]}>
            <.source_tabs
              :if={@species_sources != []}
              sources={@species_sources}
              selected={@selected_source}
            />
            <.source_content :if={@selected_source} source={@selected_source} />
            <div
              :if={@species_sources == []}
              class="card p-8 text-center"
              style="color: var(--color-text-tertiary);"
            >
              <.icon name="hero-document-text" class="size-12 mx-auto mb-3 opacity-40" />
              <p class="italic">No source data available for this species.</p>
            </div>
          </div>
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

  attr :species, :any, required: true
  attr :authenticated, :boolean, default: false

  defp species_header(assigns) do
    ~H"""
    <div
      class="card p-6 mb-6"
      style="background: linear-gradient(135deg, var(--color-forest-50) 0%, var(--color-surface) 100%);"
    >
      <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
        <div>
          <h1
            class="text-3xl font-bold"
            style="font-family: var(--font-serif); color: var(--color-forest-900);"
          >
            Quercus{" "}
            <span :if={@species.is_hybrid}>&times;</span>
            <em>{display_name(@species.scientific_name)}</em>
          </h1>
          <p :if={@species.author} class="mt-1" style="color: var(--color-text-secondary);">
            {@species.author}
          </p>
        </div>
        <div class="flex items-center gap-2 flex-shrink-0">
          <span class={[
            "badge badge-uppercase",
            if(@species.is_hybrid, do: "badge-forest", else: "badge-forest-light")
          ]}>
            {if(@species.is_hybrid, do: "Hybrid", else: "Species")}
          </span>
          <.conservation_badge
            :if={@species.conservation_status}
            status={@species.conservation_status}
          />
        </div>
      </div>
      <.taxonomy_breadcrumb species={@species} />

      <!-- Compare link (visible to all users) -->
      <div class="mt-4 pt-4 border-t border-base-200">
        <.link
          navigate={~p"/compare/#{@species.scientific_name}"}
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-colors"
          style="color: var(--color-forest-700); background-color: var(--color-forest-50);"
        >
          <.icon name="hero-arrows-right-left" class="size-4" /> Compare with other species
        </.link>
      </div>

      <div :if={@authenticated} class="flex items-center gap-2 mt-4 pt-4 border-t border-base-200">
        <.link
          navigate={~p"/species/#{@species.scientific_name}/edit"}
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-colors"
          style="color: var(--color-forest-700); background-color: var(--color-forest-50);"
          id="edit-species-btn"
        >
          <.icon name="hero-pencil-square" class="size-4" /> Edit
        </.link>
        <button
          phx-click="show_merge_picker"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-colors"
          style="color: var(--color-forest-700); background-color: var(--color-forest-50);"
          id="merge-species-btn"
        >
          <.icon name="hero-arrows-right-left" class="size-4" /> Merge Into...
        </button>
        <button
          phx-click="request_delete"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium text-red-700 bg-red-50 hover:bg-red-100 transition-colors"
          id="delete-species-btn"
        >
          <.icon name="hero-trash" class="size-4" /> Delete
        </button>
      </div>
    </div>
    """
  end

  # -- Taxonomy breadcrumb --

  attr :species, :any, required: true

  defp taxonomy_breadcrumb(assigns) do
    ~H"""
    <nav
      :if={@species.subgenus || @species.section || @species.subsection || @species.complex}
      class="taxonomy-nav mt-3"
    >
      <span class="taxonomy-label">Quercus</span>
      <span :if={@species.subgenus}>
        <span class="taxonomy-separator">&rsaquo;</span>
        <.link navigate={~p"/taxonomy/#{@species.subgenus}"} class="taxonomy-link">
          <span class="taxonomy-level-label">subg.</span>
          <span class="taxonomy-name">{@species.subgenus}</span>
        </.link>
      </span>
      <span :if={@species.section}>
        <span class="taxonomy-separator">&rsaquo;</span>
        <.link
          navigate={~p"/taxonomy/#{@species.subgenus || "unknown"}/#{@species.section}"}
          class="taxonomy-link"
        >
          <span class="taxonomy-level-label">sect.</span>
          <span class="taxonomy-name">{@species.section}</span>
        </.link>
      </span>
      <span :if={@species.subsection}>
        <span class="taxonomy-separator">&rsaquo;</span>
        <span class="taxonomy-link">
          <span class="taxonomy-level-label">subsect.</span>
          <span class="taxonomy-name">{@species.subsection}</span>
        </span>
      </span>
      <span :if={@species.complex}>
        <span class="taxonomy-separator">&rsaquo;</span>
        <span class="taxonomy-link">
          <span class="taxonomy-level-label">complex</span>
          <span class="taxonomy-name">{@species.complex}</span>
        </span>
      </span>
    </nav>
    """
  end

  # -- Conservation status badge --

  attr :status, :string, required: true

  defp conservation_badge(assigns) do
    ~H"""
    <span
      class={["badge badge-uppercase border", conservation_classes(@status)]}
      title={conservation_label(@status)}
    >
      {@status}
    </span>
    """
  end

  # -- Relationship sections --

  attr :species, :any, required: true

  defp parent_species_section(assigns) do
    ~H"""
    <section class="card p-4">
      <h2 class="section-title section-title-sm mb-3">Parent Species</h2>
      <ul class="space-y-1">
        <li :if={@species.parent1}>
          <.link
            navigate={~p"/species/#{@species.parent1}"}
            class="flex items-center gap-2 p-2 rounded hover:bg-base-200 transition-colors"
          >
            <.icon name="hero-link" class="size-4 text-forest-600" />
            <span class="font-medium">Quercus <em>{@species.parent1}</em></span>
          </.link>
        </li>
        <li :if={@species.parent2}>
          <.link
            navigate={~p"/species/#{@species.parent2}"}
            class="flex items-center gap-2 p-2 rounded hover:bg-base-200 transition-colors"
          >
            <.icon name="hero-link" class="size-4 text-forest-600" />
            <span class="font-medium">Quercus <em>{@species.parent2}</em></span>
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  attr :hybrids, :list, required: true

  defp hybrids_section(assigns) do
    ~H"""
    <section class="card p-4">
      <h2 class="section-title section-title-sm mb-3">Known Hybrids</h2>
      <ul class="space-y-1">
        <li :for={hybrid <- @hybrids}>
          <.link
            navigate={~p"/species/#{hybrid}"}
            class="flex items-center gap-2 p-2 rounded hover:bg-base-200 transition-colors"
          >
            <.icon name="hero-link" class="size-4 text-forest-600" />
            <span class="font-medium">Quercus <em>{hybrid}</em></span>
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  attr :related, :list, required: true

  defp related_section(assigns) do
    ~H"""
    <section class="card p-4">
      <h2 class="section-title section-title-sm mb-3">Closely Related</h2>
      <ul class="space-y-1">
        <li :for={name <- @related}>
          <.link
            navigate={~p"/species/#{name}"}
            class="flex items-center gap-2 p-2 rounded hover:bg-base-200 transition-colors"
          >
            <.icon name="hero-link" class="size-4 text-forest-600" />
            <span class="font-medium">Quercus <em>{name}</em></span>
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  attr :items, :list, required: true

  defp subspecies_section(assigns) do
    ~H"""
    <section class="card p-4">
      <h2 class="section-title section-title-sm mb-3">Subspecies & Varieties</h2>
      <ul class="space-y-1">
        <li :for={item <- @items} class="p-2">
          <em style="color: var(--color-text-secondary);">{item}</em>
        </li>
      </ul>
    </section>
    """
  end

  attr :synonyms, :list, required: true

  defp synonyms_section(assigns) do
    ~H"""
    <section class="card p-4">
      <h2 class="section-title section-title-sm mb-3">Synonyms</h2>
      <div class="flex flex-wrap gap-2">
        <span :for={syn <- @synonyms} class="badge badge-muted">
          {format_synonym(syn)}
        </span>
      </div>
    </section>
    """
  end

  # -- Source tabs and content --

  attr :sources, :list, required: true
  attr :selected, :any, required: true

  defp source_tabs(assigns) do
    ~H"""
    <div
      class="flex flex-wrap gap-1 p-1 rounded-lg mb-4"
      style="background-color: var(--color-forest-800);"
    >
      <button
        :for={ss <- @sources}
        phx-click="select_source"
        phx-value-id={ss.source.id}
        class={[
          "px-3 py-1.5 rounded text-sm font-medium transition-colors",
          source_tab_classes(ss, @selected)
        ]}
      >
        {ss.source.name}
        <span :if={ss.is_preferred} title="Preferred source">&#9733;</span>
      </button>
    </div>
    """
  end

  attr :source, :any, required: true

  defp source_content(assigns) do
    local_names = Species.parse_json_array(assigns.source.local_names)
    assigns = assign(assigns, :local_names, local_names)

    ~H"""
    <div class="card p-6">
      <h3 class="text-sm font-medium mb-4" style="color: var(--color-text-tertiary);">
        Data from {@source.source.name}
      </h3>

      <div class="divide-y" style="border-color: var(--color-border-light);">
        <.source_field label="Geographic Range" value={@source.range} />
        <.source_field label="Growth Habit" value={@source.growth_habit} />
        <.source_field label="Leaves" value={@source.leaves} />
        <.source_field label="Flowers" value={@source.flowers} />
        <.source_field label="Fruits" value={@source.fruits} />
        <.source_field label="Bark" value={@source.bark} />
        <.source_field label="Twigs" value={@source.twigs} />
        <.source_field label="Buds" value={@source.buds} />

        <div :if={@local_names != []} class="py-3">
          <h4 class="text-sm font-semibold mb-2" style="color: var(--color-forest-700);">
            Common Names
          </h4>
          <div class="flex flex-wrap gap-2">
            <span :for={name <- @local_names} class="badge badge-forest-light">
              {name}
            </span>
          </div>
        </div>

        <.source_field label="Hardiness & Habitat" value={@source.hardiness_habitat} />
        <.source_field label="Additional Information" value={@source.miscellaneous} />
      </div>

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

  defp source_field(assigns) do
    ~H"""
    <div :if={@value && @value != ""} class="py-3">
      <h4 class="text-sm font-semibold mb-1" style="color: var(--color-forest-700);">
        {@label}
      </h4>
      <p class="prose-content" style="white-space: pre-wrap;">{@value}</p>
    </div>
    """
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
          Are you sure you want to delete <strong>
            Quercus <em>{display_name(@species.scientific_name)}</em>
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
          <em style="color: var(--color-forest-700);">Quercus {@species.scientific_name}</em>
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
                  <span
                    class="font-semibold"
                    style="font-style: italic; color: var(--color-forest-800);"
                  >
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
                    style="color: var(--color-text-secondary);"
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
    hybrids = Species.parse_json_array(species.hybrids)
    closely_related = Species.parse_json_array(species.closely_related_to)
    subspecies_varieties = Species.parse_json_array(species.subspecies_varieties)
    synonyms = Species.parse_json_array(species.synonyms)
    external_links = Species.parse_json_array(species.external_links)
    species_sources = species.species_sources
    selected_source = List.first(species_sources)

    has_relationships =
      species.is_hybrid || hybrids != [] || closely_related != [] ||
        subspecies_varieties != [] || synonyms != []

    {:noreply,
     assign(socket,
       species: species,
       hybrids: hybrids,
       closely_related: closely_related,
       subspecies_varieties: subspecies_varieties,
       synonyms: synonyms,
       external_links: external_links,
       species_sources: species_sources,
       selected_source: selected_source,
       has_relationships: has_relationships,
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

  defp format_synonym(syn) when is_binary(syn), do: syn

  defp format_synonym(%{"name" => name, "author" => author}) when author != "" do
    "#{name} #{author}"
  end

  defp format_synonym(%{"name" => name}), do: name
  defp format_synonym(other), do: inspect(other)

  defp source_tab_classes(source, selected) do
    if selected && source.id == selected.id do
      "bg-white text-forest-800"
    else
      "text-white/70 hover:text-white hover:bg-white/10"
    end
  end

  defp conservation_classes("LC"), do: "bg-green-100 text-green-800 border-green-300"
  defp conservation_classes("NT"), do: "bg-lime-100 text-lime-800 border-lime-300"
  defp conservation_classes("VU"), do: "bg-yellow-100 text-yellow-800 border-yellow-300"
  defp conservation_classes("EN"), do: "bg-orange-100 text-orange-800 border-orange-300"
  defp conservation_classes("CR"), do: "bg-red-100 text-red-800 border-red-300"
  defp conservation_classes("EW"), do: "bg-purple-100 text-purple-800 border-purple-300"
  defp conservation_classes("EX"), do: "bg-gray-800 text-white border-gray-900"
  defp conservation_classes("DD"), do: "bg-gray-100 text-gray-600 border-gray-300"
  defp conservation_classes("NE"), do: "bg-white text-gray-500 border-gray-300"
  defp conservation_classes(_), do: "bg-gray-100 text-gray-600 border-gray-300"

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
