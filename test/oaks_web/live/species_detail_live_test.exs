defmodule OaksWeb.SpeciesDetailLiveTest do
  @moduledoc """
  Tests for the SpeciesDetailLive LiveView: the species page for today's
  data (docs/species-photos-plan.md, Phase 4 decisions and Phase 7), and
  the page regression checks of the plan's acceptance table.
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.AccountsFixtures
  import Oaks.SourcesFixtures
  import Oaks.SpeciesFixtures

  alias Oaks.Repo
  alias Oaks.Sources.Source

  # alba has two sources (the preferred one with full data) and lists
  # ×bebbiana, stellata as closely related, a synonym, a variety and a
  # stored external link; ×bebbiana's parents are alba × macrocarpa;
  # velutina has no sources.
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
        subspecies_varieties: ["#{alba} var. latiloba"],
        external_links:
          Jason.encode!([
            %{name: "Flora of North America", url: "https://floranorthamerica.org/x"}
          ])
      )

    ootw = source_fixture(name: "Oaks of the World #{n}")
    inat = source_fixture(name: "iNaturalist #{n}")

    species_source_fixture(alba_species, ootw,
      is_preferred: true,
      url: "https://oaksoftheworld.fr/quercus_alba.htm",
      local_names: ["white oak", "eastern white oak"],
      range: "Eastern North America; 0 to 1600 m",
      growth_habit: "Reaches 25 m high",
      leaves: "8-20 cm long, obovate"
    )

    species_source_fixture(alba_species, inat)

    %{
      alba: alba,
      alba_species: alba_species,
      bebbiana: bebbiana,
      stellata: stellata,
      velutina: species_fixture(scientific_name: "velutina#{n}").scientific_name,
      ootw: ootw,
      inat: inat
    }
  end

  # The source the display contract treats by its id (3 is Oak Compendium,
  # 2 Oaks of the World): created when the test database has none.
  defp source_with_id(id) do
    Repo.insert!(%Source{id: id, name: "Source #{id}", source_type: "website"},
      on_conflict: :nothing
    )

    Repo.get!(Source, id)
  end

  # The tabs' names, in order.
  defp tab_names(view) do
    html = view |> element("#source-tabs [role=tablist]") |> render()

    ~r{role="tab".*?>\s*(.*?)\s*</button>}s
    |> Regex.scan(html, capture: :all_but_first)
    |> Enum.map(&hd/1)
  end

  describe "the title row and the band" do
    test "shows the name, author, kind word and IUCN stamp", %{conn: conn, alba: alba} do
      {:ok, view, html} = live(conn, ~p"/species/#{alba}")
      assert has_element?(view, "#species-title h1 .oc-sci-display .oc-sci-g", "Quercus")
      assert has_element?(view, "#species-title h1 .oc-sci-display .oc-sci-e", alba)
      assert has_element?(view, "#species-title h1", "L. 1753")
      assert has_element?(view, "#species-title .oc-title-meta", "Species")
      assert has_element?(view, "#species-title .oc-title-meta .oc-iucn-lc", "IUCN LC")
      assert html =~ "Least Concern"
    end

    test "names the common name the source order picks, with a mark that opens its tab", %{
      conn: conn,
      alba: alba,
      ootw: ootw
    } do
      {:ok, view, _html} = live(conn, ~p"/species/#{alba}")

      assert has_element?(view, "#species-title .oc-title-cn", "white oak")
      refute has_element?(view, "#species-title .oc-title-cn", "eastern white oak")

      assert has_element?(
               view,
               ~s(#species-title .oc-title-cn a.oc-src[href="/species/#{alba}?source=#{ootw.id}"]),
               ootw.name
             )
    end

    test "shows the taxonomy band above the title row, ending on the species", %{
      conn: conn,
      alba: alba
    } do
      {:ok, view, _html} = live(conn, ~p"/species/#{alba}")
      assert has_element?(view, ".oc-pg-bleed #taxonomy-band")
      assert has_element?(view, ".oc-pg-head #species-title")
      assert has_element?(view, ~s(#taxonomy-band a[href="/taxonomy"]), "Quercus")
      assert has_element?(view, "#taxonomy-band a .oc-band-rk", "sect.")
      assert has_element?(view, "#taxonomy-band [aria-current]", alba)
    end

    test "the band's siblings menu lists the species beside it, the species marked", %{
      conn: conn
    } do
      complex = "complex#{System.unique_integer([:positive])}"
      a = species_fixture(complex: complex)
      b = species_fixture(complex: complex)

      {:ok, view, _html} = live(conn, ~p"/species/#{a.scientific_name}")

      assert has_element?(
               view,
               "#taxonomy-band-siblings summary",
               "#{complex} complex · 2 species"
             )

      assert has_element?(
               view,
               "#taxonomy-band-siblings [aria-current=page]",
               a.scientific_name
             )

      assert has_element?(
               view,
               ~s(#taxonomy-band-siblings a[href="/species/#{b.scientific_name}"])
             )
    end

    test "a species alone in its group has no siblings menu", %{conn: conn, velutina: velutina} do
      {:ok, view, _html} = live(conn, ~p"/species/#{velutina}")
      refute has_element?(view, "#taxonomy-band-siblings")
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
  end

  describe "a hybrid's title row" do
    test "says its parents, linked, as the subtitle", %{
      conn: conn,
      bebbiana: bebbiana,
      alba: alba
    } do
      {:ok, view, _html} = live(conn, ~p"/species/#{bebbiana}")
      assert has_element?(view, "#species-title .oc-title-meta", "Hybrid")
      assert has_element?(view, "#species-title h1 .oc-sci-x", "×")
      assert has_element?(view, "#species-parents", "Hybrid of")
      assert has_element?(view, ~s(#species-parents a[href="/species/#{alba}"]))
      assert has_element?(view, ~s(#species-parents a[href="/species/macrocarpa"]))
      refute has_element?(view, "#species-parents", "unrecorded")
    end

    test "names an unrecorded parent when only one is known", %{conn: conn, alba: alba} do
      hybrid = hybrid_fixture(parent1: alba)

      {:ok, view, _html} = live(conn, ~p"/species/#{hybrid.scientific_name}")
      assert has_element?(view, ~s(#species-parents a[href="/species/#{alba}"]))
      assert has_element?(view, "#species-parents", "and an unrecorded parent")
    end

    test "a species has no parents line", %{conn: conn, alba: alba} do
      {:ok, view, _html} = live(conn, ~p"/species/#{alba}")
      refute has_element?(view, "#species-parents")
    end
  end

  describe "source tabs" do
    test "one tab per source, the preferred first, opening on it with all its text", %{
      conn: conn,
      alba: alba,
      ootw: ootw,
      inat: inat
    } do
      {:ok, view, html} = live(conn, ~p"/species/#{alba}")

      assert tab_names(view) == [ootw.name, inat.name]
      assert has_element?(view, "#source-tabs-tab-#{ootw.id}[aria-selected=true]")

      for {label, text} <- [
            {"Common names", "white oak, eastern white oak"},
            {"Geographic range", "Eastern North America; 0 to 1600 m"},
            {"Growth habit", "Reaches 25 m high"},
            {"Leaves", "8-20 cm long, obovate"}
          ] do
        assert has_element?(view, "#source-tabs-panel .oc-tabs-field h3", label)
        assert has_element?(view, "#source-tabs-panel .oc-tabs-value", text)
      end

      refute has_element?(view, "#source-tabs-panel h3", "Flowers")
      refute html =~ "preferred"
      refute html =~ "Data from"
    end

    test "the open tab's one icon link goes to the original page, or the source's page", %{
      conn: conn,
      alba: alba,
      inat: inat
    } do
      {:ok, view, _html} = live(conn, ~p"/species/#{alba}")

      assert has_element?(
               view,
               ~s(#source-tabs a.oc-tab-link[href="https://oaksoftheworld.fr/quercus_alba.htm"])
             )

      assert view |> element("#source-tabs") |> render() |> count("oc-tab-link") == 1

      view |> element("#source-tabs-tab-#{inat.id}") |> render_click()

      assert has_element?(view, ~s(#source-tabs a.oc-tab-link[href="/sources/#{inat.id}"]))
      assert view |> element("#source-tabs") |> render() |> count("oc-tab-link") == 1
    end

    test "clicking a tab opens it at its own address; an empty one says so", %{
      conn: conn,
      alba: alba,
      inat: inat
    } do
      {:ok, view, _html} = live(conn, ~p"/species/#{alba}")

      view |> element("#source-tabs-tab-#{inat.id}") |> render_click()

      assert_patch(view, ~p"/species/#{alba}?source=#{inat.id}")
      assert has_element?(view, "#source-tabs-tab-#{inat.id}[aria-selected=true]")
      assert has_element?(view, "#source-tabs-panel", "No text from #{inat.name} yet.")
      refute has_element?(view, "#source-tabs-panel", "Eastern North America")
    end

    test "the address opens a tab; an unknown source falls back to the default", %{
      conn: conn,
      alba: alba,
      ootw: ootw,
      inat: inat
    } do
      {:ok, view, _html} = live(conn, ~p"/species/#{alba}?source=#{inat.id}")
      assert has_element?(view, "#source-tabs-tab-#{inat.id}[aria-selected=true]")

      {:ok, view, _html} = live(conn, ~p"/species/#{alba}?source=999999999")
      assert has_element?(view, "#source-tabs-tab-#{ootw.id}[aria-selected=true]")
    end

    test "opens on the first source with text when the preferred one has none", %{conn: conn} do
      species = species_fixture()
      empty = source_fixture(name: "Aaa empty")
      full = source_fixture(name: "Zzz full")
      species_source_fixture(species, empty, is_preferred: true, leaves: "   ")
      species_source_fixture(species, full, bark: "Furrowed.")

      {:ok, view, _html} = live(conn, ~p"/species/#{species.scientific_name}")

      assert tab_names(view) == ["Aaa empty", "Zzz full"]
      assert has_element?(view, "#source-tabs-tab-#{full.id}[aria-selected=true]")
      assert has_element?(view, "#source-tabs-panel", "Furrowed.")
    end

    test "keeps a source's full text and Markdown", %{conn: conn} do
      species = species_fixture()
      long = String.duplicate("Lobes deep and narrow. ", 200) <> "The end of the text."
      species_source_fixture(species, source_fixture(), leaves: long <> "\n\n- first\n- second")

      {:ok, view, _html} = live(conn, ~p"/species/#{species.scientific_name}")
      assert has_element?(view, "#source-tabs-panel .oc-prose", "The end of the text.")
      assert has_element?(view, "#source-tabs-panel .oc-prose li", "second")
    end

    test "Compare sources shows with two or more sources only", %{conn: conn, alba: alba} do
      {:ok, view, _html} = live(conn, ~p"/species/#{alba}")

      assert has_element?(
               view,
               ~s(#source-tabs a[href="/species/#{alba}/compare"]),
               "Compare sources"
             )

      one = species_fixture()
      species_source_fixture(one, source_fixture(), leaves: "x")
      {:ok, view, _html} = live(conn, ~p"/species/#{one.scientific_name}")
      refute has_element?(view, "#source-tabs", "Compare sources")
    end

    test "a species with no sources says so where the tabs would be", %{
      conn: conn,
      velutina: velutina
    } do
      {:ok, view, _html} = live(conn, ~p"/species/#{velutina}")
      assert has_element?(view, "#source-tabs", "No source data for this oak yet.")
      refute has_element?(view, "#source-tabs [role=tablist]")
      refute has_element?(view, "#species-sources")
    end
  end

  describe "per-field fallback and Oak Compendium" do
    setup %{alba_species: species} do
      oc = source_with_id(3)
      ootw = source_with_id(2)
      %{species: species, oc: oc, ootw2: ootw}
    end

    test "blank Oak Compendium data: the notice shows and nothing is attributed to it", %{
      conn: conn,
      oc: oc,
      ootw2: ootw
    } do
      species = species_fixture()
      species_source_fixture(species, oc, leaves: "  ", local_names: [" "])
      species_source_fixture(species, ootw, leaves: "Lobed.", local_names: ["Their oak"])

      {:ok, view, _html} = live(conn, ~p"/species/#{species.scientific_name}")

      assert has_element?(view, "#not-covered", "no account of this oak yet")
      assert has_element?(view, "#not-covered", "Everything on this page comes from the sources")
      assert tab_names(view) == [oc.name, ootw.name]
      assert has_element?(view, "#source-tabs-tab-#{ootw.id}[aria-selected=true]")
      assert has_element?(view, "#species-title .oc-title-cn", "Their oak")
      assert has_element?(view, "#species-title .oc-title-cn .oc-src", ootw.name)
      refute has_element?(view, "#species-title .oc-title-cn .oc-src", oc.name)

      view |> element("#source-tabs-tab-#{oc.id}") |> render_click()
      assert has_element?(view, "#source-tabs-panel", "No text from #{oc.name} yet.")
      refute has_element?(view, "#source-tabs-panel", "Lobed.")
    end

    test "absent Oak Compendium data: Oaks of the World leads, ahead of the rest by name", %{
      conn: conn,
      ootw2: ootw
    } do
      species = species_fixture()
      species_source_fixture(species, source_fixture(name: "Aardvark"), leaves: "A.")
      species_source_fixture(species, ootw, leaves: "O.")

      {:ok, view, _html} = live(conn, ~p"/species/#{species.scientific_name}")

      assert has_element?(view, "#not-covered")
      assert tab_names(view) == [ootw.name, "Aardvark"]
      assert has_element?(view, "#source-tabs-tab-#{ootw.id}[aria-selected=true]")
    end

    test "Oak Compendium text: no notice, its tab opens first", %{
      conn: conn,
      oc: oc,
      ootw2: ootw
    } do
      species = species_fixture()
      species_source_fixture(species, ootw, leaves: "O.", local_names: ["Theirs"])
      species_source_fixture(species, oc, twigs: "Green.", local_names: ["Ours"])

      {:ok, view, _html} = live(conn, ~p"/species/#{species.scientific_name}")

      refute has_element?(view, "#not-covered")
      assert tab_names(view) == [oc.name, ootw.name]
      assert has_element?(view, "#source-tabs-tab-#{oc.id}[aria-selected=true]")
      assert has_element?(view, "#species-title .oc-title-cn", "Ours")
    end

    test "a species with no sources gets the notice without the sources line", %{
      conn: conn,
      velutina: velutina
    } do
      {:ok, view, _html} = live(conn, ~p"/species/#{velutina}")
      assert has_element?(view, "#not-covered", "no account of this oak yet")
      refute has_element?(view, "#not-covered", "Everything on this page")
    end
  end

  describe "the sections below" do
    test "follow the main content in order, each only with data", %{conn: conn} = ctx do
      {:ok, view, html} = live(conn, ~p"/species/#{ctx.alba}")

      ids = ~w(species-synonyms species-subspecies species-hybrids species-external-links
               species-sources species-cite)

      positions = Enum.map(ids, &(:binary.match(html, ~s(id="#{&1}")) |> elem(0)))
      assert positions == Enum.sort(positions)
      assert hd(positions) > elem(:binary.match(html, ~s(id="source-tabs")), 0)

      {:ok, view2, _html} = live(conn, ~p"/species/#{ctx.velutina}")

      for id <- ~w(species-synonyms species-subspecies species-hybrids species-sources),
          do: refute(has_element?(view2, "##{id}"))

      assert has_element?(view, "#species-cite")
    end

    test "synonyms, varieties and hybrids set every name through sci_name", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, ~p"/species/#{ctx.alba}")
      "×" <> bebbiana_epithet = ctx.bebbiana

      assert has_element?(view, "#species-synonyms", "1 name")
      assert has_element?(view, "#species-synonyms .oc-sci-g", "Q.")
      assert has_element?(view, "#species-synonyms .oc-sci-e", "repanda")
      assert has_element?(view, "#species-synonyms .oc-sci-r", "var.")

      assert has_element?(view, "#species-subspecies .oc-sci-title .oc-sci-g", "Q.")
      assert has_element?(view, "#species-subspecies .oc-sci-e", "latiloba")

      assert has_element?(view, "#species-hybrids", "1 known")
      assert has_element?(view, "#species-hybrids .oc-sci-title .oc-sci-x", "×")
      assert has_element?(view, "#species-hybrids .oc-sci-e", bebbiana_epithet)

      assert has_element?(
               view,
               ~s(#species-hybrids a[href="#{~p"/species/#{ctx.bebbiana}"}"]),
               bebbiana_epithet
             )

      assert has_element?(view, "#species-hybrids .oc-rows-with", "with")
      assert has_element?(view, ~s(#species-hybrids a[href="/species/macrocarpa"]))
    end

    test "closely related names are no longer shown", %{conn: conn} = ctx do
      {:ok, _view, html} = live(conn, ~p"/species/#{ctx.alba}")
      refute html =~ ctx.stellata
      refute html =~ "Closely"
    end

    test "external links: the stored ones and iNaturalist and Wikipedia, by name", %{
      conn: conn,
      alba: alba
    } do
      {:ok, view, _html} = live(conn, ~p"/species/#{alba}")

      section = view |> element("#species-external-links") |> render()

      names =
        ~r{class="oc-rows-text">\s*(.*?)\s*</span>}s
        |> Regex.scan(section, capture: :all_but_first)
        |> Enum.map(&hd/1)

      assert names == ["Flora of North America", "iNaturalist", "Wikipedia"]

      assert has_element?(
               view,
               ~s(#species-external-links a[href="https://floranorthamerica.org/x"][target=_blank]),
               "floranorthamerica.org"
             )

      assert has_element?(
               view,
               ~s(#species-external-links a[href="https://en.wikipedia.org/wiki/Quercus_#{alba}"])
             )
    end

    test "sources: each linked to its page, with its original page", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, ~p"/species/#{ctx.alba}")

      assert has_element?(
               view,
               ~s(#species-sources a[href="/sources/#{ctx.ootw.id}"]),
               ctx.ootw.name
             )

      assert has_element?(
               view,
               ~s(#species-sources a[href="/sources/#{ctx.inat.id}"]),
               ctx.inat.name
             )

      assert has_element?(
               view,
               ~s(#species-sources a.oc-src[href="https://oaksoftheworld.fr/quercus_alba.htm"]),
               "original page"
             )
    end

    test "the cite line never doubles the full stop after an authority", %{conn: conn} do
      for {author, expected} <- [
            {"Torr.", "Torr. http"},
            {"Buckley", "Buckley. http"},
            {nil, ". http"}
          ] do
        species = species_fixture(author: author)
        {:ok, view, _html} = live(conn, ~p"/species/#{species.scientific_name}")

        text =
          view |> element("#species-cite") |> render() |> String.replace(~r/<[^>]+>/, "")

        text = String.replace(text, ~r/\s+/, " ")

        assert text =~ expected
        refute text =~ ".."
      end
    end

    test "the cite line names the site and the page, never a person", %{conn: conn, alba: alba} do
      {:ok, view, _html} = live(conn, ~p"/species/#{alba}")

      assert has_element?(view, "#species-cite", "Oak Compendium.")
      assert has_element?(view, "#species-cite .oc-sci-e", alba)

      assert has_element?(
               view,
               "#species-cite",
               "/species/#{alba} (accessed #{Date.utc_today()})"
             )
    end
  end

  describe "photos" do
    test "the photo column says there are none yet", %{conn: conn, alba: alba} do
      {:ok, view, _html} = live(conn, ~p"/species/#{alba}")
      assert has_element?(view, "#species-main aside #species-photos", "No photos yet.")
    end
  end

  describe "editor actions" do
    test "a visitor sees no Edit menus", %{conn: conn, alba: alba} do
      {:ok, view, _html} = live(conn, ~p"/species/#{alba}")
      refute has_element?(view, "#species-edit-menu")
      refute has_element?(view, "#source-data-menu")
    end

    test "the title row's Edit menu holds every species action", %{conn: conn, alba: alba} do
      {:ok, view, _html} = conn |> log_in_user(user_fixture()) |> live(~p"/species/#{alba}")

      assert has_element?(
               view,
               ~s(#edit-species-btn[href="/species/#{alba}/edit"]),
               "Edit species"
             )

      assert has_element?(view, "#add-photos-btn", "Add photos from iNaturalist…")
      assert has_element?(view, "#manage-photos-btn", "Manage photos…")
      assert has_element?(view, "#merge-species-btn", "Make synonym of…")
      assert has_element?(view, "#delete-species-btn", "Delete species")
    end

    test "the quiet Edit menu beside the tabs edits and deletes the open source's data",
         %{
           conn: conn
         } = ctx do
      {:ok, view, _html} = conn |> log_in_user(user_fixture()) |> live(~p"/species/#{ctx.alba}")

      assert has_element?(
               view,
               ~s(#source-tabs #source-data-menu #edit-source-data-btn[href="/species/#{ctx.alba}/sources/#{ctx.ootw.id}/edit"]),
               "Edit #{ctx.ootw.name} data"
             )

      view |> element("#source-tabs-tab-#{ctx.inat.id}") |> render_click()
      assert has_element?(view, "#delete-source-data-btn", "Delete #{ctx.inat.name} data")

      view |> element("#delete-source-data-btn") |> render_click()
      assert has_element?(view, "#delete-source-confirm-modal", ctx.inat.name)

      view |> element("#confirm-delete-source-btn") |> render_click()
      assert_redirect(view, ~p"/species/#{ctx.alba}")
      assert Oaks.Species.get_species_full(ctx.alba).species_sources |> length() == 1
    end

    test "a visitor's forged delete-source event writes nothing", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, ~p"/species/#{ctx.alba}")
      [ss | _] = Oaks.Species.get_species_full(ctx.alba).species_sources

      render_click(view, "request_delete_source", %{"id" => "#{ss.id}"})
      render_click(view, "confirm_delete_source", %{})

      assert Oaks.Species.get_species_full(ctx.alba).species_sources |> length() == 2
    end

    test "Make synonym of… opens the picker", %{conn: conn, alba: alba} do
      {:ok, view, _html} = conn |> log_in_user(user_fixture()) |> live(~p"/species/#{alba}")
      view |> element("#merge-species-btn") |> render_click()
      assert has_element?(view, "#merge-picker-dialog")
    end

    test "Add source data is offered only while a source is left to add", %{
      conn: conn,
      velutina: velutina
    } do
      {:ok, view, _html} = live(conn, ~p"/species/#{velutina}")
      refute has_element?(view, "#add-source-btn")

      {:ok, view, _html} = conn |> log_in_user(user_fixture()) |> live(~p"/species/#{velutina}")

      assert has_element?(
               view,
               ~s|#species-edit-menu #add-source-btn[href="/species/#{velutina}/sources/new"]|,
               "Add source data"
             )
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
        subspecies_varieties: ~s([null]),
        external_links: ~s([{"name": 1}, "x"])
      )
      |> Oaks.Repo.update!()

      "×" <> bebbiana_epithet = ctx.bebbiana
      {:ok, _view, html} = live(conn, ~p"/species/#{ctx.alba}")
      assert html =~ bebbiana_epithet
      assert html =~ "Wikipedia"
    end
  end

  defp count(html, needle), do: html |> String.split(needle) |> length() |> Kernel.-(1)
end
