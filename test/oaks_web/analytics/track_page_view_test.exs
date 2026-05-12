defmodule OaksWeb.Analytics.TrackPageViewTest do
  @moduledoc """
  Tests for the LiveView `on_mount` hook that records SPA navigations
  in the `page_views` table. The first `handle_params` is skipped
  because the analytics plug already records the initial dead render;
  subsequent live patches/redirects are tracked by the hook.
  """

  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oaks.Analytics.PageView
  alias Oaks.Repo
  alias OaksWeb.Analytics.TrackPageView

  # Block until all running children of `Oaks.TaskSupervisor` have terminated.
  # The hook fires inserts via `Task.Supervisor.start_child/2` which returns a
  # bare pid (not a `%Task{}`). Monitor each pid and receive its `:DOWN` to
  # synchronize.
  defp await_tasks do
    pids = Task.Supervisor.children(Oaks.TaskSupervisor)

    Enum.each(pids, fn pid ->
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      after
        1_000 -> :timeout
      end
    end)
  end

  defp count_page_views, do: Repo.aggregate(PageView, :count, :id)

  defp browser_ua,
    do: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15"

  describe "on_mount/4 unit" do
    test "returns {:cont, socket} unchanged when socket is not connected" do
      # A bare struct with `transport_pid: nil` reads as not-connected via
      # `Phoenix.LiveView.connected?/1`.
      socket = %Phoenix.LiveView.Socket{transport_pid: nil}

      assert {:cont, returned_socket} =
               TrackPageView.on_mount(:default, %{}, %{}, socket)

      # Hook is a no-op on disconnected mounts; assigns/private should be
      # untouched.
      assert returned_socket == socket
    end
  end

  describe "live mount + patch through the router" do
    test "mounting a LiveView with a connected socket does NOT add a hook-row " <>
           "for the initial render (plug already recorded it)",
         %{conn: conn} do
      assert count_page_views() == 0

      conn = put_req_header(conn, "user-agent", browser_ua())
      {:ok, _view, _html} = live(conn, ~p"/about")

      await_tasks()

      # Only the plug-inserted row for the initial dead-render GET should exist.
      # The hook intentionally skips the first handle_params.
      assert count_page_views() == 1
      [pv] = Repo.all(PageView)
      assert pv.path == "/about"
    end

    test "same-path patch (query-only change) does NOT add a hook row", %{conn: conn} do
      assert count_page_views() == 0

      conn = put_req_header(conn, "user-agent", browser_ua())

      # Initial mount of the search LiveView (one row from the plug).
      {:ok, view, _html} = live(conn, ~p"/search")

      # Trigger a push_patch to the same path with a different query string.
      # In-page state changes (typing in search, clicking range buttons on
      # the analytics dashboard, etc.) must NOT count as new page views.
      view
      |> element("#search-sync")
      |> render_hook("search", %{q: "alba"})

      assert_patch(view, ~p"/search?q=alba")

      await_tasks()

      # Only the plug-row for the initial GET /search should be present.
      assert count_page_views() == 1
      [pv] = Repo.all(PageView)
      assert pv.path == "/search"
    end
  end

  describe "track_navigation/3 (direct)" do
    # Build a connected-looking socket with the hook's private assigns wired
    # up. We can't drive a real LiveView through cross-LV navigation in a
    # unit test, so we exercise the post-mount path-tracking logic directly.
    defp connected_socket(opts) do
      hash = String.duplicate("a", 64)

      assigns = %{
        __changed__: %{},
        __analytics_visitor_hash__: hash,
        __analytics_skip_initial__: Keyword.get(opts, :skip_initial, false),
        __analytics_last_path__: Keyword.get(opts, :last_path, nil)
      }

      %Phoenix.LiveView.Socket{
        transport_pid: self(),
        assigns: assigns
      }
    end

    test "first call after the initial-skip records the path but tracks nothing" do
      socket = connected_socket(skip_initial: true)

      assert {:cont, returned} =
               TrackPageView.track_navigation(%{}, "https://example.com/about", socket)

      await_tasks()
      assert count_page_views() == 0
      assert returned.assigns.__analytics_skip_initial__ == false
      assert returned.assigns.__analytics_last_path__ == "/about"
    end

    test "navigation to a new path tracks one row" do
      socket = connected_socket(last_path: "/about")

      assert {:cont, returned} =
               TrackPageView.track_navigation(%{}, "https://example.com/species", socket)

      await_tasks()
      assert count_page_views() == 1
      [pv] = Repo.all(PageView)
      assert pv.path == "/species"
      assert pv.status == 200
      assert returned.assigns.__analytics_last_path__ == "/species"
    end

    test "patch to the same path (different query) does not track" do
      socket = connected_socket(last_path: "/analytics")

      assert {:cont, _returned} =
               TrackPageView.track_navigation(
                 %{},
                 "https://example.com/analytics?range=30",
                 socket
               )

      await_tasks()
      assert count_page_views() == 0
    end
  end
end
