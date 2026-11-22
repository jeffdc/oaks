defmodule OaksWeb.Plugs.ParsersTest do
  # Through the endpoint: the refusals happen before the router, so the
  # paths needn't be routes, and no agent token is needed.
  use OaksWeb.ConnCase

  alias OaksWeb.Plugs.Parsers

  defp post_body(conn, path, body, content_type \\ "application/json") do
    conn
    |> put_req_header("content-type", content_type)
    |> post(path, body)
  end

  defp assert_private_api_error(conn, status) do
    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    assert %{"error" => message} = json_response(conn, status)
    assert map_size(json_response(conn, status)) == 1
    message
  end

  describe "the private API" do
    test "answers bad JSON with a 400 {error} whatever the accept header", %{conn: conn} do
      for accept <- [nil, "text/html", "application/json", "*/*"] do
        conn = if accept, do: put_req_header(conn, "accept", accept), else: conn
        conn = post_body(conn, "/api/private/v1/import", ~s({"species": [}))

        assert assert_private_api_error(conn, 400) ==
                 ~s[The body isn't valid JSON: unexpected byte at position 13: 0x7D ("}").]
      end
    end

    test "answers a body over the JSON limit with a 413 {error}", %{conn: conn} do
      body = ~s({"species": ") <> String.duplicate("a", 8_000_000) <> ~s("})

      conn =
        conn
        |> put_req_header("accept", "text/html")
        |> post_body("/api/private/v1/import", body)

      assert assert_private_api_error(conn, 413) ==
               "The body is too large: a JSON body may be at most 8000000 bytes."
    end

    test "answers a bad query string with a 400 {error}", %{conn: conn} do
      conn = get(conn, "/api/private/v1/token?dry_run=%FF")

      assert assert_private_api_error(conn, 400) ==
               "The query string is invalid: invalid UTF-8 on urlencoded params, got byte 255."
    end

    test "answers bad encoding with a 400 {error}", %{conn: conn} do
      conn =
        post_body(
          conn,
          "/api/private/v1/import",
          "name=" <> <<0xFF>>,
          "application/x-www-form-urlencoded"
        )

      assert assert_private_api_error(conn, 400) ==
               "The request isn't valid UTF-8: invalid UTF-8 on urlencoded params, got byte 255."
    end

    test "parses a good body as Plug.Parsers does" do
      opts =
        Parsers.init(
          parsers: [:urlencoded, :multipart, :json],
          pass: ["*/*"],
          json_decoder: Jason
        )

      conn =
        Plug.Test.conn(:post, "/api/private/v1/import?dry_run=true", ~s({"species": []}))
        |> put_req_header("content-type", "application/json")
        |> Parsers.call(opts)

      refute conn.halted
      assert conn.body_params == %{"species" => []}
      assert conn.params == %{"species" => [], "dry_run" => "true"}
    end
  end

  describe "the rest of the site" do
    test "raises as before, for Phoenix's error pages", %{conn: conn} do
      for path <- ["/api/v1/species", "/users/log-in"] do
        assert_error_sent 400, fn -> post_body(conn, path, ~s({"species": [})) end
      end
    end
  end
end
