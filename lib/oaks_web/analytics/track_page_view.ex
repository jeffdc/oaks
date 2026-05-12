defmodule OaksWeb.Analytics.TrackPageView do
  @moduledoc """
  `on_mount` hook that records LiveView page views.

  Pairs with `OaksWeb.Plugs.Analytics`, which handles non-LiveView
  traffic (controller routes, 404s on unrouted paths). The hook owns
  ALL LiveView mounts — including the initial connected mount and any
  later `live_patch` / `live_redirect`.

  Why the hook owns LV mounts (and the plug does not): a
  `<.link navigate>` reuses the existing WebSocket and mounts the
  destination LiveView without producing an HTTP request, so the plug
  cannot see it. To avoid the double-tracking that an earlier
  `skip_initial` flag was meant to prevent, the plug now SKIPS LV
  routes entirely (it checks `conn.private[:phoenix_live_view]` in
  `register_before_send/2`).

  How it works:

    * `connected?(socket)` gates the hook: dead-render mounts do
      nothing. The hook attaches only on the connected mount.
    * `attach_hook/4` on `:handle_params` fires once on the connected
      mount and again on every `live_patch` / `push_patch` /
      `live_redirect`.
    * On each firing, the hook compares the new path to the last
      tracked path on the socket. If the path differs (or it is the
      first firing on this socket, where `last_path` is nil), a row
      is inserted via `Oaks.TaskSupervisor`. Same-path patches — for
      example the analytics dashboard's range buttons updating
      `?range=30` — are in-page state, not page views, so the hook
      skips them.

  Visitor hash: computed from `get_connect_info/2` (peer IP and
  user-agent). Stable within the WS session and rotates daily because
  the date is part of the hash input.
  """

  import Phoenix.LiveView

  alias Oaks.Analytics

  @skip_prefixes ["/api", "/assets"]
  @skip_exact ["/favicon.ico", "/health"]

  @doc false
  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      visitor_hash = compute_visitor_hash(socket)

      socket =
        socket
        |> Phoenix.Component.assign(:__analytics_visitor_hash__, visitor_hash)
        |> Phoenix.Component.assign(:__analytics_last_path__, nil)
        |> attach_hook(:track_page_view, :handle_params, &track_navigation/3)

      {:cont, socket}
    else
      {:cont, socket}
    end
  end

  @doc false
  # Public so the path-change logic can be exercised by unit tests
  # without driving a full cross-LiveView navigation through the
  # test harness. Called by `attach_hook/4` internally.
  def track_navigation(_params, uri, socket) do
    path = uri |> URI.parse() |> Map.get(:path) || "/"
    last_path = socket.assigns[:__analytics_last_path__]

    if path != last_path and should_track?(path) do
      spawn_track(path, socket.assigns[:__analytics_visitor_hash__])
    end

    {:cont, Phoenix.Component.assign(socket, :__analytics_last_path__, path)}
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

  defp compute_visitor_hash(socket) do
    Analytics.visitor_hash(connect_ip(socket), connect_ua(socket))
  end

  defp connect_ip(socket) do
    case get_connect_info(socket, :peer_data) do
      %{address: address} when not is_nil(address) ->
        address |> :inet.ntoa() |> to_string()

      _ ->
        ""
    end
  rescue
    _ -> ""
  end

  defp connect_ua(socket) do
    case get_connect_info(socket, :user_agent) do
      ua when is_binary(ua) -> ua
      _ -> ""
    end
  rescue
    _ -> ""
  end

  # Mirror the plug's path-based skip rules so plug + hook agree.
  defp should_track?(path) do
    cond do
      path in @skip_exact -> false
      Enum.any?(@skip_prefixes, &String.starts_with?(path, &1 <> "/")) -> false
      Enum.any?(@skip_prefixes, &(path == &1)) -> false
      true -> true
    end
  end
end
