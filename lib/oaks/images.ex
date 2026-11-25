defmodule Oaks.Images do
  @moduledoc """
  Species photos: importing them from iNaturalist observations, editing their
  captions and order, and removing them.

  An import reserves the photo (`pending`) and an attempt with paths of its
  own in one transaction, and enqueues `Oaks.Images.ImportWorker`, which
  downloads the photo, makes its variants, stores all five files and only
  then marks it `ready`. Only ready photos are public (`list_for_species/1`);
  editors also see pending and failed ones (`list_for_editor/1`).

  Removing photos (`delete/1`, a species' deletion or a merge's duplicates)
  deletes their rows and records a `Oaks.Images.Cleanup` of all their files
  in the same transaction; `Oaks.Images.CleanupWorker` deletes the files and
  invalidates their CDN paths after the transaction commits. Readers stop
  seeing a photo when its removal commits.

  Ported in part from gallformers' `Gallformers.Images`
  (docs/species-photos-plan.md, Phase 3).
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Oaks.Accounts.Scope
  alias Oaks.Accounts.User
  alias Oaks.Images.{Attribution, Cleanup, CleanupWorker, Image, ImportAttempt, ImportWorker}
  alias Oaks.INaturalist
  alias Oaks.INaturalist.{Observation, Photo}
  alias Oaks.Licenses
  alias Oaks.Repo
  alias Oaks.Species.Species
  alias Oaks.Storage.Images, as: ImageStorage

  @max_caption 2000

  @typedoc """
  What an import did with a photo: reserved it (`:queued`), found it already
  imported or importing (`:exists`, with its current state), or retried a
  failed import of it (`:retrying`).
  """
  @type import_result ::
          {:ok, {:queued | :exists | :retrying, Image.t()}} | {:error, import_error()}

  @type import_error ::
          :unauthorized
          | :not_in_observation
          | :all_rights_reserved
          | :missing_attribution
          | :invalid_photo_url
          | :unsupported_format
          | :species_not_found

  # -- Reading --

  @doc "A species' ready photos, in order: the ones the public sees."
  @spec list_for_species(Species.t() | integer()) :: [Image.t()]
  def list_for_species(species),
    do: species |> species_images() |> where(status: "ready") |> Repo.all()

  @doc "All of a species' photos, in order, including pending and failed imports."
  @spec list_for_editor(Species.t() | integer()) :: [Image.t()]
  def list_for_editor(species), do: species |> species_images() |> Repo.all()

  @doc """
  How many photos a species has, by status (`"pending"`, `"ready"`,
  `"failed"`; a status with none is left out).
  """
  @spec count_by_status(Species.t() | integer()) :: %{String.t() => pos_integer()}
  def count_by_status(species) do
    from(i in Image,
      where: i.species_id == ^species_id(species),
      group_by: i.status,
      select: {i.status, count(i.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  The species' photo with ID `image_id`, or nil when it has none: how a
  client-supplied ID is resolved, so it can't reach another species' photo.
  """
  @spec get_species_image(Species.t() | integer(), term()) :: Image.t() | nil
  def get_species_image(species, image_id) do
    case to_id(image_id) do
      {:ok, id} -> Repo.get_by(Image, id: id, species_id: species_id(species))
      :error -> nil
    end
  end

  @doc """
  The species' photos imported (or importing) from the given iNat photos, by
  iNat photo ID: what an editor reopening an observation sees as already
  imported, pending or failed.
  """
  @spec images_for_photos(Species.t() | integer(), [integer()]) :: %{integer() => Image.t()}
  def images_for_photos(species, inat_photo_ids) when is_list(inat_photo_ids) do
    from(i in Image,
      where: i.species_id == ^species_id(species) and i.inat_photo_id in ^inat_photo_ids
    )
    |> Repo.all()
    |> Map.new(&{&1.inat_photo_id, &1})
  end

  defp species_images(species) do
    from(i in Image,
      where: i.species_id == ^species_id(species),
      order_by: [asc: i.sort_order, asc: i.id]
    )
  end

  # -- Importing --

  @doc """
  Imports the photos with `photo_ids` from `observation` (as
  `Oaks.INaturalist.fetch_observation/1` fetched it) to `species`, as the
  scope's editor. Each photo is imported on its own (`import_inat_photo/4`):
  one failing doesn't stop the others. IDs not among the observation's
  photos are refused, so a client can only pick photos the server fetched.

  Returns each requested photo ID with its result, in the order given.
  """
  @spec import_inat_photos(Species.t(), Observation.t(), [term()], Scope.t() | nil) ::
          {:ok, [{term(), import_result()}]} | {:error, :unauthorized}
  def import_inat_photos(%Species{} = species, %Observation{} = observation, photo_ids, scope)
      when is_list(photo_ids) do
    with {:ok, _editor} <- editor(scope) do
      photos = Map.new(observation.photos, &{&1.id, &1})

      {:ok,
       for requested <- Enum.uniq(photo_ids) do
         {requested, import_requested(requested, photos, observation, species, scope)}
       end}
    end
  end

  defp import_requested(requested, photos, observation, species, scope) do
    with {:ok, id} <- to_id(requested),
         {:ok, photo} <- Map.fetch(photos, id) do
      import_inat_photo(photo, observation, species, scope)
    else
      :error -> {:error, :not_in_observation}
    end
  end

  @doc """
  Imports one photo of `observation` to `species`, as the scope's editor.

  Its attribution comes from the observation: the observer as creator, the
  photo's license (mapped again from iNat's code, so a photo struct can't
  claim a license iNat didn't give it) and the observation's URL. All Rights
  Reserved photos, which include any with no license or one not in
  `Oaks.Licenses`, are refused.

  A photo the species already has, ready or pending, is left as it is
  (`:exists`); a failed one is retried through the same photo (`:retrying`).
  """
  @spec import_inat_photo(Photo.t(), Observation.t(), Species.t(), Scope.t() | nil) ::
          import_result()
  def import_inat_photo(
        %Photo{} = photo,
        %Observation{} = observation,
        %Species{} = species,
        scope
      ) do
    with {:ok, editor} <- editor(scope),
         {:ok, attrs} <- inat_attrs(photo, observation),
         {:ok, extension} <- photo_extension(photo.original_url) do
      reserve(species, attrs, photo.original_url, extension, editor)
    end
  end

  defp inat_attrs(photo, observation) do
    license = INaturalist.map_license(photo.license_code)

    attrs = %{
      creator:
        observation.observer_login &&
          INaturalist.format_creator(observation.observer_login, observation.observer_name),
      license: license,
      licenselink: Licenses.url(license),
      sourcelink: observation.url,
      inat_observation_id: observation.id,
      inat_photo_id: photo.id
    }

    cond do
      not Licenses.importable?(license) -> {:error, :all_rights_reserved}
      not Attribution.attributed?(attrs) -> {:error, :missing_attribution}
      not is_integer(observation.id) or not is_integer(photo.id) -> {:error, :missing_attribution}
      true -> {:ok, attrs}
    end
  end

  defp photo_extension(url) when is_binary(url) do
    ext = url |> URI.parse() |> Map.get(:path, "") |> Path.extname()

    cond do
      not INaturalist.photo_url?(url) -> {:error, :invalid_photo_url}
      ImageStorage.supported_extension?(ext) -> {:ok, ext}
      true -> {:error, :unsupported_format}
    end
  end

  defp photo_extension(_url), do: {:error, :invalid_photo_url}

  defp reserve(species, attrs, photo_url, extension, editor) do
    Repo.transaction(fn ->
      case Repo.get_by(Image, species_id: species.id, inat_photo_id: attrs.inat_photo_id) do
        nil ->
          image = insert_image(species, attrs, editor)
          {:queued, start_attempt!(image, photo_url, extension)}

        %Image{status: "failed"} = image ->
          image =
            image
            |> Ecto.Changeset.change(Map.put(attrs, :lastchangedby, editor))
            |> Repo.update!()

          {:retrying, start_attempt!(image, photo_url, extension)}

        image ->
          {:exists, image}
      end
    end)
    |> case do
      {:ok, result} ->
        {:ok, result}

      # Another request reserved it first (the unique index).
      {:error, :already_reserved} ->
        {:ok,
         {:exists,
          Repo.get_by!(Image, species_id: species.id, inat_photo_id: attrs.inat_photo_id)}}

      {:error, :species_not_found} ->
        {:error, :species_not_found}
    end
  end

  defp insert_image(species, attrs, editor) do
    next =
      from(i in Image, where: i.species_id == ^species.id, select: max(i.sort_order))
      |> Repo.one()

    %Image{}
    |> Ecto.Changeset.change(
      Map.merge(attrs, %{
        species_id: species.id,
        sort_order: (next || -1) + 1,
        status: "pending",
        uploader: editor,
        lastchangedby: editor
      })
    )
    |> Ecto.Changeset.unique_constraint([:species_id, :inat_photo_id])
    |> Ecto.Changeset.foreign_key_constraint(:species_id)
    |> Repo.insert()
    |> case do
      {:ok, image} ->
        image

      {:error, %Ecto.Changeset{errors: errors}} ->
        Repo.rollback(if errors[:species_id], do: :species_not_found, else: :already_reserved)
    end
  end

  # A new attempt with paths of its own, made the photo's current one, and
  # its job: inserted in the caller's transaction, so the worker only sees
  # it once the reservation has committed.
  defp start_attempt!(image, photo_url, extension) do
    {:ok, original_path} = ImageStorage.original_path(image.species_id, extension)

    attempt =
      Repo.insert!(%ImportAttempt{
        image_id: image.id,
        original_path: original_path,
        photo_url: photo_url,
        state: "queued"
      })

    Oban.insert!(ImportWorker.new(%{attempt_id: attempt.id}))

    image
    |> Ecto.Changeset.change(status: "pending", last_error: nil, current_attempt_id: attempt.id)
    |> Repo.update!()
  end

  @doc """
  Retries a species' failed photo, as the scope's editor: a new attempt with
  fresh paths, so the cleanup of the failed attempt's files can't touch the
  new one's. `image_id` is resolved against the species.
  """
  @spec retry_import(Species.t() | integer(), term(), Scope.t() | nil) ::
          {:ok, Image.t()} | {:error, :unauthorized | :not_found | :not_failed}
  def retry_import(species, image_id, scope) do
    with {:ok, editor} <- editor(scope) do
      Repo.transaction(fn -> retry!(get_species_image(species, image_id), editor) end)
    end
  end

  defp retry!(%Image{status: "failed", current_attempt_id: attempt_id} = image, editor)
       when is_integer(attempt_id) do
    last = Repo.get!(ImportAttempt, attempt_id)

    image
    |> Ecto.Changeset.change(lastchangedby: editor)
    |> Repo.update!()
    |> start_attempt!(last.photo_url, Path.extname(last.original_path))
  end

  defp retry!(nil, _editor), do: Repo.rollback(:not_found)
  defp retry!(%Image{}, _editor), do: Repo.rollback(:not_failed)

  # -- Editing --

  @doc """
  Sets a photo's caption (blank clears it), as the scope's editor.
  """
  @spec update_caption(Image.t(), String.t() | nil, Scope.t() | nil) ::
          {:ok, Image.t()} | {:error, :unauthorized | :not_found | Ecto.Changeset.t()}
  def update_caption(%Image{} = image, caption, scope) do
    with {:ok, editor} <- editor(scope) do
      caption = blank_to_nil(caption)

      Repo.transaction(fn ->
        image.species_id |> get_species_image(image.id) |> save_caption(caption, editor)
      end)
    end
  end

  defp blank_to_nil(text) when is_binary(text) do
    case String.trim(text) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_text), do: nil

  defp save_caption(nil, _caption, _editor), do: Repo.rollback(:not_found)

  defp save_caption(image, caption, editor) do
    image
    |> Ecto.Changeset.change(caption: caption, lastchangedby: editor)
    |> Ecto.Changeset.validate_length(:caption, max: @max_caption)
    |> Repo.update()
    |> case do
      {:ok, updated} -> updated
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  @doc """
  Puts a species' photos in the order of `image_ids`; photos not listed keep
  their order after the listed ones (one imported since the editor's page
  loaded, say). Refuses IDs that aren't the species' photos, or repeats.
  """
  @spec reorder(Species.t() | integer(), [term()]) :: :ok | {:error, :invalid_ids}
  def reorder(species, image_ids) when is_list(image_ids) do
    Repo.transaction(fn ->
      current = species |> species_images() |> select([i], i.id) |> Repo.all()

      case listed_ids(image_ids, current) do
        {:ok, listed} -> put_order(listed ++ (current -- listed))
        :error -> Repo.rollback(:invalid_ids)
      end
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def reorder(_species, _image_ids), do: {:error, :invalid_ids}

  # The IDs as integers, if each is one of `current` and none repeats.
  defp listed_ids(image_ids, current) do
    ids = Enum.map(image_ids, &to_id/1)

    if Enum.all?(ids, &match?({:ok, _}, &1)) do
      listed = Enum.map(ids, fn {:ok, id} -> id end)
      if listed == Enum.uniq(listed) and listed -- current == [], do: {:ok, listed}, else: :error
    else
      :error
    end
  end

  defp put_order(ids) do
    ids
    |> Enum.with_index()
    |> Enum.each(fn {id, index} ->
      from(i in Image, where: i.id == ^id) |> Repo.update_all(set: [sort_order: index])
    end)
  end

  # -- Removing --

  @doc """
  Deletes a photo: its row goes and a cleanup of all its files is recorded,
  in one transaction. The files are removed after the transaction commits.
  """
  @spec delete(Image.t()) :: {:ok, Image.t()} | {:error, :not_found}
  def delete(%Image{} = image) do
    Repo.transaction(fn ->
      case Repo.get(Image, image.id) do
        nil ->
          Repo.rollback(:not_found)

        current ->
          remove_images!([current], "photo_deleted")
          current
      end
    end)
  end

  @doc """
  Adds to `multi` the removal of all of `species`' photos (see `delete/1`),
  for the species' deletion. It must come before the species is deleted:
  the database refuses to delete a species that still has photos.
  """
  @spec delete_species_images(Multi.t(), Species.t()) :: Multi.t()
  def delete_species_images(%Multi{} = multi, %Species{} = species) do
    Multi.run(multi, :delete_images, fn _repo, _changes ->
      images = list_for_editor(species)
      remove_images!(images, "species_deleted")
      {:ok, length(images)}
    end)
  end

  @doc """
  What merging `source`'s photos into `target`'s would do: the photos that
  move (in the order they'll follow the target's), and the duplicates (an
  iNat photo both have), each with the target's photo that wins and the
  source caption that would be discarded (nil when the source has none, or
  the same one).
  """
  @spec merge_preview(Species.t() | integer(), Species.t() | integer()) :: %{
          transfer: [Image.t()],
          duplicates: [
            %{source: Image.t(), target: Image.t(), discarded_caption: String.t() | nil}
          ]
        }
  def merge_preview(source, target) do
    {duplicates, transfer} = split_merge(source, target)
    %{transfer: transfer, duplicates: duplicates}
  end

  @doc """
  Adds to `multi` the merge of `source`'s photos into `target`'s, before
  `source` is deleted: photos the target lacks follow the target's own, in
  the source's order; duplicates of target photos are removed (the target's
  photo, caption and position win). Pending and failed imports move too.
  Stored files never move: a photo's path records where it was imported,
  not who owns it.
  """
  @spec merge_species_images(Multi.t(), Species.t(), Species.t()) :: Multi.t()
  def merge_species_images(%Multi{} = multi, %Species{} = source, %Species{} = target) do
    Multi.run(multi, :merge_images, fn _repo, _changes ->
      {duplicates, transfer} = split_merge(source, target)
      remove_images!(Enum.map(duplicates, & &1.source), "merge_duplicate")

      last =
        from(i in Image, where: i.species_id == ^target.id, select: max(i.sort_order))
        |> Repo.one()

      transfer
      |> Enum.with_index((last || -1) + 1)
      |> Enum.each(fn {image, sort_order} ->
        from(i in Image, where: i.id == ^image.id)
        |> Repo.update_all(set: [species_id: target.id, sort_order: sort_order])
      end)

      {:ok, %{moved: length(transfer), removed: length(duplicates)}}
    end)
  end

  defp split_merge(source, target) do
    target_photos = Map.new(list_for_editor(target), &{&1.inat_photo_id, &1})

    {duplicates, transfer} =
      source
      |> list_for_editor()
      |> Enum.split_with(&Map.has_key?(target_photos, &1.inat_photo_id))

    duplicates =
      for image <- duplicates do
        kept = Map.fetch!(target_photos, image.inat_photo_id)
        discarded = if image.caption not in [nil, kept.caption], do: image.caption
        %{source: image, target: kept, discarded_caption: discarded}
      end

    {duplicates, transfer}
  end

  # Deletes the photos' rows, cancels their unfinished attempts (a worker
  # still running one stops before its next write and can't publish), and
  # records and enqueues a cleanup of every file their attempts may have
  # stored. Runs in the caller's transaction.
  defp remove_images!(images, reason) do
    for image <- images do
      attempts =
        from(a in ImportAttempt,
          where: a.image_id == ^image.id and a.state in ["queued", "running", "published"]
        )
        |> Repo.all()

      from(a in ImportAttempt,
        where: a.image_id == ^image.id and a.state in ["queued", "running"]
      )
      |> Repo.update_all(set: [state: "cancelled", updated_at: DateTime.utc_now()])

      record_cleanup!(attempts, reason, image)
      Repo.delete!(image)
    end

    :ok
  end

  @doc false
  # Records and enqueues the cleanup of `attempts`' files, in the caller's
  # transaction (also used by Oaks.Images.ImportWorker when an attempt fails).
  @spec record_cleanup!([ImportAttempt.t()], String.t(), Image.t() | nil) :: Cleanup.t() | nil
  def record_cleanup!([], _reason, _image), do: nil

  def record_cleanup!(attempts, reason, image) do
    true = reason in Cleanup.reasons()

    cleanup =
      Repo.insert!(%Cleanup{
        paths: Enum.flat_map(attempts, &ImageStorage.all_paths(&1.original_path)),
        attempt_ids: Enum.map(attempts, & &1.id),
        reason: reason,
        image_id: image && image.id,
        species_id: image && image.species_id,
        state: "deleting"
      })

    Oban.insert!(CleanupWorker.new(%{cleanup_id: cleanup.id}))
    cleanup
  end

  # -- Helpers --

  defp editor(%Scope{user: %User{email: email}}) when is_binary(email) and email != "",
    do: {:ok, email}

  defp editor(_scope), do: {:error, :unauthorized}

  defp species_id(%Species{id: id}), do: id
  defp species_id(id) when is_integer(id), do: id

  defp to_id(id) when is_integer(id) and id > 0, do: {:ok, id}

  defp to_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} when int > 0 -> {:ok, int}
      _ -> :error
    end
  end

  defp to_id(_id), do: :error
end
