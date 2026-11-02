defmodule Oaks.Analytics.Rollup do
  @moduledoc """
  Rolls raw `page_views` up into daily summary tables and prunes old raw rows.

  Adapted from gallformers' rollup. Each finished UTC day is summarized into
  `daily_stats`, `daily_page_stats`, `daily_referrer_stats`, and
  `daily_error_stats`; `Oaks.Analytics` then reads past days from those
  tables. Raw rows older than the retention window are deleted, but only for
  days that have been rolled up, so a failed rollup never loses data.

  404s are dominated by bots probing random paths, so each day keeps only its
  50 most frequent 404 paths (plus the day's total in `daily_stats`).

  Everything here is idempotent and safe to run repeatedly; see
  `Oaks.Analytics.RollupScheduler` for when it runs.
  """

  import Ecto.Query

  require Logger

  alias Oaks.Analytics.PageView
  alias Oaks.Repo

  @default_retention_days 30
  @top_404s_per_day 50
  @insert_batch 500

  @doc """
  Rolls up every finished day that has raw page views but no `daily_stats`
  row yet. A failed day is logged and retried on the next run.

  Returns `{:ok, days_rolled_up}`.
  """
  @spec rollup_pending_days() :: {:ok, non_neg_integer()}
  def rollup_pending_days do
    count =
      Enum.count(pending_dates(), fn date ->
        try do
          rollup_day(date) == :ok
        rescue
          e ->
            Logger.error("Analytics rollup failed for #{date}: #{Exception.message(e)}")
            false
        end
      end)

    {:ok, count}
  end

  defp pending_dates do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT DISTINCT date(inserted_at) AS day FROM page_views
        WHERE inserted_at < ?1
          AND date(inserted_at) NOT IN (SELECT date FROM daily_stats)
        ORDER BY day
        """,
        [day_start(Date.utc_today())]
      )

    Enum.map(rows, fn [day] -> Date.from_iso8601!(day) end)
  end

  @doc """
  Summarizes one day's raw page views, replacing any earlier summary for
  that day. Returns `:noop` when the day has no raw rows.
  """
  @spec rollup_day(Date.t()) :: :ok | :noop
  def rollup_day(%Date{} = date) do
    day = from(pv in PageView, where: pv.inserted_at >= ^day_start(date))
    day = from(pv in day, where: pv.inserted_at < ^day_start(Date.add(date, 1)))

    if Repo.exists?(day) do
      {:ok, :ok} = Repo.transaction(fn -> write_day(day, Date.to_iso8601(date)) end)
      :ok
    else
      :noop
    end
  end

  defp write_day(day, date) do
    for table <- ~w(daily_page_stats daily_referrer_stats daily_error_stats daily_stats) do
      Repo.query!("DELETE FROM #{table} WHERE date = ?1", [date])
    end

    ok = from(pv in day, where: pv.status < 400)

    insert_rows(
      "daily_page_stats",
      from(pv in ok,
        group_by: pv.path,
        select: %{
          path: pv.path,
          page_views: count(pv.id),
          unique_visitors: count(pv.visitor_hash, :distinct)
        }
      ),
      date
    )

    insert_rows(
      "daily_referrer_stats",
      from(pv in ok,
        where: not is_nil(pv.referrer_host),
        group_by: pv.referrer_host,
        select: %{referrer_host: pv.referrer_host, page_views: count(pv.id)}
      ),
      date
    )

    error_counts =
      from(pv in day,
        group_by: [pv.path, pv.status],
        select: %{path: pv.path, status: pv.status, count: count(pv.id)}
      )

    insert_rows(
      "daily_error_stats",
      from(pv in error_counts,
        where: pv.status == 404,
        order_by: [desc: count(pv.id)],
        limit: @top_404s_per_day
      ),
      date
    )

    insert_rows(
      "daily_error_stats",
      from(pv in error_counts, where: pv.status >= 400 and pv.status != 404),
      date
    )

    # Written last: its presence marks the day as rolled up.
    totals =
      from(pv in day,
        select: %{
          page_views: filter(count(pv.id), pv.status < 400),
          unique_visitors: filter(count(pv.visitor_hash, :distinct), pv.status < 400),
          not_found: filter(count(pv.id), pv.status == 404),
          other_errors: filter(count(pv.id), pv.status >= 400 and pv.status != 404)
        }
      )
      |> Repo.one!()

    Repo.insert_all("daily_stats", [Map.put(totals, :date, date)])
    :ok
  end

  defp insert_rows(table, query, date) do
    query
    |> Repo.all()
    |> Enum.map(&Map.put(&1, :date, date))
    |> Enum.chunk_every(@insert_batch)
    |> Enum.each(&Repo.insert_all(table, &1))
  end

  @doc """
  Deletes raw page views older than `days` days whose day has been rolled
  up. Returns the number of rows deleted.
  """
  @spec prune_rolled_up_page_views(pos_integer()) :: non_neg_integer()
  def prune_rolled_up_page_views(days \\ @default_retention_days) do
    cutoff = day_start(Date.add(Date.utc_today(), -days))

    {count, _} =
      from(pv in PageView,
        where: pv.inserted_at < ^cutoff,
        where: fragment("date(?) IN (SELECT date FROM daily_stats)", pv.inserted_at)
      )
      |> Repo.delete_all()

    count
  end

  @doc """
  Runs the rollup and then the prune. Called by the scheduler.
  """
  @spec run() :: %{rolled_up: non_neg_integer(), pruned: non_neg_integer()}
  def run do
    {:ok, rolled_up} = rollup_pending_days()
    %{rolled_up: rolled_up, pruned: prune_rolled_up_page_views()}
  end

  defp day_start(%Date{} = date), do: DateTime.new!(date, ~T[00:00:00.000000], "Etc/UTC")
end
