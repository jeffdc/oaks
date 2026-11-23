defmodule OaksWeb.HeaderTest do
  @moduledoc """
  The site shell (OaksWeb.Layouts): masthead, nav, search, editor marks,
  page frame and footer, on LiveViews and on controller pages.
  """
  use OaksWeb.ConnCase

  import Oaks.AccountsFixtures
  import Phoenix.LiveViewTest

  alias OaksWeb.Layouts

  describe "masthead" do
    test "has the mark and the main nav in order", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#site-header a.oc-mark[href='/']", "Oak Compendium")

      nav = view |> element("#site-header nav[aria-label='Main']") |> render()

      hrefs =
        Regex.scan(~r/href="([^"]+)"/, nav, capture: :all_but_first) |> List.flatten()

      assert hrefs == ["/species", "/taxonomy", "/sources", "/about"]
    end

    test "leaves the old nav items and the logo image out", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      refute has_element?(view, "#site-header a[href='/articles']")
      refute has_element?(view, "#site-header a[href='/settings']")
      refute has_element?(view, "#site-header a[href='/species/new']")
      refute html =~ "oakcompendium-192.png"
    end

    test "has the search field with its key hint", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(
               view,
               "#site-header form[role='search'][action='/search'][method='get']"
             )

      assert has_element?(view, "input#header-search[name='q'][aria-keyshortcuts='/']")
      assert has_element?(view, "label[for='header-search']", "Search")
      assert has_element?(view, "#site-header kbd", "/")
    end

    test "has a skip link to the page frame", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "a.oc-skip[href='#main']", "Skip to content")
      assert has_element?(view, "main#main.oc-page")
    end
  end

  describe "current nav item" do
    test "marks nothing on the home page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      refute has_element?(view, "#site-header [aria-current]")
    end

    test "marks the item's own page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      assert has_element?(view, "nav a[href='/about'][aria-current='page']")
      assert view |> element("#site-header") |> render() |> count_current() == 1
    end

    test "marks Species on the species index", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/species")

      assert has_element?(view, "nav a[href='/species'][aria-current='page']")
    end
  end

  describe "nav_current/2" do
    test "is page on the item's path, true below it, nil elsewhere" do
      assert Layouts.nav_current("/sources", "/sources") == "page"
      assert Layouts.nav_current("/sources/3", "/sources") == "true"
      assert Layouts.nav_current("/species/alba", "/species") == "true"
      assert Layouts.nav_current("/taxonomy/Quercus/Lobatae", "/taxonomy") == "true"
      assert Layouts.nav_current("/speciesx", "/species") == nil
      assert Layouts.nav_current("/", "/species") == nil
      assert Layouts.nav_current(nil, "/species") == nil
    end

    test "leaves Add species to the editor menu" do
      assert Layouts.nav_current("/species/new", "/species") == nil
      assert Layouts.editor_current("/species/new") == "true"
      assert Layouts.editor_current("/settings") == "true"
      assert Layouts.editor_current("/users/settings/password") == "true"
      assert Layouts.editor_current("/species/alba") == nil
      assert Layouts.editor_current(nil) == nil
    end
  end

  describe "editor marks" do
    test "are absent when logged out", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      refute has_element?(view, "#editor-menu")
      refute has_element?(view, ".oc-who")
    end

    test "show the Editor menu and the editor's name when logged in", %{conn: conn} do
      user = user_fixture(%{email: "jeff#{System.unique_integer([:positive])}@example.com"})
      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/")

      assert has_element?(view, "#editor-menu summary", "Editor")
      assert has_element?(view, "#editor-menu a[href='/species/new']", "Add species")
      assert has_element?(view, "#editor-menu a[href='/settings']", "Settings")
      assert has_element?(view, "#editor-menu a[href='/users/log-out'][data-method='delete']")
      assert has_element?(view, ".oc-who", "Jeff")
    end

    test "mark Editor current on an editor page", %{conn: conn} do
      user = user_fixture()
      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings")

      assert has_element?(view, "#editor-menu summary[aria-current]")
    end
  end

  describe "footer" do
    test "carries the licensing line and the secondary pages", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#site-footer", "Oak Compendium’s prose is © all rights reserved")
      assert has_element?(view, "#site-footer", "All facts are free to use")
      assert has_element?(view, "#site-footer", "Other sources are under their own terms")
      assert has_element?(view, "#site-footer a[href='/articles']", "Articles")
      assert has_element?(view, "#site-footer a[href='/privacy']", "Privacy")
      assert has_element?(view, "#site-footer a[href='/analytics']", "Analytics")
      assert has_element?(view, "#site-footer a[href='/api/v1/docs']", "API")
      assert has_element?(view, "#site-footer a[href='/users/log-in']", "Log in")
    end

    test "drops the log-in link when logged in", %{conn: conn} do
      {:ok, view, _html} = conn |> log_in_user(user_fixture()) |> live(~p"/")

      refute has_element?(view, "#site-footer a[href='/users/log-in']")
    end
  end

  describe "controller pages" do
    test "get the same shell", %{conn: conn} do
      html = conn |> get(~p"/users/log-in") |> html_response(200)

      assert html =~ ~s(id="site-header")
      assert html =~ ~s(id="header-search")
      assert html =~ ~s(id="site-footer")
      assert html =~ "All facts are free to use"
    end

    test "mark Editor current on the security settings", %{conn: conn} do
      html =
        conn
        |> log_in_user(user_fixture())
        |> get(~p"/users/settings/password")
        |> html_response(200)

      assert html =~ ~r/<summary[^>]*aria-current="true"[^>]*><span>Editor</
    end
  end

  defp count_current(html), do: length(Regex.scan(~r/aria-current=/, html))
end
