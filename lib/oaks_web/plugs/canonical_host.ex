defmodule OaksWeb.Plugs.CanonicalHost do
  @moduledoc """
  Sends a request on one of the site's other hostnames to the same path and
  query on the canonical host, so there is one site and one set of cookies.
  A browser keeps a host's cookies to that host, so logging in on
  oakcompendium.org used to look like being logged out on
  www.oakcompendium.org or oakcompendium.com.

  Configured by `config :oaks, OaksWeb.Plugs.CanonicalHost, host: ...,
  aliases: [...]` (production sets it in `config/runtime.exs`) and read on
  each request, so tests can set it. Without it the plug does nothing, as in
  dev and test. Only the listed aliases redirect: the `api.` hosts, Fly's
  health checks (which reach the machine by its own address) and `/health`
  on any host are left alone.

  GET and HEAD get a 301; any other method a 308, which keeps the method and
  body.
  """
  import Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%{request_path: "/health"} = conn, _opts), do: conn

  def call(conn, _opts) do
    config = Application.get_env(:oaks, __MODULE__, [])
    host = config[:host]

    if host && conn.host in Keyword.get(config, :aliases, []) do
      redirect(conn, host)
    else
      conn
    end
  end

  defp redirect(conn, host) do
    # request_path and query_string are as the client sent them, still
    # percent-encoded.
    query = if conn.query_string == "", do: "", else: "?" <> conn.query_string
    location = "https://#{host}#{conn.request_path}#{query}"

    status = if conn.method in ["GET", "HEAD"], do: 301, else: 308

    conn
    |> put_resp_header("location", location)
    |> send_resp(status, "")
    |> halt()
  end
end
