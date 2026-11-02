defmodule OaksWeb.AboutLiveTest do
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

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
    total = Oaks.Species.count()
    hybrids = Oaks.Species.count_hybrids()
    {:ok, view, _html} = live(conn, ~p"/about")
    html = render(view)

    assert html =~ ~r/>\s*#{total - hybrids}\s*<\/span>\s*<span[^>]*>Species</
    assert html =~ ~r/>\s*#{total}\s*<\/span>\s*<span[^>]*>\s*Total Entries/
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
