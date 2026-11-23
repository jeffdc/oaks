defmodule OaksWeb.ContentSecurityPolicyTest do
  use OaksWeb.ConnCase

  test "HTML pages only allow scripts from our own origin", %{conn: conn} do
    [csp] = conn |> get(~p"/") |> get_resp_header("content-security-policy")

    assert csp =~ "script-src 'self'"
    refute csp =~ "unsafe-eval"
    refute csp =~ ~r/script-src[^;]*unsafe-inline/
  end

  test "error pages that no pipeline reaches carry the same headers", %{conn: conn} do
    [page_csp] = conn |> get(~p"/") |> get_resp_header("content-security-policy")

    # An unmatched route.
    not_found = get(conn, "/no-such-page")
    assert not_found.status == 404
    assert get_resp_header(not_found, "content-security-policy") == [page_csp]
    assert get_resp_header(not_found, "x-content-type-options") == ["nosniff"]

    assert get_resp_header(not_found, "referrer-policy") == [
             "strict-origin-when-cross-origin"
           ]

    # A request the parsers refuse, before the router.
    {400, headers, _body} = assert_error_sent 400, fn -> get(conn, "/species?q=%FF") end
    assert {"content-security-policy", page_csp} in headers
  end

  test "API docs keep loading Swagger UI from its CDN", %{conn: conn} do
    assert conn |> get("/api/v1/docs") |> get_resp_header("content-security-policy") == []
  end

  test "templates use no inline event handlers or inline scripts" do
    offenders =
      for path <- Path.wildcard("lib/oaks_web/**/*.{ex,heex}"),
          source = File.read!(path),
          Regex.match?(~r/\son[a-z]+="|<script(?![^>]*\ssrc=)/, source),
          do: path

    assert offenders == []
  end
end
