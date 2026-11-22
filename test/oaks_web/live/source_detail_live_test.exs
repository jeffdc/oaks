defmodule OaksWeb.SourceDetailLiveTest do
  @moduledoc """
  Tests for the SourceDetailLive LiveView.
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.SourcesFixtures
  import Oaks.SpeciesFixtures

  # `ootw` has data for alba and rubra; `compendium` for stellata.
  setup do
    n = System.unique_integer([:positive])

    ootw =
      source_fixture(
        name: "Oaks of the World #{n}",
        description: "Rich descriptive data (morphology, distribution)",
        url: "https://oaksoftheworld.fr"
      )

    compendium = source_fixture(name: "Oak Compendium #{n}", source_type: "personal_observation")

    alba = species_fixture(scientific_name: "alba#{n}")
    rubra = species_fixture(scientific_name: "rubra#{n}")
    stellata = species_fixture(scientific_name: "stellata#{n}")

    species_source_fixture(alba, ootw)
    species_source_fixture(rubra, ootw)
    species_source_fixture(stellata, compendium)

    %{
      ootw: ootw,
      compendium: compendium,
      alba: alba.scientific_name,
      rubra: rubra.scientific_name,
      stellata: stellata.scientific_name
    }
  end

  describe "GET /sources/:id" do
    test "renders source detail page", %{conn: conn, ootw: ootw} do
      {:ok, _view, html} = live(conn, ~p"/sources/#{ootw.id}")
      assert html =~ ootw.name
    end

    test "sets the name, type and editor actions on the title row", %{
      conn: conn,
      compendium: compendium
    } do
      {:ok, view, _html} = live(conn, ~p"/sources/#{compendium.id}")
      assert has_element?(view, "#source-title h1", compendium.name)
      assert has_element?(view, "#source-title .oc-title-meta .oc-status", "personal_observation")
      refute has_element?(view, "#source-title .oc-title-actions")

      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      {:ok, view, _html} = live(conn, ~p"/sources/#{compendium.id}")
      assert has_element?(view, "#source-title .oc-title-actions #edit-source-btn")
      assert has_element?(view, "#source-title .oc-title-actions #delete-source-btn")
    end

    test "shows source metadata", %{conn: conn, ootw: ootw} do
      {:ok, _view, html} = live(conn, ~p"/sources/#{ootw.id}")
      assert html =~ "website"
      assert html =~ "https://oaksoftheworld.fr"
    end

    test "shows description", %{conn: conn, ootw: ootw} do
      {:ok, _view, html} = live(conn, ~p"/sources/#{ootw.id}")
      assert html =~ "Rich descriptive data"
    end

    test "shows source URL as clickable link", %{conn: conn, ootw: ootw} do
      {:ok, _view, html} = live(conn, ~p"/sources/#{ootw.id}")
      assert html =~ ~s(href="https://oaksoftheworld.fr")
      assert html =~ "target=\"_blank\""
    end

    test "shows species count in coverage section", %{conn: conn, ootw: ootw} do
      {:ok, view, html} = live(conn, ~p"/sources/#{ootw.id}")
      assert html =~ "Coverage"
      assert has_element?(view, ".source-coverage-count", "2 species")
    end

    test "lists associated species", %{conn: conn} = ctx do
      {:ok, _view, html} = live(conn, ~p"/sources/#{ctx.ootw.id}")
      assert html =~ "Species with Data from This Source"
      assert html =~ ctx.alba
      assert html =~ ctx.rubra
      refute html =~ ctx.stellata
    end

    test "species link to detail pages", %{conn: conn} = ctx do
      {:ok, _view, html} = live(conn, ~p"/sources/#{ctx.ootw.id}")
      assert html =~ ~s(href="/species/#{ctx.alba}")
      assert html =~ ~s(href="/species/#{ctx.rubra}")
    end

    test "a single-species source shows its species", %{conn: conn} = ctx do
      {:ok, _view, html} = live(conn, ~p"/sources/#{ctx.compendium.id}")
      assert html =~ ctx.compendium.name
      assert html =~ "Species with Data from This Source"
      assert html =~ ctx.stellata
    end
  end

  describe "not found" do
    test "an unknown source ID is a 404 with the not-found page", %{conn: conn} do
      {404, _headers, html} = assert_error_sent 404, fn -> get(conn, ~p"/sources/0") end

      assert html =~ "<title>Source not found · Oak Compendium</title>"
      assert html =~ ~r{<h1>\s*Source not found\s*</h1>}
      assert html =~ "/sources/0"
      assert html =~ ~r{<a href="/sources" class="oc-btn">\s*Sources\s*</a>}
      assert_raise OaksWeb.NotFoundError, fn -> live(conn, ~p"/sources/0") end
    end

    test "an ID that isn't a number is a 404", %{conn: conn} do
      {404, _headers, html} = assert_error_sent 404, fn -> get(conn, ~p"/sources/abc") end
      assert html =~ ~r{<h1>\s*Source not found\s*</h1>}
    end
  end

  describe "delete" do
    test "a source with species data can't be deleted, and the dialog only closes", %{
      conn: conn,
      ootw: ootw
    } do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      {:ok, view, _html} = live(conn, ~p"/sources/#{ootw.id}")

      view |> element("#delete-source-btn") |> render_click()

      assert has_element?(view, "[role=dialog]", "Can't Delete Source")
      assert has_element?(view, "[role=dialog]", "2 species have data from this source")
      refute has_element?(view, "[role=dialog] [phx-click=confirm_delete]")
      assert has_element?(view, "[role=dialog] [phx-click=cancel_delete]", "Close")
    end
  end
end
