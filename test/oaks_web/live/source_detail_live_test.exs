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
      {:ok, _view, html} = live(conn, ~p"/sources/#{ootw.id}")
      assert html =~ "Coverage"
      assert html =~ "Species"
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
    test "shows not found for unknown source ID", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources/0")
      assert html =~ "Source Not Found"
      assert html =~ "Back to Sources"
    end

    test "shows not found for invalid ID", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources/abc")
      assert html =~ "Source Not Found"
    end

    test "not found page has link back to sources list", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources/0")
      assert html =~ ~s(href="/sources")
    end
  end
end
