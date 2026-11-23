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
      # Markdown headings render inside oc-prose div
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

    test "a non-existent slug is a 404 with the not-found page", %{conn: conn} do
      {404, _headers, html} =
        assert_error_sent 404, fn -> get(conn, ~p"/articles/does-not-exist") end

      assert html =~ "<title>Article not found · Oak Compendium</title>"
      assert html =~ ~r{<h1>\s*Article not found\s*</h1>}
      assert html =~ "/articles/does-not-exist"
      assert html =~ ~r{<a href="/articles" class="oc-btn">\s*Articles\s*</a>}
      assert_raise OaksWeb.NotFoundError, fn -> live(conn, ~p"/articles/does-not-exist") end
    end

    test "an unpublished article is a 404 for unauthenticated users", %{conn: conn, draft: draft} do
      {404, _headers, html} =
        assert_error_sent 404, fn -> get(conn, ~p"/articles/#{draft.slug}") end

      assert html =~ ~r{<h1>\s*Article not found\s*</h1>}
      refute html =~ draft.title
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
      assert has_element?(view, "#delete-article-modal h2", "Delete article")
      assert has_element?(view, "#delete-article-modal-cancel", "Cancel")
      assert has_element?(view, "#confirm-delete-article-btn.oc-btn-danger", "Delete article")
      assert {:error, {:live_redirect, %{to: "/articles"}}} = render_click(view, "delete")

      refute Oaks.Articles.get_article_by_slug(article.slug, true)
    end
  end
end
