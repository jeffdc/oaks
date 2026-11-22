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
           |> put_flash(:error, "Can't delete: species have data from this source.")
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
      <:head>
        <.header>
          Data Sources
          <:subtitle>
            The Oak Compendium draws from multiple sources to provide comprehensive
            information about oak species.
          </:subtitle>
          <:actions :if={@current_scope}>
            <.edit_menu id="sources-edit-menu">
              <:item navigate={~p"/sources/new"} id="create-source-btn">Create source</:item>
            </.edit_menu>
          </:actions>
        </.header>
      </:head>

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
    <div class="source-card">
      <.link
        navigate={~p"/sources/#{@source.id}"}
        class="source-card-link"
        aria-label={@source.name}
      ></.link>
      <div class="source-card-body">
        <div class="source-card-header">
          <h2 class="source-card-name">{@source.name}</h2>
          <div class="source-card-header-right">
            <.edit_menu
              :if={@editor}
              id={"source-#{@source.id}-menu"}
              quiet
              aria_label={"Edit #{@source.name}"}
            >
              <:item navigate={~p"/sources/#{@source.id}/edit"}>Edit source</:item>
              <:item click="request_delete" values={%{id: @source.id}}>Delete source</:item>
            </.edit_menu>
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
    <.modal
      id="delete-source-modal"
      show
      on_cancel={JS.push("cancel_delete")}
      cancel={if @species_count > 0, do: "Close", else: "Cancel"}
    >
      <:title>{if @species_count > 0, do: "Can't delete source", else: "Delete source"}</:title>
      <p :if={@species_count == 0}>
        Delete <strong>{@source.name}</strong> from the Compendium?
      </p>
      <p :if={@species_count > 0}>
        {species_have(@species_count)} data from <strong>{@source.name}</strong>.
      </p>
      <:note :if={@species_count > 0}>Delete that data on each species' page first.</:note>
      <:note :if={@species_count == 0}><strong>This can't be undone.</strong></:note>
      <:actions :if={@species_count == 0}>
        <.button variant="danger" phx-click="confirm_delete" id="confirm-delete-source-btn">
          Delete source
        </.button>
      </:actions>
    </.modal>
    """
  end

  defp species_have(1), do: "1 species has"
  defp species_have(n), do: "#{n} species have"
end
