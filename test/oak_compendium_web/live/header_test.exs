defmodule OakCompendiumWeb.HeaderTest do
  use OakCompendiumWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "site header" do
    test "renders all navigation links", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Oak Compendium"
      assert html =~ ~s(href="/articles")
      assert html =~ ~s(href="/sources")
      assert html =~ ~s(href="/about")
      assert html =~ ~s(href="/settings")
    end

    test "renders skip-to-content link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Skip to main content"
      assert html =~ ~s(href="#main-content")
    end

    test "renders search input", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~s(id="header-search")
      assert html =~ "Search by name"
    end

    test "renders oak leaf logo", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "oak-leaf-outline.svg"
    end

    test "highlights active nav link on about page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "nav-link-active"
    end

    test "no active nav link on home page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Home page has no matching nav link, so no active class
      refute html =~ "nav-link-active"
    end
  end
end
