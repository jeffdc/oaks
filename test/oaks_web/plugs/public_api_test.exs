defmodule OaksWeb.Plugs.PublicApiTest do
  # Changes the app env, so it runs alone and restores it afterwards.
  use OaksWeb.ConnCase, async: false

  import Oaks.AccountsFixtures

  setup do
    previous = Application.get_env(:oaks, :public_api)

    on_exit(fn ->
      if previous == nil do
        Application.delete_env(:oaks, :public_api)
      else
        Application.put_env(:oaks, :public_api, previous)
      end
    end)

    :ok
  end

  defp put_flag(value), do: Application.put_env(:oaks, :public_api, value)

  defp api_host(conn, host \\ "api.oakcompendium.org"), do: %{conn | host: host}

  describe "with the public API off" do
    setup do
      put_flag(false)
      :ok
    end

    test "answers 410 to the public API and its docs", %{conn: conn} do
      for path <- ["/api/v1/species", "/api/v1/docs"] do
        conn = get(conn, path)

        assert json_response(conn, 410) == %{
                 "error" =>
                   "The Oak Compendium API is offline while the site is rebuilt. See https://oakcompendium.org."
               }

        assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
      end
    end

    test "an api. host answers 410 at the root and on other paths", %{conn: conn} do
      for path <- ["/", "/species", "/api/v1/species"] do
        conn = conn |> api_host() |> get(path)

        assert %{"error" => message} = json_response(conn, 410)
        assert message =~ "https://oakcompendium.org"
      end
    end

    test "/health answers 200 on any host", %{conn: conn} do
      assert conn |> get("/health") |> response(200) =~ "ok"
      assert conn |> api_host() |> get("/health") |> response(200) =~ "ok"
    end

    test "the private API answers as it does with the flag on, on both hosts", %{conn: conn} do
      user = user_fixture()

      {raw, token} =
        api_token_fixture(user, %{"name" => "importer", "scopes" => ["packages:submit"]})

      for host <- ["localhost", "api.oakcompendium.org"] do
        body =
          conn
          |> api_host(host)
          |> put_req_header("authorization", "Bearer " <> raw)
          |> get("/api/private/v1/token")
          |> json_response(200)

        assert body["name"] == "importer"
        assert body["scopes"] == ["packages:submit"]
        assert body["expires_at"] == DateTime.to_iso8601(token.expires_at)
      end
    end
  end

  describe "with the public API on" do
    setup do
      put_flag(true)
      :ok
    end

    test "an api. host redirects the root to the docs", %{conn: conn} do
      conn = conn |> api_host() |> get("/")

      assert redirected_to(conn) == "/api/v1/docs"
    end

    test "the public API is served", %{conn: conn} do
      assert conn |> get("/api/v1/stats") |> json_response(200)
    end
  end
end
