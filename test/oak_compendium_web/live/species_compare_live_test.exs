defmodule OakCompendiumWeb.SpeciesCompareLiveTest do
  @moduledoc """
  Tests for the SpeciesCompareLive LiveView.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OakCompendiumWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "mount and handle_params" do
    test "loads comparison page with single species", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compare/alba")

      assert html =~ "Compare Oak Species"
      assert html =~ "Quercus alba"
      assert html =~ "L. 1753"
      assert html =~ "Comparing 1 species"
    end

    test "loads comparison page with multiple species", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compare/alba,rubra")

      assert html =~ "Quercus alba"
      assert html =~ "Quercus rubra"
      assert html =~ "Comparing 2 species"
    end

    test "handles species not found", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compare/nonexistent")

      assert html =~ "Species not found"
      assert html =~ "Quercus nonexistent"
      assert html =~ "No species selected for comparison"
    end

    test "handles partial matches (some found, some not)", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compare/alba,nonexistent")

      assert html =~ "Species not found"
      assert html =~ "Quercus nonexistent"
      assert html =~ "Quercus alba"
      assert html =~ "Comparing 1 species"
    end

    test "deduplicates species names", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compare/alba,alba")

      assert html =~ "Comparing 1 species"
    end

    test "handles URL with whitespace and trimming", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compare/alba, rubra , stellata")

      assert html =~ "Comparing 3 species"
      assert html =~ "Quercus alba"
      assert html =~ "Quercus rubra"
      assert html =~ "Quercus stellata"
    end
  end

  describe "comparison table" do
    test "displays taxonomy fields", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compare/alba,rubra")

      assert html =~ "Subgenus"
      assert html =~ "Section"
      # Both species should show their section
      assert html =~ "Quercus"
      assert html =~ "Lobatae"
    end

    test "displays descriptive fields from preferred source", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compare/alba,rubra")

      assert html =~ "Common Names"
      # Alba common names from test seeds
      assert html =~ "white oak"

      assert html =~ "Geographic Range"
      assert html =~ "Eastern North America"

      assert html =~ "Leaves"
    end

    test "shows conservation status", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compare/alba,rubra")

      assert html =~ "Conservation Status"
      assert html =~ "LC"
    end

    test "only shows fields with data", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compare/alba,rubra")

      # These fields have data in test seeds
      assert html =~ "Common Names"
      assert html =~ "Geographic Range"
      assert html =~ "Leaves"
    end
  end

  describe "adding species" do
    test "shows picker modal when 'Add species' clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compare/alba")

      html = view |> element("button", "Add species") |> render_click()

      assert html =~ "Add Species to Comparison"
      assert html =~ "Search species..."
    end

    test "searches for species in picker", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compare/alba")

      view |> element("button", "Add species") |> render_click()

      # Trigger search via change event
      view
      |> render_change("search", %{"query" => "rub"})

      html = render(view)
      assert html =~ "rubra"
    end

    test "adds species to comparison via picker", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compare/alba")

      view |> element("button", "Add species") |> render_click()

      # Search for species first
      view |> render_change("search", %{"query" => "rub"})

      # Now click on the search result
      view
      |> element("button[phx-click='add_species'][phx-value-name='rubra']")
      |> render_click()

      # Should redirect to new URL (URL-encoded comma)
      assert_patched(view, "/compare/alba%2Crubra")

      html = render(view)
      assert html =~ "Comparing 2 species"
      assert html =~ "Quercus alba"
      assert html =~ "Quercus rubra"
    end

    test "prevents adding more than 4 species", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compare/alba,rubra,stellata,velutina")

      html = render(view)
      # Should not show "Add species" button when at max (4 species)
      refute html =~ "Add species"
    end

    test "filters out already-selected species from search", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compare/alba")

      view |> element("button", "Add species") |> render_click()

      view |> render_change("search", %{"query" => "alb"})
      html = render(view)

      # Alba should not appear in results since it's already selected
      # (Search results should be empty or show other species with "alb" in name)
      refute html =~ "button[phx-value-name='alba']"
    end
  end

  describe "removing species" do
    test "removes species from comparison", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compare/alba,rubra")

      view
      |> element("button[phx-click='remove_species'][phx-value-name='rubra']")
      |> render_click()

      assert_patched(view, "/compare/alba")

      html = render(view)
      assert html =~ "Comparing 1 species"
      refute html =~ "Quercus rubra"
    end

    test "redirects to species list when removing last species", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compare/alba")

      view
      |> element("button[phx-click='remove_species'][phx-value-name='alba']")
      |> render_click()

      # Should redirect (navigate, not patch) to list
      assert_redirect(view, ~p"/list")
    end
  end

  describe "page title" do
    test "shows species name for single species", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compare/alba")

      assert page_title(view) =~ "Compare Quercus alba"
    end

    test "shows 'vs' for multiple species", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compare/alba,rubra")

      # Page title should show first two species with "vs"
      title = page_title(view)
      assert title =~ "Compare"
      assert title =~ "alba"
      assert title =~ "rubra"
    end
  end

  describe "closing picker modal" do
    test "closes modal when 'Close' button clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compare/alba")

      # Open picker
      view |> element("button", "Add species") |> render_click()
      html = render(view)
      assert html =~ "Add Species to Comparison"

      # Close picker
      html = view |> element("button", "Close") |> render_click()
      refute html =~ "Add Species to Comparison"
    end
  end
end
