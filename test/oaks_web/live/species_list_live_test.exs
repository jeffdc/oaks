defmodule OaksWeb.SpeciesListLiveTest do
  @moduledoc """
  Tests for the SpeciesListLive LiveView.
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.SpeciesFixtures

  alias Oaks.Species

  # Subgenus q (section qs) holds alba, stellata and ×bebbiana; subgenus l
  # (section ls) holds rubra and velutina.
  setup do
    n = System.unique_integer([:positive])
    q = "Quercus#{n}"
    qs = "QuercusSection#{n}"
    l = "Lobatae#{n}"
    ls = "LobataeSection#{n}"

    %{
      n: n,
      q: q,
      qs: qs,
      l: l,
      ls: ls,
      alba:
        species_fixture(
          scientific_name: "alba#{n}",
          subgenus: q,
          section: qs,
          conservation_status: "LC"
        ),
      stellata: species_fixture(scientific_name: "stellata#{n}", subgenus: q, section: qs),
      bebbiana: hybrid_fixture(scientific_name: "×bebbiana#{n}", subgenus: q, section: qs),
      rubra: species_fixture(scientific_name: "rubra#{n}", subgenus: l, section: ls),
      velutina: species_fixture(scientific_name: "velutina#{n}", subgenus: l, section: ls)
    }
  end

  defp listed?(view, species), do: has_element?(view, "#species-#{species.id}")

  describe "GET /list" do
    test "renders species list page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list")
      assert html =~ "Species List"
      assert html =~ "species-search"
    end

    test "displays all species", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, ~p"/list")

      for species <- [ctx.alba, ctx.rubra, ctx.stellata, ctx.velutina, ctx.bebbiana] do
        assert listed?(view, species)
      end
    end

    test "shows species count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list")
      assert html =~ "#{Species.count()} total"
    end

    test "shows hybrid count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list")
      assert html =~ "#{Species.count_hybrids()} hybrids"
    end

    test "counts hybrids separately within a filter", %{conn: conn, q: q} do
      {:ok, _view, html} = live(conn, ~p"/list?subgenus=#{q}")
      assert html =~ "2 species"
      assert html =~ "1 hybrids"
      assert html =~ "3 total"
    end

    test "displays hybrid symbol for hybrids", %{conn: conn, bebbiana: bebbiana} do
      {:ok, view, _html} = live(conn, ~p"/list")
      # &times; renders as Unicode × in the HTML
      assert view |> element("#species-#{bebbiana.id}") |> render() =~ "×"
    end

    test "species link to detail page", %{conn: conn, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/list")
      assert html =~ ~s(href="/species/#{alba.scientific_name}")
    end

    test "shows conservation status badges", %{conn: conn, alba: alba} do
      {:ok, view, _html} = live(conn, ~p"/list")
      assert view |> element("#species-#{alba.id}") |> render() =~ "LC"
    end

    test "shows subgenus and section badges", %{conn: conn, q: q, l: l} do
      {:ok, _view, html} = live(conn, ~p"/list")
      assert html =~ q
      assert html =~ l
    end
  end

  describe "filtering" do
    test "search narrows the list", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, ~p"/list")
      q = ctx.alba.scientific_name

      view
      |> form("#filter-form", %{q: q, subgenus: "", section: ""})
      |> render_change()

      assert_patch(view, ~p"/list?q=#{q}")

      assert listed?(view, ctx.alba)
      refute listed?(view, ctx.rubra)
      assert render(view) =~ "1 total"
    end

    test "filter by subgenus", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, ~p"/list")

      view
      |> form("#filter-form", %{q: "", subgenus: ctx.l, section: ""})
      |> render_change()

      assert_patch(view, ~p"/list?subgenus=#{ctx.l}")

      assert listed?(view, ctx.rubra)
      assert listed?(view, ctx.velutina)
      refute listed?(view, ctx.alba)
    end

    test "filter by section", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, ~p"/list")

      view
      |> form("#filter-form", %{q: "", subgenus: "", section: ctx.qs})
      |> render_change()

      assert_patch(view, ~p"/list?section=#{ctx.qs}")

      assert listed?(view, ctx.alba)
      assert listed?(view, ctx.stellata)
      refute listed?(view, ctx.rubra)
    end

    test "combined filters", %{conn: conn} = ctx do
      {:ok, view, html} = live(conn, ~p"/list?q=stella&subgenus=#{ctx.q}")
      assert listed?(view, ctx.stellata)
      refute listed?(view, ctx.alba)
      assert html =~ "1 total"
    end

    test "shows empty state when no matches", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list?q=zzzznonexistent")
      assert html =~ "No species found"
    end

    test "clearing filters shows all species", %{conn: conn, alba: alba} do
      {:ok, view, _html} = live(conn, ~p"/list?q=#{alba.scientific_name}")

      view
      |> form("#filter-form", %{q: "", subgenus: "", section: ""})
      |> render_change()

      assert_patch(view, ~p"/list")

      assert render(view) =~ "#{Species.count()} total"
    end

    test "filters from URL params on initial load", %{conn: conn} = ctx do
      {:ok, view, html} = live(conn, ~p"/list?subgenus=#{ctx.l}")
      assert listed?(view, ctx.rubra)
      assert listed?(view, ctx.velutina)
      assert html =~ "2 total"
    end
  end
end
