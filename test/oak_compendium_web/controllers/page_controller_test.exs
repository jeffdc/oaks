defmodule OakCompendiumWeb.PageControllerTest do
  use OakCompendiumWeb.ConnCase

  test "GET /health returns 200", %{conn: conn} do
    conn = get(conn, "/health")
    assert response(conn, 200) =~ "ok"
  end
end
