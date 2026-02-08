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
       sources: sources,
       show_delete_confirm: false,
       delete_source: nil
     )}
  end

  @impl true
  def handle_event("request_delete", %{"id" => id_str}, socket) do
    if socket.assigns[:authenticated] do
      {id, ""} = Integer.parse(id_str)
      source = Sources.get_source(id)
      species = Sources.get_species_for_source(id)

      {:noreply,
       assign(socket,
         show_delete_confirm: true,
         delete_source: source,
         delete_species_count: length(species)
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, show_delete_confirm: false, delete_source: nil)}
  end

  def handle_event("confirm_delete", _params, socket) do
    if socket.assigns[:authenticated] do
      source = socket.assigns.delete_source

      case Sources.delete_source(source) do
        {:ok, _} ->
          sources = Sources.list_sources_with_species_count()

          {:noreply,
           socket
           |> put_flash(:info, "Source \"#{source.name}\" deleted.")
           |> assign(
             sources: sources,
             show_delete_confirm: false,
             delete_source: nil
           )}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Cannot delete: species have data from this source.")
           |> assign(show_delete_confirm: false, delete_source: nil)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto">
      <header class="mb-8">
        <div class="flex items-center justify-between gap-4 mb-2">
          <h1
            class="text-3xl font-bold"
            style="font-family: var(--font-serif); color: var(--color-forest-800);"
          >
            Data Sources
          </h1>
          <.link
            :if={@authenticated}
            navigate={~p"/sources/new"}
            class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-lg text-sm font-medium"
            style="background-color: var(--color-forest-600); color: white; text-decoration: none; white-space: nowrap;"
            id="create-source-btn"
          >
            <.icon name="hero-plus" class="size-4" /> Create Source
          </.link>
        </div>
        <p style="color: var(--color-text-secondary); line-height: 1.6;">
          The Oak Compendium draws from multiple sources to provide comprehensive
          information about oak species.
        </p>
      </header>

      <div :if={@sources == []} class="text-center py-12" style="color: var(--color-text-tertiary);">
        <.icon name="hero-document-text" class="size-12 mx-auto mb-4 opacity-50" />
        <p class="text-lg">No sources found.</p>
      </div>

      <div :if={@sources != []} class="sources-grid">
        <.source_card
          :for={source <- @sources}
          source={source}
          authenticated={@authenticated}
        />
      </div>

      <.delete_confirm_modal
        :if={@show_delete_confirm && @delete_source}
        source={@delete_source}
        species_count={assigns[:delete_species_count] || 0}
      />
    </div>
    """
  end

  # -- Components --

  attr :source, :map, required: true
  attr :authenticated, :boolean, default: false

  defp source_card(assigns) do
    ~H"""
    <div class={["source-card", @authenticated && "can-edit"]}>
      <.link
        navigate={~p"/sources/#{@source.id}"}
        class="source-card-link"
        aria-label={@source.name}
      >
      </.link>
      <div class="source-content">
        <h2 class="source-card-name">{@source.name}</h2>
        <p :if={@source.description} class="source-card-desc">
          {@source.description}
        </p>
        <div class="source-card-meta">
          <span
            :if={@source.source_type}
            class="badge badge-muted"
            style="text-transform: capitalize;"
          >
            {@source.source_type}
          </span>
          <span :if={@source.author} class="source-card-author">
            {@source.author}
          </span>
          <span :if={@source.year} class="source-card-author">
            ({@source.year})
          </span>
        </div>
      </div>
      <div class="source-card-right">
        <div :if={@source.species_count > 0} class="source-card-count">
          <span class="source-card-count-value">{@source.species_count}</span>
          <span class="source-card-count-label">species</span>
        </div>
        <div :if={@authenticated} class="source-card-actions">
          <.link
            navigate={~p"/sources/#{@source.id}/edit"}
            class="source-action-btn source-action-edit"
            title="Edit source"
          >
            <.icon name="hero-pencil-square" class="size-3.5" />
          </.link>
          <button
            phx-click="request_delete"
            phx-value-id={@source.id}
            class="source-action-btn source-action-delete"
            title="Delete source"
          >
            <.icon name="hero-trash" class="size-3.5" />
          </button>
        </div>
        <span :if={!@authenticated} class="source-card-arrow">
          <.icon name="hero-chevron-right" class="size-5" />
        </span>
      </div>
    </div>
    """
  end

  # -- Delete confirmation modal --

  attr :source, :any, required: true
  attr :species_count, :integer, required: true

  defp delete_confirm_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 flex items-center justify-center"
      style="background-color: rgba(0,0,0,0.5);"
      phx-window-keydown="cancel_delete"
      phx-key="Escape"
    >
      <div class="card p-6 w-full max-w-md mx-4">
        <h3 class="text-lg font-bold mb-2" style="color: var(--color-text-primary);">
          Delete Source
        </h3>
        <p class="mb-4" style="color: var(--color-text-secondary);">
          Are you sure you want to delete <strong>{@source.name}</strong>?
        </p>
        <div
          :if={@species_count > 0}
          class="mb-4 p-3 rounded-lg text-sm"
          style="background-color: #fef2f2; color: #991b1b; border: 1px solid #fecaca;"
        >
          Cannot delete: {@species_count} species have data from this source.
        </div>
        <div class="flex justify-end gap-2">
          <button
            phx-click="cancel_delete"
            class="px-4 py-2 rounded-lg text-sm font-medium border transition-colors"
            style="border-color: var(--color-border); color: var(--color-text-secondary);"
          >
            Cancel
          </button>
          <button
            :if={@species_count == 0}
            phx-click="confirm_delete"
            class="px-4 py-2 rounded-lg text-sm font-medium text-white transition-colors"
            style="background-color: #dc2626;"
          >
            Delete
          </button>
          <button
            :if={@species_count > 0}
            phx-click="cancel_delete"
            class="px-4 py-2 rounded-lg text-sm font-medium text-white transition-colors"
            style="background-color: #dc2626;"
          >
            OK
          </button>
        </div>
      </div>
    </div>
    """
  end
end
