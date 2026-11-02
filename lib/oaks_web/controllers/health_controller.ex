defmodule OaksWeb.HealthController do
  use OaksWeb, :controller

  require Logger

  alias Oaks.Repo

  # Fly's health check: 200 only when the app can actually query the database.
  def check(conn, _params) do
    case Repo.query("SELECT 1") do
      {:ok, _result} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, "ok")

      {:error, reason} ->
        Logger.error("Health check database query failed: #{inspect(reason)}")

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(503, "database unavailable")
    end
  end
end
