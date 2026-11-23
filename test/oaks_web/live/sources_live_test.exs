defmodule OaksWeb.SourcesLiveTest do
  @moduledoc """
  Tests for the SourcesLive LiveView.
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.SourcesFixtures
  import Oaks.SpeciesFixtures

  # `ootw` has data for two species; the others have none.
  setup do
    n = System.unique_integer([:positive])

    inat =
      source_fixture(
        name: "iNaturalist #{n}",
        description: "Authoritative taxonomy and species list"
      )

    ootw =
      source_fixture(
        name: "Oaks of the World #{n}",
        description: "Rich descriptive data (morphology, distribution)"
      )

    compendium = source_fixture(name: "Oak Compendium #{n}", source_type: "personal_observation")

    species_source_fixture(species_fixture(), ootw)
    species_source_fixture(species_fixture(), ootw)

    %{sources: [inat, ootw, compendium], ootw: ootw}
  end

  defp card(view, source), do: view |> element(".source-card", source.name) |> render()

  describe "GET /sources" do
    test "renders sources list page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources")
      assert html =~ "Data sources"
    end

    test "displays all sources", %{conn: conn, sources: sources} do
      {:ok, _view, html} = live(conn, ~p"/sources")

      for source <- sources do
        assert html =~ source.name
      end
    end

    test "shows source descriptions", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources")
      assert html =~ "Rich descriptive data"
      assert html =~ "Authoritative taxonomy"
    end

    test "shows source type badges", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources")
      assert html =~ "website"
      assert html =~ "personal_observation"
    end

    test "shows species count for sources with species", %{conn: conn, sources: sources} do
      [inat, ootw, _] = sources
      {:ok, view, _html} = live(conn, ~p"/sources")
      assert card(view, ootw) =~ "2 species"
      refute card(view, inat) =~ "source-card-count"
    end

    test "source cards link to detail pages", %{conn: conn, sources: sources} do
      {:ok, _view, html} = live(conn, ~p"/sources")

      for source <- sources do
        assert html =~ ~s(href="/sources/#{source.id}")
      end
    end

    test "clicking a source navigates to detail page", %{conn: conn, ootw: ootw} do
      {:ok, view, _html} = live(conn, ~p"/sources")

      {:ok, _view, html} =
        view
        |> element(~s(a[href="/sources/#{ootw.id}"]))
        |> render_click()
        |> follow_redirect(conn)

      assert html =~ ootw.name
    end

    test "editor buttons on a row name their source", %{conn: conn, ootw: ootw} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      {:ok, view, _html} = live(conn, ~p"/sources")

      menu = "#source-#{ootw.id}-menu"
      assert has_element?(view, menu <> ~s( summary[aria-label="Edit #{ootw.name}"]))
      assert has_element?(view, menu <> ~s( a[href="/sources/#{ootw.id}/edit"]), "Edit source")
      assert has_element?(view, menu <> " button", "Delete source")
    end
  end
end
