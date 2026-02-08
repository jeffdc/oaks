defmodule OaksWeb.SpeciesMergeLiveTest do
  @moduledoc """
  Tests for the SpeciesMergeLive LiveView.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oaks.Species

  defp api_key do
    Application.get_env(:oaks, :api_key)
  end

  defp authenticated_conn(conn) do
    put_connect_params(conn, %{"api_key" => api_key()})
  end

  describe "unauthenticated access" do
    test "redirects to species detail page", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/species/stellata"}}} =
               live(conn, ~p"/species/stellata/merge/alba")
    end
  end

  describe "authenticated merge page" do
    test "renders merge page with both species", %{conn: conn} do
      {:ok, _view, html} =
        conn |> authenticated_conn() |> live(~p"/species/stellata/merge/alba")

      assert html =~ "stellata"
      assert html =~ "alba"
      assert html =~ "Synonym"
      assert html =~ "Target"
    end

    test "shows field comparison rows", %{conn: conn} do
      {:ok, _view, html} =
        conn |> authenticated_conn() |> live(~p"/species/stellata/merge/alba")

      assert html =~ "Author"
      assert html =~ "Conservation Status"
      assert html =~ "Subgenus"
    end

    test "shows source transfer section", %{conn: conn} do
      {:ok, _view, html} =
        conn |> authenticated_conn() |> live(~p"/species/stellata/merge/alba")

      assert html =~ "Source Data"
    end

    test "shows error for same species", %{conn: conn} do
      {:ok, _view, html} =
        conn |> authenticated_conn() |> live(~p"/species/alba/merge/alba")

      assert html =~ "cannot be merged with itself"
    end

    test "shows error for nonexistent species", %{conn: conn} do
      {:ok, _view, html} =
        conn |> authenticated_conn() |> live(~p"/species/nonexistent/merge/alba")

      assert html =~ "could not be found"
    end
  end

  describe "merge execution" do
    test "executes merge and redirects to target", %{conn: conn} do
      {:ok, view, _html} =
        conn |> authenticated_conn() |> live(~p"/species/velutina/merge/rubra")

      # Show confirmation dialog
      render_click(view, "show_confirm")

      # Execute merge
      assert {:error, {:live_redirect, %{to: "/species/rubra"}}} =
               render_click(view, "execute_merge")

      # Verify source was deleted
      assert Species.get_species_by_name("velutina") == nil

      # Verify synonym was added
      target = Species.get_species_full("rubra")
      synonyms = Species.parse_json_array(target.synonyms)
      assert "velutina" in synonyms
    end
  end

  describe "species detail merge picker" do
    test "unauthenticated user does not see merge button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species/alba")
      refute html =~ "merge-species-btn"
    end

    test "authenticated user sees merge button", %{conn: conn} do
      {:ok, _view, html} = conn |> authenticated_conn() |> live(~p"/species/alba")
      assert html =~ "merge-species-btn"
    end
  end
end
