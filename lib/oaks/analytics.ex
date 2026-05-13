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

  @doc """
  Returns a 64-character lowercase hex SHA256 hash of
  `today_iso_date <> ip <> user_agent`.

  The hash is stable for the same `ip` + `user_agent` within a UTC day
  and rotates at the UTC day boundary, preventing cross-day correlation.
  """
  @spec visitor_hash(String.t(), String.t()) :: String.t()
  def visitor_hash(ip, user_agent) when is_binary(ip) and is_binary(user_agent) do
    date = Date.utc_today() |> Date.to_iso8601()
    :crypto.hash(:sha256, date <> ip <> user_agent) |> Base.encode16(case: :lower)
  end

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

  defp normalize_attrs(attrs) when is_map(attrs), do: attrs
  defp normalize_attrs(_), do: %{}

  @doc """
  Returns total `page_views` and distinct `unique_visitors` for the
  inclusive UTC-date range `from_date..to_date`.

  Uses `date(inserted_at)` for SQLite-compatible day-bucketing.
  """
  @spec stats(Date.t(), Date.t()) :: %{page_views: integer(), unique_visitors: integer()}
  def stats(%Date{} = from_date, %Date{} = to_date) do
    query =
      from(pv in PageView,
        where: pv.status < 400,
        where: fragment("date(?)", pv.inserted_at) >= ^from_date,
        where: fragment("date(?)", pv.inserted_at) <= ^to_date,
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
        where: fragment("date(?)", pv.inserted_at) >= ^from_date,
        where: fragment("date(?)", pv.inserted_at) <= ^to_date,
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
      where: fragment("date(?)", pv.inserted_at) >= ^from_date,
      where: fragment("date(?)", pv.inserted_at) <= ^to_date,
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
      where: fragment("date(?)", pv.inserted_at) >= ^from_date,
      where: fragment("date(?)", pv.inserted_at) <= ^to_date,
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
      where: fragment("date(?)", pv.inserted_at) >= ^from_date,
      where: fragment("date(?)", pv.inserted_at) <= ^to_date,
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
