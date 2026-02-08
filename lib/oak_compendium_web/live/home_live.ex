defmodule OakCompendiumWeb.HomeLive do
  use OakCompendiumWeb, :live_view

  alias OakCompendium.Sources
  alias OakCompendium.Species

  @impl true
  def mount(_params, _session, socket) do
    # Only fetch data when connected to avoid fetching twice
    if connected?(socket) do
      send(self(), :load_data)
    end

    {:ok,
     assign(socket,
       page_title: "Oak Compendium - A Database of the World's Oak Species",
       page_description:
         "A comprehensive guide to oak species (genus Quercus) featuring detailed information on taxonomy, morphology, distribution, and hybrid relationships.",
       page_url: "/",
       page_image: nil,
       stats: %{oak_count: 0, hybrid_count: 0},
       all_species: [],
       sources: [],
       featured_species: nil,
       is_loading: true
     )}
  end

  @impl true
  def handle_info(:load_data, socket) do
    stats = fetch_stats()
    all_species = Species.list_all_species()
    sources = fetch_and_sort_sources()
    featured_species = pick_featured_species(all_species)

    {:noreply,
     assign(socket,
       stats: stats,
       all_species: all_species,
       sources: sources,
       featured_species: featured_species,
       is_loading: false
     )}
  end

  @impl true
  def handle_event("shuffle", _params, socket) do
    featured_species = pick_featured_species(socket.assigns.all_species)
    {:noreply, assign(socket, featured_species: featured_species)}
  end

  defp fetch_stats do
    %{
      oak_count: Species.count(),
      hybrid_count: Species.count_hybrids()
    }
  end

  defp fetch_and_sort_sources do
    Sources.list_sources()
    |> Enum.filter(&(&1.id != 1))
    |> Enum.sort_by(fn source ->
      case source.id do
        3 -> {0, source.name}
        _ -> {1, source.name}
      end
    end)
  end

  defp pick_featured_species(all_species) do
    non_hybrid_species =
      all_species
      |> Enum.filter(fn s -> !s.is_hybrid end)

    if Enum.empty?(non_hybrid_species) do
      nil
    else
      Enum.random(non_hybrid_species)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto">
      <%!-- Welcome section --%>
      <section class="text-center mb-10">
        <h2
          class="text-3xl font-bold mb-3"
          style="font-family: var(--font-serif); color: var(--color-forest-800, #165132);"
        >
          Explore the World of Oaks
        </h2>
        <%= if @is_loading do %>
          <p class="text-lg" style="color: var(--color-text-secondary);">Loading species data...</p>
        <% else %>
          <p class="text-lg leading-relaxed" style="color: var(--color-text-secondary);">
            A comprehensive database of
            <strong class="font-semibold" style="color: var(--color-forest-700);">
              {@stats.oak_count}
            </strong>
            oak species and
            <strong class="font-semibold" style="color: var(--color-forest-700);">
              {@stats.hybrid_count}
            </strong>
            hybrids from around the globe.
          </p>
        <% end %>
      </section>

      <%!-- Browse options --%>
      <section class="mb-10">
        <h3 class="section-title">What would you like to do?</h3>
        <div class="flex flex-col gap-4 sm:flex-row">
          <.browse_card
            navigate={~p"/taxonomy"}
            icon="hero-squares-2x2"
            title="Taxonomy Tree"
            description="Explore by subgenus, section, and more"
          />
          <.disabled_card
            icon="hero-magnifying-glass"
            title="Identification"
            badge="Coming Soon"
            description="Identify oaks by their characteristics"
          />
        </div>
      </section>

      <%!-- Featured species --%>
      <%= if !@is_loading && @featured_species do %>
        <section class="mb-10">
          <div class="flex items-center justify-between mb-4">
            <h3 class="section-title">Featured Species</h3>
            <button
              phx-click="shuffle"
              aria-label="Show another random species"
              class="p-2 rounded text-stone-400 hover:bg-stone-100 hover:text-forest-600 focus-visible:outline-none focus-visible:bg-stone-100 focus-visible:text-forest-600 focus-visible:ring-2 focus-visible:ring-forest-600"
            >
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
                stroke-width="2"
              >
                #
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                />
              </svg>
            </button>
          </div>
          <.list_card href={~p"/species/#{@featured_species.scientific_name}"}>
            <span class="font-medium" style="color: var(--color-forest-700);">
              <em>Quercus {@featured_species.scientific_name}</em>
            </span>
            <%= if @featured_species.author do %>
              <span class="text-sm" style="color: var(--color-text-tertiary);">
                {@featured_species.author}
              </span>
            <% end %>
            <%= if @featured_species.section do %>
              <span class="text-xs" style="color: var(--color-text-tertiary);">
                Section {@featured_species.section}
              </span>
            <% end %>
          </.list_card>
        </section>
      <% end %>

      <%!-- Data sources --%>
      <%= if !@is_loading && !Enum.empty?(@sources) do %>
        <section class="mb-10">
          <h3 class="section-title">Data Sources</h3>
          <div class="flex flex-col gap-2">
            <%= for source <- @sources do %>
              <.list_card href={~p"/sources/#{source.id}"}>
                <span
                  class="font-medium"
                  style={
                    if source.id === 3,
                      do: "color: var(--color-forest-800); font-weight: 600;",
                      else: "color: var(--color-forest-700);"
                  }
                >
                  {source.name}
                </span>
                <%= if source.id === 3 do %>
                  <span class="badge badge-uppercase badge-forest-dark">Primary</span>
                <% end %>
              </.list_card>
            <% end %>
          </div>
        </section>
      <% end %>
    </div>
    """
  end

  defp list_card(assigns) do
    ~H"""
    <a
      href={@href}
      class="flex items-center justify-between px-4 py-3.5 rounded-lg transition-all bg-white border border-stone-200 hover:border-forest-400 hover:bg-forest-50"
      style="text-decoration: none;"
    >
      <div class="flex items-baseline gap-3">
        {render_slot(@inner_block)}
      </div>
      <svg
        class="w-5 h-5 flex-shrink-0"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
        stroke-width="2"
        style="color: var(--color-text-tertiary);"
      >
        <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
      </svg>
    </a>
    """
  end

  defp browse_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="card card-interactive flex flex-row sm:flex-col items-center sm:items-center gap-4 p-5 sm:p-6 text-left sm:text-center flex-1"
      style="text-decoration: none;"
    >
      <div class="flex-shrink-0 w-12 h-12 sm:w-16 sm:h-16 rounded-lg bg-forest-50 flex items-center justify-center text-forest-600 sm:mb-2">
        <.icon name={@icon} class="size-6 sm:size-8" />
      </div>
      <div class="flex-1 sm:flex-none">
        <h4 class="font-semibold text-base sm:text-lg" style="color: var(--color-text-primary);">
          {@title}
        </h4>
        <p class="text-sm" style="color: var(--color-text-secondary);">
          {@description}
        </p>
      </div>
      <svg
        class="flex-shrink-0 size-5 sm:hidden"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
        stroke-width="2"
        style="color: var(--color-text-tertiary);"
      >
        <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
      </svg>
    </.link>
    """
  end

  defp disabled_card(assigns) do
    ~H"""
    <div class="card flex flex-row sm:flex-col items-center sm:items-center gap-4 p-5 sm:p-6 text-left sm:text-center opacity-70 flex-1">
      <div
        class="flex-shrink-0 w-12 h-12 sm:w-16 sm:h-16 rounded-lg flex items-center justify-center sm:mb-2"
        style="background-color: var(--color-stone-100, #f5f5f4); color: var(--color-text-tertiary);"
      >
        <.icon name={@icon} class="size-6 sm:size-8" />
      </div>
      <div class="flex-1 sm:flex-none">
        <h4
          class="font-semibold text-base sm:text-lg flex items-center gap-2 flex-wrap sm:justify-center"
          style="color: var(--color-text-primary);"
        >
          {@title}
          <span class="badge badge-uppercase badge-muted">{@badge}</span>
        </h4>
        <p class="text-sm" style="color: var(--color-text-secondary);">
          {@description}
        </p>
      </div>
    </div>
    """
  end
end
