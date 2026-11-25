defmodule OaksWeb.SpeciesPhotos.ManagePhotos do
  @moduledoc """
  The Manage photos dialog on the species page: every photo of the species,
  ready, adding or failed, in order, where an editor captions, reorders
  (dragging a row's handle, or Up and Down on it), retries a failed import
  and deletes a photo, after the Delete photo confirmation
  (docs/species-photos-plan.md, Phase 5).

  Its rows are read from the database (`Oaks.Images.list_for_editor/1`), so
  reopening it shows imports as they stand; the page sends `refresh: true`
  when the species' photos change. Every write checks the editor's scope,
  and photo IDs from the browser are resolved against this species.
  """
  use OaksWeb, :live_component

  alias Oaks.Images
  alias Oaks.Images.{Attribution, Image}
  alias Oaks.Licenses

  @impl true
  def mount(socket) do
    {:ok, assign(socket, images: [], confirm_delete: nil, caption_errors: %{})}
  end

  @impl true
  def update(%{refresh: true}, socket), do: {:ok, load_images(socket)}

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(id: assigns.id, species: assigns.species, current_scope: assigns.current_scope)
     |> load_images()}
  end

  # -- Render --

  @impl true
  def render(%{confirm_delete: %Image{}} = assigns) do
    ~H"""
    <div id={"#{@id}-component"}>
      <.modal
        id={"#{@id}-delete"}
        show
        on_cancel={JS.push("cancel_delete_photo", target: @myself)}
      >
        <:title>Delete photo</:title>
        <p>
          Delete this photo from
          <.sci_name name={@species.scientific_name} hybrid={@species.is_hybrid} weight="regular" />?
        </p>
        <:note>Its files are removed from storage.</:note>
        <:note><strong>This can't be undone.</strong></:note>
        <:actions>
          <.button
            id={"#{@id}-delete-confirm"}
            variant="danger"
            phx-click="delete_photo"
            phx-target={@myself}
          >
            Delete photo
          </.button>
        </:actions>
      </.modal>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div id={"#{@id}-component"}>
      <.modal id={@id} show on_cancel={JS.push("close_photo_dialog")} cancel="Close">
        <:title>Manage photos</:title>
        <p :if={@images == []}>
          No photos yet. Add photos from iNaturalist from the Edit menu.
        </p>
        <p :if={@images != []}>Drag to reorder. The first photo leads the page.</p>
        <.photo_list
          :if={@images != []}
          id={"#{@id}-list"}
          on_reorder="reorder"
          target={@myself}
        >
          <.photo_row
            :for={{image, number} <- Enum.with_index(@images, 1)}
            id={"#{@id}-photo-#{image.id}"}
            photo_id={image.id}
            label={"Photo #{number}"}
            src={Image.url(image, :small)}
            muted={image.status != "ready"}
            on_delete={JS.push("request_delete_photo", value: %{id: image.id}, target: @myself)}
          >
            <form
              id={"#{@id}-caption-#{image.id}"}
              phx-change="save_caption"
              phx-submit="save_caption"
              phx-target={@myself}
            >
              <input type="hidden" name="image_id" value={image.id} />
              <.input
                id={"#{@id}-caption-#{image.id}-field"}
                name="caption"
                value={image.caption}
                placeholder="Caption"
                aria-label={"Caption of photo #{number}"}
                maxlength="2000"
                autocomplete="off"
                phx-debounce="blur"
                disabled={image.status != "ready"}
                errors={List.wrap(@caption_errors[image.id])}
              />
            </form>
            <:meta>
              <.photo_credit
                :if={image.status == "ready"}
                creator={image.creator}
                license={Attribution.license_label(image)}
                reserved={Licenses.needs_permission?(image.license)}
              />
              <.photo_status
                :if={image.status == "pending"}
                status="adding"
                error={image.last_error && "Trying again: #{image.last_error}"}
              />
              <.photo_status
                :if={image.status == "failed"}
                status="failed"
                error={image.last_error}
              >
                <:action>
                  <.button
                    type="button"
                    size="compact"
                    phx-click="retry"
                    phx-value-id={image.id}
                    phx-target={@myself}
                  >
                    Retry
                  </.button>
                </:action>
              </.photo_status>
            </:meta>
          </.photo_row>
        </.photo_list>
      </.modal>
    </div>
    """
  end

  # -- Events --

  @impl true
  def handle_event("save_caption", %{"image_id" => id, "caption" => caption}, socket) do
    with true <- editor?(socket),
         %Image{status: "ready"} = image <- Images.get_species_image(socket.assigns.species, id) do
      case Images.update_caption(image, caption, socket.assigns.current_scope) do
        {:ok, _image} ->
          {:noreply, socket |> clear_caption_error(image.id) |> load_images()}

        {:error, %Ecto.Changeset{}} ->
          {:noreply,
           put_caption_error(socket, image.id, "Keep the caption under 2,000 characters.")}

        {:error, _reason} ->
          {:noreply, load_images(socket)}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("reorder", %{"order" => order}, socket) when is_list(order) do
    # Refused orders (an ID not the species', a repeat) change nothing;
    # loading the photos again puts the rows back where they were.
    if editor?(socket), do: Images.reorder(socket.assigns.species, order)
    {:noreply, load_images(socket)}
  end

  def handle_event("retry", %{"id" => id}, socket) do
    if editor?(socket) do
      _ = Images.retry_import(socket.assigns.species, id, socket.assigns.current_scope)
      {:noreply, load_images(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("request_delete_photo", %{"id" => id}, socket) do
    with true <- editor?(socket),
         %Image{} = image <- Images.get_species_image(socket.assigns.species, id) do
      {:noreply, assign(socket, confirm_delete: image)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("cancel_delete_photo", _params, socket),
    do: {:noreply, socket |> assign(confirm_delete: nil) |> load_images()}

  def handle_event("delete_photo", _params, socket) do
    with true <- editor?(socket),
         %Image{id: id} <- socket.assigns.confirm_delete,
         %Image{} = image <- Images.get_species_image(socket.assigns.species, id) do
      _ = Images.delete(image)
      {:noreply, socket |> assign(confirm_delete: nil) |> load_images()}
    else
      _ -> {:noreply, socket |> assign(confirm_delete: nil) |> load_images()}
    end
  end

  # -- Helpers --

  defp editor?(socket), do: socket.assigns[:current_scope] != nil

  defp load_images(socket),
    do: assign(socket, images: Images.list_for_editor(socket.assigns.species))

  defp put_caption_error(socket, id, message),
    do: update(socket, :caption_errors, &Map.put(&1, id, message))

  defp clear_caption_error(socket, id),
    do: update(socket, :caption_errors, &Map.delete(&1, id))
end
