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

    test "live_patch/redirect to a different URL on the same LV inserts an extra row",
         %{conn: conn} do
      assert count_page_views() == 0

      conn = put_req_header(conn, "user-agent", browser_ua())

      # Initial mount of the search LiveView (one row from the plug).
      {:ok, view, _html} = live(conn, ~p"/search")

      # Trigger a push_patch via the existing search event; the hook should
      # observe the patched URL.
      view
      |> element("#search-sync")
      |> render_hook("search", %{q: "alba"})

      assert_patch(view, ~p"/search?q=alba")

      await_tasks()

      # Plug recorded the initial GET /search; hook recorded the patch to
      # /search?q=alba.
      assert count_page_views() == 2
      paths = PageView |> Repo.all() |> Enum.map(& &1.path) |> Enum.sort()
      assert paths == ["/search", "/search"]
    end

    test "hook reuses :visitor_hash from the session (same hash as plug-row)",
         %{conn: conn} do
      conn = put_req_header(conn, "user-agent", browser_ua())

      {:ok, view, _html} = live(conn, ~p"/search")

      view
      |> element("#search-sync")
      |> render_hook("search", %{q: "alba"})

      assert_patch(view, ~p"/search?q=alba")
      await_tasks()

      hashes =
        PageView
        |> Repo.all()
        |> Enum.map(& &1.visitor_hash)
        |> Enum.uniq()

      # Plug + hook should share the same visitor_hash stored in session.
      assert length(hashes) == 1
      assert hd(hashes) |> String.length() == 64
    end
  end
end
