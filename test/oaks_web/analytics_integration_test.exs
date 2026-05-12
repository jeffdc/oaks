defmodule OaksWeb.AnalyticsIntegrationTest do
  @moduledoc """
  End-to-end verification that the analytics plug is wired into the
  `:browser` pipeline and that real GET requests insert rows in the
  `page_views` table.

  Per-plug unit tests live in `OaksWeb.Plugs.AnalyticsTest`. This file
  exercises the plug through the actual router so we catch regressions
  in pipeline ordering (the plug must run after `fetch_session`) and
  scope wiring (`:api` requests must NOT be tracked).
  """

  use OaksWeb.ConnCase

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

  describe ":browser pipeline integration" do
    test "GET / inserts one page_view row with path: \"/\"", %{conn: conn} do
      assert count_page_views() == 0

      conn
      |> put_req_header(
        "user-agent",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15"
      )
      |> get("/")

      await_tasks()

      assert count_page_views() == 1
      [pv] = Repo.all(PageView)
      assert pv.path == "/"
      assert is_binary(pv.visitor_hash)
      assert String.length(pv.visitor_hash) == 64
    end

    test "GET /api/v1/species inserts NO rows (api pipeline skipped)", %{conn: conn} do
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

    test "GET / with Googlebot UA inserts NO rows", %{conn: conn} do
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

    # Note: /assets/* is served by Plug.Static at the endpoint level and
    # never reaches the router, so it can't be exercised here. The plug's
    # `should_track?/2` rule is still covered by unit tests in
    # `OaksWeb.Plugs.AnalyticsTest`.
  end
end
