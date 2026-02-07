defmodule OakCompendiumWeb.SourceDetailLive do
  @moduledoc """
  LiveView for displaying detailed information about a single data source.

  Shows source metadata (type, author, year, URL, ISBN) with description
  and notes, a coverage count, and a list of species associated with the source.
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
       not_found: false,
       show_delete_confirm: false
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
      source = socket.assigns.source

      case Sources.delete_source(source) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Source \"#{source.name}\" deleted.")
           |> push_navigate(to: ~p"/sources")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Cannot delete: species have data from this source.")
           |> assign(show_delete_confirm: false)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="source-detail-page">
      <.not_found_view :if={@not_found} />

      <article :if={@source} class="source-detail">
        <.source_header source={@source} authenticated={@authenticated} />
        <.metadata_card source={@source} />
        <.coverage_section species={@species} />
        <.species_section :if={@species != []} species={@species} />
      </article>

      <.delete_confirm_modal
        :if={@show_delete_confirm && @source}
        source={@source}
        species_count={length(@species)}
      />
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
  attr :authenticated, :boolean, default: false

  defp source_header(assigns) do
    ~H"""
    <header class="source-header">
      <div class="source-header-left">
        <h1 class="source-name">
          {@source.name}
        </h1>
        <span :if={@source.source_type} class="type-badge">
          {@source.source_type}
        </span>
      </div>

      <div :if={@authenticated} class="source-actions">
        <.link
          navigate={~p"/sources/#{@source.id}/edit"}
          class="action-btn action-btn-edit"
          id="edit-source-btn"
        >
          <.icon name="hero-pencil-square" class="size-4" /> Edit
        </.link>
        <button
          phx-click="request_delete"
          class="action-btn action-btn-delete"
          id="delete-source-btn"
        >
          <.icon name="hero-trash" class="size-4" /> Delete
        </button>
      </div>
    </header>
    """
  end

  attr :source, :any, required: true

  defp metadata_card(assigns) do
    has_metadata =
      assigns.source.source_type || assigns.source.author || assigns.source.year ||
        assigns.source.isbn || assigns.source.url ||
        assigns.source.description || assigns.source.notes

    assigns = assign(assigns, :has_metadata, has_metadata)

    ~H"""
    <section :if={@has_metadata} class="card source-metadata-card">
      <dl class="source-metadata-grid">
        <.metadata_item :if={@source.source_type} label="Type" value={@source.source_type} />
        <.metadata_item :if={@source.author} label="Author" value={@source.author} />
        <.metadata_item :if={@source.year} label="Year" value={to_string(@source.year)} />
        <.metadata_item :if={@source.isbn} label="ISBN" value={@source.isbn} />
        <div :if={@source.url} class="source-metadata-url">
          <dt class="metadata-label">Website</dt>
          <dd>
            <a
              href={@source.url}
              target="_blank"
              rel="noopener noreferrer"
              class="source-url-link"
            >
              {@source.url}
              <.icon name="hero-arrow-top-right-on-square" class="size-3.5 flex-shrink-0" />
            </a>
          </dd>
        </div>
      </dl>

      <p :if={@source.description} class="source-description">
        {@source.description}
      </p>

      <p :if={@source.notes} class="source-notes">
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
      <dt class="metadata-label">{@label}</dt>
      <dd class="metadata-value">{@value}</dd>
    </div>
    """
  end

  attr :species, :list, required: true

  defp coverage_section(assigns) do
    ~H"""
    <section class="source-coverage">
      <h2 class="section-title">Coverage</h2>
      <div class="card source-stat-card">
        <span class="source-stat-value">{length(@species)}</span>
        <span class="source-stat-label">Species</span>
      </div>
    </section>
    """
  end

  attr :species, :list, required: true

  defp species_section(assigns) do
    ~H"""
    <section class="source-species">
      <h2 class="section-title">Species with Data from This Source</h2>
      <div class="source-species-grid">
        <.link
          :for={sp <- @species}
          navigate={~p"/species/#{sp.scientific_name}"}
          class="source-species-link"
        >
          <span class="source-species-name">
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

  # -- Helpers --

  defp display_name("\u00D7" <> rest), do: rest
  defp display_name(name), do: name
end
