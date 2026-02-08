defmodule OaksWeb.AboutLiveTest do
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders about page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/about")
    assert html =~ "About the Oak Compendium"
    assert html =~ "Jeff Clark"
    assert html =~ "Gallformers"
  end

  test "has data sources section", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/about")
    assert html =~ "Data Sources"
    assert html =~ "iNaturalist"
    assert html =~ "Oaks of the World"
  end

  test "has licensing and open source sections", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/about")
    assert html =~ "Data Licensing"
    assert html =~ "Open Source"
    assert html =~ "MIT License"
  end
end
