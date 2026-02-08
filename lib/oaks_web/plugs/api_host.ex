defmodule OaksWeb.Plugs.ApiHost do
  @moduledoc """
  Restricts api.* hosts to only serve API endpoints and docs.
  Redirects the root path to Swagger UI.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(%{host: "api." <> _} = conn, _opts) do
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

  def call(conn, _opts), do: conn
end
