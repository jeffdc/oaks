defmodule OaksWeb.API.ArticlesControllerTest do
  use OaksWeb.ConnCase

  describe "GET /api/v1/articles" do
    test "returns published articles", %{conn: conn} do
      conn = get(conn, "/api/v1/articles")
      articles = json_response(conn, 200)
      assert is_list(articles)
      assert length(articles) == 1
    end

    test "articles have expected fields", %{conn: conn} do
      conn = get(conn, "/api/v1/articles")
      [article | _] = json_response(conn, 200)
      assert article["slug"] == "getting-started"
      assert article["title"] == "Getting Started with Oak Identification"
      assert article["tags"] == ["guide", "beginner"]
    end
  end

  describe "GET /api/v1/articles/:slug" do
    test "returns an article by slug", %{conn: conn} do
      conn = get(conn, "/api/v1/articles/getting-started")
      article = json_response(conn, 200)
      assert article["slug"] == "getting-started"
      assert article["author"] == "Jeff"
    end

    test "returns 404 for unknown slug", %{conn: conn} do
      conn = get(conn, "/api/v1/articles/nonexistent")
      assert %{"error" => _} = json_response(conn, 404)
    end
  end
end
