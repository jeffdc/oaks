defmodule OaksWeb.AnalyticsLiveTest do
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.AnalyticsFixtures

  defp at(%Date{} = date, %Time{} = time) do
    time_us = %{time | microsecond: {0, 6}}
    {:ok, ndt} = NaiveDateTime.new(date, time_us)
    DateTime.from_naive!(ndt, "Etc/UTC")
  end

  defp hash(letter) when is_binary(letter), do: String.duplicate(letter, 64)

  describe "mount and default range" do
    test "renders Last 7 days as the active range by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/analytics")

      assert html =~ "Site Analytics"
      assert html =~ "Last 7 days"
      # The default range "7" button should be marked active.
      assert html =~ ~s(phx-value-range="7")
      assert html =~ ~s(data-active-range="7")
    end

    test "totals reflect the 7-day window", %{conn: conn} do
      today = Date.utc_today()

      page_view_fixture(%{
        path: "/recent",
        visitor_hash: hash("a"),
        inserted_at: at(today, ~T[09:00:00])
      })

      # Outside the 7-day window: 100 days ago.
      old = Date.add(today, -100)

      page_view_fixture(%{
        path: "/old",
        visitor_hash: hash("b"),
        inserted_at: at(old, ~T[09:00:00])
      })

      {:ok, _view, html} = live(conn, ~p"/analytics")

      assert html =~ "/recent"
      refute html =~ "/old"
    end
  end

  describe "range switching" do
    test "clicking 30 updates the totals to include older rows", %{conn: conn} do
      today = Date.utc_today()
      twenty_days_ago = Date.add(today, -20)

      page_view_fixture(%{
        path: "/today-page",
        visitor_hash: hash("a"),
        inserted_at: at(today, ~T[09:00:00])
      })

      page_view_fixture(%{
        path: "/twenty-days-ago",
        visitor_hash: hash("b"),
        inserted_at: at(twenty_days_ago, ~T[09:00:00])
      })

      {:ok, view, html} = live(conn, ~p"/analytics")

      # Default 7-day range excludes the 20-day-old row.
      assert html =~ "/today-page"
      refute html =~ "/twenty-days-ago"

      html_after = render_click(view, "set_range", %{"range" => "30"})

      assert html_after =~ "/today-page"
      assert html_after =~ "/twenty-days-ago"
      assert html_after =~ ~s(data-active-range="30")
    end
  end

  describe "top pages table" do
    test "renders multiple paths in order by view count", %{conn: conn} do
      today = Date.utc_today()
      a = hash("a")
      b = hash("b")

      # /alpha: 3 views, /beta: 2 views, /gamma: 1 view
      page_view_fixture(%{path: "/alpha", visitor_hash: a, inserted_at: at(today, ~T[09:00:00])})
      page_view_fixture(%{path: "/alpha", visitor_hash: b, inserted_at: at(today, ~T[09:01:00])})
      page_view_fixture(%{path: "/alpha", visitor_hash: a, inserted_at: at(today, ~T[09:02:00])})
      page_view_fixture(%{path: "/beta", visitor_hash: a, inserted_at: at(today, ~T[09:03:00])})
      page_view_fixture(%{path: "/beta", visitor_hash: b, inserted_at: at(today, ~T[09:04:00])})
      page_view_fixture(%{path: "/gamma", visitor_hash: a, inserted_at: at(today, ~T[09:05:00])})

      {:ok, _view, html} = live(conn, ~p"/analytics")

      assert html =~ "/alpha"
      assert html =~ "/beta"
      assert html =~ "/gamma"

      # All three should appear in descending order.
      alpha_pos = :binary.match(html, "/alpha") |> elem(0)
      beta_pos = :binary.match(html, "/beta") |> elem(0)
      gamma_pos = :binary.match(html, "/gamma") |> elem(0)

      assert alpha_pos < beta_pos
      assert beta_pos < gamma_pos
    end
  end

  describe "top 404s section" do
    test "is hidden when there are no 404s and appears once a 404 is seeded", %{conn: conn} do
      today = Date.utc_today()

      page_view_fixture(%{
        path: "/ok",
        status: 200,
        visitor_hash: hash("a"),
        inserted_at: at(today, ~T[09:00:00])
      })

      {:ok, _view, html} = live(conn, ~p"/analytics")

      refute html =~ "Top 404s"

      page_view_fixture(%{
        path: "/missing",
        status: 404,
        visitor_hash: hash("b"),
        inserted_at: at(today, ~T[09:01:00])
      })

      {:ok, _view2, html2} = live(conn, ~p"/analytics")

      assert html2 =~ "Top 404s"
      assert html2 =~ "/missing"
    end
  end

  describe "all-time range" do
    test "includes rows older than 90 days when range=all", %{conn: conn} do
      today = Date.utc_today()
      hundred_days_ago = Date.add(today, -100)

      page_view_fixture(%{
        path: "/ancient",
        visitor_hash: hash("a"),
        inserted_at: at(hundred_days_ago, ~T[09:00:00])
      })

      page_view_fixture(%{
        path: "/today-page",
        visitor_hash: hash("b"),
        inserted_at: at(today, ~T[09:00:00])
      })

      {:ok, view, html} = live(conn, ~p"/analytics")

      # Default 7-day range excludes the 100-day-old row.
      refute html =~ "/ancient"

      html_all = render_click(view, "set_range", %{"range" => "all"})

      assert html_all =~ "/ancient"
      assert html_all =~ "/today-page"
      assert html_all =~ ~s(data-active-range="all")
    end

    test "with no rows, all-time still renders without error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/analytics")
      html_all = render_click(view, "set_range", %{"range" => "all"})
      assert html_all =~ "Site Analytics"
      assert html_all =~ ~s(data-active-range="all")
    end
  end
end
