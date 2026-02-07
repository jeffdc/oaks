defmodule OakCompendiumWeb.HomeLiveTest do
  use OakCompendiumWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders home page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Explore the World of Oaks"
    assert html =~ "Browse Species"
    assert html =~ "Taxonomy Tree"
  end

  test "has navigation links", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ ~s(href="/list")
    assert html =~ ~s(href="/taxonomy")
    assert html =~ ~s(href="/search")
    assert html =~ ~s(href="/about")
  end
end
