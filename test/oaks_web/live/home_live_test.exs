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

  test "tagline counts non-hybrid species separately from hybrids", %{conn: conn} do
    non_hybrids = Oaks.Species.count() - Oaks.Species.count_hybrids()
    {:ok, view, _html} = live(conn, ~p"/")

    assert render(view) =~ ~r/>\s*#{non_hybrids}\s*<\/strong>\s*oak species and/
  end
end
