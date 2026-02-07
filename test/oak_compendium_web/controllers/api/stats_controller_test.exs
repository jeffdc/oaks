defmodule OakCompendiumWeb.API.StatsControllerTest do
  use OakCompendiumWeb.ConnCase

  describe "GET /api/v1/stats" do
    test "returns aggregate counts", %{conn: conn} do
      conn = get(conn, "/api/v1/stats")
      stats = json_response(conn, 200)
      assert stats["species_count"] == 5
      assert stats["hybrid_count"] == 1
      assert stats["taxa_count"] == 5
      assert stats["source_count"] == 3
    end
  end
end
