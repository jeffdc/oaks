defmodule OaksWeb.ErrorHTMLTest do
  use OaksWeb.ConnCase

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  @statuses ["403", "404", "500"]

  defp render(status, assigns \\ []),
    do: render_to_string(OaksWeb.ErrorHTML, status, "html", assigns)

  defp with_referer(url),
    do: Plug.Conn.put_req_header(Phoenix.ConnTest.build_conn(), "referer", url)

  test "renders 404.html: not found, with search and the species list" do
    html = render("404")
    assert html =~ "Error 404"
    assert html =~ "<title>Page not found · Oak Compendium</title>"
    assert html =~ ~r{<h1>\s*Page not found\s*</h1>}
    assert html =~ ~s(action="/search")
    assert html =~ ~s(method="get")
    assert html =~ ~s(name="q")
    assert html =~ ~s(href="/species")
  end

  test "the 404 names the address that was asked for, escaped" do
    conn = %{Phoenix.ConnTest.build_conn() | request_path: "/specis/<alba>"}
    html = render("404", conn: conn)

    assert html =~ "/specis/&lt;alba&gt;"
    refute html =~ "<alba>"
    refute html =~ "this address."
    assert render("404") =~ "There’s no page at this address."
  end

  test "renders 403.html: request refused, with a way to log in" do
    html = render("403")
    assert html =~ "Error 403"
    assert html =~ "<title>Request refused · Oak Compendium</title>"
    assert html =~ "security check expired"
    assert html =~ ~s(<a href="/users/log-in" class="oc-btn oc-btn-primary">)
    refute html =~ ~s(action="/search")
  end

  test "on the 403, Go back is the one primary action when there is a page to go back to" do
    html = render("403", conn: with_referer("https://oakcompendium.org/users/log-in"))

    assert html =~
             ~s(<a href="https://oakcompendium.org/users/log-in" class="oc-btn oc-btn-primary">)

    assert html =~ ~s(<a href="/users/log-in" class="oc-btn">)
    assert length(String.split(html, "Go back")) == 2
  end

  test "renders 500.html: something went wrong" do
    html = render("500")
    assert html =~ "Error 500"
    assert html =~ "<title>Something went wrong · Oak Compendium</title>"
    refute html =~ ~s(action="/search")
  end

  test "each is a standalone page of the design system: stylesheet, masthead, footer, no script" do
    for status <- @statuses do
      html = render(status)
      assert html =~ "<!DOCTYPE html>", status
      assert html =~ ~s(href="/assets/css/app.css"), status
      assert html =~ ~s(aria-label="Oak Compendium home"), status
      assert html =~ "Facts free to use", status
      assert html =~ ~s(<meta name="description"), status
      refute html =~ "<script", status
      refute html =~ "<style", status
      refute html =~ ~s( style="), status
    end
  end

  test "Go back links to the page the visitor came from" do
    for status <- @statuses do
      html = render(status, conn: with_referer("https://oakcompendium.org/species/alba"))

      assert html =~ ~s(href="https://oakcompendium.org/species/alba"), status
      assert html =~ "Go back", status
    end
  end

  test "with no page to go back to, there is no Go back" do
    for status <- @statuses do
      refute render(status, conn: Phoenix.ConnTest.build_conn()) =~ "Go back", status
      refute render(status) =~ "Go back", status
      assert render(status) =~ ~s(href="/"), status
    end
  end

  test "a referer that isn't a web address gives no Go back" do
    for referer <- ["javascript:alert(1)", "data:text/html,hi", "/species/alba"] do
      html = render("404", conn: with_referer(referer))

      refute html =~ "Go back", referer
      refute html =~ "javascript:", referer
    end
  end

  test "a status without a template renders its plain status message" do
    assert render("400") == "Bad Request"
  end

  describe "through the endpoint" do
    test "an unknown address gets the 404 page", %{conn: conn} do
      body = conn |> get("/no-such-page") |> html_response(404)

      assert body =~ "<title>Page not found · Oak Compendium</title>"
      assert body =~ "/no-such-page"
    end

    test "a form sent without its security token gets the 403 page", %{conn: conn} do
      conn = Plug.Conn.put_private(conn, :plug_skip_csrf_protection, false)

      {403, _headers, body} =
        assert_error_sent 403, fn -> post(conn, ~p"/users/log-in", %{}) end

      assert body =~ "<title>Request refused · Oak Compendium</title>"
    end
  end
end
