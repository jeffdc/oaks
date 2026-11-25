defmodule OaksWeb.DevComponentsLiveTest do
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

  test "shows every design component on its own page", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/dev/components")

    assert html =~ "oc-band"
    refute html =~ "header-search"

    for id <- ~w(marks buttons list field-marks fields notices names title-pages page not-found) do
      assert has_element?(view, "##{id}")
    end

    assert has_element?(view, "#field-marks-table th[scope=row]", "Buds")
    assert has_element?(view, "#gallery-modal[role=dialog], #gallery-modal [role=dialog]")
  end

  test "shows the species page's parts, with working source tabs", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev/components")

    assert has_element?(view, "#gallery-species-title .oc-title-cn", "Shumard's oak")
    assert has_element?(view, "#gallery-not-covered", "no account of this oak yet")
    assert has_element?(view, "#gallery-photo-columns aside[aria-label=Photos]")
    assert has_element?(view, "#gallery-hybrids li", "with")
    assert has_element?(view, "#gallery-links a[target=_blank]", "Flora of North America")
    assert has_element?(view, "#gallery-cite", "Oak Compendium.")

    assert has_element?(view, "#gallery-source-tabs-tab-3[aria-selected=true]")
    assert has_element?(view, "#gallery-source-tabs a[aria-label='About Oak Compendium']")
    assert has_element?(view, "#gallery-source-tabs-panel h3", "Twigs")

    view |> element("#gallery-source-tabs-tab-2") |> render_click()

    assert has_element?(view, "#gallery-source-tabs-tab-2[aria-selected=true]")

    assert has_element?(
             view,
             "#gallery-source-tabs a[aria-label='Original page at Oaks of the World']"
           )

    refute has_element?(view, "#gallery-source-tabs a[aria-label='About Oak Compendium']")
    assert has_element?(view, "#gallery-source-tabs-panel h3", "Hardiness and habitat")

    view |> element("#gallery-source-tabs-tab-5") |> render_click()
    assert has_element?(view, "#gallery-source-tabs-panel", "No text from")
  end

  test "is not served when dev routes are off", %{conn: conn} do
    Application.put_env(:oaks, :dev_routes, false)
    on_exit(fn -> Application.put_env(:oaks, :dev_routes, true) end)

    assert_raise OaksWeb.DevComponentsLive.NotAvailable, fn ->
      live(conn, ~p"/dev/components")
    end
  end
end
