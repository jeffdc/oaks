defmodule OaksWeb.API.SourcesControllerTest do
  use OaksWeb.ConnCase

  import Oaks.SourcesFixtures

  alias Oaks.Sources

  setup do
    %{source: source_fixture(url: "https://oaksoftheworld.fr")}
  end

  describe "GET /api/v1/sources" do
    test "returns all sources", %{conn: conn, source: source} do
      conn = get(conn, "/api/v1/sources")
      sources = json_response(conn, 200)
      assert is_list(sources)
      assert length(sources) == Sources.count()
      assert source.id in Enum.map(sources, & &1["id"])
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
    test "returns a source by ID", %{conn: conn, source: source} do
      conn = get(conn, "/api/v1/sources/#{source.id}")
      body = json_response(conn, 200)
      assert body["name"] == source.name
      assert body["source_type"] == "website"
      assert body["url"] == "https://oaksoftheworld.fr"
    end

    test "returns 404 for unknown ID", %{conn: conn} do
      conn = get(conn, "/api/v1/sources/0")
      assert %{"error" => _} = json_response(conn, 404)
    end

    test "returns 400 for invalid ID", %{conn: conn} do
      conn = get(conn, "/api/v1/sources/abc")
      assert %{"error" => _} = json_response(conn, 400)
    end
  end
end
