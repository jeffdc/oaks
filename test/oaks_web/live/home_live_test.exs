defmodule OaksWeb.HomeLiveTest do
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders home page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Explore the World of Oaks"
    assert html =~ "Taxonomy Tree"
  end

  test "has navigation links", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ ~s(href="/taxonomy")
    assert html =~ ~s(href="/about")
  end
end
