defmodule OaksWeb.PageControllerTest do
  use OaksWeb.ConnCase

  test "GET /health returns 200", %{conn: conn} do
    conn = get(conn, "/health")
    assert response(conn, 200) =~ "ok"
  end
end
