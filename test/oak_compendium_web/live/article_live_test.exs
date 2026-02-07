defmodule OakCompendiumWeb.ArticleLiveTest do
  @moduledoc """
  Tests for the ArticleLive LiveView (article detail page).
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OakCompendiumWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "GET /articles/:slug" do
    test "renders article detail page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles/getting-started")
      assert html =~ "Getting Started with Oak Identification"
      assert html =~ "Jeff"
    end

    test "renders markdown content as HTML", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles/getting-started")
      # Markdown headings render inside prose-content div
      assert html =~ "Key Features"
      assert html =~ "<strong>"
      assert html =~ "leaves"
    end

    test "shows tags that link to filtered list", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles/getting-started")
      assert html =~ "guide"
      assert html =~ "beginner"
      assert html =~ ~s(href="/articles?tag=guide")
    end

    test "shows back link to articles list", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles/getting-started")
      assert html =~ "Back to Articles"
      assert html =~ ~s(href="/articles")
    end

    test "shows 404 for non-existent slug", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles/does-not-exist")
      assert html =~ "Article Not Found"
    end

    test "hides unpublished article from unauthenticated users", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles/advanced-taxonomy-draft")
      assert html =~ "Article Not Found"
    end

    test "does not show edit/delete buttons for unauthenticated users", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles/getting-started")
      refute html =~ "Edit"
      refute html =~ "Delete"
    end
  end
end
