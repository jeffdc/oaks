defmodule OaksWeb.API.StatsControllerTest do
  use OaksWeb.ConnCase

  import Oaks.SourcesFixtures
  import Oaks.SpeciesFixtures
  import Oaks.TaxonomyFixtures

  defp stats(conn), do: conn |> get("/api/v1/stats") |> json_response(200)

  describe "GET /api/v1/stats" do
    test "returns aggregate counts", %{conn: conn} do
      before = stats(conn)

      species_fixture()
      species_fixture()
      hybrid_fixture()
      taxon_fixture()
      source_fixture()

      stats = stats(conn)
      assert stats["species_count"] == before["species_count"] + 3
      assert stats["hybrid_count"] == before["hybrid_count"] + 1
      assert stats["taxa_count"] == before["taxa_count"] + 1
      assert stats["source_count"] == before["source_count"] + 1
    end
  end
end
