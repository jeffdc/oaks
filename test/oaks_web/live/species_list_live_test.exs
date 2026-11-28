defmodule OaksWeb.SpeciesListLiveTest do
  @moduledoc """
  Tests for the SpeciesListLive LiveView.
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.SpeciesFixtures
  import Oaks.TaxonomyFixtures

  alias Oaks.Species

  # Subgenus q (section qs) holds alba, stellata and ×bebbiana; subgenus l
  # (section ls) holds rubra and velutina.
  setup do
    n = System.unique_integer([:positive])
    q = taxon_fixture(name: "Quercus#{n}", level: "subgenus")
    qs = taxon_fixture(name: "QuercusSection#{n}", level: "section", parent_id: q.id)
    l = taxon_fixture(name: "Lobatae#{n}", level: "subgenus")
    ls = taxon_fixture(name: "LobataeSection#{n}", level: "section", parent_id: l.id)

    %{
      n: n,
      q: q.name,
      qs: qs.name,
      l: l.name,
      ls: ls.name,
      alba:
        species_fixture(
          scientific_name: "alba#{n}",
          taxon_id: qs.id,
          conservation_status: "LC"
        ),
      stellata: species_fixture(scientific_name: "stellata#{n}", taxon_id: qs.id),
      bebbiana: hybrid_fixture(scientific_name: "×bebbiana#{n}", taxon_id: qs.id),
      rubra: species_fixture(scientific_name: "rubra#{n}", taxon_id: ls.id),
      velutina: species_fixture(scientific_name: "velutina#{n}", taxon_id: ls.id)
    }
  end

  defp listed?(view, species), do: has_element?(view, "#species-#{species.id}")

  describe "GET /species" do
    test "renders species list page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species")
      assert html =~ "Species list"
      assert html =~ "species-search"
    end

    test "displays all species", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, ~p"/species")

      for species <- [ctx.alba, ctx.rubra, ctx.stellata, ctx.velutina, ctx.bebbiana] do
        assert listed?(view, species)
      end
    end

    test "shows species count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species")
      assert html =~ "#{Species.count()} total"
    end

    test "shows hybrid count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species")
      hybrids = Species.count_hybrids()
      assert html =~ "#{hybrids} #{if hybrids == 1, do: "hybrid", else: "hybrids"}<"
    end

    test "counts hybrids separately within a filter", %{conn: conn, q: q} do
      {:ok, _view, html} = live(conn, ~p"/species?subgenus=#{q}")
      assert html =~ "2 species"
      assert html =~ "1 hybrid<"
      assert html =~ "3 total"
    end

    test "displays hybrid symbol for hybrids", %{conn: conn, bebbiana: bebbiana} do
      {:ok, view, _html} = live(conn, ~p"/species")
      # &times; renders as Unicode × in the HTML
      assert view |> element("#species-#{bebbiana.id}") |> render() =~ "×"
    end

    test "species link to detail page", %{conn: conn, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/species")
      assert html =~ ~s(href="/species/#{alba.scientific_name}")
    end

    test "shows conservation status badges", %{conn: conn, alba: alba} do
      {:ok, view, _html} = live(conn, ~p"/species")
      assert has_element?(view, "#species-#{alba.id} .oc-iucn-lc", "LC")
      assert has_element?(view, ~s(#species-#{alba.id} [title="IUCN Red List: Least Concern"]))
    end

    test "shows subgenus and section badges", %{conn: conn, q: q, l: l} do
      {:ok, _view, html} = live(conn, ~p"/species")
      assert html =~ q
      assert html =~ l
    end
  end

  describe "filtering" do
    test "search narrows the list", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, ~p"/species")
      q = ctx.alba.scientific_name

      view
      |> form("#filter-form", %{q: q, subgenus: "", section: ""})
      |> render_change()

      assert_patch(view, ~p"/species?q=#{q}")

      assert listed?(view, ctx.alba)
      refute listed?(view, ctx.rubra)
      assert render(view) =~ "1 total"
    end

    test "filter by subgenus", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, ~p"/species")

      view
      |> form("#filter-form", %{q: "", subgenus: ctx.l, section: ""})
      |> render_change()

      assert_patch(view, ~p"/species?subgenus=#{ctx.l}")

      assert listed?(view, ctx.rubra)
      assert listed?(view, ctx.velutina)
      refute listed?(view, ctx.alba)
    end

    test "filter by section", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, ~p"/species")

      view
      |> form("#filter-form", %{q: "", subgenus: "", section: ctx.qs})
      |> render_change()

      assert_patch(view, ~p"/species?section=#{ctx.qs}")

      assert listed?(view, ctx.alba)
      assert listed?(view, ctx.stellata)
      refute listed?(view, ctx.rubra)
    end

    test "combined filters", %{conn: conn} = ctx do
      {:ok, view, html} = live(conn, ~p"/species?q=stella&subgenus=#{ctx.q}")
      assert listed?(view, ctx.stellata)
      refute listed?(view, ctx.alba)
      assert html =~ "1 total"
    end

    test "shows empty state when no matches", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species?q=zzzznonexistent")
      assert html =~ "No species found"
    end

    test "clearing filters shows all species", %{conn: conn, alba: alba} do
      {:ok, view, _html} = live(conn, ~p"/species?q=#{alba.scientific_name}")

      view
      |> form("#filter-form", %{q: "", subgenus: "", section: ""})
      |> render_change()

      assert_patch(view, ~p"/species")

      assert render(view) =~ "#{Species.count()} total"
    end

    test "filters from URL params on initial load", %{conn: conn} = ctx do
      {:ok, view, html} = live(conn, ~p"/species?subgenus=#{ctx.l}")
      assert listed?(view, ctx.rubra)
      assert listed?(view, ctx.velutina)
      assert html =~ "2 total"
    end
  end

  describe "GET /list (the old species index)" do
    test "redirects permanently to /species", %{conn: conn} do
      conn = get(conn, "/list")

      assert conn.status == 301
      assert redirected_to(conn, 301) == ~p"/species"
    end

    test "keeps the query string", %{conn: conn} do
      conn = get(conn, "/list?q=alba&subgenus=Quercus")

      assert redirected_to(conn, 301) == "/species?q=alba&subgenus=Quercus"
    end
  end
end
