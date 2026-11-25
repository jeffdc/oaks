defmodule Oaks.Species.MergePhotosTest do
  # Merging species moves the synonym's photos to the target
  # (Oaks.Images.merge_species_images/3, in Oaks.Species.Merge's transaction).
  use Oaks.DataCase
  use Oban.Testing, repo: Oaks.Repo, engine: Oban.Engines.Lite

  import Oaks.ImagesFixtures
  import Oaks.SpeciesFixtures

  alias Ecto.Multi
  alias Oaks.Images
  alias Oaks.Images.{Cleanup, CleanupWorker, Image, ImportAttempt, ImportWorker}
  alias Oaks.Species.Merge

  @moduletag :tmp_dir
  @moduletag :capture_log

  setup %{tmp_dir: tmp_dir} do
    use_local_storage(tmp_dir)

    # Four iNat photos: the target has p1 and p2; the synonym has p2 (a
    # duplicate, with its own caption), p3 (ready) and p4 (still pending).
    photos = for _ <- 1..4, do: inat_photo_json()
    json = observation_json(%{photos: photos})
    stub_inat(json)
    observation = observation(json)
    [o1, o2, o3, o4] = observation.photos
    scope = editor_scope()

    source = species_fixture()
    target = species_fixture()

    t1 = ready_photo(target, observation, scope, o1)
    t2 = ready_photo(target, observation, scope, o2)
    {:ok, t2} = Images.update_caption(t2, "Target's caption", scope)

    s3 = ready_photo(source, observation, scope, o3)
    s2 = ready_photo(source, observation, scope, o2)
    {:ok, s2} = Images.update_caption(s2, "Synonym's caption", scope)
    s4 = import_photo(source, observation, scope, o4)

    %{json: json, source: source, target: target, t1: t1, t2: t2, s2: s2, s3: s3, s4: s4}
  end

  defp ready_photo(species, observation, scope, photo) do
    image = import_photo(species, observation, scope, photo)
    :ok = perform_job(ImportWorker, %{attempt_id: image.current_attempt_id})
    reload(image)
  end

  test "the preview lists the photos that move and the duplicates, with captions lost", ctx do
    assert {:ok, preview} =
             Merge.preview_merge(ctx.source.scientific_name, ctx.target.scientific_name)

    assert Enum.map(preview.photos.transfer, & &1.id) == [ctx.s3.id, ctx.s4.id]

    assert [%{source: dup, target: kept, discarded_caption: "Synonym's caption"}] =
             preview.photos.duplicates

    assert {dup.id, kept.id} == {ctx.s2.id, ctx.t2.id}
  end

  test "a duplicate with no caption of its own loses none", ctx do
    {:ok, _} = Images.update_caption(ctx.s2, nil, editor_scope())
    {:ok, preview} = Merge.preview_merge(ctx.source.scientific_name, ctx.target.scientific_name)
    assert [%{discarded_caption: nil}] = preview.photos.duplicates
  end

  test "unique photos follow the target's in the synonym's order; the target's duplicate wins",
       ctx do
    assert {:ok, _} = Merge.execute_merge(ctx.source.scientific_name, ctx.target.scientific_name)

    assert Enum.map(Images.list_for_editor(ctx.target), &{&1.id, &1.status}) == [
             {ctx.t1.id, "ready"},
             {ctx.t2.id, "ready"},
             {ctx.s3.id, "ready"},
             {ctx.s4.id, "pending"}
           ]

    assert reload(ctx.t2).caption == "Target's caption"
    assert reload(ctx.s2) == nil

    # Stored files don't move: the path still records the synonym's ID.
    assert reload(ctx.s3).path == ctx.s3.path
    assert ctx.s3.path =~ "species/#{ctx.source.id}/"

    # Only the dropped duplicate's files are cleaned up.
    assert [%Cleanup{reason: "merge_duplicate"} = cleanup] = cleanups_for(ctx.s2)
    assert cleanup.paths == Oaks.Storage.Images.all_paths(ctx.s2.path)
    assert Repo.aggregate(from(c in Cleanup, where: c.species_id == ^ctx.target.id), :count) == 0

    :ok = perform_job(CleanupWorker, %{cleanup_id: cleanup.id})

    for image <- [ctx.t1, ctx.t2, ctx.s3],
        path <- Oaks.Storage.Images.all_paths(image.path),
        do: assert(path in stored_paths())
  end

  test "a pending import moved by the merge still publishes, to the target", ctx do
    {:ok, _} = Merge.execute_merge(ctx.source.scientific_name, ctx.target.scientific_name)

    assert :ok = perform_job(ImportWorker, %{attempt_id: ctx.s4.current_attempt_id})
    assert %Image{status: "ready", species_id: target_id} = reload(ctx.s4)
    assert target_id == ctx.target.id
    assert ctx.s4.id in Enum.map(Images.list_for_species(ctx.target), & &1.id)
  end

  test "a failed import moves to the target, where a retry publishes it", ctx do
    stub_inat(ctx.json, photo_status: %{ctx.s4.inat_photo_id => 404})
    {:cancel, _} = perform_job(ImportWorker, %{attempt_id: ctx.s4.current_attempt_id})
    [old_cleanup] = cleanups_for(ctx.s4)

    {:ok, _} = Merge.execute_merge(ctx.source.scientific_name, ctx.target.scientific_name)

    assert %Image{status: "failed", species_id: target_id} = reload(ctx.s4)
    assert target_id == ctx.target.id

    stub_inat(ctx.json)

    assert {:ok, %Image{current_attempt_id: attempt_id}} =
             Images.retry_import(ctx.target, ctx.s4.id, editor_scope())

    assert attempt_id != ctx.s4.current_attempt_id
    assert :ok = perform_job(ImportWorker, %{attempt_id: attempt_id})
    :ok = perform_job(CleanupWorker, %{cleanup_id: old_cleanup.id})

    assert %Image{status: "ready", path: path} = reload(ctx.s4)
    assert ctx.s4.id in Enum.map(Images.list_for_species(ctx.target), & &1.id)
    for p <- Oaks.Storage.Images.all_paths(path), do: assert(p in stored_paths())
  end

  test "a duplicate's import cut off by the merge never publishes", ctx do
    pending_dup = ctx.s4

    # Make the synonym's pending photo a duplicate of one the target has.
    Repo.update_all(from(i in Image, where: i.id == ^ctx.t1.id),
      set: [inat_photo_id: pending_dup.inat_photo_id]
    )

    {:ok, _} = Merge.execute_merge(ctx.source.scientific_name, ctx.target.scientific_name)

    assert reload(pending_dup) == nil

    assert %ImportAttempt{state: "cancelled"} =
             Repo.get(ImportAttempt, pending_dup.current_attempt_id)

    assert :ok = perform_job(ImportWorker, %{attempt_id: pending_dup.current_attempt_id})
    stem = String.replace_suffix(current_path(pending_dup), "_original.jpg", "")
    refute Enum.any?(stored_paths(), &String.starts_with?(&1, stem))
  end

  test "a merge that rolls back leaves every photo, file and job as it was", ctx do
    before = stored_paths()
    jobs = Repo.aggregate(Oban.Job, :count)

    assert {:error, :boom, :failed, _} =
             Multi.new()
             |> Images.merge_species_images(ctx.source, ctx.target)
             |> Multi.run(:boom, fn _repo, _changes -> {:error, :failed} end)
             |> Repo.transaction()

    assert Enum.map(Images.list_for_editor(ctx.source), & &1.id) == [
             ctx.s3.id,
             ctx.s2.id,
             ctx.s4.id
           ]

    assert reload(ctx.s2).caption == "Synonym's caption"
    assert cleanups_for(ctx.s2) == []
    assert Repo.aggregate(Oban.Job, :count) == jobs
    assert stored_paths() == before
  end

  defp current_path(image), do: Repo.get!(ImportAttempt, image.current_attempt_id).original_path
end
