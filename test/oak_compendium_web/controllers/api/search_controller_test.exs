defmodule OakCompendiumWeb.API.SearchControllerTest do
  use OakCompendiumWeb.ConnCase

  describe "GET /api/v1/search" do
    test "returns results grouped by type", %{conn: conn} do
      conn = get(conn, "/api/v1/search?q=quercus")
      result = json_response(conn, 200)
      assert Map.has_key?(result, "species")
      assert Map.has_key?(result, "taxa")
      assert Map.has_key?(result, "sources")
    end

    test "finds species by name", %{conn: conn} do
      conn = get(conn, "/api/v1/search?q=alba")
      %{"species" => species} = json_response(conn, 200)
      assert Enum.any?(species, fn s -> s["scientific_name"] == "alba" end)
    end

    test "finds taxa by name", %{conn: conn} do
      conn = get(conn, "/api/v1/search?q=lobatae")
      %{"taxa" => taxa} = json_response(conn, 200)
      assert taxa != []
    end

    test "returns 400 when q is missing", %{conn: conn} do
      conn = get(conn, "/api/v1/search")
      assert %{"error" => _} = json_response(conn, 400)
    end
  end
end
