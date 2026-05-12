defmodule Oaks.AnalyticsTest do
  @moduledoc """
  Unit tests for the `Oaks.Analytics` context.
  """
  use Oaks.DataCase

  import ExUnit.CaptureLog
  import Oaks.AnalyticsFixtures

  alias Oaks.Analytics
  alias Oaks.Analytics.PageView
  alias Oaks.Repo

  @valid_visitor_hash String.duplicate("a", 64)

  describe "visitor_hash/2" do
    test "returns a 64-char lowercase hex string" do
      hash = Analytics.visitor_hash("10.0.0.1", "Mozilla/5.0")
      assert String.length(hash) == 64
      assert Regex.match?(~r/^[0-9a-f]{64}$/, hash)
    end

    test "is stable for identical inputs on the same day" do
      hash1 = Analytics.visitor_hash("192.168.1.1", "Mozilla/5.0")
      hash2 = Analytics.visitor_hash("192.168.1.1", "Mozilla/5.0")
      assert hash1 == hash2
    end

    test "differs for different IPs" do
      hash1 = Analytics.visitor_hash("192.168.1.1", "Mozilla/5.0")
      hash2 = Analytics.visitor_hash("192.168.1.2", "Mozilla/5.0")
      refute hash1 == hash2
    end

    test "differs for different user agents" do
      hash1 = Analytics.visitor_hash("192.168.1.1", "Mozilla/5.0 Chrome")
      hash2 = Analytics.visitor_hash("192.168.1.1", "Mozilla/5.0 Firefox")
      refute hash1 == hash2
    end
  end

  describe "track/1" do
    test "returns :ok and inserts a row when attrs are valid" do
      attrs = %{
        path: "/species/quercus-alba",
        status: 200,
        visitor_hash: @valid_visitor_hash
      }

      assert :ok = Analytics.track(attrs)
      assert Repo.aggregate(PageView, :count, :id) == 1
    end

    test "returns :error (does not raise) when attrs are invalid and logs a warning" do
      # Missing required visitor_hash + status
      attrs = %{path: "/oops"}

      log =
        capture_log([level: :warning], fn ->
          assert :error = Analytics.track(attrs)
        end)

      assert log =~ "Analytics insert failed"
      assert Repo.aggregate(PageView, :count, :id) == 0
    end

    test "returns :error without raising when given non-map attrs" do
      log =
        capture_log([level: :warning], fn ->
          assert :error = Analytics.track(:not_a_map)
        end)

      assert log =~ "Analytics insert failed"
    end
  end

  describe "stats/2" do
    test "returns zeros when no page views exist" do
      today = Date.utc_today()
      assert Analytics.stats(today, today) == %{page_views: 0, unique_visitors: 0}
    end

    test "sums page views and counts distinct visitors within range" do
      today = Date.utc_today()
      hash_a = String.duplicate("a", 64)
      hash_b = String.duplicate("b", 64)

      page_view_fixture(%{visitor_hash: hash_a, inserted_at: at(today, ~T[10:00:00])})
      page_view_fixture(%{visitor_hash: hash_a, inserted_at: at(today, ~T[10:01:00])})
      page_view_fixture(%{visitor_hash: hash_b, inserted_at: at(today, ~T[10:02:00])})

      assert Analytics.stats(today, today) == %{page_views: 3, unique_visitors: 2}
    end

    test "excludes rows outside the inclusive range" do
      today = Date.utc_today()
      yesterday = Date.add(today, -1)
      tomorrow = Date.add(today, 1)
      hash_a = String.duplicate("a", 64)
      hash_b = String.duplicate("b", 64)

      page_view_fixture(%{visitor_hash: hash_a, inserted_at: at(yesterday, ~T[10:00:00])})
      page_view_fixture(%{visitor_hash: hash_b, inserted_at: at(today, ~T[10:00:00])})
      page_view_fixture(%{visitor_hash: hash_b, inserted_at: at(tomorrow, ~T[10:00:00])})

      # Today only
      assert Analytics.stats(today, today) == %{page_views: 1, unique_visitors: 1}

      # Yesterday through today (inclusive)
      assert Analytics.stats(yesterday, today) == %{page_views: 2, unique_visitors: 2}

      # Full three-day range
      assert Analytics.stats(yesterday, tomorrow) == %{page_views: 3, unique_visitors: 2}
    end

    test "counts DISTINCT visitor_hash within range (same hash on multiple days counts once)" do
      today = Date.utc_today()
      yesterday = Date.add(today, -1)
      hash = String.duplicate("c", 64)

      page_view_fixture(%{visitor_hash: hash, inserted_at: at(yesterday, ~T[09:00:00])})
      page_view_fixture(%{visitor_hash: hash, inserted_at: at(today, ~T[09:00:00])})
      page_view_fixture(%{visitor_hash: hash, inserted_at: at(today, ~T[10:00:00])})

      assert Analytics.stats(yesterday, today) == %{page_views: 3, unique_visitors: 1}
    end
  end

  describe "daily_stats/2" do
    test "returns one entry per day in range, ascending, with zeros when no data" do
      today = Date.utc_today()
      from = Date.add(today, -2)

      result = Analytics.daily_stats(from, today)

      assert length(result) == 3
      assert Enum.map(result, & &1.date) == [from, Date.add(today, -1), today]
      assert Enum.all?(result, &(&1.page_views == 0 and &1.unique_visitors == 0))
    end

    test "fills missing days with zeros within a populated range" do
      today = Date.utc_today()
      day1 = Date.add(today, -4)
      day3 = Date.add(today, -2)
      hash = String.duplicate("a", 64)

      page_view_fixture(%{visitor_hash: hash, inserted_at: at(day1, ~T[09:00:00])})
      page_view_fixture(%{visitor_hash: hash, inserted_at: at(day3, ~T[10:00:00])})

      result = Analytics.daily_stats(day1, today)

      assert length(result) == 5
      dates = Enum.map(result, & &1.date)
      assert dates == Enum.map(0..4, &Date.add(day1, &1))

      by_date = Map.new(result, &{&1.date, &1})
      assert by_date[day1].page_views == 1
      assert by_date[day1].unique_visitors == 1

      assert by_date[Date.add(day1, 1)] == %{
               date: Date.add(day1, 1),
               page_views: 0,
               unique_visitors: 0
             }

      assert by_date[day3].page_views == 1
      assert by_date[day3].unique_visitors == 1
      assert by_date[Date.add(day1, 3)].page_views == 0
      assert by_date[today].page_views == 0
    end

    test "unique_visitors is per-day, not range-wide" do
      today = Date.utc_today()
      yesterday = Date.add(today, -1)
      hash = String.duplicate("d", 64)

      # Same visitor on two different days
      page_view_fixture(%{visitor_hash: hash, inserted_at: at(yesterday, ~T[09:00:00])})
      page_view_fixture(%{visitor_hash: hash, inserted_at: at(today, ~T[09:00:00])})

      result = Analytics.daily_stats(yesterday, today)

      by_date = Map.new(result, &{&1.date, &1})
      assert by_date[yesterday].unique_visitors == 1
      assert by_date[today].unique_visitors == 1
    end
  end

  describe "top_pages/3" do
    test "orders by page_views desc" do
      today = Date.utc_today()
      hash_a = String.duplicate("a", 64)
      hash_b = String.duplicate("b", 64)

      # /one has 1 view, /two has 3 views, /three has 2 views
      page_view_fixture(%{
        path: "/one",
        visitor_hash: hash_a,
        inserted_at: at(today, ~T[09:00:00])
      })

      page_view_fixture(%{
        path: "/two",
        visitor_hash: hash_a,
        inserted_at: at(today, ~T[09:01:00])
      })

      page_view_fixture(%{
        path: "/two",
        visitor_hash: hash_b,
        inserted_at: at(today, ~T[09:02:00])
      })

      page_view_fixture(%{
        path: "/two",
        visitor_hash: hash_a,
        inserted_at: at(today, ~T[09:03:00])
      })

      page_view_fixture(%{
        path: "/three",
        visitor_hash: hash_a,
        inserted_at: at(today, ~T[09:04:00])
      })

      page_view_fixture(%{
        path: "/three",
        visitor_hash: hash_b,
        inserted_at: at(today, ~T[09:05:00])
      })

      result = Analytics.top_pages(today, today)

      assert Enum.map(result, & &1.path) == ["/two", "/three", "/one"]
      assert Enum.map(result, & &1.page_views) == [3, 2, 1]
    end

    test "respects limit" do
      today = Date.utc_today()
      hash = String.duplicate("a", 64)

      for n <- 1..5 do
        page_view_fixture(%{
          path: "/path#{n}",
          visitor_hash: hash,
          inserted_at: at(today, ~T[09:00:00])
        })
      end

      result = Analytics.top_pages(today, today, 3)
      assert length(result) == 3
    end

    test "unique_visitors per path is distinct visitor_hash for that path" do
      today = Date.utc_today()
      hash_a = String.duplicate("a", 64)
      hash_b = String.duplicate("b", 64)

      # /one: same visitor twice → unique=1, views=2
      page_view_fixture(%{
        path: "/one",
        visitor_hash: hash_a,
        inserted_at: at(today, ~T[09:00:00])
      })

      page_view_fixture(%{
        path: "/one",
        visitor_hash: hash_a,
        inserted_at: at(today, ~T[09:01:00])
      })

      # /two: two different visitors → unique=2, views=2
      page_view_fixture(%{
        path: "/two",
        visitor_hash: hash_a,
        inserted_at: at(today, ~T[09:02:00])
      })

      page_view_fixture(%{
        path: "/two",
        visitor_hash: hash_b,
        inserted_at: at(today, ~T[09:03:00])
      })

      result = Analytics.top_pages(today, today)
      by_path = Map.new(result, &{&1.path, &1})

      assert by_path["/one"].page_views == 2
      assert by_path["/one"].unique_visitors == 1
      assert by_path["/two"].page_views == 2
      assert by_path["/two"].unique_visitors == 2
    end
  end

  describe "top_404s/3" do
    test "excludes non-404 rows" do
      today = Date.utc_today()
      hash = String.duplicate("a", 64)

      page_view_fixture(%{
        path: "/ok",
        status: 200,
        visitor_hash: hash,
        inserted_at: at(today, ~T[09:00:00])
      })

      page_view_fixture(%{
        path: "/missing",
        status: 404,
        visitor_hash: hash,
        inserted_at: at(today, ~T[09:01:00])
      })

      page_view_fixture(%{
        path: "/boom",
        status: 500,
        visitor_hash: hash,
        inserted_at: at(today, ~T[09:02:00])
      })

      result = Analytics.top_404s(today, today)

      assert length(result) == 1
      assert hd(result).path == "/missing"
      assert hd(result).count == 1
    end

    test "orders by count desc" do
      today = Date.utc_today()
      hash = String.duplicate("a", 64)

      # /a: 1 hit, /b: 3 hits, /c: 2 hits
      page_view_fixture(%{
        path: "/a",
        status: 404,
        visitor_hash: hash,
        inserted_at: at(today, ~T[09:00:00])
      })

      page_view_fixture(%{
        path: "/b",
        status: 404,
        visitor_hash: hash,
        inserted_at: at(today, ~T[09:01:00])
      })

      page_view_fixture(%{
        path: "/b",
        status: 404,
        visitor_hash: hash,
        inserted_at: at(today, ~T[09:02:00])
      })

      page_view_fixture(%{
        path: "/b",
        status: 404,
        visitor_hash: hash,
        inserted_at: at(today, ~T[09:03:00])
      })

      page_view_fixture(%{
        path: "/c",
        status: 404,
        visitor_hash: hash,
        inserted_at: at(today, ~T[09:04:00])
      })

      page_view_fixture(%{
        path: "/c",
        status: 404,
        visitor_hash: hash,
        inserted_at: at(today, ~T[09:05:00])
      })

      result = Analytics.top_404s(today, today)

      assert Enum.map(result, & &1.path) == ["/b", "/c", "/a"]
      assert Enum.map(result, & &1.count) == [3, 2, 1]
    end

    test "respects limit" do
      today = Date.utc_today()
      hash = String.duplicate("a", 64)

      for n <- 1..5 do
        page_view_fixture(%{
          path: "/missing#{n}",
          status: 404,
          visitor_hash: hash,
          inserted_at: at(today, ~T[09:00:00])
        })
      end

      result = Analytics.top_404s(today, today, 3)
      assert length(result) == 3
    end
  end

  # Build a utc_datetime_usec for a given Date and Time.
  defp at(%Date{} = date, %Time{} = time) do
    time_us = %{time | microsecond: {0, 6}}
    {:ok, ndt} = NaiveDateTime.new(date, time_us)
    DateTime.from_naive!(ndt, "Etc/UTC")
  end
end
