defmodule OakCompendiumWeb.TaxonFormLiveTest do
  @moduledoc """
  Tests for the TaxonFormLive LiveView (create/edit taxa).
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OakCompendiumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias OakCompendium.Taxonomy

  defp api_key do
    Application.get_env(:oak_compendium, :api_key)
  end

  defp authenticated_conn(conn) do
    put_connect_params(conn, %{"api_key" => api_key()})
  end

  # -- New (unauthenticated) --

  describe "GET /taxonomy/new (unauthenticated)" do
    test "redirects to taxonomy browser on connected mount", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/taxonomy"}}} =
               live(conn, ~p"/taxonomy/new")
    end
  end

  # -- New (authenticated) --

  describe "GET /taxonomy/new (authenticated)" do
    test "renders create taxon form", %{conn: conn} do
      {:ok, _view, html} = conn |> authenticated_conn() |> live(~p"/taxonomy/new")

      assert html =~ "Create Taxon"
      assert html =~ "Level"
      assert html =~ "Name"
    end

    test "pre-selects level and parent from query params", %{conn: conn} do
      {:ok, _view, html} =
        conn |> authenticated_conn() |> live("/taxonomy/new?level=section&parent=Quercus")

      assert html =~ "Create Taxon"
      # The parent dropdown should be present since level is section
      assert html =~ "Parent"
    end

    test "creates taxon on submit", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/taxonomy/new")

      {:ok, _view, html} =
        view
        |> form("#taxon-form",
          taxon: %{name: "TestSubgenus", level: "subgenus"}
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Taxon created"
    end

    test "validates form on change", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/taxonomy/new")

      html =
        view
        |> form("#taxon-form", taxon: %{name: "", level: ""})
        |> render_change()

      assert html =~ "be blank"
    end

    test "shows error for duplicate name+level", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/taxonomy/new")

      # "Quercus" subgenus already exists in seeds
      html =
        view
        |> form("#taxon-form", taxon: %{name: "Quercus", level: "subgenus"})
        |> render_submit()

      assert html =~ "has already been taken"
    end
  end

  # -- Edit (unauthenticated) --

  describe "GET /taxonomy/:id/edit (unauthenticated)" do
    test "redirects to taxonomy browser on connected mount", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/taxonomy"}}} =
               live(conn, ~p"/taxonomy/1/edit")
    end
  end

  # -- Edit (authenticated) --

  describe "GET /taxonomy/:id/edit (authenticated)" do
    test "renders edit form with pre-populated data", %{conn: conn} do
      {:ok, _view, html} = conn |> authenticated_conn() |> live(~p"/taxonomy/1/edit")

      assert html =~ "Edit"
      assert html =~ "Quercus"
    end

    test "updates taxon on submit", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/taxonomy/1/edit")

      {:ok, _view, html} =
        view
        |> form("#taxon-form", taxon: %{author: "Updated Author"})
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Taxon updated"
    end

    test "redirects for nonexistent taxon", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/taxonomy"}}} =
               conn |> authenticated_conn() |> live(~p"/taxonomy/9999/edit")
    end
  end

  # -- Taxonomy page buttons --

  describe "taxonomy page admin buttons" do
    test "unauthenticated user does not see Create Taxon button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy")
      refute html =~ "create-taxon-btn"
    end

    test "authenticated user sees Create Taxon button", %{conn: conn} do
      {:ok, _view, html} = conn |> authenticated_conn() |> live(~p"/taxonomy")

      assert html =~ "create-taxon-btn"
      assert html =~ "Create Taxon"
    end

    test "delete taxon flow with confirmation", %{conn: conn} do
      {:ok, taxon} =
        Taxonomy.create_taxon(%{name: "DeleteMe", level: "subgenus"})

      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/taxonomy")

      # Request delete
      html = render_click(view, "request_delete_taxon", %{"id" => to_string(taxon.id)})
      assert html =~ "Delete Taxon"
      assert html =~ "Are you sure"
      assert html =~ "DeleteMe"

      # Confirm
      {:ok, _view, html} =
        view
        |> render_click("confirm_delete_taxon")
        |> follow_redirect(conn)

      assert html =~ "Taxon deleted"
      assert Taxonomy.get_taxon_by_id(taxon.id) == nil
    end

    test "cancel delete hides modal", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/taxonomy")

      html = render_click(view, "request_delete_taxon", %{"id" => "1"})
      assert html =~ "delete-taxon-modal"

      html = render_click(view, "cancel_delete_taxon")
      refute html =~ "delete-taxon-modal"
    end
  end
end
