defmodule OaksWeb.Plugs.CORS do
  @moduledoc """
  Simple CORS plug for the API pipeline.

  Allows cross-origin requests from any origin for public API access.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_cors_headers()
    |> handle_preflight()
  end

  @doc """
  Puts the public API's CORS headers on `conn`, without answering a
  preflight. `OaksWeb.Plugs.Parsers` uses it for the public API's refusals,
  which come before the router's `:api` pipeline.
  """
  @spec put_cors_headers(Plug.Conn.t()) :: Plug.Conn.t()
  def put_cors_headers(conn) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "authorization, content-type")
    |> put_resp_header("access-control-max-age", "86400")
  end

  defp handle_preflight(%{method: "OPTIONS"} = conn) do
    conn
    |> send_resp(204, "")
    |> halt()
  end

  defp handle_preflight(conn), do: conn
end
