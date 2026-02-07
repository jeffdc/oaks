defmodule OakCompendiumWeb.API.TaxaControllerTest do
  use OakCompendiumWeb.ConnCase

  describe "GET /api/v1/taxa" do
    test "returns all taxa", %{conn: conn} do
      conn = get(conn, "/api/v1/taxa")
      taxa = json_response(conn, 200)
      assert is_list(taxa)
      assert length(taxa) == 5
    end

    test "taxa have expected fields", %{conn: conn} do
      conn = get(conn, "/api/v1/taxa")
      [taxon | _] = json_response(conn, 200)
      assert Map.has_key?(taxon, "id")
      assert Map.has_key?(taxon, "name")
      assert Map.has_key?(taxon, "level")
    end

    test "filters by level", %{conn: conn} do
      conn = get(conn, "/api/v1/taxa?level=subgenus")
      taxa = json_response(conn, 200)
      assert length(taxa) == 2
      assert Enum.all?(taxa, fn t -> t["level"] == "subgenus" end)
    end

    test "filters by parent", %{conn: conn} do
      conn = get(conn, "/api/v1/taxa?parent=Quercus")
      taxa = json_response(conn, 200)
      assert taxa != []
      assert Enum.all?(taxa, fn t -> t["parent"] == "Quercus" end)
    end
  end

  describe "GET /api/v1/taxa/:level/:name" do
    test "returns a taxon", %{conn: conn} do
      conn = get(conn, "/api/v1/taxa/subgenus/Quercus")
      taxon = json_response(conn, 200)
      assert taxon["name"] == "Quercus"
      assert taxon["level"] == "subgenus"
      assert taxon["author"] == "(L.) Oerst."
    end

    test "returns 404 for unknown taxon", %{conn: conn} do
      conn = get(conn, "/api/v1/taxa/subgenus/Nonexistent")
      assert %{"error" => _} = json_response(conn, 404)
    end

    test "returns 400 for invalid level", %{conn: conn} do
      conn = get(conn, "/api/v1/taxa/invalid/Quercus")
      assert %{"error" => _} = json_response(conn, 400)
    end
  end
end
