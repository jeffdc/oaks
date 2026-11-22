defmodule OaksWeb.DevComponentsLiveTest do
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

  test "shows every design component on its own page", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/dev/components")

    assert html =~ "oc-band"
    refute html =~ "header-search"

    for id <- ~w(marks buttons list field-marks fields notices names title-pages page) do
      assert has_element?(view, "##{id}")
    end

    assert has_element?(view, "#field-marks-table th[scope=row]", "Buds")
    assert has_element?(view, "#gallery-modal[role=dialog], #gallery-modal [role=dialog]")
  end

  test "is not served when dev routes are off", %{conn: conn} do
    Application.put_env(:oaks, :dev_routes, false)
    on_exit(fn -> Application.put_env(:oaks, :dev_routes, true) end)

    assert_raise OaksWeb.DevComponentsLive.NotAvailable, fn ->
      live(conn, ~p"/dev/components")
    end
  end
end
