defmodule OaksWeb.AnalyticsLive do
  @moduledoc """
  Public dashboard at `/analytics` for the self-hosted page-view analytics.

  Shows totals, a daily sparkline, the top pages, and the top 404s for a
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
    <div class="max-w-4xl mx-auto" data-active-range={@range}>
      <header class="mb-8">
        <h1
          class="text-3xl font-bold mb-2"
          style="font-family: var(--font-serif); color: var(--color-forest-800, #165132);"
        >
          Site Analytics
        </h1>
        <p style="color: var(--color-text-secondary);">
          Privacy-respecting page view stats for the Oak Compendium.
          Showing <strong>{range_label(@range)}</strong> ({@from} &mdash; {@to}).
        </p>
      </header>

      <%!-- Range buttons --%>
      <div class="flex flex-wrap items-center gap-2 mb-6" role="group" aria-label="Date range">
        <span class="text-sm" style="color: var(--color-text-secondary);">Period:</span>
        <button
          :for={{key, label} <- @ranges}
          type="button"
          phx-click="set_range"
          phx-value-range={key}
          class={[
            "px-3 py-1 text-sm rounded-md border transition-colors",
            if(key == @range,
              do: "bg-forest-700 text-white border-forest-700",
              else: "bg-white text-stone-700 border-stone-200 hover:bg-stone-50"
            )
          ]}
        >
          {label}
        </button>
      </div>

      <%!-- Totals header card --%>
      <section class="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-6">
        <div class="card p-5">
          <div class="text-sm uppercase tracking-wide" style="color: var(--color-text-tertiary);">
            Page Views
          </div>
          <div
            class="text-3xl font-semibold mt-1"
            style="color: var(--color-forest-800);"
          >
            {@stats.page_views}
          </div>
        </div>
        <div class="card p-5">
          <div class="text-sm uppercase tracking-wide" style="color: var(--color-text-tertiary);">
            Unique Visitors
          </div>
          <div
            class="text-3xl font-semibold mt-1"
            style="color: var(--color-forest-800);"
          >
            {@stats.unique_visitors}
          </div>
        </div>
      </section>

      <%!-- Sparkline --%>
      <section
        :if={Enum.any?(@daily, &(&1.page_views > 0))}
        class="card p-5 mb-6"
        aria-label="Daily page views"
      >
        <div class="flex items-baseline justify-between mb-2">
          <h2 class="text-lg font-semibold" style="color: var(--color-forest-800);">
            Daily Page Views
          </h2>
          <span class="text-xs" style="color: var(--color-text-tertiary);">
            {length(@daily)} day(s)
          </span>
        </div>
        <svg
          viewBox="0 0 300 60"
          preserveAspectRatio="none"
          class="w-full h-16"
          style="color: var(--color-forest-600, #2f7a4d);"
          role="img"
          aria-label="Sparkline of daily page views"
        >
          <polyline
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linejoin="round"
            stroke-linecap="round"
            points={sparkline_points(@daily)}
          />
        </svg>
      </section>

      <%!-- Top pages table --%>
      <section class="card p-0 mb-6 overflow-hidden">
        <div class="px-5 py-3 border-b border-stone-200 bg-stone-50">
          <h2 class="text-lg font-semibold" style="color: var(--color-forest-800);">
            Top Pages
          </h2>
        </div>
        <table class="w-full text-sm">
          <thead class="bg-stone-50">
            <tr>
              <th class="text-left px-4 py-2 font-medium" style="color: var(--color-text-secondary);">
                Path
              </th>
              <th
                class="text-right px-4 py-2 font-medium"
                style="color: var(--color-text-secondary);"
              >
                Views
              </th>
              <th
                class="text-right px-4 py-2 font-medium"
                style="color: var(--color-text-secondary);"
              >
                Unique Visitors
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={page <- @top_pages}
              class="border-t border-stone-100"
            >
              <td class="px-4 py-2 font-mono text-xs break-all">{display_path(page.path)}</td>
              <td class="px-4 py-2 text-right">{page.page_views}</td>
              <td class="px-4 py-2 text-right">{page.unique_visitors}</td>
            </tr>
            <tr :if={@top_pages == []}>
              <td
                colspan="3"
                class="px-4 py-6 text-center"
                style="color: var(--color-text-tertiary);"
              >
                No page views recorded for this period.
              </td>
            </tr>
          </tbody>
        </table>
      </section>

      <%!-- Top 404s table --%>
      <section :if={@top_404s != []} class="card p-0 mb-6 overflow-hidden">
        <div class="px-5 py-3 border-b border-stone-200 bg-stone-50">
          <h2 class="text-lg font-semibold" style="color: var(--color-forest-800);">
            Top 404s
          </h2>
        </div>
        <table class="w-full text-sm">
          <thead class="bg-stone-50">
            <tr>
              <th class="text-left px-4 py-2 font-medium" style="color: var(--color-text-secondary);">
                Path
              </th>
              <th
                class="text-right px-4 py-2 font-medium"
                style="color: var(--color-text-secondary);"
              >
                Count
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={row <- @top_404s}
              class="border-t border-stone-100"
            >
              <td class="px-4 py-2 font-mono text-xs break-all">{display_path(row.path)}</td>
              <td class="px-4 py-2 text-right">{row.count}</td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>
    """
  end
end
