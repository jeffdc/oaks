defmodule OakCompendiumWeb.API.SourcesControllerTest do
  use OakCompendiumWeb.ConnCase

  describe "GET /api/v1/sources" do
    test "returns all sources", %{conn: conn} do
      conn = get(conn, "/api/v1/sources")
      sources = json_response(conn, 200)
      assert is_list(sources)
      assert length(sources) == 3
    end

    test "sources have expected fields", %{conn: conn} do
      conn = get(conn, "/api/v1/sources")
      [source | _] = json_response(conn, 200)
      assert Map.has_key?(source, "id")
      assert Map.has_key?(source, "name")
      assert Map.has_key?(source, "source_type")
    end
  end

  describe "GET /api/v1/sources/:id" do
    test "returns a source by ID", %{conn: conn} do
      conn = get(conn, "/api/v1/sources/2")
      source = json_response(conn, 200)
      assert source["name"] == "Oaks of the World"
      assert source["source_type"] == "website"
      assert source["url"] == "https://oaksoftheworld.fr"
    end

    test "returns 404 for unknown ID", %{conn: conn} do
      conn = get(conn, "/api/v1/sources/999")
      assert %{"error" => _} = json_response(conn, 404)
    end

    test "returns 400 for invalid ID", %{conn: conn} do
      conn = get(conn, "/api/v1/sources/abc")
      assert %{"error" => _} = json_response(conn, 400)
    end
  end
end
