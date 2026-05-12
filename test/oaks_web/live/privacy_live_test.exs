defmodule OaksWeb.PrivacyLiveTest do
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders privacy policy page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/privacy")
    assert html =~ "Privacy Policy"
    assert html =~ "Privacy-Protecting Analytics"
  end

  test "links to the analytics dashboard", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/privacy")
    assert html =~ ~s(href="/analytics")
  end

  test "links to the GitHub issues contact route", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/privacy")
    assert html =~ "https://github.com/jeffdc/oaks/issues"
  end

  test "describes the daily-rotating visitor hash", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/privacy")
    assert html =~ "SHA256"
  end

  test "lists what is NOT stored", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/privacy")
    assert html =~ "What We Don"
    assert html =~ "IP Addresses"
  end

  test "lists what IS collected", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/privacy")
    assert html =~ "What We Do Collect"
    assert html =~ "Page Paths"
  end
end
