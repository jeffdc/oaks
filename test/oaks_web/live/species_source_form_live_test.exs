defmodule OaksWeb.SpeciesSourceFormLiveTest do
  @moduledoc """
  Tests for the SpeciesSourceFormLive LiveView (create/edit species source data).
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.AccountsFixtures
  import Oaks.SourcesFixtures
  import Oaks.SpeciesFixtures

  alias Oaks.Sources

  # alba has data from `linked`; `unlinked` is a source alba lacks.
  setup do
    alba = species_fixture()
    linked = source_fixture()
    link = species_source_fixture(alba, linked, range: "Eastern North America")

    %{
      species: alba,
      alba: alba.scientific_name,
      linked: linked,
      link: link,
      unlinked: source_fixture()
    }
  end

  defp authenticated_conn(conn) do
    log_in_user(conn, user_fixture())
  end

  # -- New (unauthenticated) --

  describe "GET /species/:name/sources/new (unauthenticated)" do
    test "redirects to species list", %{conn: conn, alba: alba} do
      assert {:error, {:live_redirect, %{to: "/species"}}} =
               live(conn, ~p"/species/#{alba}/sources/new")
    end
  end

  # -- New (authenticated) --

  describe "GET /species/:name/sources/new (authenticated)" do
    test "renders form with available sources dropdown", %{conn: conn} = ctx do
      {:ok, view, html} =
        conn |> authenticated_conn() |> live(~p"/species/#{ctx.alba}/sources/new")

      assert html =~ "Add source data"
      assert html =~ "Data Source"
      assert has_element?(view, ~s(option[value="#{ctx.unlinked.id}"]), ctx.unlinked.name)
      refute has_element?(view, ~s(option[value="#{ctx.linked.id}"]))
      assert html =~ "Geographic Range"
    end

    test "redirects for nonexistent species", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/species"}}} =
               conn |> authenticated_conn() |> live(~p"/species/zzz_nonexistent/sources/new")
    end

    test "creates species source on submit", %{conn: conn} = ctx do
      {:ok, view, _html} =
        conn |> authenticated_conn() |> live(~p"/species/#{ctx.alba}/sources/new")

      {:ok, _view, html} =
        view
        |> form("#species-source-form",
          species_source: %{
            source_id: to_string(ctx.unlinked.id),
            range: "Test range data",
            leaves: "Test leaf description"
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Source data added"
    end

    test "validates form on change", %{conn: conn, alba: alba} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/#{alba}/sources/new")

      html =
        view
        |> form("#species-source-form", species_source: %{source_id: ""})
        |> render_change()

      # source_id is required — validation shown
      assert html =~ "be blank"
    end
  end

  # -- Edit (unauthenticated) --

  describe "GET /species/:name/sources/:source_id/edit (unauthenticated)" do
    test "redirects to species list", %{conn: conn, alba: alba, linked: linked} do
      assert {:error, {:live_redirect, %{to: "/species"}}} =
               live(conn, ~p"/species/#{alba}/sources/#{linked.id}/edit")
    end
  end

  # -- Edit (authenticated) --

  describe "GET /species/:name/sources/:source_id/edit (authenticated)" do
    test "renders edit form with pre-populated data", %{conn: conn} = ctx do
      {:ok, _view, html} =
        conn
        |> authenticated_conn()
        |> live(~p"/species/#{ctx.alba}/sources/#{ctx.linked.id}/edit")

      assert html =~ "Edit source data"
      assert html =~ ctx.linked.name
      assert html =~ "Geographic Range"
      assert html =~ "Eastern North America"
    end

    test "updates species source on submit", %{conn: conn} = ctx do
      {:ok, view, _html} =
        conn
        |> authenticated_conn()
        |> live(~p"/species/#{ctx.alba}/sources/#{ctx.linked.id}/edit")

      {:ok, _view, html} =
        view
        |> form("#species-source-form",
          species_source: %{range: "Updated range description"}
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Source data updated"
    end

    test "redirects for nonexistent source", %{conn: conn, alba: alba} do
      path = "/species/#{alba}"

      assert {:error, {:live_redirect, %{to: ^path}}} =
               conn |> authenticated_conn() |> live(~p"/species/#{alba}/sources/0/edit")
    end
  end

  # -- Delete source from detail page --

  describe "delete source from species detail" do
    test "delete source flow with confirmation", %{conn: conn} do
      velutina = species_fixture()
      source = source_fixture()
      species_source_fixture(velutina, source, range: "Temporary data")

      {:ok, view, _html} =
        conn |> authenticated_conn() |> live(~p"/species/#{velutina.scientific_name}")

      # Request delete from the source's quiet Edit menu
      assert has_element?(
               view,
               "#source-data-menu #edit-source-data-btn",
               "Edit #{source.name} data"
             )

      view |> element("#delete-source-data-btn") |> render_click()
      assert has_element?(view, "#delete-source-confirm-modal h2", "Delete source data")
      assert has_element?(view, "#confirm-delete-source-btn.oc-btn-danger")

      # Confirm delete
      {:ok, _view, html} =
        view
        |> render_click("confirm_delete_source")
        |> follow_redirect(conn)

      assert html =~ "Source data deleted"
    end

    test "cancel delete hides modal", %{conn: conn, alba: alba, link: link} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/#{alba}")

      html = render_click(view, "request_delete_source", %{"id" => to_string(link.id)})
      assert html =~ "delete-source-confirm-modal"

      html = render_click(view, "cancel_delete_source")
      refute html =~ "delete-source-confirm-modal"
    end
  end

  describe "duplicate source" do
    test "shows the error on the source field", %{conn: conn, alba: alba, linked: linked} do
      {:ok, view, _html} =
        conn |> authenticated_conn() |> live(~p"/species/#{alba}/sources/new")

      html =
        render_submit(view, "save", %{"species_source" => %{"source_id" => to_string(linked.id)}})

      assert html =~ "already has data for this species"
    end
  end

  describe "add source availability" do
    test "hides Add Source once every source is linked", %{conn: conn, species: species} do
      for source <- Sources.available_sources_for_species(species.id) do
        species_source_fixture(species, source)
      end

      assert Sources.available_sources_for_species(species.id) == []

      {:ok, view, _html} =
        conn |> authenticated_conn() |> live(~p"/species/#{species.scientific_name}")

      refute has_element?(view, "#add-source-btn")
    end

    test "shows Add Source while a source is still available", %{conn: conn, alba: alba} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/#{alba}")
      assert has_element?(view, "#species-edit-menu #add-source-btn")
    end
  end
end
