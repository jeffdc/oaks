defmodule OaksWeb.API.TaxaControllerTest do
  use OaksWeb.ConnCase

  import Oaks.TaxonomyFixtures

  alias Oaks.Taxonomy

  setup do
    %{tree: taxon_tree_fixture()}
  end

  describe "GET /api/v1/taxa" do
    test "returns all taxa", %{conn: conn, tree: tree} do
      conn = get(conn, "/api/v1/taxa")
      taxa = json_response(conn, 200)
      assert is_list(taxa)
      assert length(taxa) == Taxonomy.count()
      assert tree.section.id in Enum.map(taxa, & &1["id"])
    end

    test "taxa have expected fields", %{conn: conn} do
      conn = get(conn, "/api/v1/taxa")
      [taxon | _] = json_response(conn, 200)
      assert Map.has_key?(taxon, "id")
      assert Map.has_key?(taxon, "name")
      assert Map.has_key?(taxon, "level")
    end

    test "filters by level", %{conn: conn, tree: tree} do
      conn = get(conn, "/api/v1/taxa?level=subgenus")
      taxa = json_response(conn, 200)
      assert length(taxa) == length(Taxonomy.list_taxa_by_level("subgenus"))
      assert Enum.all?(taxa, fn t -> t["level"] == "subgenus" end)
      assert tree.subgenus.id in Enum.map(taxa, & &1["id"])
    end

    test "filters by parent", %{conn: conn, tree: tree} do
      conn = get(conn, "/api/v1/taxa?parent_id=#{tree.subgenus.id}")
      assert [taxon] = json_response(conn, 200)
      assert taxon["id"] == tree.section.id
      assert taxon["parent_id"] == tree.subgenus.id
    end
  end

  describe "GET /api/v1/taxa/:level/:name" do
    test "returns a taxon", %{conn: conn} do
      subgenus = taxon_fixture(author: "(L.) Oerst.")

      conn = get(conn, "/api/v1/taxa/subgenus/#{subgenus.name}")
      taxon = json_response(conn, 200)
      assert taxon["name"] == subgenus.name
      assert taxon["level"] == "subgenus"
      assert taxon["author"] == "(L.) Oerst."
    end

    test "returns 404 for unknown taxon", %{conn: conn} do
      conn = get(conn, "/api/v1/taxa/subgenus/Nonexistent")
      assert %{"error" => _} = json_response(conn, 404)
    end

    test "returns 400 for invalid level", %{conn: conn, tree: tree} do
      conn = get(conn, "/api/v1/taxa/invalid/#{tree.subgenus.name}")
      assert %{"error" => _} = json_response(conn, 400)
    end
  end
end
