defmodule Oaks.Analytics.RollupTest do
  use Oaks.DataCase

  import Oaks.AnalyticsFixtures

  alias Oaks.Analytics
  alias Oaks.Analytics.PageView
  alias Oaks.Analytics.Rollup
  alias Oaks.Repo

  defp at(date, time), do: DateTime.new!(date, %{time | microsecond: {0, 6}}, "Etc/UTC")
  defp hash(c), do: String.duplicate(c, 64)
  defp days_ago(n), do: Date.add(Date.utc_today(), -n)

  # A mix of successful views, referrers, 404s, and other errors across days.
  defp seed_traffic do
    for {day, offset} <- [{days_ago(40), 0}, {days_ago(2), 1}, {Date.utc_today(), 2}] do
      page_view_fixture(%{path: "/", visitor_hash: hash("a"), inserted_at: at(day, ~T[08:00:00])})

      page_view_fixture(%{
        path: "/",
        visitor_hash: hash("b"),
        referrer_host: "google.com",
        inserted_at: at(day, ~T[09:00:00])
      })

      page_view_fixture(%{
        path: "/species/alba",
        visitor_hash: hash("a"),
        inserted_at: at(day, ~T[10:00:00])
      })

      page_view_fixture(%{
        path: "/.env",
        status: 404,
        visitor_hash: hash("c"),
        inserted_at: at(day, ~T[11:00:00])
      })

      page_view_fixture(%{
        path: "/boom#{offset}",
        status: 500,
        visitor_hash: hash("c"),
        inserted_at: at(day, ~T[12:00:00])
      })
    end
  end

  defp snapshot(from, to) do
    %{
      stats: Analytics.stats(from, to),
      daily: Analytics.daily_stats(from, to),
      pages: Analytics.top_pages(from, to),
      not_found: Analytics.top_404s(from, to),
      errors: Analytics.top_other_errors(from, to)
    }
  end

  test "dashboard queries return the same results after rollup and pruning" do
    seed_traffic()

    ranges = [
      {days_ago(45), Date.utc_today()},
      {days_ago(45), days_ago(1)},
      {days_ago(3), days_ago(1)}
    ]

    before = Map.new(ranges, &{&1, snapshot(elem(&1, 0), elem(&1, 1))})

    assert %{rolled_up: 2, pruned: 5} = Rollup.run()

    for {from, to} = range <- ranges do
      assert snapshot(from, to) == before[range], "range #{from}..#{to}"
    end
  end

  test "only finished days are rolled up and today stays raw" do
    seed_traffic()
    Rollup.run()

    rolled = Repo.all(from(ds in "daily_stats", select: ds.date, order_by: ds.date))
    assert rolled == Enum.map([days_ago(40), days_ago(2)], &Date.to_iso8601/1)

    raw_days =
      Repo.all(from(pv in PageView, select: fragment("date(?)", pv.inserted_at), distinct: true))

    assert Enum.sort(raw_days) == Enum.map([days_ago(2), Date.utc_today()], &Date.to_iso8601/1)
  end

  test "daily totals count successes, 404s, and other errors separately" do
    seed_traffic()
    Rollup.rollup_day(days_ago(2))

    assert [%{page_views: 3, unique_visitors: 2, not_found: 1, other_errors: 1}] =
             Repo.all(
               from(ds in "daily_stats",
                 select: %{
                   page_views: ds.page_views,
                   unique_visitors: ds.unique_visitors,
                   not_found: ds.not_found,
                   other_errors: ds.other_errors
                 }
               )
             )
  end

  test "rolling up a day again replaces its summary" do
    seed_traffic()
    assert :ok = Rollup.rollup_day(days_ago(2))
    assert :ok = Rollup.rollup_day(days_ago(2))

    assert Repo.aggregate("daily_stats", :count) == 1
    assert Repo.aggregate("daily_page_stats", :count) == 2
  end

  test "days without raw rows are a no-op" do
    assert :noop = Rollup.rollup_day(days_ago(5))
    assert {:ok, 0} = Rollup.rollup_pending_days()
  end

  test "keeps only each day's most frequent 404 paths" do
    day = days_ago(2)

    for n <- 1..60 do
      page_view_fixture(%{path: "/probe-#{n}", status: 404, inserted_at: at(day, ~T[10:00:00])})
    end

    for _ <- 1..3,
        do: page_view_fixture(%{path: "/.env", status: 404, inserted_at: at(day, ~T[11:00:00])})

    Rollup.rollup_day(day)

    assert Repo.aggregate(from(de in "daily_error_stats", where: de.status == 404), :count) == 50

    assert %{not_found: 63} =
             Repo.one(from(ds in "daily_stats", select: %{not_found: ds.not_found}))

    assert [%{path: "/.env", count: 3} | _] = Analytics.top_404s(day, day)
  end

  test "never prunes raw rows for a day that wasn't rolled up" do
    page_view_fixture(%{inserted_at: at(days_ago(40), ~T[08:00:00])})

    assert Rollup.prune_rolled_up_page_views() == 0
    assert Repo.aggregate(PageView, :count) == 1
  end

  test "keeps raw rows inside the retention window" do
    page_view_fixture(%{inserted_at: at(days_ago(10), ~T[08:00:00])})

    assert %{rolled_up: 1, pruned: 0} = Rollup.run()
    assert Repo.aggregate(PageView, :count) == 1
  end
end
