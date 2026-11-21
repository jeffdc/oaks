defmodule OaksWeb.PrivateAPI.TokenControllerTest do
  use OaksWeb.ConnCase

  import Oaks.AccountsFixtures

  alias OaksWeb.Plugs.ApiToken, as: ApiTokenPlug

  setup %{conn: conn} do
    user = user_fixture()

    {raw, token} =
      api_token_fixture(user, %{"name" => "importer", "scopes" => ["packages:submit"]})

    # A fresh IP per test, so failure counts don't carry over.
    ip = "198.51.100.#{System.unique_integer([:positive])}"
    conn = put_req_header(conn, "fly-client-ip", ip)
    %{conn: conn, user: user, raw: raw, token: token}
  end

  defp with_token(conn, raw), do: put_req_header(conn, "authorization", "Bearer " <> raw)

  defp put_limits(limits) do
    previous = Application.get_env(:oaks, :api_token_rate_limits)
    Application.put_env(:oaks, :api_token_rate_limits, limits)
    on_exit(fn -> Application.put_env(:oaks, :api_token_rate_limits, previous) end)
  end

  describe "GET /api/private/v1/token" do
    test "describes the token", %{conn: conn, raw: raw, token: token} do
      body = conn |> with_token(raw) |> get(~p"/api/private/v1/token") |> json_response(200)

      assert body["name"] == "importer"
      assert body["scopes"] == ["packages:submit"]
      assert body["expires_at"] == DateTime.to_iso8601(token.expires_at)
      refute Map.has_key?(body, "hashed_token")
    end

    test "has no CORS headers", %{conn: conn, raw: raw} do
      conn = conn |> with_token(raw) |> get(~p"/api/private/v1/token")
      assert get_resp_header(conn, "access-control-allow-origin") == []
    end

    test "refuses a missing, unknown, malformed or expired token", %{
      conn: conn,
      raw: raw,
      token: token
    } do
      for header <- [nil, "Bearer oak_nope", "Basic " <> raw, raw] do
        conn = if header, do: put_req_header(conn, "authorization", header), else: conn
        conn = get(conn, ~p"/api/private/v1/token")

        assert json_response(conn, 401) == %{"error" => "A valid agent token is required."}
        assert get_resp_header(conn, "www-authenticate") == ["Bearer"]
      end

      set_api_token_expiry(token, -1, :second)
      assert conn |> with_token(raw) |> get(~p"/api/private/v1/token") |> json_response(401)
    end

    test "refuses a revoked token", %{conn: conn, user: user, raw: raw, token: token} do
      :ok = Oaks.Accounts.delete_api_token(user, token.id)
      assert conn |> with_token(raw) |> get(~p"/api/private/v1/token") |> json_response(401)
    end
  end

  describe "rate limits" do
    test "limits requests per token", %{conn: conn, raw: raw} do
      put_limits(per_token: 2, failures_per_ip: 1_000)

      assert conn |> with_token(raw) |> get(~p"/api/private/v1/token") |> json_response(200)
      assert conn |> with_token(raw) |> get(~p"/api/private/v1/token") |> json_response(200)

      conn = conn |> with_token(raw) |> get(~p"/api/private/v1/token")
      assert json_response(conn, 429)
      assert [seconds] = get_resp_header(conn, "retry-after")
      assert String.to_integer(seconds) in 1..60
    end

    test "after too many failures, an IP is refused even with a good token", %{
      conn: conn,
      raw: raw
    } do
      put_limits(per_token: 1_000, failures_per_ip: 2)

      for _ <- 1..2 do
        assert conn
               |> with_token("oak_wrong")
               |> get(~p"/api/private/v1/token")
               |> json_response(401)
      end

      conn = conn |> with_token(raw) |> get(~p"/api/private/v1/token")
      assert json_response(conn, 429)
      assert [_] = get_resp_header(conn, "retry-after")
    end
  end

  describe "require_api_scope/2" do
    test "passes a token with the scope and refuses one without", %{conn: conn, token: token} do
      conn = Plug.Conn.assign(conn, :current_api_token, token)

      refute ApiTokenPlug.require_api_scope(conn, "packages:submit").halted

      refused = ApiTokenPlug.require_api_scope(conn, "materials:read")
      assert refused.halted

      assert json_response(refused, 403) == %{
               "error" => "This token doesn't grant materials:read."
             }
    end
  end

  test "the private API is not in the public OpenAPI spec" do
    paths = Map.keys(OaksWeb.ApiSpec.spec().paths)
    assert "/api/v1/species" in paths
    refute Enum.any?(paths, &String.starts_with?(&1, "/api/private"))
  end
end
