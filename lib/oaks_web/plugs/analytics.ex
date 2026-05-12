defmodule OaksWeb.Plugs.Analytics do
  @moduledoc """
  Tracks page views after the response is built, without blocking the
  request.

  Behavior:

    * On every request, derives a daily-rotating `visitor_hash` from the
      client IP and User-Agent and stores it in the session so LiveView
      navigations can reuse it (see Task 6's `on_mount` hook).
    * In `register_before_send/2`, decides whether to record the view via
      `should_track?/2`. Skips non-GETs, asset and API paths, the favicon
      and health endpoints, and common bot/crawler User-Agents.
    * Inserts are dispatched through `Oaks.TaskSupervisor` so the request
      never blocks on the DB write and tests can synchronize on the
      supervisor's children if they need to.

  The helpers `should_track?/2`, `build_attrs/2`, and `client_ip/1` are
  public so they can be unit-tested directly.
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
    ip = client_ip(conn)
    ua = user_agent(conn)
    hash = Analytics.visitor_hash(ip, ua)
    conn = put_session(conn, :visitor_hash, hash)

    register_before_send(conn, fn conn ->
      maybe_track(conn, ua, hash)
      conn
    end)
  end

  defp maybe_track(conn, ua, hash) do
    if should_track?(conn, ua) do
      attrs = build_attrs(conn, hash)
      Task.Supervisor.start_child(Oaks.TaskSupervisor, fn -> Analytics.track(attrs) end)
    end
  end

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
