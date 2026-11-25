defmodule OaksWeb.SpeciesPhotos.AddPhotos do
  @moduledoc """
  The Add photos dialog on the species page: an editor loads an iNaturalist
  observation, picks its photos and adds them to the species
  (docs/species-photos-plan.md, Phase 5; ported from gallformers'
  `InatImportComponent`).

  Its states: `:idle` (the observation field), `:loading`, `:loaded` (the
  observation's photos to pick from) and `:adding` (the picked photos and how
  their imports stand). Imports are durable work (`Oaks.Images`): closing the
  dialog doesn't stop them, and each photo's state is read from the database,
  so loading the observation again shows what was added, is adding or
  failed. The page sends `refresh: true` when the species' photos change.

  Only photos of the observation the server fetched can be picked, and an All
  Rights Reserved photo (stamped "All rights reserved", or "No license given"
  for a license iNat names that we don't know) is added only when the editor
  ticks the permission box. Every write checks the editor's scope.
  """
  use OaksWeb, :live_component

  alias Oaks.Images
  alias Oaks.INaturalist

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       state: :idle,
       query: "",
       load_error: nil,
       observation: nil,
       selected: MapSet.new(),
       permission: false,
       existing: %{},
       refused: %{},
       added: []
     )}
  end

  @impl true
  def update(%{refresh: true}, socket), do: {:ok, refresh_existing(socket)}

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(id: assigns.id, species: assigns.species, current_scope: assigns.current_scope)
     |> refresh_existing()}
  end

  # -- Render --

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-component"}>
      <.modal
        id={@id}
        show
        on_cancel={JS.push("close_photo_dialog")}
        cancel={if @state == :adding, do: "Close", else: "Cancel"}
      >
        <:title>Add photos from iNaturalist</:title>
        <p :if={@state in [:idle, :loading]}>
          Load an observation, then choose the photos to add to
          <.sci_name name={@species.scientific_name} hybrid={@species.is_hybrid} weight="regular" />.
        </p>

        <form
          :if={@state != :adding}
          id={"#{@id}-load"}
          phx-submit="load"
          phx-target={@myself}
        >
          <.input
            id={"#{@id}-observation"}
            name="observation"
            label="iNaturalist observation"
            value={@query}
            placeholder="Observation URL or number"
            autocomplete="off"
            errors={List.wrap(@load_error)}
          >
            <:action>
              <.button type="submit" disabled={@state == :loading}>
                {if @state == :loading, do: "Loading…", else: "Load"}
              </.button>
            </:action>
          </.input>
        </form>

        <p :if={@state == :loaded && @observation.photos == []}>
          This observation has no photos.
        </p>

        <form
          :if={@state == :loaded && @observation.photos != []}
          id={"#{@id}-pick"}
          phx-change="pick"
          phx-submit="add"
          phx-target={@myself}
        >
          <.photo_picker id={"#{@id}-photos"}>
            <:meta><.observation_meta observation={@observation} /></:meta>
            <.pick_tile
              :for={{photo, index} <- Enum.with_index(@observation.photos, 1)}
              photo={photo}
              index={index}
              image={@existing[photo.id]}
              selected={MapSet.member?(@selected, photo.id)}
              myself={@myself}
            />
          </.photo_picker>

          <.ruled_notice
            :if={reserved_numbers(@observation, @selected) != []}
            id={"#{@id}-permission"}
            class="mt-s4"
          >
            <.permission_text numbers={reserved_numbers(@observation, @selected)} />
            <:confirm>
              <.input
                id={"#{@id}-permission-box"}
                type="checkbox"
                name="permission"
                checked={@permission}
                label={permission_label(reserved_numbers(@observation, @selected))}
              />
            </:confirm>
          </.ruled_notice>
        </form>

        <.photo_picker
          :if={@state == :adding}
          id={"#{@id}-progress"}
          aria-live="polite"
        >
          <:meta><.observation_meta observation={@observation} /></:meta>
          <.progress_tile
            :for={{photo, index} <- @added}
            photo={photo}
            index={index}
            image={@existing[photo.id]}
            refused={@refused[photo.id]}
            myself={@myself}
          />
        </.photo_picker>

        <:note :if={@state == :adding}>
          Closing this doesn't stop the import. Photos appear on the page when they're ready;
          Manage photos shows any that failed.
        </:note>

        <:actions :if={@state == :loaded && @observation.photos != []}>
          <.button
            type="submit"
            form={"#{@id}-pick"}
            variant="primary"
            disabled={not can_add?(@observation, @selected, @permission)}
          >
            {add_label(MapSet.size(@selected))}
          </.button>
        </:actions>
      </.modal>
    </div>
    """
  end

  attr :numbers, :list, required: true

  defp permission_text(%{numbers: [number]} = assigns) do
    assigns = assign(assigns, :number, number)

    ~H"""
    <p>
      <strong>Photo {@number} is All rights reserved.</strong>
      Its creator keeps every right to it. Add it only if the creator has given the
      Oak Compendium permission. The page will say it is used with the creator's permission.
    </p>
    """
  end

  defp permission_text(assigns) do
    ~H"""
    <p>
      <strong>Photos {numbers_text(@numbers)} are All rights reserved.</strong>
      Their creator keeps every right to them. Add them only if the creator has given the
      Oak Compendium permission. The page will say they are used with the creator's permission.
    </p>
    """
  end

  defp permission_label([_one]), do: "The creator has given permission to use this photo."
  defp permission_label(_many), do: "The creator has given permission to use these photos."

  defp numbers_text(numbers) do
    {init, [last]} = Enum.split(numbers, -1)
    "#{Enum.join(init, ", ")} and #{last}"
  end

  attr :observation, :any, required: true

  defp observation_meta(assigns) do
    assigns = assign(assigns, :parts, meta_parts(assigns.observation))

    ~H"""
    {Enum.join(@parts, " · ")}
    <span :if={@observation.taxon_name}>
      {if @parts != [], do: "·"}
      <.sci_name name={@observation.taxon_name} genus={nil} weight="regular" />
    </span>
    """
  end

  defp meta_parts(observation) do
    [
      observer(observation),
      observation.place_guess,
      observation.observed_on && Date.to_iso8601(observation.observed_on)
    ]
    |> Enum.filter(&(is_binary(&1) and String.trim(&1) != ""))
  end

  defp observer(%{observer_name: name, observer_login: login}) do
    if is_binary(name) and String.trim(name) != "", do: name, else: login
  end

  attr :photo, :any, required: true
  attr :index, :integer, required: true
  attr :image, :any, default: nil
  attr :selected, :boolean, required: true
  attr :myself, :any, required: true

  # A photo the species doesn't have yet can be picked; one it has shows
  # where its import stands.
  defp pick_tile(%{image: nil} = assigns) do
    ~H"""
    <.photo_tile
      src={@photo.thumbnail_url}
      label={"Photo #{@index}, #{license_word(@photo)}"}
      name="photo_ids[]"
      value={@photo.id}
      checked={@selected}
    >
      <.status_tag :if={@photo.needs_permission?}>{license_word(@photo)}</.status_tag>
      <span :if={!@photo.needs_permission?}>{license_word(@photo)}</span>
    </.photo_tile>
    """
  end

  defp pick_tile(assigns) do
    ~H"""
    <.photo_tile src={@photo.thumbnail_url} label={"Photo #{@index}"} off={@image.status == "ready"}>
      <.image_status image={@image} ready="exists" myself={@myself} />
    </.photo_tile>
    """
  end

  attr :photo, :any, required: true
  attr :index, :integer, required: true
  attr :image, :any, default: nil
  attr :refused, :string, default: nil
  attr :myself, :any, required: true

  defp progress_tile(assigns) do
    ~H"""
    <.photo_tile src={@photo.thumbnail_url} label={"Photo #{@index}"}>
      <.image_status :if={@image} image={@image} ready="added" myself={@myself} />
      <.photo_status :if={!@image} status="failed" error={@refused} />
    </.photo_tile>
    """
  end

  attr :image, :any, required: true
  attr :ready, :string, required: true, doc: "the status word for a ready photo"
  attr :myself, :any, required: true

  defp image_status(assigns) do
    ~H"""
    <.photo_status :if={@image.status == "ready"} status={@ready} />
    <.photo_status :if={@image.status == "pending"} status="adding" />
    <.photo_status :if={@image.status == "failed"} status="failed" error={@image.last_error}>
      <:action>
        <.button
          type="button"
          size="compact"
          phx-click="retry"
          phx-value-id={@image.id}
          phx-target={@myself}
        >
          Retry
        </.button>
      </:action>
    </.photo_status>
    """
  end

  # -- Events --

  @impl true
  def handle_event("load", %{"observation" => input}, socket) do
    input = String.trim(input)

    cond do
      not editor?(socket) ->
        {:noreply, socket}

      match?({:error, _}, INaturalist.parse_observation_id(input)) ->
        {:noreply,
         assign(socket,
           query: input,
           load_error: "Enter an iNaturalist observation's address or number."
         )}

      true ->
        {:noreply,
         socket
         |> assign(state: :loading, query: input, load_error: nil)
         |> start_async(:fetch, fn -> INaturalist.fetch_observation(input) end)}
    end
  end

  def handle_event("pick", params, socket) do
    observation = socket.assigns.observation
    pickable = pickable_ids(observation, socket.assigns.existing)

    selected =
      params
      |> Map.get("photo_ids", [])
      |> List.wrap()
      |> Enum.flat_map(&parse_id/1)
      |> Enum.filter(&MapSet.member?(pickable, &1))
      |> MapSet.new()

    {:noreply, assign(socket, selected: selected, permission: params["permission"] == "true")}
  end

  def handle_event("add", _params, socket) do
    %{observation: observation, selected: selected, permission: permission} = socket.assigns

    with true <- editor?(socket),
         true <- can_add?(observation, selected, permission),
         ids = for(photo <- observation.photos, MapSet.member?(selected, photo.id), do: photo.id),
         {:ok, results} <-
           Images.import_inat_photos(
             socket.assigns.species,
             observation,
             ids,
             socket.assigns.current_scope,
             permission_confirmed: permission
           ) do
      refused = for {id, {:error, reason}} <- results, into: %{}, do: {id, refusal(reason)}
      indexed = Enum.with_index(observation.photos, 1)

      {:noreply,
       socket
       |> assign(
         state: :adding,
         refused: refused,
         added: for({photo, _} = pair <- indexed, MapSet.member?(selected, photo.id), do: pair),
         selected: MapSet.new(),
         permission: false
       )
       |> refresh_existing()}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("retry", %{"id" => image_id}, socket) do
    if editor?(socket) do
      # A refused retry (not this species' photo, not failed) changes nothing.
      _ = Images.retry_import(socket.assigns.species, image_id, socket.assigns.current_scope)
      {:noreply, refresh_existing(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_async(:fetch, {:ok, {:ok, observation}}, socket) do
    {:noreply,
     socket
     |> assign(
       state: :loaded,
       observation: observation,
       selected: MapSet.new(),
       permission: false
     )
     |> refresh_existing()}
  end

  def handle_async(:fetch, {:ok, {:error, reason}}, socket),
    do: {:noreply, assign(socket, state: :idle, load_error: fetch_error(reason))}

  def handle_async(:fetch, {:exit, _reason}, socket),
    do: {:noreply, assign(socket, state: :idle, load_error: fetch_error(:exit))}

  # -- Helpers --

  defp editor?(socket), do: socket.assigns[:current_scope] != nil

  # The species' photos from this observation's photos, by iNat photo ID.
  defp refresh_existing(%{assigns: %{observation: %{photos: photos}}} = socket) do
    existing = Images.images_for_photos(socket.assigns.species, Enum.map(photos, & &1.id))
    pickable = pickable_ids(socket.assigns.observation, existing)
    selected = MapSet.intersection(socket.assigns.selected, pickable)
    assign(socket, existing: existing, selected: selected)
  end

  defp refresh_existing(socket), do: socket

  defp pickable_ids(nil, _existing), do: MapSet.new()

  defp pickable_ids(observation, existing) do
    for photo <- observation.photos, not Map.has_key?(existing, photo.id), into: MapSet.new() do
      photo.id
    end
  end

  defp can_add?(nil, _selected, _permission), do: false

  defp can_add?(observation, selected, permission) do
    MapSet.size(selected) > 0 and (permission or reserved_numbers(observation, selected) == [])
  end

  # The numbers (as the dialog counts the observation's photos) of the
  # picked photos that need the creator's permission.
  defp reserved_numbers(observation, selected) do
    for {photo, number} <- Enum.with_index(observation.photos, 1),
        photo.needs_permission? and MapSet.member?(selected, photo.id),
        do: number
  end

  defp license_word(%{unrecognized_license?: true}), do: "No license given"
  defp license_word(%{needs_permission?: true}), do: "All rights reserved"
  defp license_word(photo), do: photo.mapped_license

  defp add_label(0), do: "Add photos"
  defp add_label(1), do: "Add 1 photo"
  defp add_label(n), do: "Add #{n} photos"

  defp parse_id(text) when is_binary(text) do
    case Integer.parse(text) do
      {id, ""} -> [id]
      _ -> []
    end
  end

  defp parse_id(_text), do: []

  defp fetch_error(:invalid_input), do: "Enter an iNaturalist observation's address or number."
  defp fetch_error(:not_found), do: "iNaturalist has no observation with that number."
  defp fetch_error(_reason), do: "Couldn't reach iNaturalist. Try again."

  defp refusal(:permission_required), do: "Needs the creator's permission."
  defp refusal(:missing_attribution), do: "iNaturalist names no observer to credit."
  defp refusal(:invalid_photo_url), do: "The photo isn't on iNaturalist's photo hosts."
  defp refusal(:unsupported_format), do: "The photo's format can't be stored."
  defp refusal(:not_in_observation), do: "Not one of this observation's photos."
  defp refusal(:species_not_found), do: "This species no longer exists."
  defp refusal(_reason), do: "Couldn't add the photo."
end
