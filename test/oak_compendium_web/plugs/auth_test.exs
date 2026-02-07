defmodule OakCompendiumWeb.Plugs.AuthTest do
  use OakCompendiumWeb.ConnCase

  @valid_key "test-api-key-secret"
  @invalid_key "wrong-key"

  describe "require_auth/2" do
    test "GET requests pass through without auth" do
      conn =
        build_conn()
        |> Map.put(:method, "GET")
        |> OakCompendiumWeb.Plugs.Auth.require_auth([])

      refute conn.halted
    end

    test "HEAD requests pass through without auth" do
      conn =
        build_conn()
        |> Map.put(:method, "HEAD")
        |> OakCompendiumWeb.Plugs.Auth.require_auth([])

      refute conn.halted
    end

    test "OPTIONS requests pass through without auth" do
      conn =
        build_conn()
        |> Map.put(:method, "OPTIONS")
        |> OakCompendiumWeb.Plugs.Auth.require_auth([])

      refute conn.halted
    end

    test "POST without auth returns 401" do
      conn =
        build_conn()
        |> Map.put(:method, "POST")
        |> OakCompendiumWeb.Plugs.Auth.require_auth([])

      assert conn.halted
      assert conn.status == 401
      assert %{"error" => "Missing authorization header"} = Jason.decode!(conn.resp_body)
    end

    test "PUT without auth returns 401" do
      conn =
        build_conn()
        |> Map.put(:method, "PUT")
        |> OakCompendiumWeb.Plugs.Auth.require_auth([])

      assert conn.halted
      assert conn.status == 401
    end

    test "DELETE without auth returns 401" do
      conn =
        build_conn()
        |> Map.put(:method, "DELETE")
        |> OakCompendiumWeb.Plugs.Auth.require_auth([])

      assert conn.halted
      assert conn.status == 401
    end

    test "PATCH without auth returns 401" do
      conn =
        build_conn()
        |> Map.put(:method, "PATCH")
        |> OakCompendiumWeb.Plugs.Auth.require_auth([])

      assert conn.halted
      assert conn.status == 401
    end

    test "POST with valid auth passes through" do
      conn =
        build_conn()
        |> Map.put(:method, "POST")
        |> put_req_header("authorization", "Bearer #{@valid_key}")
        |> OakCompendiumWeb.Plugs.Auth.require_auth([])

      refute conn.halted
      assert conn.assigns[:authenticated] == true
    end

    test "POST with invalid auth returns 401" do
      conn =
        build_conn()
        |> Map.put(:method, "POST")
        |> put_req_header("authorization", "Bearer #{@invalid_key}")
        |> OakCompendiumWeb.Plugs.Auth.require_auth([])

      assert conn.halted
      assert conn.status == 401
      assert %{"error" => "Invalid API key"} = Jason.decode!(conn.resp_body)
    end
  end

  describe "force_auth/2" do
    test "GET without auth returns 401" do
      conn =
        build_conn()
        |> Map.put(:method, "GET")
        |> OakCompendiumWeb.Plugs.Auth.force_auth([])

      assert conn.halted
      assert conn.status == 401
    end

    test "GET with valid auth passes through" do
      conn =
        build_conn()
        |> Map.put(:method, "GET")
        |> put_req_header("authorization", "Bearer #{@valid_key}")
        |> OakCompendiumWeb.Plugs.Auth.force_auth([])

      refute conn.halted
      assert conn.assigns[:authenticated] == true
    end

    test "POST with valid auth passes through" do
      conn =
        build_conn()
        |> Map.put(:method, "POST")
        |> put_req_header("authorization", "Bearer #{@valid_key}")
        |> OakCompendiumWeb.Plugs.Auth.force_auth([])

      refute conn.halted
    end
  end

  describe "auth verify endpoint" do
    test "GET /api/v1/auth/verify without auth returns 401", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/auth/verify")

      assert json_response(conn, 401)["error"] == "Missing authorization header"
    end

    test "GET /api/v1/auth/verify with valid auth returns success", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_key}")
        |> get(~p"/api/v1/auth/verify")

      assert json_response(conn, 200)["authenticated"] == true
    end

    test "GET /api/v1/auth/verify with invalid auth returns 401", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{@invalid_key}")
        |> get(~p"/api/v1/auth/verify")

      assert json_response(conn, 401)["error"] == "Invalid API key"
    end

    test "POST /api/v1/auth/verify with valid auth returns success", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_key}")
        |> post(~p"/api/v1/auth/verify")

      assert json_response(conn, 200)["authenticated"] == true
    end
  end

  describe "bearer token extraction" do
    test "handles missing Authorization header" do
      conn =
        build_conn()
        |> Map.put(:method, "POST")
        |> OakCompendiumWeb.Plugs.Auth.require_auth([])

      assert conn.halted
      assert %{"error" => "Missing authorization header"} = Jason.decode!(conn.resp_body)
    end

    test "handles non-Bearer authorization" do
      conn =
        build_conn()
        |> Map.put(:method, "POST")
        |> put_req_header("authorization", "Basic dXNlcjpwYXNz")
        |> OakCompendiumWeb.Plugs.Auth.require_auth([])

      assert conn.halted
      assert conn.status == 401
    end

    test "handles Bearer with extra whitespace" do
      conn =
        build_conn()
        |> Map.put(:method, "POST")
        |> put_req_header("authorization", "Bearer  #{@valid_key}  ")
        |> OakCompendiumWeb.Plugs.Auth.require_auth([])

      refute conn.halted
    end
  end
end
