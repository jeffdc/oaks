defmodule OaksWeb.Plugs.CanonicalHostTest do
  # Changes the app env, so it runs alone and restores it afterwards.
  use OaksWeb.ConnCase, async: false

  alias OaksWeb.Plugs.CanonicalHost

  setup do
    previous = Application.get_env(:oaks, CanonicalHost)

    on_exit(fn ->
      if previous == nil do
        Application.delete_env(:oaks, CanonicalHost)
      else
        Application.put_env(:oaks, CanonicalHost, previous)
      end
    end)

    Application.put_env(:oaks, CanonicalHost,
      host: "oakcompendium.org",
      aliases: ["www.oakcompendium.org", "oakcompendium.com", "oaks.fly.dev"]
    )

    :ok
  end

  defp on_host(conn, host), do: %{conn | host: host}

  test "an alias host redirects to the same path and query on the canonical host", %{conn: conn} do
    conn = conn |> on_host("www.oakcompendium.org") |> get("/species/alba?tab=2")

    assert conn.status == 301
    assert get_resp_header(conn, "location") == ["https://oakcompendium.org/species/alba?tab=2"]
  end

  test "a path with no query redirects without a trailing ?", %{conn: conn} do
    conn = conn |> on_host("oakcompendium.com") |> get("/taxonomy")

    assert get_resp_header(conn, "location") == ["https://oakcompendium.org/taxonomy"]
  end

  test "a POST keeps its method with a 308", %{conn: conn} do
    conn = conn |> on_host("oaks.fly.dev") |> post("/users/log-in", %{})

    assert conn.status == 308
    assert get_resp_header(conn, "location") == ["https://oakcompendium.org/users/log-in"]
  end

  test "the canonical host, other hosts and /health are left alone", %{conn: conn} do
    assert conn |> on_host("oakcompendium.org") |> get("/health") |> response(200)
    assert conn |> on_host("oakcompendium.org") |> get("/about") |> html_response(200)
    assert conn |> on_host("www.oakcompendium.org") |> get("/health") |> response(200)
    assert conn |> on_host("172.19.0.2") |> get("/health") |> response(200)

    api = conn |> on_host("api.oakcompendium.org") |> get("/health")
    assert api.status == 200
  end

  test "does nothing when it isn't configured", %{conn: conn} do
    Application.delete_env(:oaks, CanonicalHost)

    assert conn |> on_host("www.oakcompendium.org") |> get("/about") |> html_response(200)
  end
end
