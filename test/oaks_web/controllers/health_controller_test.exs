defmodule OaksWeb.HealthControllerTest do
  use OaksWeb.ConnCase

  test "returns ok when the database answers", %{conn: conn} do
    conn = get(conn, "/health")
    assert response(conn, 200) == "ok"
  end
end
