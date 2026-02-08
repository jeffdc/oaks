defmodule OaksWeb.SourceFormLive do
  @moduledoc """
  LiveView for creating and editing sources.

  Requires authentication — unauthenticated users are redirected
  to the sources list with a flash message.
  """

  use OaksWeb, :live_view

  alias Oaks.Sources
  alias Oaks.Sources.Source

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       source: nil,
       form: nil
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    cond do
      socket.assigns[:authenticated] ->
        {:noreply, apply_action(socket, socket.assigns.live_action, params)}

      connected?(socket) ->
        {:noreply,
         socket
         |> put_flash(:error, "You must be authenticated to manage sources.")
         |> push_navigate(to: ~p"/sources")}

      true ->
        {:noreply, socket}
    end
  end

  defp apply_action(socket, :new, _params) do
    source = %Source{}
    changeset = Sources.change_source(source)

    socket
    |> assign(
      page_title: "New Source",
      source: source,
      form: to_form(changeset)
    )
  end

  defp apply_action(socket, :edit, %{"id" => id_str}) do
    with {id, ""} <- Integer.parse(id_str),
         %{} = source <- Sources.get_source(id) do
      changeset = Sources.change_source(source)

      socket
      |> assign(
        page_title: "Edit #{source.name}",
        source: source,
        form: to_form(changeset)
      )
    else
      nil ->
        socket
        |> put_flash(:error, "Source not found.")
        |> push_navigate(to: ~p"/sources")

      _ ->
        socket
        |> put_flash(:error, "Invalid source ID.")
        |> push_navigate(to: ~p"/sources")
    end
  end

  @impl true
  def handle_event("validate", %{"source" => source_params}, socket) do
    if socket.assigns[:authenticated] do
      changeset =
        socket.assigns.source
        |> Sources.change_source(source_params)
        |> Map.put(:action, :validate)

      {:noreply, assign(socket, form: to_form(changeset))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("save", %{"source" => source_params}, socket) do
    if socket.assigns[:authenticated] do
      save_source(socket, socket.assigns.live_action, source_params)
    else
      {:noreply,
       socket
       |> put_flash(:error, "You must be authenticated to manage sources.")
       |> push_navigate(to: ~p"/sources")}
    end
  end

  defp save_source(socket, :new, source_params) do
    case Sources.create_source(source_params) do
      {:ok, source} ->
        {:noreply,
         socket
         |> put_flash(:info, "Source created.")
         |> push_navigate(to: ~p"/sources/#{source.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_source(socket, :edit, source_params) do
    case Sources.update_source(socket.assigns.source, source_params) do
      {:ok, source} ->
        {:noreply,
         socket
         |> put_flash(:info, "Source updated.")
         |> push_navigate(to: ~p"/sources/#{source.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div :if={@form == nil} class="max-w-3xl mx-auto py-12 text-center">
      <p style="color: var(--color-text-tertiary);">Loading...</p>
    </div>

    <div :if={@form} class="max-w-3xl mx-auto">
      <.link
        navigate={cancel_path(@live_action, @source)}
        class="inline-flex items-center gap-1 text-sm mb-4"
        style="color: var(--color-forest-700);"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back
      </.link>

      <h1
        class="text-2xl font-bold mb-6"
        style="font-family: var(--font-serif); color: var(--color-forest-800);"
      >
        {@page_title}
      </h1>

      <.form for={@form} id="source-form" phx-change="validate" phx-submit="save">
        <div class="space-y-6">
          <div class="card p-6">
            <h2 class="section-title section-title-sm mb-4">Source Information</h2>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div class="sm:col-span-2">
                <.input
                  field={@form[:name]}
                  type="text"
                  label="Name"
                  placeholder="e.g. The Sibley Guide to Trees"
                  phx-debounce="300"
                />
              </div>
              <div>
                <.input
                  field={@form[:source_type]}
                  type="select"
                  label="Type"
                  options={source_type_options()}
                  prompt="Select type..."
                />
              </div>
              <div>
                <.input
                  field={@form[:author]}
                  type="text"
                  label="Author"
                  placeholder="e.g. David Allen Sibley"
                  phx-debounce="300"
                />
              </div>
              <div>
                <.input
                  field={@form[:year]}
                  type="number"
                  label="Year"
                  placeholder="e.g. 2009"
                  phx-debounce="300"
                />
              </div>
              <div>
                <.input
                  field={@form[:isbn]}
                  type="text"
                  label="ISBN"
                  placeholder="e.g. 978-0-375-415197"
                  phx-debounce="300"
                />
              </div>
              <div>
                <.input
                  field={@form[:doi]}
                  type="text"
                  label="DOI"
                  phx-debounce="300"
                />
              </div>
              <div>
                <.input
                  field={@form[:license]}
                  type="text"
                  label="License"
                  placeholder="e.g. CC BY 4.0"
                  phx-debounce="300"
                />
              </div>
              <div class="sm:col-span-2">
                <.input
                  field={@form[:url]}
                  type="text"
                  label="Website URL"
                  placeholder="e.g. https://example.com"
                  phx-debounce="300"
                />
              </div>
              <div class="sm:col-span-2">
                <.input
                  field={@form[:license_url]}
                  type="text"
                  label="License URL"
                  phx-debounce="300"
                />
              </div>
            </div>
          </div>

          <div class="card p-6">
            <h2 class="section-title section-title-sm mb-4">Description & Notes</h2>
            <div class="space-y-4">
              <.input
                field={@form[:description]}
                type="textarea"
                label="Description"
                placeholder="A brief description of this source..."
                phx-debounce="300"
              />
              <.input
                field={@form[:notes]}
                type="textarea"
                label="Notes"
                placeholder="Internal notes about how this source is used..."
                phx-debounce="300"
              />
            </div>
          </div>

          <div class="flex items-center justify-end gap-3">
            <.link
              navigate={cancel_path(@live_action, @source)}
              class="px-4 py-2 rounded-lg text-sm font-medium"
              style="color: var(--color-text-secondary);"
            >
              Cancel
            </.link>
            <button
              type="submit"
              phx-disable-with="Saving..."
              class="px-6 py-2 rounded-lg text-sm font-medium text-white"
              style="background-color: var(--color-forest-600);"
            >
              {if @live_action == :new, do: "Create Source", else: "Save Changes"}
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  defp cancel_path(:new, _source), do: ~p"/sources"

  defp cancel_path(:edit, source), do: ~p"/sources/#{source.id}"

  defp source_type_options do
    [
      {"Book", "Book"},
      {"Website", "Website"},
      {"Journal Article", "Journal Article"},
      {"Personal Observation", "Personal Observation"},
      {"Database", "Database"},
      {"Other", "Other"}
    ]
  end
end
