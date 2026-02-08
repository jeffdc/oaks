defmodule OaksWeb.ArticlesLiveTest do
  @moduledoc """
  Tests for the ArticlesLive LiveView.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "GET /articles" do
    test "renders articles list page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles")
      assert html =~ "Articles"
      assert html =~ "Guides, reviews, and notes"
    end

    test "displays published articles", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles")
      assert html =~ "Getting Started with Oak Identification"
    end

    test "does not show draft articles to unauthenticated users", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles")
      refute html =~ "Advanced Oak Taxonomy"
    end

    test "shows article metadata", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles")
      assert html =~ "Jeff"
      assert html =~ "guide"
      assert html =~ "beginner"
    end

    test "article cards link to detail pages", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles")
      assert html =~ ~s(href="/articles/getting-started")
    end

    test "shows tag filter chips", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles")
      assert html =~ "guide"
      assert html =~ "beginner"
    end

    test "does not show New Article button for unauthenticated users", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles")
      refute html =~ "New Article"
    end

    test "filters articles by tag via URL param", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles?tag=guide")
      assert html =~ "Getting Started with Oak Identification"
    end

    test "shows empty state when no articles match tag filter", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles?tag=nonexistent")
      assert html =~ "No articles found"
      assert html =~ "Clear filter"
    end
  end
end
