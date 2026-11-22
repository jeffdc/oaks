defmodule OaksWeb.TaxonomyLiveTest do
  @moduledoc """
  Tests for the TaxonomyLive LiveView.
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.AccountsFixtures
  import Oaks.SpeciesFixtures
  import Oaks.TaxonomyFixtures

  alias Oaks.Species

  # Two subgenera, each with a section of the same name, and a subsection
  # under the first:
  #
  #   q / q        alba, ×bebbiana
  #   q / q / st   stellata
  #   l / l        rubra, velutina
  #
  # Names carry a unique suffix so they can't clash with seeded taxa.
  setup do
    n = System.unique_integer([:positive])
    q = "Quercus#{n}"
    l = "Lobatae#{n}"
    st = "Stellatae#{n}"

    subgenus_q = taxon_fixture(name: q, level: "subgenus")
    section_q = taxon_fixture(name: q, level: "section", parent: subgenus_q)
    subgenus_l = taxon_fixture(name: l, level: "subgenus")
    taxon_fixture(name: l, level: "section", parent: subgenus_l)
    taxon_fixture(name: st, level: "subsection", parent: section_q)

    %{
      q: q,
      l: l,
      st: st,
      section_q: section_q,
      alba: species_fixture(scientific_name: "alba#{n}", subgenus: q, section: q).scientific_name,
      stellata:
        species_fixture(scientific_name: "stellata#{n}", subgenus: q, section: q, subsection: st).scientific_name,
      bebbiana:
        hybrid_fixture(scientific_name: "×bebbiana#{n}", subgenus: q, section: q).scientific_name,
      rubra:
        species_fixture(scientific_name: "rubra#{n}", subgenus: l, section: l).scientific_name,
      velutina:
        species_fixture(scientific_name: "velutina#{n}", subgenus: l, section: l).scientific_name
    }
  end

  defp card(view, path), do: view |> element(~s(a.taxon-card[href="#{path}"])) |> render()

  describe "GET /taxonomy (genus level)" do
    test "renders taxonomy root page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy")
      assert html =~ "Quercus"
      assert html =~ "Genus"
    end

    test "shows subgenera as child taxa", %{conn: conn, l: l} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy")
      assert html =~ "Subgenera"
      assert html =~ l
    end

    test "shows species counts on subgenus cards", %{conn: conn, q: q, l: l} do
      {:ok, view, _html} = live(conn, ~p"/taxonomy")
      assert card(view, "/taxonomy/#{q}") =~ "3 species"
      assert card(view, "/taxonomy/#{l}") =~ "2 species"
    end

    test "shows total species count in header", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy")
      assert html =~ "#{Species.count()} species"
    end

    test "the taxonomy band holds only the genus, as the current taxon", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/taxonomy")
      assert has_element?(view, "#taxonomy-band [aria-current]", "Quercus")
      refute has_element?(view, "#taxonomy-band a")
    end

    test "subgenus cards link to drill-down pages", %{conn: conn, q: q, l: l} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy")
      assert html =~ ~s(href="/taxonomy/#{q}")
      assert html =~ ~s(href="/taxonomy/#{l}")
    end
  end

  describe "subgenus level" do
    test "renders subgenus page", %{conn: conn, q: q} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy/#{q}")
      assert html =~ q
      assert html =~ "Subgenus"
    end

    test "shows the path in the taxonomy band", %{conn: conn, q: q} do
      {:ok, view, _html} = live(conn, ~p"/taxonomy/#{q}")
      assert has_element?(view, ~s(#taxonomy-band a[href="/taxonomy"]), "Quercus")
      assert has_element?(view, "#taxonomy-band [aria-current]", "subg.")
      assert has_element?(view, "#taxonomy-band [aria-current]", q)
    end

    test "shows sections as child taxa", %{conn: conn, q: q} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy/#{q}")
      assert html =~ "Sections"
    end
  end

  describe "section level" do
    test "renders section page with species", %{conn: conn, q: q, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy/#{q}/#{q}")
      assert html =~ "Section"
      assert html =~ alba
    end

    test "shows hybrid species with multiply sign", %{conn: conn, q: q, bebbiana: bebbiana} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy/#{q}/#{q}")
      "×" <> epithet = bebbiana
      assert html =~ "×"
      assert html =~ epithet
    end

    test "does not show species from deeper levels", %{conn: conn, q: q, stellata: stellata} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy/#{q}/#{q}")
      # stellata is in the subsection, so it doesn't appear at section level
      refute html =~ stellata
    end

    test "species link to detail pages", %{conn: conn, q: q, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy/#{q}/#{q}")
      assert html =~ ~s(href="/species/#{alba}")
    end

    test "shows subsections as child taxa", %{conn: conn, q: q, st: st} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy/#{q}/#{q}")
      assert html =~ "Subsections"
      assert html =~ st
    end

    test "the taxonomy band shows the full ancestry", %{conn: conn, q: q} do
      {:ok, view, _html} = live(conn, ~p"/taxonomy/#{q}/#{q}")
      assert has_element?(view, ~s(#taxonomy-band a[href="/taxonomy"]), "Quercus")
      assert has_element?(view, ~s(#taxonomy-band a[href="/taxonomy/#{q}"]), "subg.")
      assert has_element?(view, "#taxonomy-band [aria-current]", "sect.")
    end
  end

  describe "subsection level" do
    test "renders subsection page with species", %{conn: conn} = ctx do
      {:ok, _view, html} = live(conn, ~p"/taxonomy/#{ctx.q}/#{ctx.q}/#{ctx.st}")
      assert html =~ ctx.st
      assert html =~ "Subsection"
      assert html =~ ctx.stellata
    end
  end

  describe "a section without subsections" do
    test "shows its species", %{conn: conn, l: l, rubra: rubra, velutina: velutina} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy/#{l}/#{l}")
      assert html =~ rubra
      assert html =~ velutina
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
    test "clicking a subgenus card navigates to subgenus page", %{conn: conn, q: q} do
      {:ok, view, _html} = live(conn, ~p"/taxonomy")
      path = "/taxonomy/#{q}"

      # Clicking navigate links between separate live routes triggers a redirect
      {:error, {:live_redirect, %{to: ^path}}} =
        view
        |> element(~s(a[href="#{path}"]))
        |> render_click()
    end
  end

  describe "delete taxon" do
    setup %{conn: conn} do
      %{conn: log_in_user(conn, user_fixture())}
    end

    test "shows what still uses the taxon and offers no delete button", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, ~p"/taxonomy/#{ctx.q}/#{ctx.q}")

      html = render_click(view, "request_delete_taxon", %{"id" => to_string(ctx.section_q.id)})

      assert html =~ "3 species and 1 child taxon still use this taxon"
      refute has_element?(view, "#confirm-delete-taxon-btn")
      assert Oaks.Taxonomy.get_taxon_by_id(ctx.section_q.id)
    end

    test "deletes an unused taxon", %{conn: conn} = ctx do
      taxon = taxon_fixture(level: "complex", parent: ctx.st)

      {:ok, view, _html} = live(conn, ~p"/taxonomy/#{ctx.q}/#{ctx.q}/#{ctx.st}")
      render_click(view, "request_delete_taxon", %{"id" => to_string(taxon.id)})

      assert {:error, {:live_redirect, %{to: "/taxonomy"}}} =
               view |> element("#confirm-delete-taxon-btn") |> render_click()

      refute Oaks.Taxonomy.get_taxon_by_id(taxon.id)
    end
  end

  describe "complex directly under a section" do
    test "is listed on the section page and browsable", %{conn: conn} = ctx do
      group = "velutina-group#{ctx.l}"
      taxon_fixture(name: group, level: "complex", parent: ctx.l)

      Oaks.Species.get_species_by_name(ctx.velutina)
      |> Ecto.Changeset.change(complex: group)
      |> Oaks.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/taxonomy/#{ctx.l}/#{ctx.l}")
      assert html =~ group
      assert html =~ "Complexes"

      {:ok, _view, html} = live(conn, ~p"/taxonomy/#{ctx.l}/#{ctx.l}/#{group}")
      refute html =~ "Taxon Not Found"
      assert html =~ ctx.velutina
    end
  end
end
