defmodule OaksWeb.Plugs.PublicApi do
  @moduledoc """
  The public API's on/off switch (`config :oaks, :public_api`), read on each
  request so tests can turn it off.

  While it is off, the API answers 410 with the same `{"error": ...}` shape
  its controllers use: the public API is off the air while the Facts
  expansion lands (Jeff, 2026-11-27; [decisions.md](../../../docs/architecture/decisions.md)).
  `OaksWeb.Router`'s `:api` pipeline and `OaksWeb.Plugs.ApiHost` both answer
  with `offline/1`.
  """
  import Plug.Conn

  alias OaksWeb.Plugs.CORS

  @behaviour Plug

  @message "The Oak Compendium API is offline while the site is rebuilt. See https://oakcompendium.org."

  @doc "Whether the public API is served."
  @spec enabled?() :: boolean()
  def enabled?, do: Application.get_env(:oaks, :public_api, false)

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    if enabled?() do
      conn
    else
      conn
      |> offline()
      |> halt()
    end
  end

  @doc """
  Answers the public API's 410, with the public API's CORS headers so a
  browser caller can read the error.
  """
  @spec offline(Plug.Conn.t()) :: Plug.Conn.t()
  def offline(conn) do
    conn
    |> CORS.put_cors_headers()
    |> put_resp_content_type("application/json")
    |> send_resp(410, Jason.encode!(%{error: @message}))
  end
end
