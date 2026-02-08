defmodule OaksWeb.SourcesLiveTest do
  @moduledoc """
  Tests for the SourcesLive LiveView.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "GET /sources" do
    test "renders sources list page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources")
      assert html =~ "Data Sources"
    end

    test "displays all sources", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources")
      assert html =~ "iNaturalist"
      assert html =~ "Oaks of the World"
      assert html =~ "Oak Compendium"
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

    test "shows species count for sources with species", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources")
      # Oaks of the World has 2 species
      assert html =~ "2"
    end

    test "source cards link to detail pages", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources")
      assert html =~ ~s(href="/sources/1")
      assert html =~ ~s(href="/sources/2")
      assert html =~ ~s(href="/sources/3")
    end

    test "clicking a source navigates to detail page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sources")

      {:ok, _view, html} =
        view
        |> element(~s(a[href="/sources/2"]))
        |> render_click()
        |> follow_redirect(conn)

      assert html =~ "Oaks of the World"
    end
  end
end
