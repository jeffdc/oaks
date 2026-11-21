defmodule OaksWeb.Plugs.ApiToken do
  @moduledoc """
  Authenticates the private API (`/api/private/v1`) with an agent token
  (`Oaks.Accounts.ApiToken`, item fbd0) sent as `Authorization: Bearer
  <token>`, and assigns it as `:current_api_token`, with its user.

  Answers, as JSON `{"error": ...}`:

    * 401 for a missing, unknown, revoked or expired token, with
      `www-authenticate: Bearer`. The message doesn't say which.
    * 403 from `require_api_scope/2` for a token without the route's scope.
    * 429 when a limit is hit, with `retry-after` in seconds.

  Limits, counted in memory by `Oaks.RateLimit`, come from
  `config :oaks, :api_token_rate_limits` so tests can change them:

    * `:per_token` requests a minute for each token (default 120);
    * `:failures_per_ip` failed attempts per 15 minutes for each client IP
      (default 10). Once hit, that IP is refused before its token is checked.
  """

  import Plug.Conn

  alias Oaks.Accounts
  alias Oaks.Accounts.ApiToken
  alias OaksWeb.Plugs.Analytics

  @token_window :timer.minutes(1)
  @failure_window :timer.minutes(15)

  @doc false
  def init(opts), do: opts

  @doc false
  def call(conn, _opts) do
    limits = limits()
    failure_key = "api_token:failures:ip:#{Analytics.client_ip(conn)}"

    if Oaks.RateLimit.get(failure_key, @failure_window) >= limits[:failures_per_ip] do
      expires_at = Oaks.RateLimit.expires_at(failure_key, @failure_window)
      too_many(conn, expires_at - System.system_time(:millisecond))
    else
      authenticate(conn, failure_key, limits)
    end
  end

  defp authenticate(conn, failure_key, limits) do
    with {:ok, raw} <- bearer_token(conn),
         {:ok, token} <- Accounts.fetch_api_token(raw) do
      # Keyed by the hash, not the id: SQLite can reuse a revoked token's id.
      key = "api_token:" <> Base.encode16(token.hashed_token)

      case Oaks.RateLimit.hit(key, @token_window, limits[:per_token]) do
        {:allow, _} -> assign(conn, :current_api_token, token)
        {:deny, retry_after_ms} -> too_many(conn, retry_after_ms)
      end
    else
      _ ->
        Oaks.RateLimit.hit(failure_key, @failure_window, limits[:failures_per_ip])

        conn
        |> put_resp_header("www-authenticate", "Bearer")
        |> error(:unauthorized, "A valid agent token is required.")
    end
  end

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      [<<scheme::binary-size(7), raw::binary>>] when scheme in ["Bearer ", "bearer "] ->
        {:ok, String.trim(raw)}

      _ ->
        :error
    end
  end

  @doc """
  Function plug for routes that need a scope: `plug :require_api_scope,
  "materials:read"` in a controller after this plug has run.
  """
  def require_api_scope(conn, scope) when is_binary(scope) do
    if ApiToken.grants?(conn.assigns.current_api_token, scope),
      do: conn,
      else: error(conn, :forbidden, "This token doesn't grant #{scope}.")
  end

  defp too_many(conn, retry_after_ms) do
    conn
    |> put_resp_header("retry-after", to_string(max(div(retry_after_ms, 1000), 1)))
    |> error(:too_many_requests, "Too many requests. Try again later.")
  end

  defp error(conn, status, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{error: message}))
    |> halt()
  end

  defp limits do
    Keyword.merge(
      [per_token: 120, failures_per_ip: 10],
      Application.get_env(:oaks, :api_token_rate_limits, [])
    )
  end
end
