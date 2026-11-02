defmodule OaksWeb.ContentSecurityPolicyTest do
  use OaksWeb.ConnCase

  test "HTML pages only allow scripts from our own origin", %{conn: conn} do
    [csp] = conn |> get(~p"/") |> get_resp_header("content-security-policy")

    assert csp =~ "script-src 'self'"
    refute csp =~ "unsafe-eval"
    refute csp =~ ~r/script-src[^;]*unsafe-inline/
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
