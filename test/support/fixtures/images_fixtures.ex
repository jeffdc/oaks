defmodule Oaks.ImagesFixtures do
  @moduledoc """
  Species photo test helpers: iNaturalist observations and a `Req.Test`
  stub serving them and their photos (no test reaches iNaturalist), real
  image bytes, photo store setup, and imported photos.
  """

  import Ecto.Query

  alias Oaks.Accounts.Scope
  alias Oaks.Images
  alias Oaks.Images.{Cleanup, ImportAttempt}
  # Image is the image library here; a species photo is Oaks.Images.Image.
  alias Oaks.INaturalist
  alias Oaks.Repo
  alias Oaks.Storage.Local
  alias Oaks.Storage.MockAdapter

  @fixture Path.expand("images/landscape_rotated.jpg", __DIR__)

  @doc "An editor's scope, for a new user."
  def editor_scope, do: Scope.for_user(Oaks.AccountsFixtures.user_fixture())

  @doc "The bytes of a real JPEG photo (2400 x 1600, tagged to rotate)."
  def photo_bytes, do: File.read!(@fixture)

  @doc "A small JPEG, quick to resize."
  def small_photo_bytes do
    {:ok, image} = Image.new(400, 300, color: :forest_green)
    {:ok, bytes} = Image.write(image, :memory, suffix: ".jpg")
    bytes
  end

  @doc "A unique iNaturalist ID."
  def unique_inat_id, do: System.unique_integer([:positive]) + 1_000_000

  @doc """
  An iNat photo as the API gives it, with a unique ID: license `cc-by-nc`
  unless `license_code` says otherwise (nil for All Rights Reserved).
  """
  def inat_photo_json(attrs \\ %{}) do
    id = attrs[:id] || unique_inat_id()

    %{
      "id" => id,
      "url" => "https://inaturalist-open-data.s3.amazonaws.com/photos/#{id}/square.jpg",
      "license_code" => Map.get(attrs, :license_code, "cc-by-nc")
    }
  end

  @doc """
  The API's response for one observation, with a unique ID and the given
  photos (by default two CC-BY-NC ones).
  """
  def observation_json(attrs \\ %{}) do
    id = attrs[:id] || unique_inat_id()

    %{
      "results" => [
        %{
          "id" => id,
          "taxon" => %{"id" => 54_779, "name" => "Quercus alba"},
          "user" => %{"login" => "janedoe", "name" => Map.get(attrs, :observer_name, "Jane Doe")},
          "observed_on" => "2026-05-04",
          "place_guess" => "Blue Ridge, VA",
          "quality_grade" => "research",
          "photos" => attrs[:photos] || [inat_photo_json(), inat_photo_json()]
        }
      ]
    }
  end

  @doc "The observation `json` parsed, as `Oaks.INaturalist` would give it."
  def observation(json \\ observation_json()) do
    {:ok, observation} = INaturalist.parse_observation_response(json)
    observation
  end

  @doc """
  Stubs iNaturalist: serves the observations given (their JSON) and every
  photo as `bytes`. `:photo_status` overrides a photo's response by iNat
  photo ID (a status code). Pass `test_pid` to be sent `{:inat_request,
  path}` for each request.
  """
  def stub_inat(observations, opts \\ []) do
    bytes = Keyword.get_lazy(opts, :bytes, &small_photo_bytes/0)
    statuses = Keyword.get(opts, :photo_status, %{})
    test_pid = Keyword.get(opts, :test_pid)

    by_id =
      Map.new(List.wrap(observations), fn %{"results" => [%{"id" => id} | _]} = json ->
        {Integer.to_string(id), json}
      end)

    Req.Test.stub(INaturalist, fn conn ->
      if test_pid, do: send(test_pid, {:inat_request, conn.request_path})
      respond(conn, String.split(conn.request_path, "/", trim: true), by_id, statuses, bytes)
    end)
  end

  defp respond(conn, ["v1", "observations", id], by_id, _statuses, _bytes) do
    Req.Test.json(conn, Map.get(by_id, id, %{"results" => []}))
  end

  defp respond(conn, ["photos", id, _file], _by_id, statuses, bytes) do
    case Map.fetch(statuses, String.to_integer(id)) do
      {:ok, status} ->
        Plug.Conn.send_resp(conn, status, "")

      :error ->
        conn |> Plug.Conn.put_resp_content_type("image/jpeg") |> Plug.Conn.send_resp(200, bytes)
    end
  end

  defp respond(conn, _path, _by_id, _statuses, _bytes), do: Plug.Conn.send_resp(conn, 404, "")

  @doc """
  Stores photos for real under `root` (`Oaks.Storage.Local` behind the
  storage mock), restoring the configured root when the test exits.
  """
  def use_local_storage(root) do
    config = Application.fetch_env!(:oaks, :images)
    Application.put_env(:oaks, :images, Keyword.put(config, :local_root, root))
    ExUnit.Callbacks.on_exit(fn -> Application.put_env(:oaks, :images, config) end)
    Mox.stub_with(MockAdapter, Local)
    :ok
  end

  @doc "The paths stored under the local root, in order."
  def stored_paths do
    {:ok, paths} = Local.list("")
    paths
  end

  @doc """
  Reserves (imports) one photo of `observation` to `species` as `scope`'s
  editor, the first one unless `photo` is given. Returns the pending image.
  """
  def import_photo(species, observation, scope, photo \\ nil) do
    photo = photo || hd(observation.photos)
    {:ok, {_, image}} = Images.import_inat_photo(photo, observation, species, scope)
    image
  end

  @doc "The image as stored now."
  def reload(%Oaks.Images.Image{id: id}), do: Repo.get(Oaks.Images.Image, id)

  @doc "The photo's current attempt."
  def current_attempt(%Oaks.Images.Image{} = image),
    do: Repo.get!(ImportAttempt, reload(image).current_attempt_id)

  @doc "Every attempt of a photo, oldest first."
  def attempts(%Oaks.Images.Image{id: id}),
    do: Repo.all(from(a in ImportAttempt, where: a.image_id == ^id, order_by: a.id))

  @doc "The cleanups recorded for a photo, oldest first."
  def cleanups_for(%Oaks.Images.Image{id: id}),
    do: Repo.all(from(c in Cleanup, where: c.image_id == ^id, order_by: c.id))

  @doc "Ends an attempt's lease, as when the run holding it died."
  def expire_lease(%ImportAttempt{id: id}) do
    past = DateTime.add(DateTime.utc_now(), -1, :second)
    from(a in ImportAttempt, where: a.id == ^id) |> Repo.update_all(set: [lease_until: past])
  end

  @doc "Deletes every job, as if they were lost, leaving the work recorded."
  def lose_jobs, do: Repo.delete_all(Oban.Job)
end
