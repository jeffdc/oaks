defmodule OaksWeb.SpeciesSourceFormLiveTest do
  @moduledoc """
  Tests for the SpeciesSourceFormLive LiveView (create/edit species source data).
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oaks.Sources

  defp api_key do
    Application.get_env(:oaks, :api_key)
  end

  defp authenticated_conn(conn) do
    put_connect_params(conn, %{"api_key" => api_key()})
  end

  # -- New (unauthenticated) --

  describe "GET /species/:name/sources/new (unauthenticated)" do
    test "redirects to species list on connected mount", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/list"}}} =
               live(conn, ~p"/species/alba/sources/new")
    end
  end

  # -- New (authenticated) --

  describe "GET /species/:name/sources/new (authenticated)" do
    test "renders form with available sources dropdown", %{conn: conn} do
      {:ok, _view, html} = conn |> authenticated_conn() |> live(~p"/species/alba/sources/new")

      assert html =~ "Add Source Data"
      assert html =~ "Data Source"
      # Source 3 (Oak Compendium) is not linked to alba
      assert html =~ "Oak Compendium"
      assert html =~ "Geographic Range"
    end

    test "redirects for nonexistent species", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/list"}}} =
               conn |> authenticated_conn() |> live(~p"/species/zzz_nonexistent/sources/new")
    end

    test "creates species source on submit", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/alba/sources/new")

      {:ok, _view, html} =
        view
        |> form("#species-source-form",
          species_source: %{
            source_id: "3",
            range: "Test range data",
            leaves: "Test leaf description"
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Source data added"
    end

    test "validates form on change", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/alba/sources/new")

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
    test "redirects to species list on connected mount", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/list"}}} =
               live(conn, ~p"/species/alba/sources/2/edit")
    end
  end

  # -- Edit (authenticated) --

  describe "GET /species/:name/sources/:source_id/edit (authenticated)" do
    test "renders edit form with pre-populated data", %{conn: conn} do
      {:ok, _view, html} =
        conn |> authenticated_conn() |> live(~p"/species/alba/sources/2/edit")

      assert html =~ "Edit Source Data"
      assert html =~ "Oaks of the World"
      assert html =~ "Geographic Range"
    end

    test "updates species source on submit", %{conn: conn} do
      {:ok, view, _html} =
        conn |> authenticated_conn() |> live(~p"/species/alba/sources/2/edit")

      {:ok, _view, html} =
        view
        |> form("#species-source-form",
          species_source: %{range: "Updated range description"}
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Source data updated"
    end

    test "redirects for nonexistent source", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/species/alba"}}} =
               conn |> authenticated_conn() |> live(~p"/species/alba/sources/999/edit")
    end
  end

  # -- Delete source from detail page --

  describe "delete source from species detail" do
    test "delete source flow with confirmation", %{conn: conn} do
      # Create a throwaway species_source to delete
      {:ok, ss} =
        Sources.create_species_source(%{
          species_id: 4,
          source_id: 1,
          range: "Temporary data"
        })

      {:ok, view, _html} =
        conn |> authenticated_conn() |> live(~p"/species/velutina")

      # Request delete
      html = render_click(view, "request_delete_source", %{"id" => to_string(ss.id)})
      assert html =~ "Delete Source Data"
      assert html =~ "Are you sure"

      # Confirm delete
      {:ok, _view, html} =
        view
        |> render_click("confirm_delete_source")
        |> follow_redirect(conn)

      assert html =~ "Source data deleted"
    end

    test "cancel delete hides modal", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/alba")

      # species_source id=1 is alba + Oaks of the World
      html = render_click(view, "request_delete_source", %{"id" => "1"})
      assert html =~ "delete-source-confirm-modal"

      html = render_click(view, "cancel_delete_source")
      refute html =~ "delete-source-confirm-modal"
    end
  end
end
