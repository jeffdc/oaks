defmodule OaksWeb.AnalyticsIntegrationTest do
  @moduledoc """
  End-to-end verification of analytics tracking through the real router
  and endpoint.

  Tracking is split: the plug catches non-LiveView traffic (controller
  routes, 404s on unrouted paths); the LiveView on_mount hook catches
  LiveView mounts and patches. This file covers both paths through
  representative routes.
  """

  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oaks.Analytics.PageView
  alias Oaks.Repo

  # Wait for all currently-running children of Oaks.TaskSupervisor to
  # terminate. The plug fires inserts via `Task.Supervisor.start_child/2`
  # which returns a bare pid (not a `%Task{}`). `Task.Supervisor.children/1`
  # returns a flat list of pids; we monitor each and block until its
  # `:DOWN` arrives. Bounded by 1s per child.
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

  describe "endpoint-level integration" do
    test "LiveView mount via `live/2` inserts exactly one row through the hook",
         %{conn: conn} do
      assert count_page_views() == 0

      conn
      |> put_req_header(
        "user-agent",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15"
      )
      |> live(~p"/")

      await_tasks()

      # The plug skips LV routes (conn.private[:phoenix_live_view] is set by
      # Phoenix.LiveView.Router). The hook fires on the connected mount.
      assert count_page_views() == 1
      [pv] = Repo.all(PageView)
      assert pv.path == "/"
      assert is_binary(pv.visitor_hash)
      assert String.length(pv.visitor_hash) == 64
    end

    test "dead-render only (no WS connect) for a LiveView inserts NO rows",
         %{conn: conn} do
      # `get/2` simulates a request without the websocket upgrade — bots,
      # curl, JS-disabled browsers. Plug skips because it's a LV route;
      # hook never fires because no WS connect happens. Net result: zero
      # rows. Bot tracking is intentional: bots don't run JS.
      assert count_page_views() == 0

      conn
      |> put_req_header(
        "user-agent",
        "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
      )
      |> get("/")

      await_tasks()

      assert count_page_views() == 0
    end

    test "GET /api/v1/species inserts NO rows (path skip rule)", %{conn: conn} do
      assert count_page_views() == 0

      conn
      |> put_req_header(
        "user-agent",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15"
      )
      |> get("/api/v1/species")

      await_tasks()

      assert count_page_views() == 0
    end

    test "GET to an unrouted path tracks the 404", %{conn: conn} do
      assert count_page_views() == 0

      conn
      |> put_req_header(
        "user-agent",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15"
      )
      |> get("/this-route-does-not-exist")

      await_tasks()

      assert count_page_views() == 1
      [pv] = Repo.all(PageView)
      assert pv.path == "/this-route-does-not-exist"
      assert pv.status == 404
    end

    # Note: /assets/* is served by Plug.Static at the endpoint level and
    # never reaches the router, so it can't be exercised here. The plug's
    # `should_track?/2` rule is still covered by unit tests in
    # `OaksWeb.Plugs.AnalyticsTest`.
  end
end
