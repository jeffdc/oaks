defmodule OakCompendiumWeb.SearchLiveTest do
  @moduledoc """
  Tests for the SearchLive LiveView.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OakCompendiumWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "GET /search" do
    test "renders search page with input", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search")
      assert html =~ "Search"
      assert html =~ "search-input"
    end

    test "shows empty state when no query", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search")
      assert html =~ "Enter a search term"
    end

    test "performs search from URL query param", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search?q=alba")
      assert html =~ "alba"
      assert html =~ "species"
    end

    test "shows no results message for unmatched query", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search?q=zzzznonexistent")
      assert html =~ "No results found"
    end
  end

  describe "search interaction" do
    test "search input triggers results via phx-change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")

      view
      |> form("#search-form", %{q: "alba"})
      |> render_change()

      # After the push_patch, handle_params runs the search
      assert_patch(view, ~p"/search?q=alba")

      html = render(view)
      assert html =~ "alba"
    end

    test "clearing search shows empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search?q=alba")

      view
      |> form("#search-form", %{q: ""})
      |> render_change()

      assert_patch(view, ~p"/search")

      html = render(view)
      assert html =~ "Enter a search term"
    end

    test "species results link to detail page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search?q=alba")
      assert html =~ ~s(href="/species/alba")
    end

    test "taxa results link to taxonomy page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search?q=Lobatae")
      assert html =~ "/taxonomy/"
      assert html =~ "Lobatae"
    end

    test "source results link to source detail page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search?q=iNaturalist")
      assert html =~ ~s(href="/sources/)
    end

    test "shows result counts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search?q=alba")
      assert html =~ "total"
    end

    test "displays hybrid species with multiply sign", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search?q=bebbiana")
      assert html =~ "×"
    end

    test "finds species by common name", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search?q=white+oak")
      assert html =~ "alba"
    end
  end
end
