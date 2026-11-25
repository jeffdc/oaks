defmodule Oaks.ImagesTest do
  # Workers run in the test process (Oban.Testing), with iNaturalist stubbed
  # (Req.Test) and photos stored for real under tmp_dir (Oaks.Storage.Local
  # behind the storage mock); failures are injected through the mock.
  use Oaks.DataCase
  use Oban.Testing, repo: Oaks.Repo, engine: Oban.Engines.Lite

  import Mox
  import Oaks.ImagesFixtures
  import Oaks.SpeciesFixtures

  alias Oaks.Images
  alias Oaks.Images.{Cleanup, CleanupWorker, Image, ImportAttempt, ImportWorker, RecoveryWorker}
  alias Oaks.Storage.Images, as: ImageStorage
  alias Oaks.Storage.Local
  alias Oaks.Storage.MockAdapter

  @moduletag :tmp_dir
  @moduletag :capture_log

  setup :verify_on_exit!

  setup %{tmp_dir: tmp_dir} do
    use_local_storage(tmp_dir)
    json = observation_json()
    stub_inat(json)

    %{
      species: species_fixture(),
      json: json,
      observation: observation(json),
      scope: editor_scope()
    }
  end

  defp run_import(image),
    do: perform_job(ImportWorker, %{attempt_id: reload(image).current_attempt_id})

  defp run_cleanup(%Cleanup{id: id}), do: perform_job(CleanupWorker, %{cleanup_id: id})

  describe "import_inat_photos/4" do
    test "reserves each picked photo, hidden, with the observation's attribution", ctx do
      [first, second] = ctx.observation.photos

      assert {:ok, [{a, {:ok, {:queued, one}}}, {b, {:ok, {:queued, two}}}]} =
               Images.import_inat_photos(
                 ctx.species,
                 ctx.observation,
                 [first.id, "#{second.id}"],
                 ctx.scope
               )

      assert {a, b} == {first.id, "#{second.id}"}

      for {image, photo, order} <- [{one, first, 0}, {two, second, 1}] do
        assert image.status == "pending"
        assert image.path == nil
        assert image.sort_order == order
        assert image.species_id == ctx.species.id
        assert image.inat_photo_id == photo.id
        assert image.inat_observation_id == ctx.observation.id
        assert image.creator == "janedoe - Jane Doe"
        assert image.license == "CC-BY-NC"
        assert image.licenselink == "https://creativecommons.org/licenses/by-nc/4.0/"
        assert image.sourcelink == ctx.observation.url
        assert image.uploader == ctx.scope.user.email
        assert image.lastchangedby == ctx.scope.user.email
        assert_enqueued(worker: ImportWorker, args: %{attempt_id: image.current_attempt_id})
      end

      assert Images.list_for_species(ctx.species) == []
      assert Enum.map(Images.list_for_editor(ctx.species), & &1.id) == [one.id, two.id]
      assert Images.count_by_status(ctx.species) == %{"pending" => 2}
    end

    test "gives every attempt paths of its own under the species", ctx do
      image = import_photo(ctx.species, ctx.observation, ctx.scope)
      attempt = current_attempt(image)

      assert attempt.state == "queued"

      assert attempt.original_path =~
               ~r"\Aspecies/#{ctx.species.id}/#{ctx.species.id}_\d+_[0-9a-f]{10}_original\.jpg\z"

      assert attempt.photo_url == hd(ctx.observation.photos).original_url
    end

    test "refuses a logged-out caller and writes nothing", ctx do
      photo = hd(ctx.observation.photos)

      assert Images.import_inat_photos(ctx.species, ctx.observation, [photo.id], nil) ==
               {:error, :unauthorized}

      assert Images.import_inat_photo(photo, ctx.observation, ctx.species, %Oaks.Accounts.Scope{}) ==
               {:error, :unauthorized}

      assert Images.list_for_editor(ctx.species) == []
      refute_enqueued(worker: ImportWorker)
    end

    test "refuses photo IDs the server didn't fetch for the observation", ctx do
      assert {:ok, results} =
               Images.import_inat_photos(
                 ctx.species,
                 ctx.observation,
                 [123, "x", nil, -1],
                 ctx.scope
               )

      assert Enum.all?(results, &match?({_, {:error, :not_in_observation}}, &1))
      assert Images.list_for_editor(ctx.species) == []
    end

    test "refuses All Rights Reserved, missing and unknown licenses, whatever the photo claims",
         ctx do
      photos =
        for code <- [nil, "gpl", "all-rights-reserved"],
            do: inat_photo_json(%{license_code: code})

      observation = observation(observation_json(%{photos: photos}))

      for photo <- observation.photos do
        assert Images.import_inat_photo(photo, observation, ctx.species, ctx.scope) ==
                 {:error, :all_rights_reserved}

        # A struct claiming a license iNat didn't give it is mapped again.
        forged = %{photo | mapped_license: "CC-BY", all_rights_reserved?: false}

        assert Images.import_inat_photo(forged, observation, ctx.species, ctx.scope) ==
                 {:error, :all_rights_reserved}
      end

      assert Images.list_for_editor(ctx.species) == []
    end

    test "refuses photos with no observer to credit, or not on iNaturalist's hosts", ctx do
      observation = %{ctx.observation | observer_login: nil}
      [photo | _] = ctx.observation.photos

      assert Images.import_inat_photo(photo, observation, ctx.species, ctx.scope) ==
               {:error, :missing_attribution}

      elsewhere = %{photo | original_url: "https://example.com/photos/1/original.jpg"}

      assert Images.import_inat_photo(elsewhere, ctx.observation, ctx.species, ctx.scope) ==
               {:error, :invalid_photo_url}

      gif = %{photo | original_url: "https://static.inaturalist.org/photos/1/original.gif"}

      assert Images.import_inat_photo(gif, ctx.observation, ctx.species, ctx.scope) ==
               {:error, :unsupported_format}
    end

    test "importing a photo again reports it as it is and makes no second photo", ctx do
      photo = hd(ctx.observation.photos)
      image = import_photo(ctx.species, ctx.observation, ctx.scope)

      assert {:ok, {:exists, %Image{id: id, status: "pending"}}} =
               Images.import_inat_photo(photo, ctx.observation, ctx.species, editor_scope())

      assert id == image.id
      assert :ok = run_import(image)

      assert {:ok, [{_, {:ok, {:exists, %Image{status: "ready"}}}}]} =
               Images.import_inat_photos(ctx.species, ctx.observation, [photo.id], ctx.scope)

      assert length(Images.list_for_editor(ctx.species)) == 1
      assert length(all_enqueued(worker: ImportWorker)) == 1
    end

    test "the database keeps one photo per species and iNat photo, whatever its state", ctx do
      image = import_photo(ctx.species, ctx.observation, ctx.scope)

      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%{image | id: nil, status: "failed", current_attempt_id: nil})
      end
    end

    test "the same iNat photo can belong to two species", ctx do
      other = species_fixture()
      import_photo(ctx.species, ctx.observation, ctx.scope)

      assert {:ok, {:queued, _}} =
               Images.import_inat_photo(
                 hd(ctx.observation.photos),
                 ctx.observation,
                 other,
                 ctx.scope
               )
    end

    test "each photo stands alone: a refused one doesn't stop the rest", ctx do
      photos = [inat_photo_json(), inat_photo_json(%{license_code: nil})]
      observation = observation(observation_json(%{photos: photos}))
      [ok, refused] = observation.photos

      assert {:ok, [{_, {:ok, {:queued, _}}}, {_, {:error, :all_rights_reserved}}]} =
               Images.import_inat_photos(ctx.species, observation, [ok.id, refused.id], ctx.scope)
    end
  end

  describe "the import worker" do
    test "stores the original and four real variants, then publishes the photo", ctx do
      stub_inat(ctx.json, bytes: photo_bytes())
      image = import_photo(ctx.species, ctx.observation, ctx.scope)
      attempt = current_attempt(image)

      assert :ok = run_import(image)

      paths = ImageStorage.all_paths(attempt.original_path)
      assert stored_paths() == Enum.sort(paths)
      assert File.read!(Path.join(Local.root(), attempt.original_path)) == photo_bytes()

      for {size, longest} <- ImageStorage.variant_sizes() do
        {:ok, variant} =
          Local.root()
          |> Path.join(ImageStorage.variant_path(attempt.original_path, size))
          |> Elixir.Image.open()

        assert max(Elixir.Image.width(variant), Elixir.Image.height(variant)) == longest
      end

      ready = reload(image)
      assert ready.status == "ready"
      assert ready.path == attempt.original_path
      assert ready.last_error == nil

      assert Oaks.Images.Image.url(ready, :medium) ==
               ImageStorage.variant_url(attempt.original_path, :medium)

      assert [%Image{id: id}] = Images.list_for_species(ctx.species)
      assert id == image.id

      assert %ImportAttempt{state: "published", lease_until: nil, tries: 1} =
               Repo.get(ImportAttempt, attempt.id)
    end

    test "retries a transient download failure, showing it to editors meanwhile", ctx do
      [photo | _] = ctx.observation.photos
      stub_inat(ctx.json, photo_status: %{photo.id => 503})
      image = import_photo(ctx.species, ctx.observation, ctx.scope)

      assert {:error, message} = run_import(image)
      assert message =~ "HTTP 503"

      pending = reload(image)
      assert pending.status == "pending"
      assert pending.last_error == message
      assert Images.list_for_species(ctx.species) == []
      assert %ImportAttempt{state: "queued", lease_until: nil} = current_attempt(image)

      stub_inat(ctx.json)
      assert :ok = run_import(image)
      assert %Image{status: "ready", last_error: nil} = reload(image)
    end

    test "fails at once when iNaturalist no longer has the photo, and cleans up its paths", ctx do
      [photo | _] = ctx.observation.photos
      stub_inat(ctx.json, photo_status: %{photo.id => 404})
      image = import_photo(ctx.species, ctx.observation, ctx.scope)
      attempt = current_attempt(image)

      assert {:cancel, message} = run_import(image)
      assert message =~ "no longer has this photo"

      assert %Image{status: "failed", last_error: ^message, path: nil} = reload(image)
      assert %ImportAttempt{state: "failed"} = Repo.get(ImportAttempt, attempt.id)

      assert [%Cleanup{reason: "import_failed"} = cleanup] = cleanups_for(image)
      assert cleanup.paths == ImageStorage.all_paths(attempt.original_path)
      assert cleanup.attempt_ids == [attempt.id]
      assert_enqueued(worker: CleanupWorker, args: %{cleanup_id: cleanup.id})
    end

    test "fails a photo whose bytes aren't an image", ctx do
      stub_inat(ctx.json, bytes: "not an image")
      image = import_photo(ctx.species, ctx.observation, ctx.scope)

      assert {:cancel, "The photo couldn't be read as an image."} = run_import(image)
      assert %Image{status: "failed"} = reload(image)
      assert stored_paths() == []
    end

    test "a partial upload stays hidden, and its last try fails and removes what was stored",
         ctx do
      image = import_photo(ctx.species, ctx.observation, ctx.scope)
      attempt = current_attempt(image)

      stub(MockAdapter, :put, fn path, data, type ->
        if String.contains?(path, "_large."),
          do: {:error, :timeout},
          else: Local.put(path, data, type)
      end)

      for _try <- 1..(ImportWorker.max_tries() - 1) do
        assert {:error, "Couldn't store the photo: :timeout"} = run_import(image)
        assert %Image{status: "pending"} = reload(image)
      end

      # Original, small and medium were stored before the large failed.
      assert length(stored_paths()) == 3
      assert Images.list_for_species(ctx.species) == []

      assert {:cancel, _} = run_import(image)
      assert %Image{status: "failed"} = reload(image)
      assert %ImportAttempt{tries: 5} = Repo.get(ImportAttempt, attempt.id)

      [cleanup] = cleanups_for(image)
      assert :ok = run_cleanup(cleanup)
      assert stored_paths() == []
      assert %Cleanup{state: "done"} = Repo.get(Cleanup, cleanup.id)
    end

    test "a run that died after storing every file is resumed at restart and only publishes",
         ctx do
      image = import_photo(ctx.species, ctx.observation, ctx.scope)
      attempt = current_attempt(image)

      # The run claimed the attempt and stored all five files, then the app
      # stopped before it could publish.
      for path <- ImageStorage.all_paths(attempt.original_path),
          do: :ok = Local.put(path, "x", "image/jpeg")

      attempt
      |> Ecto.Changeset.change(
        state: "running",
        lease_token: "dead",
        lease_until: DateTime.add(DateTime.utc_now(), -1),
        tries: 1,
        stored_at: DateTime.utc_now()
      )
      |> Repo.update!()

      lose_jobs()
      Req.Test.stub(Oaks.INaturalist, fn _conn -> flunk("no download needed") end)

      assert %{attempts: 1} = RecoveryWorker.resume()
      assert :ok = run_import(image)
      assert %Image{status: "ready"} = reload(image)
      assert %ImportAttempt{state: "published", tries: 2} = Repo.get(ImportAttempt, attempt.id)
    end

    test "a second run waits while the first holds the attempt, then takes over a dead one",
         ctx do
      image = import_photo(ctx.species, ctx.observation, ctx.scope)
      attempt = current_attempt(image)
      assert {:ok, %ImportAttempt{state: "running"} = claimed} = ImportWorker.claim(attempt.id)

      assert {:snooze, seconds} = run_import(image)
      assert seconds > 60
      assert stored_paths() == []

      expire_lease(claimed)
      assert :ok = run_import(image)
      assert %Image{status: "ready"} = reload(image)
    end

    test "an attempt out of tries after a crash fails at the next sweep", ctx do
      image = import_photo(ctx.species, ctx.observation, ctx.scope)
      attempt = current_attempt(image)

      attempt
      |> Ecto.Changeset.change(state: "running", lease_until: DateTime.utc_now(), tries: 5)
      |> Repo.update!()

      RecoveryWorker.resume()

      assert %Image{status: "failed", last_error: "Gave up after 5 tries."} = reload(image)
      assert [%Cleanup{reason: "import_failed"}] = cleanups_for(image)
    end

    test "photos of one observation succeed or fail on their own", ctx do
      [good, bad] = ctx.observation.photos
      stub_inat(ctx.json, photo_status: %{bad.id => 404})

      {:ok, results} =
        Images.import_inat_photos(ctx.species, ctx.observation, [good.id, bad.id], ctx.scope)

      for {_, {:ok, {:queued, image}}} <- results, do: run_import(image)

      assert %{good.id => "ready", bad.id => "failed"} ==
               ctx.species
               |> Images.images_for_photos([good.id, bad.id])
               |> Map.new(fn {id, image} -> {id, image.status} end)
    end
  end

  describe "retry_import/3" do
    setup ctx do
      [photo | _] = ctx.observation.photos
      stub_inat(ctx.json, photo_status: %{photo.id => 404})
      image = import_photo(ctx.species, ctx.observation, ctx.scope)
      {:cancel, _} = run_import(image)
      stub_inat(ctx.json)
      %{failed: reload(image)}
    end

    test "retries through the same photo with fresh paths the old cleanup can't touch", ctx do
      old = current_attempt(ctx.failed)
      [old_cleanup] = cleanups_for(ctx.failed)

      assert {:ok, %Image{id: id, status: "pending", last_error: nil}} =
               Images.retry_import(ctx.species, "#{ctx.failed.id}", ctx.scope)

      assert id == ctx.failed.id
      new = current_attempt(ctx.failed)
      assert new.id != old.id
      assert new.original_path != old.original_path
      assert new.photo_url == old.photo_url

      assert :ok = run_import(ctx.failed)
      assert %Image{status: "ready"} = reload(ctx.failed)

      assert :ok = run_cleanup(old_cleanup)
      assert stored_paths() == Enum.sort(ImageStorage.all_paths(new.original_path))
    end

    test "importing a failed photo again retries it", ctx do
      photo = hd(ctx.observation.photos)

      assert {:ok, {:retrying, %Image{status: "pending"}}} =
               Images.import_inat_photo(photo, ctx.observation, ctx.species, ctx.scope)

      assert length(attempts(ctx.failed)) == 2
    end

    test "refuses logged-out callers, other species' photos and photos that didn't fail", ctx do
      assert Images.retry_import(ctx.species, ctx.failed.id, nil) == {:error, :unauthorized}

      assert Images.retry_import(species_fixture(), ctx.failed.id, ctx.scope) ==
               {:error, :not_found}

      assert Images.retry_import(ctx.species, "nope", ctx.scope) == {:error, :not_found}

      {:ok, _} = Images.retry_import(ctx.species, ctx.failed.id, ctx.scope)
      assert Images.retry_import(ctx.species, ctx.failed.id, ctx.scope) == {:error, :not_failed}
      assert length(attempts(ctx.failed)) == 2
    end
  end

  describe "update_caption/3 and reorder/2" do
    setup ctx do
      images =
        for photo <- ctx.observation.photos,
            do: import_photo(ctx.species, ctx.observation, ctx.scope, photo)

      %{images: images}
    end

    test "sets and clears a caption as the editor", %{images: [image | _]} = ctx do
      other = editor_scope()

      assert {:ok, %Image{caption: "Acorns", lastchangedby: by}} =
               Images.update_caption(image, "  Acorns ", other)

      assert by == other.user.email
      assert {:ok, %Image{caption: nil}} = Images.update_caption(image, "  ", ctx.scope)

      assert {:error, %Ecto.Changeset{}} =
               Images.update_caption(image, String.duplicate("a", 2001), ctx.scope)
    end

    test "refuses a logged-out caller and a photo gone or of another species",
         %{images: [image | _]} = ctx do
      assert Images.update_caption(image, "x", nil) == {:error, :unauthorized}

      assert Images.update_caption(%{image | species_id: species_fixture().id}, "x", ctx.scope) ==
               {:error, :not_found}

      assert reload(image).caption == nil
    end

    test "reorders, keeping unlisted photos after the listed ones", %{images: [a, b]} = ctx do
      c = import_photo(ctx.species, observation(), ctx.scope)

      assert :ok = Images.reorder(ctx.species, ["#{b.id}", a.id])
      assert Enum.map(Images.list_for_editor(ctx.species), & &1.id) == [b.id, a.id, c.id]
    end

    test "refuses another species' photos, repeats and junk", %{images: [a, b]} = ctx do
      stranger = import_photo(species_fixture(), ctx.observation, ctx.scope)

      for ids <- [[a.id, stranger.id], [a.id, a.id], [a.id, "x"], [nil]] do
        assert Images.reorder(ctx.species, ids) == {:error, :invalid_ids}, inspect(ids)
      end

      assert Images.reorder(ctx.species, :nope) == {:error, :invalid_ids}
      assert Enum.map(Images.list_for_editor(ctx.species), & &1.id) == [a.id, b.id]
    end

    test "get_species_image/2 resolves IDs only within the species", %{images: [a | _]} = ctx do
      assert %Image{} = Images.get_species_image(ctx.species, "#{a.id}")
      assert Images.get_species_image(species_fixture(), a.id) == nil
      assert Images.get_species_image(ctx.species, "1; drop") == nil
    end
  end

  describe "delete/1" do
    setup ctx do
      image = import_photo(ctx.species, ctx.observation, ctx.scope)
      :ok = run_import(image)
      %{image: reload(image), attempt: current_attempt(image)}
    end

    test "hides the photo at once and records its files before any are removed", ctx do
      assert {:ok, _} = Images.delete(ctx.image)

      assert reload(ctx.image) == nil
      assert Images.list_for_editor(ctx.species) == []

      assert [%Cleanup{reason: "photo_deleted", state: "deleting"} = cleanup] =
               cleanups_for(ctx.image)

      assert cleanup.paths == ImageStorage.all_paths(ctx.attempt.original_path)
      assert cleanup.species_id == ctx.species.id
      # Storage work only starts when the job runs, after the commit.
      assert length(stored_paths()) == 5
      assert_enqueued(worker: CleanupWorker, args: %{cleanup_id: cleanup.id})

      assert Images.delete(ctx.image) == {:error, :not_found}
    end

    test "cleanup deletes every file, then invalidates them and waits for that to complete",
         ctx do
      {:ok, _} = Images.delete(ctx.image)
      [cleanup] = cleanups_for(ctx.image)
      paths = cleanup.paths

      expect(MockAdapter, :create_invalidation, fn ^paths, reference ->
        assert reference =~ ~r"\Aoaks-image-cleanup-#{cleanup.id}-\d+\z"
        {:ok, "I123"}
      end)

      expect(MockAdapter, :invalidation_status, fn "I123" -> {:ok, :in_progress} end)

      assert {:snooze, 30} = run_cleanup(cleanup)
      assert stored_paths() == []

      assert %Cleanup{state: "invalidating", invalidation_id: "I123"} =
               Repo.get(Cleanup, cleanup.id)

      # Checking again resumes from the saved invalidation.
      expect(MockAdapter, :invalidation_status, fn "I123" -> {:ok, :completed} end)
      assert :ok = run_cleanup(cleanup)
      assert %Cleanup{state: "done", completed_at: %DateTime{}} = Repo.get(Cleanup, cleanup.id)
      assert :ok = run_cleanup(cleanup)
    end

    test "storage and CDN failures are recorded and retried, across a restart", ctx do
      {:ok, _} = Images.delete(ctx.image)
      [cleanup] = cleanups_for(ctx.image)

      stub(MockAdapter, :delete, fn _path -> {:error, :access_denied} end)
      assert {:error, _} = run_cleanup(cleanup)

      assert %Cleanup{state: "deleting", tries: 1, last_error: error} =
               Repo.get(Cleanup, cleanup.id)

      assert error =~ "access_denied"
      assert length(stored_paths()) == 5

      stub(MockAdapter, :delete, &Local.delete/1)
      stub(MockAdapter, :create_invalidation, fn _paths, _ref -> {:error, :throttled} end)
      assert {:error, _} = run_cleanup(cleanup)
      assert stored_paths() == []

      assert %Cleanup{state: "invalidating", tries: 2, invalidation_id: nil} =
               Repo.get(Cleanup, cleanup.id)

      lose_jobs()
      assert %{cleanups: 1} = RecoveryWorker.resume()
      assert_enqueued(worker: CleanupWorker, args: %{cleanup_id: cleanup.id})

      stub(MockAdapter, :create_invalidation, &Local.create_invalidation/2)
      assert :ok = run_cleanup(cleanup)
      assert %Cleanup{state: "done", last_error: nil} = Repo.get(Cleanup, cleanup.id)
    end

    test "a photo can be imported again after deletion, with new paths", ctx do
      {:ok, _} = Images.delete(ctx.image)

      again = import_photo(ctx.species, ctx.observation, ctx.scope)
      :ok = run_import(again)
      [cleanup] = cleanups_for(ctx.image)
      :ok = run_cleanup(cleanup)

      assert stored_paths() == Enum.sort(ImageStorage.all_paths(reload(again).path))
      assert [%Image{status: "ready"}] = Images.list_for_species(ctx.species)
    end
  end

  describe "removal during an import" do
    test "a photo deleted mid-import gets no more files, and its cleanup waits for the run",
         ctx do
      image = import_photo(ctx.species, ctx.observation, ctx.scope)
      test_pid = self()

      # Delete the photo while the run is writing its first file.
      stub(MockAdapter, :put, fn path, data, type ->
        if String.ends_with?(path, "_original.jpg") do
          {:ok, _} = Images.delete(reload(image))
          [cleanup] = cleanups_for(image)
          send(test_pid, {:cleanup_while_running, run_cleanup(cleanup)})
        end

        Local.put(path, data, type)
      end)

      assert :ok = run_import(image)

      # The cleanup waited while the run held the attempt's lease.
      assert_received {:cleanup_while_running, {:snooze, _}}
      # Only the write in flight landed; no variant was written after.
      assert [_original] = stored_paths()
      [cleanup] = cleanups_for(image)

      assert %ImportAttempt{state: "cancelled", lease_until: nil} =
               Repo.get(ImportAttempt, hd(cleanup.attempt_ids))

      assert :ok = run_cleanup(cleanup)
      assert stored_paths() == []
    end

    test "a cancelled attempt never publishes, even with every file stored", ctx do
      image = import_photo(ctx.species, ctx.observation, ctx.scope)
      attempt = current_attempt(image)
      {:ok, _} = ImportWorker.claim(attempt.id)

      Repo.update_all(from(a in ImportAttempt, where: a.id == ^attempt.id),
        set: [state: "cancelled"]
      )

      assert :done = ImportWorker.claim(attempt.id)
      assert :ok = run_import(image)
      assert stored_paths() == []
    end
  end

  describe "species deletion" do
    test "removes every photo with the species and records their files", ctx do
      ready = import_photo(ctx.species, ctx.observation, ctx.scope)
      :ok = run_import(ready)

      pending =
        import_photo(ctx.species, ctx.observation, ctx.scope, List.last(ctx.observation.photos))

      assert {:ok, _} = Oaks.Species.delete_species(ctx.species)

      assert reload(ready) == nil
      assert reload(pending) == nil
      assert [%Cleanup{reason: "species_deleted"}] = cleanups_for(ready)
      assert [%Cleanup{reason: "species_deleted"} = cleanup] = cleanups_for(pending)
      assert %ImportAttempt{state: "cancelled"} = Repo.get(ImportAttempt, hd(cleanup.attempt_ids))
    end

    test "the database refuses to delete a species out from under its photos", ctx do
      import_photo(ctx.species, ctx.observation, ctx.scope)
      assert_raise Ecto.ConstraintError, fn -> Repo.delete!(ctx.species) end
    end
  end
end
