defmodule OakCompendiumWeb.SpeciesListLiveTest do
  @moduledoc """
  Tests for the SpeciesListLive LiveView.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OakCompendiumWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "GET /list" do
    test "renders species list page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list")
      assert html =~ "Species List"
      assert html =~ "species-search"
    end

    test "displays all species", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list")
      assert html =~ "alba"
      assert html =~ "rubra"
      assert html =~ "stellata"
      assert html =~ "velutina"
      assert html =~ "bebbiana"
    end

    test "shows species count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list")
      assert html =~ "5 total"
    end

    test "shows hybrid count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list")
      assert html =~ "1 hybrid"
    end

    test "displays hybrid symbol for hybrids", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list")
      # &times; renders as Unicode × in the HTML
      assert html =~ "\u00D7"
    end

    test "species link to detail page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list")
      assert html =~ ~s(href="/species/alba")
    end

    test "shows conservation status badges", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list")
      assert html =~ "LC"
    end

    test "shows subgenus and section badges", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list")
      assert html =~ "Quercus"
      assert html =~ "Lobatae"
    end
  end

  describe "filtering" do
    test "search narrows the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/list")

      view
      |> form("#filter-form", %{q: "alba", subgenus: "", section: ""})
      |> render_change()

      assert_patch(view, ~p"/list?q=alba")

      html = render(view)
      assert html =~ "alba"
      refute html =~ "rubra"
      assert html =~ "1 total"
    end

    test "filter by subgenus", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/list")

      view
      |> form("#filter-form", %{q: "", subgenus: "Lobatae", section: ""})
      |> render_change()

      assert_patch(view, ~p"/list?subgenus=Lobatae")

      html = render(view)
      assert html =~ "rubra"
      assert html =~ "velutina"
      refute html =~ "alba"
    end

    test "filter by section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/list")

      view
      |> form("#filter-form", %{q: "", subgenus: "", section: "Quercus"})
      |> render_change()

      assert_patch(view, ~p"/list?section=Quercus")

      html = render(view)
      assert html =~ "alba"
      assert html =~ "stellata"
      refute html =~ "rubra"
    end

    test "combined filters", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list?q=stella&subgenus=Quercus")
      assert html =~ "stellata"
      refute html =~ "alba"
      assert html =~ "1 total"
    end

    test "shows empty state when no matches", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list?q=zzzznonexistent")
      assert html =~ "No species found"
    end

    test "clearing filters shows all species", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/list?q=alba")

      view
      |> form("#filter-form", %{q: "", subgenus: "", section: ""})
      |> render_change()

      assert_patch(view, ~p"/list")

      html = render(view)
      assert html =~ "5 total"
    end

    test "filters from URL params on initial load", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list?subgenus=Lobatae")
      assert html =~ "rubra"
      assert html =~ "velutina"
      assert html =~ "2 total"
    end
  end
end
