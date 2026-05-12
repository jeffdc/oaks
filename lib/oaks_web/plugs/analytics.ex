defmodule OaksWeb.Plugs.Analytics do
  @moduledoc """
  Tracks non-LiveView page views after the response is built.

  Tracking is split between this plug and the
  `OaksWeb.Analytics.TrackPageView` LiveView `on_mount` hook:

    * This plug handles requests that are NOT served by a LiveView
      (controller actions, asset requests that miss the router, and most
      importantly: 404s on unrouted paths, which never enter a router
      pipeline).
    * The hook handles every LiveView mount and patch — including
      cross-LiveView navigations via `live_redirect` (`<.link navigate>`)
      that never produce a fresh HTTP request and so would otherwise be
      invisible to this plug.

  The `conn.private[:phoenix_live_view]` key is set by
  `Phoenix.LiveView.Router` when a `live` route dispatches. We inspect
  it inside `register_before_send/2`, by which time the router has run.
  If it is set, the hook is responsible — the plug stays out of the way
  to avoid double-counting.

  Other skip rules: non-GET methods, paths under `/api` and `/assets`,
  `/favicon.ico`, `/health`, and bot/crawler User-Agents.

  Inserts go through `Oaks.TaskSupervisor` so the request never blocks
  on the DB write and tests can synchronize on the supervisor's
  children. The helpers `should_track?/2`, `build_attrs/2`, and
  `client_ip/1` are public so they can be unit-tested directly.
  """

  import Plug.Conn

  alias Oaks.Analytics

  @bot_regex ~r/bot|crawler|spider|scrape|preview/i
  @skip_prefixes ["/api", "/assets"]
  @skip_exact ["/favicon.ico", "/health"]

  @doc false
  def init(opts), do: opts

  @doc false
  def call(conn, _opts) do
    ua = user_agent(conn)

    register_before_send(conn, fn conn ->
      maybe_track(conn, ua)
      conn
    end)
  end

  defp maybe_track(conn, ua) do
    if not live_view_route?(conn) and should_track?(conn, ua) do
      hash = Analytics.visitor_hash(client_ip(conn), ua)
      attrs = build_attrs(conn, hash)
      Task.Supervisor.start_child(Oaks.TaskSupervisor, fn -> Analytics.track(attrs) end)
    end
  end

  # True when this request was dispatched to a Phoenix LiveView. Set by
  # Phoenix.LiveView.Router during route dispatch, so it's visible by the
  # time register_before_send/2 fires.
  defp live_view_route?(conn), do: Map.has_key?(conn.private, :phoenix_live_view)

  @doc """
  Returns `true` when the request should be recorded as a page view.

  Skips non-GET methods, asset/API paths, the favicon and health
  endpoints, and bot User-Agents.
  """
  @spec should_track?(Plug.Conn.t(), String.t()) :: boolean()
  def should_track?(%Plug.Conn{method: method}, _ua) when method != "GET", do: false

  def should_track?(%Plug.Conn{request_path: path}, ua) do
    cond do
      path in @skip_exact -> false
      Enum.any?(@skip_prefixes, &String.starts_with?(path, &1 <> "/")) -> false
      Enum.any?(@skip_prefixes, &(path == &1)) -> false
      is_binary(ua) and Regex.match?(@bot_regex, ua) -> false
      true -> true
    end
  end

  @doc """
  Builds the attrs map handed to `Oaks.Analytics.track/1`.
  """
  @spec build_attrs(Plug.Conn.t(), String.t()) :: %{
          path: String.t(),
          status: integer(),
          referrer_host: String.t() | nil,
          visitor_hash: String.t(),
          inserted_at: DateTime.t()
        }
  def build_attrs(conn, visitor_hash) do
    %{
      path: conn.request_path,
      status: conn.status || 200,
      referrer_host: referrer_host(conn),
      visitor_hash: visitor_hash,
      inserted_at: DateTime.utc_now()
    }
  end

  @doc """
  Returns the best-effort client IP as a string.

  Priority: `fly-client-ip` header, then the first comma-segment of
  `x-forwarded-for`, then `conn.remote_ip`.
  """
  @spec client_ip(Plug.Conn.t()) :: String.t()
  def client_ip(conn) do
    case fly_client_ip(conn) do
      ip when is_binary(ip) and ip != "" ->
        ip

      _ ->
        case forwarded_for(conn) do
          ip when is_binary(ip) and ip != "" -> ip
          _ -> conn.remote_ip |> :inet.ntoa() |> to_string()
        end
    end
  end

  defp fly_client_ip(conn) do
    conn |> get_req_header("fly-client-ip") |> List.first()
  end

  defp forwarded_for(conn) do
    case conn |> get_req_header("x-forwarded-for") |> List.first() do
      nil ->
        nil

      header ->
        header
        |> String.split(",")
        |> List.first()
        |> case do
          nil -> nil
          part -> String.trim(part)
        end
    end
  end

  defp user_agent(conn) do
    conn |> get_req_header("user-agent") |> List.first() || ""
  end

  defp referrer_host(conn) do
    conn
    |> get_req_header("referer")
    |> List.first()
    |> parse_referrer_host(conn.host)
  end

  defp parse_referrer_host(nil, _own), do: nil
  defp parse_referrer_host("", _own), do: nil

  defp parse_referrer_host(referer, own_host) do
    case URI.parse(referer) do
      %URI{host: host} when is_binary(host) and host != "" and host != own_host -> host
      _ -> nil
    end
  end
end
