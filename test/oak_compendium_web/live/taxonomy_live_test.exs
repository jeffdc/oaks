defmodule OakCompendiumWeb.TaxonomyLiveTest do
  @moduledoc """
  Tests for the TaxonomyLive LiveView.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OakCompendiumWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "GET /taxonomy (genus level)" do
    test "renders taxonomy root page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy")
      assert html =~ "Quercus"
      assert html =~ "genus"
    end

    test "shows subgenera as child taxa", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy")
      assert html =~ "Subgenera"
      assert html =~ "Lobatae"
    end

    test "shows species counts on subgenus cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy")
      # Quercus subgenus: 3 species, Lobatae: 2 species
      assert html =~ "3 species"
      assert html =~ "2 species"
    end

    test "shows total species count in header", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy")
      assert html =~ "5 species"
    end

    test "does not show breadcrumbs at genus level", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy")
      refute html =~ "Taxonomy:"
    end

    test "subgenus cards link to drill-down pages", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy")
      assert html =~ ~s(href="/taxonomy/Quercus")
      assert html =~ ~s(href="/taxonomy/Lobatae")
    end
  end

  describe "GET /taxonomy/Quercus (subgenus level)" do
    test "renders subgenus page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/taxonomy/Quercus")
      assert html =~ "Quercus"
      assert html =~ "subgenus"
    end

    test "shows breadcrumbs", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/taxonomy/Quercus")
      assert html =~ "Taxonomy:"
      assert html =~ "(genus)"
      assert html =~ "(subgenus)"
    end

    test "shows sections as child taxa", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/taxonomy/Quercus")
      assert html =~ "Sections"
    end
  end

  describe "GET /taxonomy/Quercus/Quercus (section level)" do
    test "renders section page with species", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/taxonomy/Quercus/Quercus")
      assert html =~ "section"
      assert html =~ "alba"
    end

    test "shows hybrid species with multiply sign", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/taxonomy/Quercus/Quercus")
      assert html =~ "×"
      assert html =~ "bebbiana"
    end

    test "does not show species from deeper levels", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/taxonomy/Quercus/Quercus")
      # stellata is in subsection Stellatae, should not appear at section level
      refute html =~ "stellata"
    end

    test "species link to detail pages", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/taxonomy/Quercus/Quercus")
      assert html =~ ~s(href="/species/alba")
    end

    test "shows subsections as child taxa", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/taxonomy/Quercus/Quercus")
      assert html =~ "Subsections"
      assert html =~ "Stellatae"
    end

    test "breadcrumbs show full ancestry", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/taxonomy/Quercus/Quercus")
      assert html =~ "(genus)"
      assert html =~ "(subgenus)"
      assert html =~ "(section)"
    end
  end

  describe "GET /taxonomy/Quercus/Quercus/Stellatae (subsection level)" do
    test "renders subsection page with species", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/taxonomy/Quercus/Quercus/Stellatae")
      assert html =~ "Stellatae"
      assert html =~ "subsection"
      assert html =~ "stellata"
    end
  end

  describe "GET /taxonomy/Lobatae/Lobatae (section Lobatae)" do
    test "shows Lobatae species", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/taxonomy/Lobatae/Lobatae")
      assert html =~ "rubra"
      assert html =~ "velutina"
    end
  end

  describe "invalid paths" do
    test "shows not found for nonexistent taxon", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/taxonomy/Nonexistent")
      assert html =~ "Taxon Not Found"
    end

    test "shows not found for path too deep", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/taxonomy/a/b/c/d/e")
      assert html =~ "Taxon Not Found"
    end

    test "not found page links back to taxonomy root", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/taxonomy/Nonexistent")
      assert html =~ ~s(href="/taxonomy")
      assert html =~ "Return to taxonomy browser"
    end
  end

  describe "navigation" do
    test "clicking a subgenus card navigates to subgenus page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/taxonomy")

      # Clicking navigate links between separate live routes triggers a redirect
      {:error, {:live_redirect, %{to: "/taxonomy/Quercus"}}} =
        view
        |> element(~s(a[href="/taxonomy/Quercus"]))
        |> render_click()
    end
  end
end
