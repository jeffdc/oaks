defmodule OaksWeb.Analytics.TrackPageViewTest do
  @moduledoc """
  Tests for the LiveView `on_mount` hook that records page views.

  The hook owns ALL LiveView mounts: the plug skips LV routes by
  checking `conn.private[:phoenix_live_view]`, so the hook tracks both
  the initial connected mount AND every subsequent `live_patch` /
  `live_redirect` (de-duplicated by same-path filter).
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
    test "connected mount of a LiveView inserts one row via the hook", %{conn: conn} do
      assert count_page_views() == 0

      conn = put_req_header(conn, "user-agent", browser_ua())
      {:ok, _view, _html} = live(conn, ~p"/about")

      await_tasks()

      # The plug skips LV routes, so the only row comes from the hook firing
      # on the connected mount's first handle_params.
      assert count_page_views() == 1
      [pv] = Repo.all(PageView)
      assert pv.path == "/about"
    end

    test "visitors behind the proxy get distinct hashes from X-Forwarded-For", %{conn: conn} do
      for ip <- ["203.0.113.1", "203.0.113.2"] do
        conn
        |> put_req_header("user-agent", browser_ua())
        |> put_req_header("x-forwarded-for", "#{ip}, 10.0.0.1")
        |> live(~p"/about")
      end

      await_tasks()

      hashes = PageView |> Repo.all() |> Enum.map(& &1.visitor_hash) |> Enum.uniq()
      assert length(hashes) == 2
    end

    test "bot user agents are not tracked", %{conn: conn} do
      conn = put_req_header(conn, "user-agent", "curl/8.4.0")
      {:ok, _view, _html} = live(conn, ~p"/about")

      await_tasks()
      assert count_page_views() == 0
    end

    test "a navigation that redirects from handle_params does NOT add a row", %{conn: conn} do
      conn = put_req_header(conn, "user-agent", browser_ua())
      {:ok, view, _html} = live(conn, ~p"/species/alba")

      # A synonym URL mounts SpeciesDetailLive, whose handle_params
      # push_navigates to the canonical page. The synonym URL is a
      # redirect, not a page view; the canonical page counts when the
      # browser follows it.
      assert {:error, {:live_redirect, %{to: "/species/alba"}}} =
               live_redirect(view, to: "/species/alba%20var.%20repanda")

      await_tasks()

      assert [%PageView{path: "/species/alba"}] = Repo.all(PageView)
    end

    test "same-path patch (query-only change) does NOT add another row", %{conn: conn} do
      assert count_page_views() == 0

      conn = put_req_header(conn, "user-agent", browser_ua())

      # Initial mount of the search LiveView (one row from the hook).
      {:ok, view, _html} = live(conn, ~p"/search")

      # Trigger a push_patch to the same path with a different query string.
      # In-page state changes (typing in search, clicking range buttons on
      # the analytics dashboard, etc.) must NOT count as new page views.
      view
      |> element("#search-sync")
      |> render_hook("search", %{q: "alba"})

      assert_patch(view, ~p"/search?q=alba")

      await_tasks()

      # Initial mount tracked /search once. Same-path patch did not add a row.
      assert count_page_views() == 1
      [pv] = Repo.all(PageView)
      assert pv.path == "/search"
    end
  end

  describe "track_navigation/3 and track_pending/1 (direct)" do
    # Build a connected-looking socket with the hook's private assigns wired
    # up. We can't drive a real cross-LiveView navigation in a unit test,
    # so we exercise the path-tracking logic directly: track_navigation/3
    # runs as the :handle_params hook, track_pending/1 as :after_render.
    defp connected_socket(opts \\ []) do
      hash = String.duplicate("a", 64)

      assigns = %{
        __changed__: %{},
        __analytics_visitor_hash__: hash,
        __analytics_last_path__: Keyword.get(opts, :last_path, nil),
        __analytics_pending_path__: nil
      }

      %Phoenix.LiveView.Socket{
        transport_pid: self(),
        assigns: assigns
      }
    end

    defp navigate(socket, uri) do
      {:cont, socket} = TrackPageView.track_navigation(%{}, uri, socket)
      socket
    end

    test "first call (last_path nil) tracks the path once rendered" do
      socket = navigate(connected_socket(), "https://example.com/about")

      assert socket.assigns.__analytics_last_path__ == "/about"
      await_tasks()
      assert count_page_views() == 0

      socket = TrackPageView.track_pending(socket)

      await_tasks()
      assert [%PageView{path: "/about"}] = Repo.all(PageView)
      assert socket.assigns.__analytics_pending_path__ == nil
    end

    test "navigation to a new path tracks one row" do
      connected_socket(last_path: "/about")
      |> navigate("https://example.com/species")
      |> TrackPageView.track_pending()

      await_tasks()
      assert [%PageView{path: "/species", status: 200}] = Repo.all(PageView)
    end

    test "later renders don't track the same navigation again" do
      connected_socket()
      |> navigate("https://example.com/about")
      |> TrackPageView.track_pending()
      |> TrackPageView.track_pending()

      await_tasks()
      assert count_page_views() == 1
    end

    test "a navigation that never renders is not tracked" do
      # A LiveView that redirects from handle_params never renders, so
      # track_pending/1 never runs for its path.
      _socket = navigate(connected_socket(), "https://example.com/species/a-synonym")

      await_tasks()
      assert count_page_views() == 0
    end

    test "a patch to a new path before the render replaces the pending path" do
      # handle_params that push_patches to another path: only the path the
      # LiveView renders counts.
      connected_socket()
      |> navigate("https://example.com/old")
      |> navigate("https://example.com/new")
      |> TrackPageView.track_pending()

      await_tasks()
      assert [%PageView{path: "/new"}] = Repo.all(PageView)
    end

    test "a same-path patch before the render keeps the pending path" do
      connected_socket()
      |> navigate("https://example.com/search")
      |> navigate("https://example.com/search?q=alba")
      |> TrackPageView.track_pending()

      await_tasks()
      assert [%PageView{path: "/search"}] = Repo.all(PageView)
    end

    test "patch to the same path (different query) does not track" do
      connected_socket(last_path: "/analytics")
      |> navigate("https://example.com/analytics?range=30")
      |> TrackPageView.track_pending()

      await_tasks()
      assert count_page_views() == 0
    end
  end
end
