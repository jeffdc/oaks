defmodule OaksWeb.SpeciesPhotosTest do
  # The species page's Add photos and Manage photos dialogs
  # (OaksWeb.SpeciesPhotos): iNaturalist is stubbed (Req.Test), imports run
  # in the test process (Oban.Testing) and store photos for real under
  # tmp_dir (Oaks.Storage.Local behind the storage mock).
  use OaksWeb.ConnCase
  use Oban.Testing, repo: Oaks.Repo, engine: Oban.Engines.Lite

  import Phoenix.LiveViewTest
  import Oaks.AccountsFixtures
  import Oaks.ImagesFixtures
  import Oaks.SpeciesFixtures

  alias Oaks.Accounts.Scope
  alias Oaks.Images
  alias Oaks.Images.{Image, ImportWorker}
  alias Oaks.Repo
  alias OaksWeb.SpeciesPhotos.{AddPhotos, ManagePhotos}

  @moduletag :tmp_dir
  @moduletag :capture_log

  setup %{conn: conn, tmp_dir: tmp_dir} do
    use_local_storage(tmp_dir)
    user = user_fixture()

    %{
      conn: log_in_user(conn, user),
      scope: Scope.for_user(user),
      species: species_fixture()
    }
  end

  defp open_page(conn, species), do: live(conn, ~p"/species/#{species.scientific_name}")

  defp open_add(view) do
    view |> element("#add-photos-btn") |> render_click()
    view
  end

  defp open_manage(view) do
    view |> element("#manage-photos-btn") |> render_click()
    view
  end

  # Loads an observation in the Add photos dialog and waits for it.
  defp load(view, input) do
    view |> form("#add-photos-load", %{observation: input}) |> render_submit()
    render_async(view)
  end

  defp pick(view, params), do: view |> form("#add-photos-pick") |> render_change(params)

  defp add(view), do: view |> form("#add-photos-pick") |> render_submit()

  defp run_import(%Image{} = image),
    do: perform_job(ImportWorker, %{attempt_id: Repo.get!(Image, image.id).current_attempt_id})

  defp photo_ids(observation), do: Enum.map(observation.photos, &"#{&1.id}")

  describe "Add photos" do
    test "loads an observation, adds the picked photos and follows their imports", ctx do
      json = observation_json()
      stub_inat(json)
      observation = observation(json)
      [first, second] = photo_ids(observation)

      {:ok, view, _html} = open_page(ctx.conn, ctx.species)
      assert has_element?(view, "#species-photos .pv-empty", "No photos yet.")
      open_add(view)
      html = load(view, "https://www.inaturalist.org/observations/#{observation.id}")

      assert html =~ "Jane Doe · Blue Ridge, VA · 2026-05-04"
      assert has_element?(view, "#add-photos-photos input[value='#{first}']")
      assert has_element?(view, "#add-photos button[disabled]", "Add photos")

      pick(view, %{photo_ids: [first, second]})
      assert has_element?(view, "#add-photos button:not([disabled])", "Add 2 photos")

      add(view)
      assert has_element?(view, "#add-photos-progress", "Adding…")
      assert has_element?(view, "#add-photos", "Closing this doesn't stop the import")

      images = Images.list_for_editor(ctx.species)
      assert length(images) == 2
      assert Enum.all?(images, &(&1.status == "pending" and &1.uploader == ctx.scope.user.email))

      for image <- images, do: assert(:ok = run_import(image))

      refute render(view) =~ "Adding…"
      assert view |> element("#add-photos-progress") |> render() =~ "Added"
      assert length(Images.list_for_species(ctx.species)) == 2

      # The page's photo column follows: both photos, in the viewer.
      assert has_element?(view, "#species-photos .pv-count", "1 / 2")
      refute has_element?(view, "#species-photos .pv-empty")
    end

    test "reopened, shows each photo as it stands: added, adding or failed with Retry", ctx do
      photos = [inat_photo_json(), inat_photo_json(), inat_photo_json(), inat_photo_json()]
      json = observation_json(%{photos: photos})
      [ready, pending, failed, _new] = Enum.map(photos, & &1["id"])
      stub_inat(json, photo_status: %{failed => 404})
      observation = observation(json)

      by_id = Map.new(observation.photos, &{&1.id, &1})
      ready_image = import_photo(ctx.species, observation, ctx.scope, by_id[ready])
      import_photo(ctx.species, observation, ctx.scope, by_id[pending])
      failed_image = import_photo(ctx.species, observation, ctx.scope, by_id[failed])
      :ok = run_import(ready_image)
      {:cancel, _} = run_import(failed_image)

      {:ok, view, _html} = open_page(ctx.conn, ctx.species)
      assert has_element?(view, "#manage-photos-btn", "1 failed")

      open_add(view)
      load(view, "#{observation.id}")

      assert has_element?(view, "#add-photos-photos", "Already added")
      assert has_element?(view, "#add-photos-photos", "Adding…")
      assert has_element?(view, "#add-photos-photos", "iNaturalist no longer has this photo")
      # Only the photo the species doesn't have can be picked.
      assert view |> element("#add-photos-photos") |> render() |> count("type=\"checkbox\"") == 1

      stub_inat(json)
      view |> element("#add-photos-photos button", "Retry") |> render_click()
      assert Repo.get!(Image, failed_image.id).status == "pending"
      refute has_element?(view, "#add-photos-photos button", "Retry")

      :ok = run_import(failed_image)
      assert render(view) =~ "Already added"
      refute has_element?(view, "#manage-photos-btn", "failed")
    end

    test "says when the observation can't be loaded", ctx do
      stub_inat([])
      {:ok, view, _html} = open_page(ctx.conn, ctx.species)
      open_add(view)

      view |> form("#add-photos-load", %{observation: "not an observation"}) |> render_submit()
      assert has_element?(view, "#add-photos", "Enter an iNaturalist observation's address")

      assert load(view, "123456") =~ "iNaturalist has no observation with that number."
    end

    test "an All Rights Reserved photo is added only with the creator's permission", ctx do
      photos = [inat_photo_json(), inat_photo_json(%{license_code: nil})]
      json = observation_json(%{photos: photos})
      stub_inat(json)
      observation = observation(json)
      [open, reserved] = photo_ids(observation)

      {:ok, view, _html} = open_page(ctx.conn, ctx.species)
      open_add(view)
      load(view, "#{observation.id}")

      assert has_element?(view, "#add-photos-photos .oc-status", "All rights reserved")

      pick(view, %{photo_ids: [open, reserved]})
      assert has_element?(view, "#add-photos-permission", "Photo 2 is All rights reserved.")
      assert has_element?(view, "#add-photos button[disabled]", "Add 2 photos")

      # Adding without the box ticked writes nothing.
      add(view)
      assert Images.list_for_editor(ctx.species) == []

      pick(view, %{photo_ids: [open, reserved], permission: "true"})
      assert has_element?(view, "#add-photos button:not([disabled])", "Add 2 photos")
      add(view)

      images = Images.list_for_editor(ctx.species)
      assert length(images) == 2
      arr = Enum.find(images, &(&1.license == "All Rights Reserved"))
      cc = Enum.find(images, &(&1.license == "CC-BY-NC"))
      assert arr.permission_confirmed_by == ctx.scope.user.email
      assert %DateTime{} = arr.permission_confirmed_at
      assert cc.permission_confirmed_by == nil
    end

    test "flags a license iNat names that we don't know as No license given", ctx do
      json = observation_json(%{photos: [inat_photo_json(%{license_code: "gpl"})]})
      stub_inat(json)
      observation = observation(json)

      {:ok, view, _html} = open_page(ctx.conn, ctx.species)
      open_add(view)
      load(view, "#{observation.id}")

      assert has_element?(view, "#add-photos-photos .oc-status", "No license given")
      pick(view, %{photo_ids: photo_ids(observation)})
      assert has_element?(view, "#add-photos-permission")
    end

    test "ignores photos the server didn't fetch for the observation", ctx do
      json = observation_json()
      stub_inat(json)
      observation = observation(json)
      [first, _] = photo_ids(observation)
      other = species_fixture()

      {:ok, view, _html} = open_page(ctx.conn, ctx.species)
      open_add(view)
      load(view, "#{observation.id}")

      render_change(view |> element("#add-photos-pick"), %{photo_ids: ["999999999", first]})
      add(view)

      assert [%Image{inat_photo_id: id}] = Images.list_for_editor(ctx.species)
      assert "#{id}" == first
      assert Images.list_for_editor(other) == []
    end
  end

  describe "Manage photos" do
    setup ctx do
      json =
        observation_json(%{photos: [inat_photo_json(), inat_photo_json(), inat_photo_json()]})

      [_, _, bad] = json |> get_in(["results", Access.at(0), "photos"]) |> Enum.map(& &1["id"])
      stub_inat(json, photo_status: %{bad => 404})
      observation = observation(json)

      [one, two, three] =
        for photo <- observation.photos,
            do: import_photo(ctx.species, observation, ctx.scope, photo)

      :ok = run_import(one)
      :ok = run_import(two)
      {:cancel, _} = run_import(three)

      %{json: json, observation: observation, images: [one, two, three]}
    end

    test "lists every photo with its credit or import status", ctx do
      {:ok, view, _html} = open_page(ctx.conn, ctx.species)
      open_manage(view)
      [one, _two, three] = ctx.images

      row = "#manage-photos-photo-#{one.id}"
      assert has_element?(view, row, "janedoe - Jane Doe")
      assert has_element?(view, row, "CC-BY-NC")
      assert has_element?(view, "#{row} img[src*='_small.']")

      failed = "#manage-photos-photo-#{three.id}"
      assert has_element?(view, failed, "Failed")
      assert has_element?(view, failed, "iNaturalist no longer has this photo")
      assert has_element?(view, "#{failed} input[name=caption][disabled]")
    end

    test "saves a caption", ctx do
      {:ok, view, _html} = open_page(ctx.conn, ctx.species)
      open_manage(view)
      [one | _] = ctx.images

      view
      |> form("#manage-photos-caption-#{one.id}", %{caption: "  Acorns in October "})
      |> render_change()

      assert Repo.get!(Image, one.id).caption == "Acorns in October"
    end

    test "reorders the photos, refusing IDs that aren't the species'", ctx do
      {:ok, view, _html} = open_page(ctx.conn, ctx.species)
      open_manage(view)
      [one, two, three] = ctx.images
      other = import_photo(species_fixture(), ctx.observation, ctx.scope)

      view
      |> element("#manage-photos-list")
      |> render_hook("reorder", %{order: ["#{three.id}", "#{one.id}", "#{two.id}"]})

      assert Enum.map(Images.list_for_editor(ctx.species), & &1.id) == [three.id, one.id, two.id]

      view
      |> element("#manage-photos-list")
      |> render_hook("reorder", %{order: ["#{other.id}", "#{one.id}"]})

      assert Enum.map(Images.list_for_editor(ctx.species), & &1.id) == [three.id, one.id, two.id]
      assert Repo.get!(Image, other.id).species_id != ctx.species.id
    end

    test "retries a failed import", ctx do
      {:ok, view, _html} = open_page(ctx.conn, ctx.species)
      open_manage(view)
      [_, _, three] = ctx.images

      stub_inat(ctx.json)
      view |> element("#manage-photos-photo-#{three.id} button", "Retry") |> render_click()
      assert has_element?(view, "#manage-photos-photo-#{three.id}", "Adding…")

      :ok = run_import(three)
      assert render(view) =~ "janedoe - Jane Doe"
      refute has_element?(view, "#manage-photos-photo-#{three.id}", "Failed")
    end

    test "deletes a photo after its confirmation, recording its cleanup", ctx do
      {:ok, view, _html} = open_page(ctx.conn, ctx.species)
      open_manage(view)
      [one, two, _] = ctx.images

      view |> element("#manage-photos-photo-#{one.id} button", "Delete") |> render_click()
      assert has_element?(view, "#manage-photos-delete", "Its files are removed from storage.")

      # Cancel (the modal's on_cancel) goes back to the list, keeping the photo.
      view |> with_target("#manage-photos-component") |> render_click("cancel_delete_photo", %{})
      assert has_element?(view, "#manage-photos-photo-#{one.id}")

      view |> element("#manage-photos-photo-#{one.id} button", "Delete") |> render_click()
      view |> element("#manage-photos-delete-confirm") |> render_click()

      refute Repo.get(Image, one.id)
      assert Repo.get(Image, two.id)
      refute has_element?(view, "#manage-photos-photo-#{one.id}")
      assert [_cleanup] = cleanups_for(one)
    end

    test "refuses to delete, caption or retry another species' photo", ctx do
      other_species = species_fixture()
      other = import_photo(other_species, ctx.observation, ctx.scope)
      {:ok, view, _html} = open_page(ctx.conn, ctx.species)
      open_manage(view)
      target = view |> element("#manage-photos-list")

      # A forged ID in a delete request opens nothing for it.
      render_hook(target, "request_delete_photo", %{id: other.id})
      refute has_element?(view, "#manage-photos-delete")

      render_hook(target, "save_caption", %{image_id: other.id, caption: "Mine now"})
      render_hook(target, "retry", %{id: other.id})

      other = Repo.get!(Image, other.id)
      assert other.caption == nil
      assert other.species_id == other_species.id
    end
  end

  describe "visitors" do
    test "see no photo actions and can't open the dialogs", ctx do
      {:ok, view, html} = live(build_conn(), ~p"/species/#{ctx.species.scientific_name}")

      refute html =~ "Add photos from iNaturalist"
      refute html =~ "Manage photos"

      render_click(view, "open_photo_dialog", %{dialog: "add"})
      render_click(view, "open_photo_dialog", %{dialog: "manage"})
      refute has_element?(view, "#add-photos")
      refute has_element?(view, "#manage-photos")
    end

    # The dialogs mount only for editors, so a visitor's events can't reach
    # them; their handlers still refuse a socket with no scope, since
    # Images.reorder/2 and Images.delete/1 take none.
    test "events sent to the dialogs with no scope write nothing", ctx do
      json = observation_json(%{photos: [inat_photo_json(), inat_photo_json()]})
      [bad, _] = json |> get_in(["results", Access.at(0), "photos"]) |> Enum.map(& &1["id"])
      stub_inat(json, photo_status: %{bad => 404})
      observation = observation(json)

      [failed, ready] =
        for photo <- observation.photos,
            do: import_photo(ctx.species, observation, ctx.scope, photo)

      {:cancel, _} = run_import(failed)
      :ok = run_import(ready)
      stub_inat(json)
      before = Images.list_for_editor(ctx.species)
      jobs = Repo.aggregate(Oban.Job, :count)

      manage = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          species: ctx.species,
          current_scope: nil,
          images: before,
          caption_errors: %{},
          confirm_delete: ready
        }
      }

      for {event, params} <- [
            {"save_caption", %{"image_id" => "#{ready.id}", "caption" => "Mine now"}},
            {"reorder", %{"order" => ["#{ready.id}", "#{failed.id}"]}},
            {"retry", %{"id" => "#{failed.id}"}},
            {"request_delete_photo", %{"id" => "#{ready.id}"}},
            {"delete_photo", %{}}
          ],
          do: {:noreply, _} = ManagePhotos.handle_event(event, params, manage)

      add = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          species: ctx.species,
          current_scope: nil,
          observation: observation,
          selected: MapSet.new(Enum.map(observation.photos, & &1.id)),
          permission: true
        }
      }

      for {event, params} <- [{"add", %{}}, {"retry", %{"id" => "#{failed.id}"}}],
          do: {:noreply, _} = AddPhotos.handle_event(event, params, add)

      assert Images.list_for_editor(ctx.species) == before
      assert Repo.aggregate(Oban.Job, :count) == jobs
      assert cleanups_for(ready) == []
    end
  end

  defp count(text, pattern), do: length(String.split(text, pattern)) - 1
end
