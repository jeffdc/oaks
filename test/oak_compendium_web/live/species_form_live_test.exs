defmodule OakCompendiumWeb.SpeciesFormLiveTest do
  @moduledoc """
  Tests for the SpeciesFormLive LiveView (create/edit species).
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OakCompendiumWeb.ConnCase

  import Phoenix.LiveViewTest

  alias OakCompendium.Species

  defp api_key do
    Application.get_env(:oak_compendium, :api_key)
  end

  defp authenticated_conn(conn) do
    put_connect_params(conn, %{"api_key" => api_key()})
  end

  describe "GET /species/new (unauthenticated)" do
    test "redirects to species list on connected mount", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/list"}}} =
               live(conn, ~p"/species/new")
    end
  end

  describe "GET /species/new (authenticated)" do
    test "renders new species form", %{conn: conn} do
      {:ok, _view, html} = conn |> authenticated_conn() |> live(~p"/species/new")

      assert html =~ "New Species"
      assert html =~ "Scientific Name"
      assert html =~ "Create Species"
    end

    test "validates form on change", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/new")

      html =
        view
        |> form("#species-form", species: %{scientific_name: "", is_hybrid: false})
        |> render_change()

      assert html =~ "be blank"
    end

    test "creates species on submit", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/new")

      {:ok, _view, html} =
        view
        |> form("#species-form",
          species: %{scientific_name: "coccinea", is_hybrid: false, author: "Muenchh."}
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "coccinea"
      assert html =~ "Species created"
    end

    test "shows error for duplicate name", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/new")

      html =
        view
        |> form("#species-form", species: %{scientific_name: "alba", is_hybrid: false})
        |> render_submit()

      assert html =~ "has already been taken"
    end
  end

  describe "GET /species/:name/edit (unauthenticated)" do
    test "redirects to species list on connected mount", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/list"}}} =
               live(conn, ~p"/species/alba/edit")
    end
  end

  describe "GET /species/:name/edit (authenticated)" do
    test "renders edit form with pre-populated data", %{conn: conn} do
      {:ok, _view, html} = conn |> authenticated_conn() |> live(~p"/species/alba/edit")

      assert html =~ "Edit"
      assert html =~ "alba"
      assert html =~ "Save Changes"
    end

    test "updates species on submit", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/alba/edit")

      {:ok, _view, html} =
        view
        |> form("#species-form", species: %{author: "Linnaeus 1753"})
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Linnaeus 1753"
      assert html =~ "Species updated"
    end

    test "redirects for nonexistent species", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/list"}}} =
               conn |> authenticated_conn() |> live(~p"/species/zzz_nonexistent/edit")
    end
  end

  describe "species list new button" do
    test "unauthenticated user does not see New Species button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list")
      refute html =~ "new-species-btn"
    end

    test "authenticated user sees New Species button", %{conn: conn} do
      {:ok, _view, html} = conn |> authenticated_conn() |> live(~p"/list")

      assert html =~ "new-species-btn"
      assert html =~ "New Species"
    end
  end

  describe "species detail edit/delete buttons" do
    test "unauthenticated user does not see edit/delete buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species/alba")
      refute html =~ "edit-species-btn"
      refute html =~ "delete-species-btn"
    end

    test "authenticated user sees edit/delete buttons", %{conn: conn} do
      {:ok, _view, html} = conn |> authenticated_conn() |> live(~p"/species/alba")

      assert html =~ "edit-species-btn"
      assert html =~ "delete-species-btn"
    end

    test "delete flow works with confirmation", %{conn: conn} do
      {:ok, _species} =
        Species.create_species(%{scientific_name: "deleteme", is_hybrid: false})

      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/deleteme")

      # Click delete button
      html = render_click(view, "request_delete")
      assert html =~ "Delete Species"
      assert html =~ "Are you sure"

      # Confirm delete
      {:ok, _view, html} =
        view
        |> render_click("confirm_delete")
        |> follow_redirect(conn)

      assert html =~ "Species deleted"
      assert Species.get_species_by_name("deleteme") == nil
    end

    test "cancel delete hides modal", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/alba")

      # Open delete confirmation
      html = render_click(view, "request_delete")
      assert html =~ "delete-confirm-modal"

      # Cancel
      html = render_click(view, "cancel_delete")
      refute html =~ "delete-confirm-modal"
    end
  end
end
