defmodule OaksWeb.SpeciesDetailLiveTest do
  @moduledoc """
  Tests for the SpeciesDetailLive LiveView.
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.AccountsFixtures
  import Oaks.SourcesFixtures
  import Oaks.SpeciesFixtures

  # alba has two sources (the preferred one with full data) and lists
  # ×bebbiana, stellata, a synonym and a variety; ×bebbiana's parents are
  # alba × macrocarpa; velutina has no sources.
  setup do
    n = System.unique_integer([:positive])
    alba = "alba#{n}"
    bebbiana = "×bebbiana#{n}"
    stellata = species_fixture(scientific_name: "stellata#{n}").scientific_name

    hybrid_fixture(scientific_name: bebbiana, parent1: alba, parent2: "macrocarpa")

    alba_species =
      species_fixture(
        scientific_name: alba,
        author: "L. 1753",
        conservation_status: "LC",
        subgenus: "Quercus",
        section: "Quercus",
        hybrids: [bebbiana],
        closely_related_to: [stellata],
        synonyms: ["#{alba} var. repanda"],
        subspecies_varieties: ["#{alba} var. latiloba"]
      )

    ootw = source_fixture(name: "Oaks of the World #{n}")
    inat = source_fixture(name: "iNaturalist #{n}")

    species_source_fixture(alba_species, ootw,
      is_preferred: true,
      local_names: ["white oak", "eastern white oak"],
      range: "Eastern North America; 0 to 1600 m",
      growth_habit: "Reaches 25 m high",
      leaves: "8-20 cm long, obovate"
    )

    species_source_fixture(alba_species, inat)

    %{
      alba: alba,
      bebbiana: bebbiana,
      stellata: stellata,
      velutina: species_fixture(scientific_name: "velutina#{n}").scientific_name,
      ootw: ootw,
      inat: inat
    }
  end

  describe "GET /species/:name" do
    test "renders species detail page", %{conn: conn, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/species/#{alba}")
      assert html =~ alba
      assert html =~ "L. 1753"
    end

    test "shows species header with name and author", %{conn: conn, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/species/#{alba}")
      assert html =~ "Quercus"
      assert html =~ alba
      assert html =~ "L. 1753"
    end

    test "shows Species badge for non-hybrids", %{conn: conn, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/species/#{alba}")
      assert html =~ "Species"
    end

    test "shows conservation status badge", %{conn: conn, alba: alba} do
      {:ok, view, html} = live(conn, ~p"/species/#{alba}")
      assert has_element?(view, "#species-title .oc-title-meta .oc-iucn-lc", "IUCN LC")
      assert html =~ "Least Concern"
    end

    test "shows the taxonomy band above the title row, ending on the species", %{
      conn: conn,
      alba: alba
    } do
      {:ok, view, html} = live(conn, ~p"/species/#{alba}")
      assert has_element?(view, ".oc-pg-bleed #taxonomy-band")
      assert has_element?(view, ".oc-pg-head #species-title")
      assert has_element?(view, ~s(#taxonomy-band a[href="/taxonomy"]), "Quercus")
      assert has_element?(view, "#taxonomy-band a .oc-band-rk", "subg.")
      assert has_element?(view, "#taxonomy-band a .oc-band-rk", "sect.")
      assert has_element?(view, "#taxonomy-band [aria-current]", alba)
      refute html =~ "taxonomy-nav"
    end

    test "places a hybrid with no ranks of its own in the band where its parents sit", %{
      conn: conn,
      alba: alba
    } do
      other = species_fixture(subgenus: "Quercus", section: "Quercus")
      hybrid = hybrid_fixture(parent1: alba, parent2: other.scientific_name)

      {:ok, view, _html} = live(conn, ~p"/species/#{hybrid.scientific_name}")
      assert has_element?(view, ~s(#taxonomy-band a[href="/taxonomy/Quercus/Quercus"]), "sect.")
      assert has_element?(view, "#taxonomy-band [aria-current]", "×")
    end

    test "places a variety in the band under its species", %{conn: conn, alba: alba} do
      variety = species_fixture(scientific_name: "#{alba} latiloba", subgenus: "Quercus")

      {:ok, view, _html} = live(conn, ~p"/species/#{variety.scientific_name}")
      assert has_element?(view, ~s(#taxonomy-band a[href="/species/#{alba}"]), alba)
      assert has_element?(view, "#taxonomy-band [aria-current]", "latiloba")
    end

    test "shows source data from preferred source", %{conn: conn, alba: alba, ootw: ootw} do
      {:ok, _view, html} = live(conn, ~p"/species/#{alba}")
      assert html =~ ootw.name
      assert html =~ "Eastern North America"
      assert html =~ "Reaches 25 m high"
      assert html =~ "8-20 cm long, obovate"
    end

    test "shows common names from preferred source", %{conn: conn, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/species/#{alba}")
      assert html =~ "white oak"
      assert html =~ "eastern white oak"
    end

    test "shows source tabs", %{conn: conn, alba: alba, ootw: ootw, inat: inat} do
      {:ok, _view, html} = live(conn, ~p"/species/#{alba}")
      assert html =~ ootw.name
      assert html =~ inat.name
    end

    test "marks the preferred source's tab", %{conn: conn, alba: alba} do
      {:ok, view, _html} = live(conn, ~p"/species/#{alba}")
      assert has_element?(view, ".source-tab .source-tab-note", "preferred")
    end

    test "shows relationship sections", %{conn: conn} = ctx do
      {:ok, view, html} = live(conn, ~p"/species/#{ctx.alba}")
      "×" <> bebbiana_epithet = ctx.bebbiana
      assert html =~ "Known Hybrids"
      assert html =~ bebbiana_epithet
      assert html =~ "Closely Related"
      assert html =~ ctx.stellata
      assert has_element?(view, "#species-synonyms .oc-sci-e", "repanda")
      assert has_element?(view, "#species-subspecies .oc-sci-e", "latiloba")
    end

    test "sets every name through sci_name, by its role", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, ~p"/species/#{ctx.alba}")
      "×" <> bebbiana_epithet = ctx.bebbiana

      # The title row: the full genus at display size.
      assert has_element?(view, "#species-title h1 .oc-sci-display .oc-sci-g", "Quercus")
      assert has_element?(view, "#species-title h1 .oc-sci-display .oc-sci-e", ctx.alba)

      # Synonyms: names under the species, Q. abbreviated; rank words roman.
      assert has_element?(view, "#species-synonyms .oc-sci-g", "Q.")
      assert has_element?(view, "#species-synonyms .oc-sci-e", ctx.alba)
      assert has_element?(view, "#species-synonyms .oc-sci-r", "var.")

      # Hybrids and varieties: list entries under the species, Q. abbreviated.
      assert has_element?(view, "#species-hybrids .oc-sci-title .oc-sci-g", "Q.")
      assert has_element?(view, "#species-hybrids .oc-sci-x", "×")
      assert has_element?(view, "#species-hybrids .oc-sci-e", bebbiana_epithet)
      assert has_element?(view, "#species-subspecies .oc-sci-title .oc-sci-g", "Q.")
      assert has_element?(view, "#species-related .oc-sci-title .oc-sci-g", "Q.")
    end

    test "relationship links point to detail pages", %{conn: conn} = ctx do
      {:ok, _view, html} = live(conn, ~p"/species/#{ctx.alba}")
      # URL-encoded × in href
      assert html =~ ~s(href="#{~p"/species/#{ctx.bebbiana}"}")
      assert html =~ ~s(href="/species/#{ctx.stellata}")
    end
  end

  describe "hybrid species" do
    test "shows Hybrid badge", %{conn: conn, bebbiana: bebbiana} do
      {:ok, _view, html} = live(conn, ~p"/species/#{bebbiana}")
      assert html =~ "Hybrid"
    end

    test "shows hybrid multiply symbol", %{conn: conn, bebbiana: bebbiana} do
      {:ok, _view, html} = live(conn, ~p"/species/#{bebbiana}")
      # &times; renders as Unicode ×
      assert html =~ "×"
    end

    test "shows parent species section", %{conn: conn, bebbiana: bebbiana, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/species/#{bebbiana}")
      assert html =~ "Parent Species"
      assert html =~ alba
      assert html =~ "macrocarpa"
    end

    test "parent links point to detail pages", %{conn: conn, bebbiana: bebbiana, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/species/#{bebbiana}")
      assert html =~ ~s(href="/species/#{alba}")
      assert html =~ ~s(href="/species/macrocarpa")
    end
  end

  describe "source tab switching" do
    test "clicking a source tab shows that source's data", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, ~p"/species/#{ctx.alba}")

      # Initially shows the preferred source
      assert render(view) =~ "Data from #{ctx.ootw.name}"

      view
      |> element("button[phx-value-id='#{ctx.inat.id}']")
      |> render_click()

      assert render(view) =~ "Data from #{ctx.inat.name}"
    end
  end

  describe "not found" do
    test "an unknown species is a 404 with the not-found page", %{conn: conn} do
      {404, _headers, html} =
        assert_error_sent 404, fn -> get(conn, ~p"/species/nonexistent") end

      assert html =~ "<title>Species not found · Oak Compendium</title>"
      assert html =~ ~r{<h1>\s*Species not found\s*</h1>}
      assert html =~ "/species/nonexistent"
      assert html =~ ~s(value="nonexistent")
      assert html =~ ~r{<a href="/species" class="oc-btn">\s*Species list\s*</a>}
    end

    test "the LiveView raises the not-found error", %{conn: conn} do
      assert_raise OaksWeb.NotFoundError, fn -> live(conn, ~p"/species/nonexistent") end
    end
  end

  describe "synonym redirect" do
    test "redirects to canonical species when synonym is found", %{conn: conn, alba: alba} do
      # push_navigate causes a live_redirect which we must follow
      path = "/species/#{alba}"

      assert {:error, {:live_redirect, %{to: ^path}}} =
               live(conn, ~p"/species/#{alba <> " var. repanda"}")
    end

    test "redirects when the stored synonym includes authorship", %{conn: conn} do
      species = species_fixture(synonyms: ["repanda#{System.unique_integer([:positive])} Michx."])
      [synonym, _author] = species.synonyms |> Jason.decode!() |> hd() |> String.split()
      path = "/species/#{species.scientific_name}"

      assert {:error, {:live_redirect, %{to: ^path}}} = live(conn, ~p"/species/#{synonym}")
    end
  end

  describe "delete confirmation" do
    test "lists the species that mention it", %{conn: conn, alba: alba, bebbiana: bebbiana} do
      conn = log_in_user(conn, user_fixture())
      {:ok, view, _html} = live(conn, ~p"/species/#{alba}")

      render_click(view, "request_delete")

      "×" <> bebbiana_epithet = bebbiana
      assert has_element?(view, "#delete-references", bebbiana_epithet)
      assert has_element?(view, "#delete-references", "parent")
    end

    test "says the species' photos go with it", %{conn: conn, velutina: velutina} do
      scope = Oaks.ImagesFixtures.editor_scope()
      observation = Oaks.ImagesFixtures.observation()
      species = Oaks.Species.get_species_by_name(velutina)

      for photo <- observation.photos,
          do: Oaks.ImagesFixtures.import_photo(species, observation, scope, photo)

      {:ok, view, _html} = conn |> log_in_user(user_fixture()) |> live(~p"/species/#{velutina}")
      render_click(view, "request_delete")

      assert has_element?(view, "#delete-confirm-modal", "Its 2 photos go with it")
    end
  end

  describe "malformed stored lists" do
    test "renders when list columns hold non-name entries", %{conn: conn} = ctx do
      Oaks.Species.get_species_by_name(ctx.alba)
      |> Ecto.Changeset.change(
        hybrids: ~s([1, "#{ctx.bebbiana}"]),
        closely_related_to: ~s([{"name": "x"}, "#{ctx.stellata}"]),
        subspecies_varieties: ~s([null])
      )
      |> Oaks.Repo.update!()

      "×" <> bebbiana_epithet = ctx.bebbiana
      {:ok, _view, html} = live(conn, ~p"/species/#{ctx.alba}")
      assert html =~ bebbiana_epithet
      assert html =~ ctx.stellata
    end
  end

  describe "species without sources" do
    test "shows no source data message", %{conn: conn, velutina: velutina} do
      {:ok, _view, html} = live(conn, ~p"/species/#{velutina}")
      assert html =~ "No source data available"
    end

    test "hides Add source data when unauthenticated", %{conn: conn, velutina: velutina} do
      {:ok, view, _html} = live(conn, ~p"/species/#{velutina}")
      refute has_element?(view, "#add-source-btn")
    end

    test "the Edit menu holds Add source data when authenticated", %{
      conn: conn,
      velutina: velutina
    } do
      conn = log_in_user(conn, user_fixture())
      {:ok, view, _html} = live(conn, ~p"/species/#{velutina}")

      assert has_element?(
               view,
               ~s|#species-edit-menu #add-source-btn[href="/species/#{velutina}/sources/new"]|,
               "Add source data"
             )
    end
  end
end
