defmodule OaksWeb.HomeLiveTest do
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.SourcesFixtures
  import Oaks.SpeciesFixtures

  alias Oaks.Sources
  alias Oaks.Species
  alias Oaks.Taxonomy

  test "sets the title page with the search across its edge", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ ~r{<h1 id="title-page-title" class="oc-tp-title">\s*Oak <em>Compendium</em>}
    assert html =~ "Oaks, their varieties and their hybrids, and how to tell them apart"
    assert has_element?(view, ~s(form.oc-tp-search[action="/search"] input[name="q"]))
    refute html =~ "29,000"
    refute html =~ "Proposed copy"
  end

  test "counts species apart from hybrids, and the sections and sources", %{conn: conn} do
    species_fixture()
    hybrid_fixture()

    hybrids = Species.count_hybrids()
    species = Species.count() - hybrids
    sections = length(Taxonomy.list_taxa_by_level("section"))
    sources = Sources.list_sources() |> Enum.reject(&(&1.id == 1)) |> length()

    {:ok, view, _html} = live(conn, ~p"/")

    for text <- [
          "#{species} species",
          "#{hybrids} hybrids",
          "#{sections} sections",
          "#{sources} sources"
        ] do
      assert has_element?(view, ".oc-tp-counts span", text)
    end
  end

  test "lists the contents, linking only the parts that exist", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    for path <- ~w(/species /taxonomy /sources /about) do
      assert has_element?(view, ~s(#contents a.oc-contents-row[href="#{path}"]))
    end

    assert has_element?(view, "#contents .oc-contents-off", "Identify")
    assert has_element?(view, "#contents .oc-contents-off .oc-status", "In preparation")
  end

  test "features a non-hybrid oak with where it sits and its hybrids", %{conn: conn} do
    name = unique_species_name()
    hybrid_name = "× #{unique_species_name()}"
    formula = "#{name} × palmeri"

    species_fixture(
      scientific_name: name,
      author: "Nutt.",
      subgenus: "Quercus",
      section: "Quercus",
      hybrids: [hybrid_name, formula]
    )

    hybrid_fixture(scientific_name: hybrid_name, parent1: name, parent2: "macrocarpa")
    hybrid_fixture(scientific_name: formula, parent1: name, parent2: "palmeri")

    {:ok, view, _html} = live(conn, ~p"/")
    html = render(view)

    assert has_element?(view, "#oak-at-random .oc-sci-e", name)
    assert has_element?(view, "#oak-at-random", "Nutt.")
    assert has_element?(view, ~s(#random-band a[href="/taxonomy/Quercus/Quercus"]))

    assert html =~
             ~r{with\s*<span class="oc-sci oc-sci-regular[^"]*"><i class="oc-sci-e">macrocarpa</i>}

    # A formula already names both parents, so it has no "with".
    assert has_element?(view, "#oak-at-random .oc-specimen-about", "palmeri")

    refute html =~
             ~r{with\s*<span class="oc-sci oc-sci-regular[^"]*"><i class="oc-sci-e">palmeri</i>}

    assert has_element?(view, ~s(#oak-at-random a[href="/species/#{name}"]), "Open the page")
  end

  test "Show another features a different oak", %{conn: conn} do
    first = species_fixture()
    second = species_fixture()
    hybrid_fixture()

    {:ok, view, _html} = live(conn, ~p"/")
    render(view)

    shown = fn ->
      Enum.find([first, second], fn s ->
        has_element?(view, ~s(#oak-at-random a[href="/species/#{s.scientific_name}"]))
      end)
    end

    before = shown.()
    assert before

    view |> element("button", "Show another") |> render_click()

    assert shown.()
    refute shown.() == before
  end

  test "lists the sources with the primary one first and not iNaturalist", %{conn: conn} do
    source = source_fixture(name: "Aaa first by name")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, ~s(#home-sources a[href="/sources/#{source.id}"]))
    refute has_element?(view, ~s(#home-sources a[href="/sources/1"]))

    if Sources.get_source(3) do
      assert has_element?(view, "#home-sources li:first-child", "Primary")
    end
  end
end
