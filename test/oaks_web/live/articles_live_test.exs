defmodule OaksWeb.ArticlesLiveTest do
  @moduledoc """
  Tests for the ArticlesLive LiveView.
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.ArticlesFixtures

  setup do
    tag = "tag#{System.unique_integer([:positive])}"

    %{
      tag: tag,
      published: article_fixture(tags: [tag, "beginner"], author: "Jeff"),
      draft: article_fixture(is_published: false)
    }
  end

  describe "GET /articles" do
    test "renders articles list page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles")
      assert html =~ "Articles"
      assert html =~ "Guides, reviews, and notes"
    end

    test "displays published articles", %{conn: conn, published: published} do
      {:ok, _view, html} = live(conn, ~p"/articles")
      assert html =~ published.title
    end

    test "does not show draft articles to unauthenticated users", %{conn: conn, draft: draft} do
      {:ok, _view, html} = live(conn, ~p"/articles")
      refute html =~ draft.title
    end

    test "shows article metadata", %{conn: conn, tag: tag} do
      {:ok, _view, html} = live(conn, ~p"/articles")
      assert html =~ "Jeff"
      assert html =~ tag
      assert html =~ "beginner"
    end

    test "article cards link to detail pages", %{conn: conn, published: published} do
      {:ok, _view, html} = live(conn, ~p"/articles")
      assert html =~ ~s(href="/articles/#{published.slug}")
    end

    test "shows tag filter chips", %{conn: conn, tag: tag} do
      {:ok, _view, html} = live(conn, ~p"/articles")
      assert html =~ ~s(href="/articles?tag=#{tag}")
      assert html =~ ~s(href="/articles?tag=beginner")
    end

    test "does not show New Article button for unauthenticated users", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles")
      refute html =~ "New Article"
    end

    test "filters articles by tag via URL param", %{conn: conn, tag: tag, published: published} do
      other = article_fixture()
      {:ok, _view, html} = live(conn, ~p"/articles?tag=#{tag}")
      assert html =~ published.title
      refute html =~ other.title
    end

    test "shows empty state when no articles match tag filter", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/articles?tag=nonexistent")
      assert html =~ "No articles found"
      assert html =~ "Clear filter"
    end

    test "marks a draft with a Draft tag for editors", %{
      conn: conn,
      draft: draft,
      published: published
    } do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      {:ok, view, _html} = live(conn, ~p"/articles")

      assert has_element?(view, ~s(a[href="/articles/#{draft.slug}"] .oc-status), "Draft")
      refute has_element?(view, ~s(a[href="/articles/#{published.slug}"] .oc-status))
    end
  end
end
