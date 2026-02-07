defmodule OakCompendiumWeb.API.HealthControllerTest do
  use OakCompendiumWeb.ConnCase

  describe "GET /health" do
    test "returns 200 ok", %{conn: conn} do
      conn = get(conn, "/health")
      assert response(conn, 200) == "ok"
    end
  end
end
