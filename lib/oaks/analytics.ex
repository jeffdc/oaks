defmodule Oaks.Analytics do
  @moduledoc """
  The Analytics context.

  Provides privacy-respecting page view tracking and basic reporting.
  No personally identifiable information is stored: visitor uniqueness
  is determined by a daily-rotating SHA256 hash that cannot be reversed
  and cannot be correlated across UTC days.

  This module exposes the API needed by the tracking plug and the
  dashboard:

    * `visitor_hash/2` — derive a stable-within-the-day hash for an IP +
      user-agent pair.
    * `track/1` — insert a `PageView` row; logs on failure, never raises.
    * `stats/2` — total views + distinct visitors for an inclusive date
      range.
    * `daily_stats/2` — per-day series, gap-filled with zero entries.
    * `top_pages/3` — top paths by view count with per-path unique visitors.
    * `top_404s/3` — top paths returning HTTP 404.
    * `top_other_errors/3` — top (path, status) pairs returning non-404
      4xx or any 5xx.
  """

  import Ecto.Query

  require Logger

  alias Oaks.Analytics.PageView
  alias Oaks.Repo

  # Matches crawlers and scripted HTTP clients; their requests aren't page views.
  @bot_regex ~r/bot|crawler|spider|scrape|preview|curl|wget|python-requests|python-urllib|aiohttp|httpx|go-http-client|okhttp|java\/|libwww|headless|phantomjs|lighthouse/i

  @doc """
  Returns a 64-character lowercase hex SHA256 hash of
  `daily_salt <> ip <> user_agent`.

  The salt is 32 random bytes generated for each UTC day and held only in
  memory, so the hash is stable for the same `ip` + `user_agent` within a
  day, can't be brute-forced from the stored value, and can't be linked
  across days once the salt is discarded.
  """
  @spec visitor_hash(String.t(), String.t()) :: String.t()
  def visitor_hash(ip, user_agent) when is_binary(ip) and is_binary(user_agent) do
    :crypto.hash(:sha256, daily_salt(Date.utc_today()) <> ip <> user_agent)
    |> Base.encode16(case: :lower)
  end

  defp daily_salt(date) do
    key = {__MODULE__, :daily_salt}

    case :persistent_term.get(key, nil) do
      {^date, salt} ->
        salt

      _ ->
        salt = :crypto.strong_rand_bytes(32)
        :persistent_term.put(key, {date, salt})
        salt
    end
  end

  @doc """
  True for user agents that belong to crawlers or scripted HTTP clients.
  """
  @spec bot?(String.t() | nil) :: boolean()
  def bot?(user_agent) when is_binary(user_agent), do: Regex.match?(@bot_regex, user_agent)
  def bot?(_user_agent), do: false

  @doc """
  Inserts a `PageView` from a plain attrs map.

  Returns `:ok` on success or `:error` on changeset failure or any
  unexpected exception. Failures are logged at `:warning` level; the
  caller never sees an exception.
  """
  @spec track(map()) :: :ok | :error
  def track(attrs) do
    %PageView{}
    |> PageView.changeset(normalize_attrs(attrs))
    |> Repo.insert()
    |> case do
      {:ok, _pv} ->
        :ok

      {:error, changeset} ->
        Logger.warning("Analytics insert failed: #{inspect(changeset.errors)}")
        :error
    end
  rescue
    exception ->
      Logger.warning("Analytics insert failed: #{Exception.message(exception)}")
      :error
  end

  @doc """
  Records a page view without blocking the caller, via `Oaks.TaskSupervisor`.

  Set `config :oaks, :analytics_async, false` to record inline instead. Tests
  do this so no insert outlives the test that triggered it.
  """
  @spec track_async(map()) :: :ok
  def track_async(attrs) do
    if Application.get_env(:oaks, :analytics_async, true) do
      Task.Supervisor.start_child(Oaks.TaskSupervisor, fn -> track(attrs) end)
    else
      track(attrs)
    end

    :ok
  end

  # Start of a UTC day, for range filters that can use the inserted_at index.
  defp day_start(%Date{} = date), do: DateTime.new!(date, ~T[00:00:00.000000], "Etc/UTC")

  defp normalize_attrs(attrs) when is_map(attrs), do: attrs
  defp normalize_attrs(_), do: %{}

  # -- Reading --
  #
  # Raw page_views are pruned after a retention window (Oaks.Analytics.Rollup),
  # so each query reads days that have been rolled up from the daily summary
  # tables and only the remaining days (today, plus any day not yet rolled up)
  # from raw rows. The visitor hash rotates daily, so summing per-day unique
  # visitors gives the same result as a distinct count over the raw rows.

  @doc """
  Returns total `page_views` and `unique_visitors` (successful responses only)
  for the inclusive UTC-date range `from_date..to_date`.
  """
  @spec stats(Date.t(), Date.t()) :: %{page_views: integer(), unique_visitors: integer()}
  def stats(%Date{} = from_date, %Date{} = to_date) do
    {summary, raw} = split_range(from_date, to_date)

    summarized =
      with_range(summary, %{page_views: 0, unique_visitors: 0}, fn from, to ->
        from(ds in "daily_stats",
          where: ds.date >= ^iso(from) and ds.date <= ^iso(to),
          select: %{
            page_views: coalesce(sum(ds.page_views), 0),
            unique_visitors: coalesce(sum(ds.unique_visitors), 0)
          }
        )
        |> Repo.one()
      end)

    recent =
      with_range(raw, [], fn from, to ->
        from(pv in raw_range(from, to),
          where: pv.status < 400,
          group_by: fragment("date(?)", pv.inserted_at),
          select: %{page_views: count(pv.id), unique_visitors: count(pv.visitor_hash, :distinct)}
        )
        |> Repo.all()
      end)

    Enum.reduce(recent, summarized, &sum_counts(&2, &1, [:page_views, :unique_visitors]))
  end

  @doc """
  Returns a per-day series of page views and unique visitors for the
  inclusive UTC-date range `from_date..to_date`.

  Every date in the range is present in the result, ordered ascending.
  Days with no traffic are included with zeroed counts.
  """
  @spec daily_stats(Date.t(), Date.t()) :: [
          %{date: Date.t(), page_views: integer(), unique_visitors: integer()}
        ]
  def daily_stats(%Date{} = from_date, %Date{} = to_date) do
    {summary, raw} = split_range(from_date, to_date)

    summarized =
      with_range(summary, [], fn from, to ->
        from(ds in "daily_stats",
          where: ds.date >= ^iso(from) and ds.date <= ^iso(to),
          select: %{date: ds.date, page_views: ds.page_views, unique_visitors: ds.unique_visitors}
        )
        |> Repo.all()
      end)

    recent =
      with_range(raw, [], fn from, to ->
        from(pv in raw_range(from, to),
          where: pv.status < 400,
          group_by: fragment("date(?)", pv.inserted_at),
          select: %{
            date: fragment("date(?)", pv.inserted_at),
            page_views: count(pv.id),
            unique_visitors: count(pv.visitor_hash, :distinct)
          }
        )
        |> Repo.all()
      end)

    by_date = Map.new(summarized ++ recent, &{to_date(&1.date), %{&1 | date: to_date(&1.date)}})

    from_date
    |> Date.range(to_date)
    |> Enum.map(&Map.get(by_date, &1, %{date: &1, page_views: 0, unique_visitors: 0}))
  end

  @doc """
  Returns the top paths by view count (successful responses only) for the
  inclusive UTC-date range `from_date..to_date`, ordered by `page_views`
  descending. The default `limit` is 20.
  """
  @spec top_pages(Date.t(), Date.t(), integer()) :: [
          %{path: String.t(), page_views: integer(), unique_visitors: integer()}
        ]
  def top_pages(%Date{} = from_date, %Date{} = to_date, limit \\ 20) do
    {summary, raw} = split_range(from_date, to_date)

    summarized =
      with_range(summary, [], fn from, to ->
        from(dp in "daily_page_stats",
          where: dp.date >= ^iso(from) and dp.date <= ^iso(to),
          group_by: dp.path,
          select: %{
            path: dp.path,
            page_views: sum(dp.page_views),
            unique_visitors: sum(dp.unique_visitors)
          }
        )
        |> Repo.all()
      end)

    recent =
      with_range(raw, [], fn from, to ->
        from(pv in raw_range(from, to),
          where: pv.status < 400,
          group_by: [pv.path, fragment("date(?)", pv.inserted_at)],
          select: %{
            path: pv.path,
            page_views: count(pv.id),
            unique_visitors: count(pv.visitor_hash, :distinct)
          }
        )
        |> Repo.all()
      end)

    (summarized ++ recent)
    |> merge_by([:path], [:page_views, :unique_visitors])
    |> top(:page_views, limit)
  end

  @doc """
  Returns the top paths that returned HTTP 404 for the inclusive UTC-date
  range `from_date..to_date`, ordered by count descending.

  Rolled-up days keep only their most frequent 404 paths, so counts for
  rarely hit paths can be lower than the raw totals. The default `limit` is 20.
  """
  @spec top_404s(Date.t(), Date.t(), integer()) :: [%{path: String.t(), count: integer()}]
  def top_404s(%Date{} = from_date, %Date{} = to_date, limit \\ 20) do
    from_date
    |> error_counts(to_date, fn q -> where(q, [r], r.status == 404) end)
    |> merge_by([:path], [:count])
    |> top(:count, limit)
  end

  @doc """
  Returns the top (path, status) pairs that returned a 4xx other than 404,
  or any 5xx, for the inclusive UTC-date range `from_date..to_date`,
  ordered by count descending. The default `limit` is 20.
  """
  @spec top_other_errors(Date.t(), Date.t(), integer()) :: [
          %{path: String.t(), status: integer(), count: integer()}
        ]
  def top_other_errors(%Date{} = from_date, %Date{} = to_date, limit \\ 20) do
    from_date
    |> error_counts(to_date, fn q ->
      where(q, [r], r.status >= 400 and r.status != 404)
    end)
    |> merge_by([:path, :status], [:count])
    |> top(:count, limit)
  end

  defp error_counts(from_date, to_date, filter) do
    {summary, raw} = split_range(from_date, to_date)

    summarized =
      with_range(summary, [], fn from, to ->
        from(de in "daily_error_stats",
          where: de.date >= ^iso(from) and de.date <= ^iso(to),
          group_by: [de.path, de.status],
          select: %{path: de.path, status: de.status, count: sum(de.count)}
        )
        |> filter.()
        |> Repo.all()
      end)

    recent =
      with_range(raw, [], fn from, to ->
        from(pv in raw_range(from, to),
          group_by: [pv.path, pv.status],
          select: %{path: pv.path, status: pv.status, count: count(pv.id)}
        )
        |> filter.()
        |> Repo.all()
      end)

    summarized ++ recent
  end

  # Splits a date range at the last rolled-up day: {summary_range, raw_range},
  # either of which may be nil.
  defp split_range(from_date, to_date) do
    case Repo.one(from(ds in "daily_stats", select: max(ds.date))) do
      nil ->
        {nil, {from_date, to_date}}

      last ->
        last = to_date(last)
        summary_to = Enum.min([to_date, last], Date)
        raw_from = Enum.max([from_date, Date.add(last, 1)], Date)

        {range_or_nil(from_date, summary_to), range_or_nil(raw_from, to_date)}
    end
  end

  defp range_or_nil(from, to), do: if(Date.compare(from, to) == :gt, do: nil, else: {from, to})

  defp with_range(nil, empty, _fun), do: empty
  defp with_range({from, to}, _empty, fun), do: fun.(from, to)

  defp raw_range(from_date, to_date) do
    from(pv in PageView,
      where: pv.inserted_at >= ^day_start(from_date),
      where: pv.inserted_at < ^day_start(Date.add(to_date, 1))
    )
  end

  defp merge_by(rows, keys, counts) do
    rows
    |> Enum.group_by(&Map.take(&1, keys))
    |> Enum.map(fn {key, group} ->
      Enum.reduce(group, Map.new(counts, &{&1, 0}) |> Map.merge(key), &sum_counts(&2, &1, counts))
    end)
  end

  defp sum_counts(acc, row, counts) do
    Enum.reduce(counts, acc, fn c, acc -> Map.update!(acc, c, &(&1 + to_int(row[c]))) end)
  end

  defp top(rows, count_key, limit) do
    rows
    |> Enum.sort_by(&{-&1[count_key], &1[:path]})
    |> Enum.take(limit)
  end

  defp to_int(nil), do: 0
  defp to_int(n) when is_integer(n), do: n
  defp to_int(n) when is_float(n), do: round(n)

  defp to_date(%Date{} = date), do: date
  defp to_date(iso) when is_binary(iso), do: Date.from_iso8601!(iso)

  defp iso(%Date{} = date), do: Date.to_iso8601(date)
end
