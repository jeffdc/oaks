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

  describe "title row" do
    test "titles the results with the query", %{conn: conn, alba: alba} do
      {:ok, view, _html} = live(conn, ~p"/search?q=#{alba}")

      assert view |> element(".oc-title h1") |> render() =~ "Results for “#{alba}”"
      refute has_element?(view, "h1.sr-only")
    end

    test "shows only the kinds of result found, with no total for one kind",
         %{conn: conn, alba: alba} do
      {:ok, view, _html} = live(conn, ~p"/search?q=#{alba}")

      assert has_element?(view, ".oc-title-meta", "1 species")
      refute has_element?(view, ".oc-title-meta", "source")
      refute has_element?(view, ".oc-title-meta", "tax")
      refute has_element?(view, ".oc-title-meta", "total")
    end

    test "totals two or more kinds of result", %{conn: conn, n: n} do
      taxon_fixture(name: "Quux#{n}", level: "section")
      species_fixture(scientific_name: "quux#{n}")

      {:ok, view, _html} = live(conn, ~p"/search?q=#{"quux#{n}"}")

      assert has_element?(view, ".oc-title-meta", "1 taxon")
      assert has_element?(view, ".oc-title-meta", "1 species")
      assert has_element?(view, ".oc-title-meta strong", "2 total")
      refute has_element?(view, ".oc-title-meta", "source")
    end

    test "has no counts when nothing is found", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search?q=zzzznonexistent")

      assert has_element?(view, ".oc-title h1", "Results for")
      refute has_element?(view, ".oc-title-meta")
    end

    test "offers Add Species to an editor only", %{conn: conn, alba: alba} do
      {:ok, view, _html} = live(conn, ~p"/search?q=#{alba}")
      refute has_element?(view, "#search-add-species")

      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      {:ok, view, _html} = live(conn, ~p"/search?q=#{alba}")

      assert has_element?(
               view,
               ".oc-title-actions #search-edit-menu #search-add-species",
               "Add species"
             )
    end
  end

  describe "synonym matches" do
    setup %{n: n} do
      species = species_fixture(scientific_name: "albida#{n}", synonyms: ["candida#{n} Steud."])
      %{species: species}
    end

    test "say which synonym a species was found through", %{conn: conn, n: n, species: species} do
      {:ok, view, _html} = live(conn, ~p"/search?q=#{"candida#{n}"}")

      note = view |> element("#species-result-#{species.id} .search-result-note") |> render()
      assert note =~ "via"
      assert note =~ "candida#{n}"
      assert note =~ "Steud."
    end

    test "say nothing when the species' own name matched", %{conn: conn, n: n, species: species} do
      {:ok, view, _html} = live(conn, ~p"/search?q=#{"albida#{n}"}")

      assert has_element?(view, "#species-result-#{species.id}")
      refute has_element?(view, "#species-result-#{species.id} .search-result-note")
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
