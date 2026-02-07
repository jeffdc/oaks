defmodule OakCompendiumWeb.HeaderTest do
  use OakCompendiumWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "site header" do
    test "renders all navigation links", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Oak Compendium"
      assert html =~ ~s(href="/list")
      assert html =~ ~s(href="/taxonomy")
      assert html =~ ~s(href="/search")
      assert html =~ ~s(href="/sources")
      assert html =~ ~s(href="/articles")
      assert html =~ ~s(href="/about")
      assert html =~ ~s(href="/settings")
    end

    test "renders skip-to-content link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Skip to main content"
      assert html =~ ~s(href="#main-content")
    end

    test "renders mobile menu toggle", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~s(aria-label="Toggle menu")
      assert html =~ ~s(id="mobile-menu")
    end

    test "renders footer", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "A comprehensive database of"
      assert html =~ "GitHub"
    end

    test "highlights active nav link on species list page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/list")

      # The /list link should have active class
      assert html =~ "nav-link-active"
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
