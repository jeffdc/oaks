defmodule OaksWeb.SourceDetailLive do
  @moduledoc """
  LiveView for displaying detailed information about a single data source.

  Shows source metadata (type, author, year, URL, ISBN) with description
  and notes, a coverage count, and a list of species associated with the source.
  An id that names no source raises `OaksWeb.NotFoundError`, a real 404.
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
       show_delete_confirm: false
     )}
  end

  @impl true
  def handle_params(%{"id" => id_str}, _uri, socket) do
    case Integer.parse(id_str) do
      {id, ""} ->
        load_source(socket, id)

      _ ->
        raise OaksWeb.NotFoundError, kind: :source
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
           |> put_flash(:error, "Can't delete: species have data from this source.")
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
      <:head :if={@source}>
        <.back navigate={~p"/sources"}>Back to sources</.back>
        <.source_header source={@source} editor={@current_scope != nil} />
      </:head>

      <article :if={@source}>
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

  attr :source, :any, required: true
  attr :editor, :boolean, default: false

  defp source_header(assigns) do
    ~H"""
    <.header id="source-title">
      <.work_title title={@source.name} />
      <:meta :if={@source.source_type}>
        <.status_tag class="capitalize">{@source.source_type}</.status_tag>
      </:meta>
      <:actions :if={@editor}>
        <.edit_menu id="source-edit-menu">
          <:item navigate={~p"/sources/#{@source.id}/edit"} id="edit-source-btn">Edit source</:item>
          <:item click="request_delete" id="delete-source-btn">Delete source</:item>
        </.edit_menu>
      </:actions>
    </.header>
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
    <section :if={@has_metadata} class="source-metadata-card">
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
      <.section_heading>Coverage</.section_heading>
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
      <.section_heading>Species with Data from This Source</.section_heading>
      <div class="source-species-grid">
        <.link
          :for={sp <- @species}
          navigate={~p"/species/#{sp.scientific_name}"}
          class="source-species-link"
        >
          <.sci_name name={sp.scientific_name} hybrid={sp.is_hybrid} abbreviate size="title" />
        </.link>
      </div>
    </section>
    """
  end

  # -- Data loading --

  defp load_source(socket, id) do
    case Sources.get_source(id) do
      nil ->
        raise OaksWeb.NotFoundError, kind: :source

      source ->
        species = Sources.get_species_for_source(id)

        {:noreply,
         assign(socket,
           source: source,
           species: species,
           page_title: source.name
         )}
    end
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

  # -- Helpers --
end
