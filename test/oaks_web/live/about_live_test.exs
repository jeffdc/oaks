defmodule OaksWeb.AboutLiveTest do
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.SpeciesFixtures

  test "renders about page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/about")
    assert html =~ "About the Oak Compendium"
    assert html =~ "Jeff Clark"
    assert html =~ "Gallformers"
  end

  test "has data sources section", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/about")
    assert html =~ "Data Sources"
    assert html =~ "iNaturalist"
    assert html =~ "Oaks of the World"
  end

  test "has licensing and open source sections", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/about")
    assert html =~ "Data Licensing"
    assert html =~ "Open Source"
    assert html =~ "MIT License"
  end

  test "links to the analytics dashboard and privacy policy", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/about")
    assert html =~ "Privacy &amp; Analytics"
    assert html =~ ~s(href="/analytics")
    assert html =~ ~s(href="/privacy")
  end

  test "counts hybrids once in the totals", %{conn: conn} do
    species_fixture()
    hybrid_fixture()
    total = Oaks.Species.count()
    hybrids = Oaks.Species.count_hybrids()
    {:ok, view, _html} = live(conn, ~p"/about")
    html = render(view)

    assert html =~ ~r/<dt>Species<\/dt>\s*<dd>\s*#{total - hybrids}\s*<\/dd>/
    assert html =~ ~r/<dt>Hybrids<\/dt>\s*<dd>\s*#{hybrids}\s*<\/dd>/
    assert html =~ ~r/<dt>Total Entries<\/dt>\s*<dd>\s*#{total}\s*<\/dd>/
  end

  test "shows the deployed app version and API version", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/about")

    assert html =~ "App: #{Oaks.Version.app_version()} | API: #{Oaks.Version.api_version()}"
    assert Oaks.Version.app_version() =~ ~r/^\d{4}\.\d{1,2}\.\d{1,2}$/

    assert has_element?(
             view,
             ~s|#release-notes-link[href="https://github.com/jeffdc/oaks/releases"]|
           )
  end
end
