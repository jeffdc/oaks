defmodule OaksWeb.Plugs.ApiHost do
  @moduledoc """
  Restricts api.* hosts to the API, its docs and `/health`, and redirects the
  root path to Swagger UI.

  While the public API is off the air (`OaksWeb.Plugs.PublicApi`), an api.*
  host answers 410 on everything but `/health` and the private API, which
  keeps working on every host.
  """
  import Plug.Conn

  alias OaksWeb.Plugs.PublicApi

  def init(opts), do: opts

  def call(%{host: "api." <> _} = conn, _opts) do
    if PublicApi.enabled?() do
      serve(conn)
    else
      serve_offline(conn)
    end
  end

  def call(conn, _opts), do: conn

  defp serve(conn) do
    case conn.request_path do
      "/" ->
        conn
        |> Phoenix.Controller.redirect(to: "/api/v1/docs")
        |> halt()

      "/api/" <> _ ->
        conn

      "/health" ->
        conn

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: "Not found"}))
        |> halt()
    end
  end

  defp serve_offline(conn) do
    case conn.request_path do
      "/health" ->
        conn

      "/api/private/" <> _ ->
        conn

      _ ->
        conn
        |> PublicApi.offline()
        |> halt()
    end
  end
end
