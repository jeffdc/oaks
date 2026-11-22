defmodule OaksWeb.API.ArticlesControllerTest do
  use OaksWeb.ConnCase

  import Oaks.ArticlesFixtures

  setup do
    tag = "tag#{System.unique_integer([:positive])}"

    %{
      tag: tag,
      published: article_fixture(tags: [tag, "beginner"]),
      draft: article_fixture(tags: [tag], is_published: false)
    }
  end

  describe "GET /api/v1/articles" do
    test "returns published articles", %{conn: conn, published: published, draft: draft} do
      conn = get(conn, "/api/v1/articles")
      articles = json_response(conn, 200)
      assert is_list(articles)
      slugs = Enum.map(articles, & &1["slug"])
      assert published.slug in slugs
      refute draft.slug in slugs
    end

    test "articles have expected fields", %{conn: conn, tag: tag, published: published} do
      conn = get(conn, "/api/v1/articles?tag=#{tag}")
      assert [article] = json_response(conn, 200)
      assert article["slug"] == published.slug
      assert article["title"] == published.title
      assert article["tags"] == [tag, "beginner"]
    end
  end

  describe "GET /api/v1/articles/:slug" do
    test "returns an article by slug", %{conn: conn, published: published} do
      conn = get(conn, "/api/v1/articles/#{published.slug}")
      article = json_response(conn, 200)
      assert article["slug"] == published.slug
      assert article["author"] == "Jeff"
    end

    test "returns 404 for an unpublished article", %{conn: conn, draft: draft} do
      conn = get(conn, "/api/v1/articles/#{draft.slug}")
      assert %{"error" => _} = json_response(conn, 404)
    end

    test "returns 404 for unknown slug", %{conn: conn} do
      conn = get(conn, "/api/v1/articles/nonexistent")
      assert %{"error" => _} = json_response(conn, 404)
    end
  end
end
