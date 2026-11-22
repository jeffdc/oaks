defmodule OaksWeb.SourceDetailLive do
  @moduledoc """
  LiveView for displaying detailed information about a single data source.

  Shows source metadata (type, author, year, URL, ISBN) with description
  and notes, a coverage count, and a list of species associated with the source.
  """

  use OaksWeb, :live_view

  alias Oaks.Sources

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
    if socket.assigns[:current_scope] do
      {:noreply, assign(socket, show_delete_confirm: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, show_delete_confirm: false)}
  end

  def handle_event("confirm_delete", _params, socket) do
    source = socket.assigns.source

    if socket.assigns[:current_scope] && source do
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
    <.page>
      <.not_found_view :if={@not_found} />

      <article :if={@source}>
        <.back navigate={~p"/sources"}>Back to Sources</.back>
        <.source_header source={@source} editor={@current_scope != nil} />
        <.metadata_card source={@source} />
        <.coverage_section species={@species} />
        <.species_section :if={@species != []} species={@species} />
      </article>

      <.delete_confirm_modal
        :if={@show_delete_confirm && @source}
        source={@source}
        species_count={length(@species)}
      />
    </.page>
    """
  end

  # -- Page sections --

  defp not_found_view(assigns) do
    ~H"""
    <div>
      <.header>
        Source Not Found
        <:subtitle>The source you're looking for doesn't exist in our database.</:subtitle>
      </.header>
      <.back navigate={~p"/sources"}>Back to Sources</.back>
    </div>
    """
  end

  attr :source, :any, required: true
  attr :editor, :boolean, default: false

  defp source_header(assigns) do
    ~H"""
    <header class="source-header">
      <div class="source-header-left">
        <h1 class="source-name">
          {@source.name}
        </h1>
        <.status_tag :if={@source.source_type} class="capitalize">
          {@source.source_type}
        </.status_tag>
      </div>

      <div :if={@editor} class="source-actions">
        <.link
          navigate={~p"/sources/#{@source.id}/edit"}
          class="action-btn action-btn-edit"
          id="edit-source-btn"
        >
          Edit
        </.link>
        <button
          phx-click="request_delete"
          class="action-btn action-btn-delete"
          id="delete-source-btn"
        >
          Delete
        </button>
      </div>
    </header>
    """
  end

  attr :source, :any, required: true

  defp metadata_card(assigns) do
    has_metadata =
      assigns.source.author || assigns.source.year ||
        assigns.source.isbn || assigns.source.url ||
        assigns.source.description || assigns.source.notes

    assigns = assign(assigns, :has_metadata, has_metadata)

    ~H"""
    <section :if={@has_metadata} class="card source-metadata-card">
      <dl class="source-metadata-grid">
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
              <.icon name="hero-arrow-top-right-on-square" class="size-3.5" />
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
      <p class="source-coverage-count">
        {length(@species)} species
      </p>
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
            <span :if={hybrid_sign?(sp.scientific_name, sp.is_hybrid)}>&times;</span>{epithet(
              sp.scientific_name
            )}
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
      class="fixed inset-0 z-50 flex items-center justify-center bg-ink/65"
      phx-window-keydown="cancel_delete"
      phx-key="Escape"
    >
      <div
        class="card p-6 w-full max-w-md mx-4"
        role="dialog"
        aria-modal="true"
        aria-labelledby="delete-source-title"
      >
        <h3 id="delete-source-title" class="mb-s3 font-serif text-[26px]/[1.15] font-semibold">
          {if @species_count > 0, do: "Can't Delete Source", else: "Delete Source"}
        </h3>
        <p :if={@species_count == 0} class="mb-s4 text-ink-2">
          Are you sure you want to delete <strong class="text-ink">{@source.name}</strong>?
        </p>
        <p
          :if={@species_count > 0}
          class="mb-s4 py-s2 border-y-2 border-ink font-frame text-sm font-bold"
        >
          Cannot delete: {@species_count} species have data from this source.
        </p>
        <div class="flex flex-wrap justify-end gap-s2">
          <.button :if={@species_count == 0} phx-click="cancel_delete">Cancel</.button>
          <.button :if={@species_count == 0} variant="primary" phx-click="confirm_delete">
            Delete
          </.button>
          <.button :if={@species_count > 0} phx-click="cancel_delete">Close</.button>
        </div>
      </div>
    </div>
    """
  end

  # -- Helpers --
end
