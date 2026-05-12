defmodule OaksWeb.Plugs.AnalyticsTest do
  @moduledoc """
  Unit tests for the analytics tracking plug. Covers the skip rules,
  IP extraction, attrs construction, and the session/before-send wiring.

  End-to-end "row appears in DB" verification belongs to Task 5
  (router wiring + integration test).
  """

  use OaksWeb.ConnCase

  alias OaksWeb.Plugs.Analytics

  # --- helpers ---------------------------------------------------------

  defp new_conn(method, path) do
    Plug.Test.conn(method, path)
    |> Plug.Test.init_test_session(%{})
  end

  defp browser_ua,
    do: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15"

  defp googlebot_ua,
    do: "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

  # --- should_track?/2 -------------------------------------------------

  describe "should_track?/2" do
    test "returns true for a normal GET / with a browser UA" do
      conn = new_conn(:get, "/")
      assert Analytics.should_track?(conn, browser_ua())
    end

    test "returns false for POST" do
      conn = new_conn(:post, "/")
      refute Analytics.should_track?(conn, browser_ua())
    end

    test "returns false for PUT" do
      conn = new_conn(:put, "/")
      refute Analytics.should_track?(conn, browser_ua())
    end

    test "returns false for DELETE" do
      conn = new_conn(:delete, "/")
      refute Analytics.should_track?(conn, browser_ua())
    end

    test "returns false for /api/species" do
      conn = new_conn(:get, "/api/species")
      refute Analytics.should_track?(conn, browser_ua())
    end

    test "returns false for any /api/* path" do
      conn = new_conn(:get, "/api/anything/else")
      refute Analytics.should_track?(conn, browser_ua())
    end

    test "returns false for /assets/app.css" do
      conn = new_conn(:get, "/assets/app.css")
      refute Analytics.should_track?(conn, browser_ua())
    end

    test "returns false for /favicon.ico" do
      conn = new_conn(:get, "/favicon.ico")
      refute Analytics.should_track?(conn, browser_ua())
    end

    test "returns false for /health" do
      conn = new_conn(:get, "/health")
      refute Analytics.should_track?(conn, browser_ua())
    end

    test "returns false for Googlebot UA" do
      conn = new_conn(:get, "/")
      refute Analytics.should_track?(conn, googlebot_ua())
    end

    test "returns false for crawler/spider/scrape/preview UAs" do
      conn = new_conn(:get, "/")
      refute Analytics.should_track?(conn, "SomeCrawler/1.0")
      refute Analytics.should_track?(conn, "Mozilla spider 9000")
      refute Analytics.should_track?(conn, "scrape-it/0.1")
      refute Analytics.should_track?(conn, "Slackbot LinkPreview")
    end
  end

  # --- client_ip/1 -----------------------------------------------------

  describe "client_ip/1" do
    test "prefers fly-client-ip over x-forwarded-for" do
      conn =
        new_conn(:get, "/")
        |> Plug.Conn.put_req_header("fly-client-ip", "203.0.113.7")
        |> Plug.Conn.put_req_header("x-forwarded-for", "198.51.100.1, 10.0.0.1")

      assert Analytics.client_ip(conn) == "203.0.113.7"
    end

    test "uses first comma-segment of x-forwarded-for when no fly header" do
      conn =
        new_conn(:get, "/")
        |> Plug.Conn.put_req_header("x-forwarded-for", "198.51.100.1, 10.0.0.1, 10.0.0.2")

      assert Analytics.client_ip(conn) == "198.51.100.1"
    end

    test "trims whitespace around x-forwarded-for segment" do
      conn =
        new_conn(:get, "/")
        |> Plug.Conn.put_req_header("x-forwarded-for", "   198.51.100.1   , 10.0.0.1")

      assert Analytics.client_ip(conn) == "198.51.100.1"
    end

    test "falls back to conn.remote_ip when no proxy headers" do
      conn = %{new_conn(:get, "/") | remote_ip: {127, 0, 0, 1}}
      assert Analytics.client_ip(conn) == "127.0.0.1"
    end

    test "ignores an empty fly-client-ip and falls through" do
      conn =
        new_conn(:get, "/")
        |> Plug.Conn.put_req_header("fly-client-ip", "")
        |> Plug.Conn.put_req_header("x-forwarded-for", "198.51.100.1")

      assert Analytics.client_ip(conn) == "198.51.100.1"
    end
  end

  # --- build_attrs/2 ---------------------------------------------------

  describe "build_attrs/2" do
    test "returns a map with the expected keys for a representative conn" do
      conn =
        new_conn(:get, "/species/quercus-alba")
        |> Map.put(:status, 200)
        |> Map.put(:host, "example.com")

      attrs = Analytics.build_attrs(conn, "abc123")

      assert attrs.path == "/species/quercus-alba"
      assert attrs.status == 200
      assert attrs.visitor_hash == "abc123"
      assert is_nil(attrs.referrer_host)
      assert %DateTime{} = attrs.inserted_at
    end

    test "defaults status to 200 when conn.status is nil" do
      conn =
        new_conn(:get, "/")
        |> Map.put(:status, nil)
        |> Map.put(:host, "example.com")

      attrs = Analytics.build_attrs(conn, "hash")
      assert attrs.status == 200
    end

    test "same-host Referer yields nil referrer_host" do
      conn =
        new_conn(:get, "/")
        |> Map.put(:host, "example.com")
        |> Plug.Conn.put_req_header("referer", "https://example.com/some/page")

      attrs = Analytics.build_attrs(conn, "hash")
      assert is_nil(attrs.referrer_host)
    end

    test "cross-host Referer yields the parsed host" do
      conn =
        new_conn(:get, "/")
        |> Map.put(:host, "example.com")
        |> Plug.Conn.put_req_header("referer", "https://duckduckgo.com/?q=oaks")

      attrs = Analytics.build_attrs(conn, "hash")
      assert attrs.referrer_host == "duckduckgo.com"
    end

    test "missing Referer yields nil referrer_host" do
      conn =
        new_conn(:get, "/")
        |> Map.put(:host, "example.com")

      attrs = Analytics.build_attrs(conn, "hash")
      assert is_nil(attrs.referrer_host)
    end

    test "unparseable Referer yields nil referrer_host" do
      conn =
        new_conn(:get, "/")
        |> Map.put(:host, "example.com")
        |> Plug.Conn.put_req_header("referer", "::not a url::")

      attrs = Analytics.build_attrs(conn, "hash")
      assert is_nil(attrs.referrer_host)
    end
  end

  # --- call/2 ----------------------------------------------------------

  describe "call/2" do
    test "does not halt the conn and preserves status/body when the response is sent" do
      conn =
        new_conn(:get, "/")
        |> Plug.Conn.put_req_header("user-agent", browser_ua())
        |> Analytics.call([])
        |> Plug.Conn.send_resp(200, "ok")

      refute conn.halted
      assert conn.status == 200
      assert conn.resp_body == "ok"
    end

    test "register_before_send runs without raising even for skipped requests" do
      conn =
        new_conn(:post, "/api/species")
        |> Plug.Conn.put_req_header("user-agent", browser_ua())
        |> Analytics.call([])
        |> Plug.Conn.send_resp(201, "created")

      assert conn.status == 201
      assert conn.resp_body == "created"
    end

    test "skips tracking for LiveView routes (conn.private[:phoenix_live_view] set)" do
      # Simulate Phoenix.LiveView.Router having dispatched to a LV: a
      # `:phoenix_live_view` key appears under `conn.private`. The plug's
      # before_send callback must NOT enqueue an insert; the on_mount hook
      # owns LV tracking.
      conn =
        new_conn(:get, "/some-live-route")
        |> Plug.Conn.put_req_header("user-agent", browser_ua())
        |> Plug.Conn.put_private(:phoenix_live_view, {SomeLive, :index, %{}, []})
        |> Analytics.call([])
        |> Plug.Conn.send_resp(200, "html")

      # We can't directly inspect Task.Supervisor calls here, so the contract
      # we assert is the response is preserved and no exception was raised
      # by the before_send callback. The real assertion (zero rows inserted
      # for LV routes via the plug) lives in the integration test.
      refute conn.halted
      assert conn.status == 200
    end
  end
end
