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

  @doc """
  Returns total `page_views` and distinct `unique_visitors` for the
  inclusive UTC-date range `from_date..to_date`.

  Filters on an `inserted_at` range so the index applies.
  """
  @spec stats(Date.t(), Date.t()) :: %{page_views: integer(), unique_visitors: integer()}
  def stats(%Date{} = from_date, %Date{} = to_date) do
    query =
      from(pv in PageView,
        where: pv.status < 400,
        where: pv.inserted_at >= ^day_start(from_date),
        where: pv.inserted_at < ^day_start(Date.add(to_date, 1)),
        select: %{
          page_views: count(pv.id),
          unique_visitors: count(pv.visitor_hash, :distinct)
        }
      )

    Repo.one(query) || %{page_views: 0, unique_visitors: 0}
  end

  @doc """
  Returns a per-day series of page views and unique visitors for the
  inclusive UTC-date range `from_date..to_date`.

  Every date in the range is present in the result, ordered ascending.
  Days with no traffic are included with zeroed counts (gap-filled in
  Elixir, not SQL). `unique_visitors` is per-day distinct, not range-wide,
  so the same hash on two different days counts once in each day's entry.
  """
  @spec daily_stats(Date.t(), Date.t()) :: [
          %{date: Date.t(), page_views: integer(), unique_visitors: integer()}
        ]
  def daily_stats(%Date{} = from_date, %Date{} = to_date) do
    rows =
      from(pv in PageView,
        where: pv.status < 400,
        where: pv.inserted_at >= ^day_start(from_date),
        where: pv.inserted_at < ^day_start(Date.add(to_date, 1)),
        group_by: fragment("date(?)", pv.inserted_at),
        select: %{
          date: fragment("date(?)", pv.inserted_at),
          page_views: count(pv.id),
          unique_visitors: count(pv.visitor_hash, :distinct)
        }
      )
      |> Repo.all()

    by_date =
      Map.new(rows, fn row ->
        {Date.from_iso8601!(row.date),
         %{
           date: Date.from_iso8601!(row.date),
           page_views: row.page_views,
           unique_visitors: row.unique_visitors
         }}
      end)

    from_date
    |> Date.range(to_date)
    |> Enum.map(fn date ->
      Map.get(by_date, date, %{date: date, page_views: 0, unique_visitors: 0})
    end)
  end

  @doc """
  Returns the top paths by view count for the inclusive UTC-date range
  `from_date..to_date`, ordered by `page_views` descending.

  `unique_visitors` is the count of distinct `visitor_hash` values for that
  path within the range. The default `limit` is 20.
  """
  @spec top_pages(Date.t(), Date.t(), integer()) :: [
          %{path: String.t(), page_views: integer(), unique_visitors: integer()}
        ]
  def top_pages(%Date{} = from_date, %Date{} = to_date, limit \\ 20) do
    from(pv in PageView,
      where: pv.status < 400,
      where: pv.inserted_at >= ^day_start(from_date),
      where: pv.inserted_at < ^day_start(Date.add(to_date, 1)),
      group_by: pv.path,
      select: %{
        path: pv.path,
        page_views: count(pv.id),
        unique_visitors: count(pv.visitor_hash, :distinct)
      },
      order_by: [desc: count(pv.id)],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Returns the top paths that returned HTTP 404 for the inclusive UTC-date
  range `from_date..to_date`, ordered by count descending.

  The default `limit` is 20. Path matching is case-sensitive.
  """
  @spec top_404s(Date.t(), Date.t(), integer()) :: [%{path: String.t(), count: integer()}]
  def top_404s(%Date{} = from_date, %Date{} = to_date, limit \\ 20) do
    from(pv in PageView,
      where: pv.status == 404,
      where: pv.inserted_at >= ^day_start(from_date),
      where: pv.inserted_at < ^day_start(Date.add(to_date, 1)),
      group_by: pv.path,
      select: %{
        path: pv.path,
        count: count(pv.id)
      },
      order_by: [desc: count(pv.id)],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Returns the top (path, status) pairs that returned a 4xx other than 404,
  or any 5xx, for the inclusive UTC-date range `from_date..to_date`,
  ordered by count descending.

  Grouping includes status so the same path failing with different codes
  produces separate rows. The default `limit` is 20.
  """
  @spec top_other_errors(Date.t(), Date.t(), integer()) :: [
          %{path: String.t(), status: integer(), count: integer()}
        ]
  def top_other_errors(%Date{} = from_date, %Date{} = to_date, limit \\ 20) do
    from(pv in PageView,
      where: pv.status >= 400 and pv.status != 404,
      where: pv.inserted_at >= ^day_start(from_date),
      where: pv.inserted_at < ^day_start(Date.add(to_date, 1)),
      group_by: [pv.path, pv.status],
      select: %{
        path: pv.path,
        status: pv.status,
        count: count(pv.id)
      },
      order_by: [desc: count(pv.id)],
      limit: ^limit
    )
    |> Repo.all()
  end
end
