defmodule OaksWeb.AnalyticsLive do
  @moduledoc """
  Public dashboard at `/analytics` for the self-hosted page-view analytics.

  Shows totals, a daily sparkline, the top pages, and a collapsed-by-default
  errors section (Top 404s plus other 4xx/5xx grouped by status) for a
  configurable date range. No JavaScript chart library — the sparkline is
  a dependency-free inline SVG `<polyline>`.

  All data comes from `Oaks.Analytics`, which queries the raw `page_views`
  table. No PII is exposed.
  """

  use OaksWeb, :live_view

  alias Oaks.Analytics
  alias Oaks.Analytics.PageView
  alias Oaks.Repo

  @default_range "7"

  @ranges [
    {"today", "Today"},
    {"7", "Last 7 days"},
    {"30", "Last 30 days"},
    {"90", "Last 90 days"},
    {"all", "All time"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Site Analytics")
     |> assign(:ranges, @ranges)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    range = normalize_range(Map.get(params, "range", @default_range))
    {:noreply, assign_for_range(socket, range)}
  end

  @impl true
  def handle_event("set_range", %{"range" => range}, socket) do
    range = normalize_range(range)
    {:noreply, push_patch(socket, to: ~p"/analytics?range=#{range}")}
  end

  defp normalize_range(range) when range in ["today", "7", "30", "90", "all"], do: range
  defp normalize_range(_), do: @default_range

  defp assign_for_range(socket, range) do
    {from_date, to_date} = date_range(range)

    socket
    |> assign(:range, range)
    |> assign(:from, from_date)
    |> assign(:to, to_date)
    |> assign(:stats, Analytics.stats(from_date, to_date))
    |> assign(:daily, Analytics.daily_stats(from_date, to_date))
    |> assign(:top_pages, Analytics.top_pages(from_date, to_date))
    |> assign(:top_404s, Analytics.top_404s(from_date, to_date))
    |> assign(:top_other_errors, Analytics.top_other_errors(from_date, to_date))
  end

  defp date_range("today") do
    today = Date.utc_today()
    {today, today}
  end

  defp date_range("7"), do: relative_range(6)
  defp date_range("30"), do: relative_range(29)
  defp date_range("90"), do: relative_range(89)

  defp date_range("all") do
    today = Date.utc_today()

    case Repo.aggregate(PageView, :min, :inserted_at) do
      nil ->
        {today, today}

      %DateTime{} = dt ->
        {DateTime.to_date(dt), today}

      %NaiveDateTime{} = ndt ->
        {NaiveDateTime.to_date(ndt), today}
    end
  end

  defp relative_range(days_back) do
    today = Date.utc_today()
    {Date.add(today, -days_back), today}
  end

  # Build a `points="x1,y1 x2,y2 ..."` string for the SVG <polyline>.
  # ViewBox is 300x60. Returns "" if no data or max is zero — the template's
  # `:if` guard hides the SVG in that case.
  defp sparkline_points([]), do: ""

  defp sparkline_points(daily) do
    counts = Enum.map(daily, & &1.page_views)
    max_views = Enum.max(counts, fn -> 0 end)

    cond do
      max_views == 0 ->
        ""

      length(daily) == 1 ->
        [pv] = daily
        y = 60 - pv.page_views / max_views * 60
        "150,#{format_coord(y)}"

      true ->
        n = length(daily)
        step = 300 / (n - 1)

        daily
        |> Enum.with_index()
        |> Enum.map_join(" ", fn {row, i} ->
          x = i * step
          y = 60 - row.page_views / max_views * 60
          "#{format_coord(x)},#{format_coord(y)}"
        end)
    end
  end

  defp format_coord(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 2)

  defp range_label(range) do
    Enum.find_value(@ranges, range, fn {key, label} -> if key == range, do: label end)
  end

  # Percent-encoded paths (e.g. "/species/%C3%97%20ganderi" for hybrid names
  # like "× ganderi") are unreadable in the dashboard. Decode for display,
  # falling back to the raw path if the encoding is malformed.
  @doc false
  def display_path(path) when is_binary(path) do
    URI.decode(path)
  rescue
    _ -> path
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-wide" data-active-range={@range}>
      <.header>
        Site Analytics
        <:subtitle>
          Privacy-respecting page view stats for the Oak Compendium.
          Showing <strong>{range_label(@range)}</strong> ({@from} &ndash; {@to}).
        </:subtitle>
      </.header>

      <%!-- Range buttons --%>
      <div class="analytics-ranges" role="group" aria-label="Date range">
        <span class="analytics-ranges-label">Period:</span>
        <button
          :for={{key, label} <- @ranges}
          type="button"
          phx-click="set_range"
          phx-value-range={key}
          class="analytics-range"
          aria-pressed={to_string(key == @range)}
        >
          {label}
        </button>
      </div>

      <%!-- Totals --%>
      <section>
        <dl class="page-figures" id="analytics-totals">
          <div>
            <dt>Page Views</dt>
            <dd>{@stats.page_views}</dd>
          </div>
          <div>
            <dt>Unique Visitors</dt>
            <dd>{@stats.unique_visitors}</dd>
          </div>
        </dl>
      </section>

      <%!-- Daily page views: an inline SVG line --%>
      <section
        :if={Enum.any?(@daily, &(&1.page_views > 0))}
        class="analytics-chart"
        aria-label="Daily page views"
      >
        <.section_heading>
          Daily Page Views<:note>{length(@daily)} day(s)</:note>
        </.section_heading>
        <svg
          viewBox="0 0 300 60"
          preserveAspectRatio="none"
          role="img"
          aria-label="Sparkline of daily page views"
        >
          <polyline
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linejoin="round"
            stroke-linecap="round"
            vector-effect="non-scaling-stroke"
            points={sparkline_points(@daily)}
          />
        </svg>
        <div class="analytics-chart-dates" aria-hidden="true">
          <span>{@from}</span>
          <span>{@to}</span>
        </div>
      </section>

      <%!-- Top pages table --%>
      <section>
        <.section_heading>Top Pages</.section_heading>
        <div class="oc-table-wrap">
          <table class="oc-table analytics-table">
            <thead>
              <tr>
                <th scope="col">Path</th>
                <th scope="col" class="analytics-num">Views</th>
                <th scope="col" class="analytics-num">Unique Visitors</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={page <- @top_pages}>
                <td class="analytics-path">{display_path(page.path)}</td>
                <td class="analytics-num">{page.page_views}</td>
                <td class="analytics-num">{page.unique_visitors}</td>
              </tr>
              <tr :if={@top_pages == []}>
                <td colspan="3" class="oc-empty">No page views recorded for this period.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <%!-- Errors (collapsed by default) --%>
      <details :if={@top_404s != [] or @top_other_errors != []} class="analytics-errors">
        <summary class="oc-section-heading">
          <h2>Errors</h2>
          <small class="oc-section-heading-note">
            {length(@top_404s)} 404 paths &middot; {length(@top_other_errors)} other
          </small>
        </summary>

        <%!-- Top 404s --%>
        <div :if={@top_404s != []}>
          <h3>Top 404s</h3>
          <div class="oc-table-wrap">
            <table class="oc-table analytics-table">
              <thead>
                <tr>
                  <th scope="col">Path</th>
                  <th scope="col" class="analytics-num">Count</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={row <- @top_404s}>
                  <td class="analytics-path">{display_path(row.path)}</td>
                  <td class="analytics-num">{row.count}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- Other 4xx / 5xx --%>
        <div :if={@top_other_errors != []}>
          <h3>Top Other Errors</h3>
          <div class="oc-table-wrap">
            <table class="oc-table analytics-table">
              <thead>
                <tr>
                  <th scope="col">Path</th>
                  <th scope="col" class="analytics-num">Status</th>
                  <th scope="col" class="analytics-num">Count</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={row <- @top_other_errors}>
                  <td class="analytics-path">{display_path(row.path)}</td>
                  <td class="analytics-num">{row.status}</td>
                  <td class="analytics-num">{row.count}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </details>
    </div>
    """
  end
end
