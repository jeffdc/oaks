defmodule OaksWeb.ArticleLiveTest do
  @moduledoc """
  Tests for the ArticleLive LiveView (article detail page).
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.AccountsFixtures
  import Oaks.ArticlesFixtures

  @content """
  # Getting Started

  Start by looking at the **leaves**.

  ## Key Features

  - Leaf shape and lobe pattern
  """

  setup do
    tag = "tag#{System.unique_integer([:positive])}"

    %{
      tag: tag,
      article: article_fixture(content: @content, tags: [tag, "beginner"]),
      draft: article_fixture(is_published: false)
    }
  end

  describe "GET /articles/:slug" do
    test "renders article detail page", %{conn: conn, article: article} do
      {:ok, _view, html} = live(conn, ~p"/articles/#{article.slug}")
      assert html =~ article.title
      assert html =~ "Jeff"
    end

    test "renders markdown content as HTML", %{conn: conn, article: article} do
      {:ok, _view, html} = live(conn, ~p"/articles/#{article.slug}")
      # Markdown headings render inside prose-content div
      assert html =~ "Key Features"
      assert html =~ "<strong>"
      assert html =~ "leaves"
    end

    test "shows tags that link to filtered list", %{conn: conn, article: article, tag: tag} do
      {:ok, _view, html} = live(conn, ~p"/articles/#{article.slug}")
      assert html =~ tag
      assert html =~ "beginner"
      assert html =~ ~s(href="/articles?tag=#{tag}")
    end

    test "shows back link to articles list", %{conn: conn, article: article} do
      {:ok, _view, html} = live(conn, ~p"/articles/#{article.slug}")
      assert html =~ "Back to Articles"
      assert html =~ ~s(href="/articles")
    end

    test "shows 404 for non-existent slug", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles/does-not-exist")
      assert html =~ "Article Not Found"
    end

    test "hides unpublished article from unauthenticated users", %{conn: conn, draft: draft} do
      {:ok, _view, html} = live(conn, ~p"/articles/#{draft.slug}")
      assert html =~ "Article Not Found"
    end

    test "does not show edit/delete buttons for unauthenticated users", %{
      conn: conn,
      article: article
    } do
      {:ok, _view, html} = live(conn, ~p"/articles/#{article.slug}")
      refute html =~ "Edit"
      refute html =~ "Delete"
    end
  end

  describe "delete" do
    test "ignores delete events from unauthenticated users", %{conn: conn, article: article} do
      {:ok, view, _html} = live(conn, ~p"/articles/#{article.slug}")

      render_click(view, "confirm_delete")
      render_click(view, "delete")

      assert Oaks.Articles.get_article_by_slug(article.slug, false)
      refute has_element?(view, "[phx-click='delete']")
    end

    test "deletes the article for authenticated users", %{conn: conn, article: article} do
      conn = log_in_user(conn, user_fixture())
      {:ok, view, _html} = live(conn, ~p"/articles/#{article.slug}")

      render_click(view, "confirm_delete")
      assert {:error, {:live_redirect, %{to: "/articles"}}} = render_click(view, "delete")

      refute Oaks.Articles.get_article_by_slug(article.slug, true)
    end
  end
end
