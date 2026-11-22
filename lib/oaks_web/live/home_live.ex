defmodule OaksWeb.HomeLive do
  use OaksWeb, :live_view

  alias Oaks.Sources
  alias Oaks.Species

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
    hybrid_count = Species.count_hybrids()

    # Species.count/0 includes hybrids; the tagline lists them separately.
    %{oak_count: Species.count() - hybrid_count, hybrid_count: hybrid_count}
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
    <div class="max-w-4xl">
      <%!-- Welcome section --%>
      <.header>
        Explore the World of Oaks
        <:subtitle>
          <%= if @is_loading do %>
            Loading species data...
          <% else %>
            A comprehensive database of <strong class="text-ink">{@stats.oak_count}</strong>
            oak species and <strong class="text-ink">{@stats.hybrid_count}</strong>
            hybrids from around the globe.
          <% end %>
        </:subtitle>
      </.header>

      <div class="space-y-s7">
        <%!-- Browse options --%>
        <section>
          <h2 class="section-title">What would you like to do?</h2>
          <.browse_card
            navigate={~p"/taxonomy"}
            title="Taxonomy Tree"
            description="Explore by subgenus, section, and more"
          />
          <.disabled_card
            title="Identification"
            badge="Coming Soon"
            description="Identify oaks by their characteristics"
          />
        </section>

        <%!-- Featured species --%>
        <section :if={!@is_loading && @featured_species}>
          <div class="flex items-center justify-between gap-s3 mb-s3">
            <h2 class="section-title">Featured Species</h2>
            <.button
              phx-click="shuffle"
              size="compact"
              aria-label="Show another random species"
            >
              Show another
            </.button>
          </div>
          <.list_card href={~p"/species/#{@featured_species.scientific_name}"}>
            <i class="font-serif text-lg font-semibold leading-snug group-hover:underline underline-offset-3">
              <span class="font-normal">Quercus</span> {@featured_species.scientific_name}
            </i>
            <span :if={@featured_species.author} class="font-serif text-sm text-ink-3">
              {@featured_species.author}
            </span>
            <span :if={@featured_species.section} class="font-frame text-[13px] text-ink-2">
              Section <i class="font-serif text-sm">{@featured_species.section}</i>
            </span>
          </.list_card>
        </section>

        <%!-- Data sources --%>
        <section :if={!@is_loading && !Enum.empty?(@sources)}>
          <h2 class="section-title">Data Sources</h2>
          <.list_card :for={source <- @sources} href={~p"/sources/#{source.id}"}>
            <span class={[
              "font-serif text-[17px] leading-snug group-hover:underline underline-offset-3",
              source.id === 3 && "font-semibold"
            ]}>
              {source.name}
            </span>
            <span :if={source.id === 3} class="badge badge-uppercase badge-forest-dark">
              Primary
            </span>
          </.list_card>
        </section>
      </div>
    </div>
    """
  end

  # A row of a ruled list: the whole row is the link, on a hairline.
  attr :href, :string, required: true
  slot :inner_block, required: true

  defp list_card(assigns) do
    ~H"""
    <a
      href={@href}
      class="group flex flex-wrap items-baseline gap-x-s3 gap-y-s1 py-s3 border-b border-rule text-ink no-underline"
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  attr :navigate, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

  defp browse_card(assigns) do
    ~H"""
    <.link navigate={@navigate} class="group block py-s3 border-b border-rule text-ink no-underline">
      <span class="block font-frame text-[17px] font-bold leading-snug group-hover:underline underline-offset-3">
        {@title}
      </span>
      <span class="block mt-s1 font-frame text-sm text-ink-2">{@description}</span>
    </.link>
    """
  end

  attr :title, :string, required: true
  attr :badge, :string, required: true
  attr :description, :string, required: true

  defp disabled_card(assigns) do
    ~H"""
    <div class="py-s3 border-b border-rule">
      <span class="flex flex-wrap items-center gap-s2 font-frame text-[17px] font-bold leading-snug text-ink-2">
        {@title}
        <span class="badge badge-uppercase badge-muted">{@badge}</span>
      </span>
      <span class="block mt-s1 font-frame text-sm text-ink-3">{@description}</span>
    </div>
    """
  end
end
