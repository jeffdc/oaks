defmodule OaksWeb.SourcesLive do
  @moduledoc """
  LiveView for browsing all data sources.

  Displays sources in a card list with name, type, description,
  and species count. Each source links to its detail page.
  """

  use OaksWeb, :live_view

  alias Oaks.Sources

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
    if socket.assigns[:current_scope] do
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
    source = socket.assigns.delete_source

    if socket.assigns[:current_scope] && source do
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
    <.page>
      <.header class="mb-s2 [&>div:first-child]:flex-[1_1_20rem]">
        Data Sources
        <:subtitle>
          The Oak Compendium draws from multiple sources to provide comprehensive
          information about oak species.
        </:subtitle>
        <:actions :if={@current_scope}>
          <.button navigate={~p"/sources/new"} id="create-source-btn">Create Source</.button>
        </:actions>
      </.header>

      <p :if={@sources == []} class="py-s7 font-serif italic text-ink-3">No sources found.</p>

      <div :if={@sources != []} class="sources-grid">
        <.source_card
          :for={source <- @sources}
          source={source}
          editor={@current_scope != nil}
        />
      </div>

      <.delete_confirm_modal
        :if={@show_delete_confirm && @delete_source}
        source={@delete_source}
        species_count={assigns[:delete_species_count] || 0}
      />
    </.page>
    """
  end

  # -- Components --

  attr :source, :map, required: true
  attr :editor, :boolean, default: false

  defp source_card(assigns) do
    ~H"""
    <div class={["source-card", @editor && "can-edit"]}>
      <.link
        navigate={~p"/sources/#{@source.id}"}
        class="source-card-link"
        aria-label={@source.name}
      ></.link>
      <div class="source-card-body">
        <div class="source-card-header">
          <h2 class="source-card-name">{@source.name}</h2>
          <div class="source-card-header-right">
            <div :if={@editor} class="source-card-actions">
              <.link
                navigate={~p"/sources/#{@source.id}/edit"}
                class="source-action-btn source-action-edit"
                aria-label={"Edit #{@source.name}"}
              >
                Edit
              </.link>
              <button
                phx-click="request_delete"
                phx-value-id={@source.id}
                class="source-action-btn source-action-delete"
                aria-label={"Delete #{@source.name}"}
              >
                Delete
              </button>
            </div>
            <span :if={!@editor} class="source-card-arrow" aria-hidden="true"></span>
          </div>
        </div>
        <p :if={@source.description} class="source-card-desc">
          {@source.description}
        </p>
        <div class="source-card-footer">
          <div class="source-card-meta">
            <.status_tag :if={@source.source_type} class="capitalize">
              {@source.source_type}
            </.status_tag>
            <span :if={@source.author || @source.year} class="source-card-author">
              {@source.author}
              <span :if={@source.year}>({@source.year})</span>
            </span>
          </div>
          <span :if={@source.species_count > 0} class="source-card-count">
            {@source.species_count} species
          </span>
        </div>
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
end
