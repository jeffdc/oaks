defmodule OakCompendiumWeb.SourcesLive do
  @moduledoc """
  LiveView for browsing all data sources.

  Displays sources in a card list with name, type, description,
  and species count. Each source links to its detail page.
  """

  use OakCompendiumWeb, :live_view

  alias OakCompendium.Sources

  @impl true
  def mount(_params, _session, socket) do
    sources = Sources.list_sources_with_species_count()

    {:ok,
     socket
     |> assign(
       page_title: "Data Sources",
       sources: sources
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto">
      <header class="mb-8">
        <h1
          class="text-3xl font-bold mb-2"
          style="font-family: var(--font-serif); color: var(--color-forest-800);"
        >
          Data Sources
        </h1>
        <p style="color: var(--color-text-secondary); line-height: 1.6;">
          The Oak Compendium draws from multiple sources to provide comprehensive
          information about oak species.
        </p>
      </header>

      <div :if={@sources == []} class="text-center py-12" style="color: var(--color-text-tertiary);">
        <.icon name="hero-document-text" class="size-12 mx-auto mb-4 opacity-50" />
        <p class="text-lg">No sources found.</p>
      </div>

      <div :if={@sources != []} class="space-y-4">
        <.source_card :for={source <- @sources} source={source} />
      </div>
    </div>
    """
  end

  # -- Components --

  attr :source, :map, required: true

  defp source_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/sources/#{@source.id}"}
      class="card card-interactive flex items-center justify-between gap-4 p-5 block"
      style="text-decoration: none;"
    >
      <div class="flex-1 min-w-0">
        <h2
          class="text-xl font-semibold mb-1"
          style="font-family: var(--font-serif); color: var(--color-forest-800);"
        >
          {@source.name}
        </h2>
        <p
          :if={@source.description}
          class="text-sm mb-2 line-clamp-2"
          style="color: var(--color-text-secondary);"
        >
          {@source.description}
        </p>
        <div class="flex flex-wrap items-center gap-2">
          <span
            :if={@source.source_type}
            class="badge badge-muted"
            style="text-transform: capitalize;"
          >
            {@source.source_type}
          </span>
          <span :if={@source.author} class="text-sm" style="color: var(--color-text-tertiary);">
            {@source.author}
          </span>
          <span :if={@source.year} class="text-sm" style="color: var(--color-text-tertiary);">
            ({@source.year})
          </span>
        </div>
      </div>
      <div class="flex items-center gap-3 flex-shrink-0">
        <div :if={@source.species_count > 0} class="text-center">
          <div class="text-lg font-bold" style="color: var(--color-forest-700);">
            {@source.species_count}
          </div>
          <div class="text-xs" style="color: var(--color-text-tertiary);">species</div>
        </div>
        <span style="color: var(--color-text-tertiary);">
          <.icon name="hero-chevron-right" class="size-5 flex-shrink-0" />
        </span>
      </div>
    </.link>
    """
  end
end
