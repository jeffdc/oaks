defmodule OaksWeb.SearchLiveTest do
  @moduledoc """
  Tests for the SearchLive LiveView.
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.SourcesFixtures
  import Oaks.SpeciesFixtures
  import Oaks.TaxonomyFixtures

  setup do
    n = System.unique_integer([:positive])
    alba = species_fixture(scientific_name: "alba#{n}")
    source = source_fixture(name: "iNaturalist #{n}")
    species_source_fixture(alba, source, local_names: ["white oak #{n}"])

    %{
      n: n,
      alba: alba.scientific_name,
      bebbiana: hybrid_fixture(scientific_name: "×bebbiana#{n}").scientific_name,
      taxon: taxon_fixture(name: "Lobatae#{n}", level: "section"),
      source: source
    }
  end

  describe "GET /search" do
    test "renders search page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search")
      assert html =~ "search-sync"
    end

    test "shows nothing when no query", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search")
      refute html =~ "total"
    end

    test "performs search from URL query param", %{conn: conn, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/search?q=#{alba}")
      assert html =~ alba
      assert html =~ "species"
    end

    test "shows no results message for unmatched query", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search?q=zzzznonexistent")
      assert html =~ "No results found"
    end
  end

  describe "search interaction" do
    test "search event triggers results via push_patch", %{conn: conn, alba: alba} do
      {:ok, view, _html} = live(conn, ~p"/search")

      view
      |> element("#search-sync")
      |> render_hook("search", %{q: alba})

      assert_patch(view, ~p"/search?q=#{alba}")

      assert render(view) =~ alba
    end

    test "clearing search shows empty state", %{conn: conn, alba: alba} do
      {:ok, view, _html} = live(conn, ~p"/search?q=#{alba}")

      view
      |> element("#search-sync")
      |> render_hook("search", %{q: ""})

      assert_patch(view, ~p"/search")

      html = render(view)
      refute html =~ "total"
    end

    test "species results link to detail page", %{conn: conn, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/search?q=#{alba}")
      assert html =~ ~s(href="/species/#{alba}")
    end

    test "taxa results link to taxonomy page", %{conn: conn, taxon: taxon} do
      {:ok, _view, html} = live(conn, ~p"/search?q=#{taxon.name}")
      assert html =~ "/taxonomy/"
      assert html =~ taxon.name
    end

    test "source results link to source detail page", %{conn: conn, source: source} do
      {:ok, _view, html} = live(conn, ~p"/search?q=#{source.name}")
      assert html =~ ~s(href="/sources/#{source.id}")
    end

    test "shows result counts", %{conn: conn, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/search?q=#{alba}")
      assert html =~ "total"
    end

    test "displays hybrid species with multiply sign", %{conn: conn, bebbiana: bebbiana} do
      "×" <> epithet = bebbiana
      {:ok, _view, html} = live(conn, ~p"/search?q=#{epithet}")
      assert html =~ "×"
    end

    test "finds species by common name", %{conn: conn, n: n, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/search?q=#{"white oak #{n}"}")
      assert html =~ alba
    end
  end

  test "resets the page title when the query is cleared", %{conn: conn, alba: alba} do
    {:ok, view, _html} = live(conn, ~p"/search?q=#{alba}")
    assert page_title(view) =~ "Search: #{alba}"

    render_patch(view, ~p"/search")
    assert page_title(view) =~ "Search"
    refute page_title(view) =~ alba
  end
end
