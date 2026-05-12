defmodule OaksWeb.Analytics.TrackPageView do
  @moduledoc """
  `on_mount` hook that records LiveView SPA navigations through
  `Oaks.Analytics`, paralleling `OaksWeb.Plugs.Analytics` for
  dead-render requests.

  The analytics plug records the initial HTTP GET (including the
  dead-render that mounts a LiveView). This hook handles every
  subsequent client-side navigation that happens over the WebSocket:

    * `attach_hook/4` on `:handle_params` fires once on mount and again
      on every `live_patch`/`push_patch`/`live_redirect`. The first
      firing is skipped because the plug already recorded it; later
      firings insert a new row IFF the path changed. Same-path patches
      (for example, the analytics dashboard's range buttons updating
      `?range=30`) are NOT recorded — they're in-page state, not page
      views.
    * Inserts go through `Oaks.TaskSupervisor` so the LiveView process
      never blocks on the DB write.
    * `connected?(socket)` gates the hook: on the disconnected mount
      (static dead-render of the LiveView) the hook is a no-op — the
      plug handles that request.

  Visitor hash resolution priority:

    1. `session["visitor_hash"]` (written by the plug).
    2. Fallback: derive from `get_connect_info(socket, :peer_data)` IP
       and `get_connect_info(socket, :user_agent)`.
    3. Final fallback: empty IP + empty UA so we still produce a
        64-char hash and never crash. The resulting hash is consistent
       within the day, just not meaningfully unique.
  """

  import Phoenix.LiveView

  alias Oaks.Analytics

  @skip_prefixes ["/api", "/assets"]
  @skip_exact ["/favicon.ico", "/health"]

  @doc false
  def on_mount(:default, _params, session, socket) do
    if connected?(socket) do
      visitor_hash = resolve_visitor_hash(session, socket)

      socket =
        socket
        |> Phoenix.Component.assign(:__analytics_visitor_hash__, visitor_hash)
        |> Phoenix.Component.assign(:__analytics_skip_initial__, true)
        |> Phoenix.Component.assign(:__analytics_last_path__, nil)
        |> attach_hook(:track_page_view, :handle_params, &track_navigation/3)

      {:cont, socket}
    else
      {:cont, socket}
    end
  end

  @doc false
  # Public for unit-testing path-change logic without driving a full
  # cross-LiveView navigation. Called from `attach_hook` internally.
  def track_navigation(_params, uri, socket) do
    path = uri |> URI.parse() |> Map.get(:path) || "/"

    if socket.assigns[:__analytics_skip_initial__] do
      # Plug already tracked the initial request — record the path so
      # subsequent same-path patches don't re-track either.
      socket =
        socket
        |> Phoenix.Component.assign(:__analytics_skip_initial__, false)
        |> Phoenix.Component.assign(:__analytics_last_path__, path)

      {:cont, socket}
    else
      maybe_track(path, socket)
      {:cont, Phoenix.Component.assign(socket, :__analytics_last_path__, path)}
    end
  end

  defp maybe_track(path, socket) do
    last_path = socket.assigns[:__analytics_last_path__]
    visitor_hash = socket.assigns[:__analytics_visitor_hash__]

    if path != last_path and should_track?(path) do
      spawn_track(path, visitor_hash)
    end
  end

  defp spawn_track(path, visitor_hash) do
    attrs = %{
      path: path,
      status: 200,
      referrer_host: nil,
      visitor_hash: visitor_hash,
      inserted_at: DateTime.utc_now()
    }

    Task.Supervisor.start_child(Oaks.TaskSupervisor, fn -> Analytics.track(attrs) end)
  end

  defp resolve_visitor_hash(session, socket) do
    case Map.get(session, "visitor_hash") do
      hash when is_binary(hash) and hash != "" ->
        hash

      _ ->
        compute_fallback_hash(socket)
    end
  end

  defp compute_fallback_hash(socket) do
    ip = fallback_ip(socket)
    ua = fallback_ua(socket)
    Analytics.visitor_hash(ip, ua)
  end

  defp fallback_ip(socket) do
    case get_connect_info(socket, :peer_data) do
      %{address: address} when not is_nil(address) ->
        address |> :inet.ntoa() |> to_string()

      _ ->
        ""
    end
  rescue
    _ -> ""
  end

  defp fallback_ua(socket) do
    case get_connect_info(socket, :user_agent) do
      ua when is_binary(ua) -> ua
      _ -> ""
    end
  rescue
    _ -> ""
  end

  # Mirror the plug's skip rules so plug + hook agree about what counts.
  defp should_track?(path) do
    cond do
      path in @skip_exact -> false
      Enum.any?(@skip_prefixes, &String.starts_with?(path, &1 <> "/")) -> false
      Enum.any?(@skip_prefixes, &(path == &1)) -> false
      true -> true
    end
  end
end
