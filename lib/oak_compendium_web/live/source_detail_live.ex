defmodule OakCompendiumWeb.SourceDetailLive do
  @moduledoc """
  LiveView for displaying detailed information about a single data source.

  Shows source metadata (type, author, year, URL, DOI, ISBN, license)
  and a list of species associated with the source.
  """

  use OakCompendiumWeb, :live_view

  alias OakCompendium.Sources

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Source",
       source: nil,
       species: [],
       not_found: false
     )}
  end

  @impl true
  def handle_params(%{"id" => id_str}, _uri, socket) do
    case Integer.parse(id_str) do
      {id, ""} ->
        load_source(socket, id)

      _ ->
        {:noreply,
         assign(socket,
           source: nil,
           not_found: true,
           page_title: "Source Not Found"
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto">
      <.not_found_view :if={@not_found} />

      <div :if={@source}>
        <.source_header source={@source} />
        <.metadata_section source={@source} />
        <.coverage_section species={@species} />
        <.species_section :if={@species != []} species={@species} />
      </div>
    </div>
    """
  end

  # -- Page sections --

  defp not_found_view(assigns) do
    ~H"""
    <div class="text-center py-16">
      <.icon name="hero-exclamation-circle" class="size-16 mx-auto mb-4 text-base-content/30" />
      <h1 class="text-2xl font-bold mb-2">Source Not Found</h1>
      <p class="mb-6" style="color: var(--color-text-secondary);">
        The source you're looking for doesn't exist in our database.
      </p>
      <.link
        navigate={~p"/sources"}
        class="inline-flex items-center gap-2 px-4 py-2 rounded-lg text-white"
        style="background-color: var(--color-forest-600); text-decoration: none;"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to Sources
      </.link>
    </div>
    """
  end

  attr :source, :any, required: true

  defp source_header(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
      <div class="flex flex-wrap items-baseline gap-3">
        <h1
          class="text-3xl font-bold"
          style="font-family: var(--font-serif); color: var(--color-forest-800);"
        >
          {@source.name}
        </h1>
        <span
          :if={@source.source_type}
          class="badge badge-muted"
          style="text-transform: capitalize;"
        >
          {@source.source_type}
        </span>
      </div>
    </div>
    """
  end

  attr :source, :any, required: true

  defp metadata_section(assigns) do
    has_metadata =
      assigns.source.source_type || assigns.source.author || assigns.source.year ||
        assigns.source.isbn || assigns.source.doi || assigns.source.url ||
        assigns.source.description || assigns.source.notes || assigns.source.license

    assigns = assign(assigns, :has_metadata, has_metadata)

    ~H"""
    <section :if={@has_metadata} class="card p-5 mb-6">
      <dl class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <.metadata_item :if={@source.source_type} label="Type" value={@source.source_type} />
        <.metadata_item :if={@source.author} label="Author" value={@source.author} />
        <.metadata_item :if={@source.year} label="Year" value={to_string(@source.year)} />
        <.metadata_item :if={@source.isbn} label="ISBN" value={@source.isbn} />
        <.metadata_item :if={@source.doi} label="DOI" value={@source.doi} />
        <.metadata_item :if={@source.license} label="License" value={@source.license} />
        <div :if={@source.url} class="sm:col-span-2">
          <dt
            class="text-xs font-medium uppercase tracking-wide mb-1"
            style="color: var(--color-text-tertiary);"
          >
            Website
          </dt>
          <dd>
            <a
              href={@source.url}
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center gap-1 break-all"
              style="color: var(--color-forest-600); text-decoration: none;"
            >
              {@source.url}
              <.icon name="hero-arrow-top-right-on-square" class="size-3.5 flex-shrink-0" />
            </a>
          </dd>
        </div>
      </dl>

      <p
        :if={@source.description}
        class="mt-4 pt-4 text-sm"
        style="border-top: 1px solid var(--color-border); color: var(--color-text-secondary); line-height: 1.6;"
      >
        {@source.description}
      </p>

      <p
        :if={@source.notes}
        class="mt-3 text-sm italic"
        style="color: var(--color-text-tertiary);"
      >
        {@source.notes}
      </p>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp metadata_item(assigns) do
    ~H"""
    <div>
      <dt
        class="text-xs font-medium uppercase tracking-wide mb-1"
        style="color: var(--color-text-tertiary);"
      >
        {@label}
      </dt>
      <dd style="color: var(--color-text-primary);">
        {@value}
      </dd>
    </div>
    """
  end

  attr :species, :list, required: true

  defp coverage_section(assigns) do
    ~H"""
    <section class="mb-6">
      <h2 class="section-title">Coverage</h2>
      <div class="card p-5 text-center" style="max-width: 10rem;">
        <div
          class="text-2xl font-bold"
          style="font-family: var(--font-serif); color: var(--color-forest-700);"
        >
          {length(@species)}
        </div>
        <div class="text-sm" style="color: var(--color-text-secondary);">Species</div>
      </div>
    </section>
    """
  end

  attr :species, :list, required: true

  defp species_section(assigns) do
    ~H"""
    <section class="mb-6">
      <h2 class="section-title">Species with Data from This Source</h2>
      <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-x-4 gap-y-1">
        <.link
          :for={sp <- @species}
          navigate={~p"/species/#{sp.scientific_name}"}
          class="block px-2 py-1.5 rounded transition-colors"
          style="text-decoration: none;"
        >
          <span style="font-family: var(--font-serif); font-style: italic; color: var(--color-forest-700);">
            Q.{" "}
            <span :if={sp.is_hybrid}>&times;</span>{display_name(sp.scientific_name)}
          </span>
        </.link>
      </div>
    </section>
    """
  end

  # -- Data loading --

  defp load_source(socket, id) do
    case Sources.get_source(id) do
      nil ->
        {:noreply,
         assign(socket,
           source: nil,
           species: [],
           not_found: true,
           page_title: "Source Not Found"
         )}

      source ->
        species = Sources.get_species_for_source(id)

        {:noreply,
         assign(socket,
           source: source,
           species: species,
           not_found: false,
           page_title: source.name
         )}
    end
  end

  # -- Helpers --

  defp display_name("\u00D7" <> rest), do: rest
  defp display_name(name), do: name
end
