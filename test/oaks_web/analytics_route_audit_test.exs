defmodule OaksWeb.AnalyticsRouteAuditTest do
  @moduledoc """
  Audits the analytics pipeline across every public route family.

  After several bugs where individual route families (taxonomy, articles,
  cross-LV-navigated species pages) were silently not being tracked, this
  test visits a representative URL for each public route in the router
  and asserts that exactly one `page_views` row is created per visit.

  The audit covers:

    * Static / no-fixture public LiveView routes — each visited via
      `live/2` so the WebSocket connects and the on_mount hook fires.
    * Plus an unrouted 404 to exercise the plug's only-non-LV-route
      tracking path.

  Dynamic LV routes (`/species/:name`, `/articles/:slug`, `/sources/:id`,
  `/taxonomy/:id/edit`) are exercised at the family level by hitting
  the parent list path. The Phoenix dispatch + hook code path is shared,
  so per-entity tests would only add fixture maintenance burden.
  """

  use OaksWeb.ConnCase

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias Oaks.Analytics.PageView
  alias Oaks.Repo

  @browser_ua "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15"

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

  defp last_path,
    do: Repo.one(from(pv in PageView, order_by: [desc: pv.id], limit: 1, select: pv.path))

  # Each entry: {description, path, fetch_fn}. `fetch_fn` is either
  # `:live` (hook tracks) or `:get` (plug tracks).
  @public_live_routes [
    {"home", "/", :live},
    {"species list", "/list", :live},
    {"taxonomy index", "/taxonomy", :live},
    {"taxonomy splat", "/taxonomy/subgenus/cerris", :live},
    {"articles index", "/articles", :live},
    {"sources index", "/sources", :live},
    {"search", "/search", :live},
    {"about", "/about", :live},
    {"help markdown", "/help/markdown", :live},
    {"analytics dashboard", "/analytics", :live},
    {"privacy", "/privacy", :live},
    {"settings", "/settings", :live}
  ]

  describe "route audit" do
    for {label, path, fetch_strategy} <- @public_live_routes do
      test "tracks #{label} (#{path})", %{conn: conn} do
        before_count = count_page_views()

        conn = put_req_header(conn, "user-agent", @browser_ua)

        case unquote(fetch_strategy) do
          :live -> live(conn, unquote(path))
          :get -> get(conn, unquote(path))
        end

        await_tasks()

        assert count_page_views() == before_count + 1,
               "expected exactly one new row for #{unquote(path)}"

        assert last_path() == unquote(path)
      end
    end

    test "tracks an unrouted path as a 404 (plug catches it)", %{conn: conn} do
      assert count_page_views() == 0

      conn
      |> put_req_header("user-agent", @browser_ua)
      |> get("/this-route-does-not-exist-anywhere")

      await_tasks()

      assert count_page_views() == 1
      [pv] = Repo.all(PageView)
      assert pv.path == "/this-route-does-not-exist-anywhere"
      assert pv.status == 404
    end
  end
end
