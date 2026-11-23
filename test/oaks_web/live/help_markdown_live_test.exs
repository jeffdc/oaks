defmodule OaksWeb.HelpMarkdownLiveTest do
  use OaksWeb.ConnCase

  test "the inline HTML example shows no inline colour and says styles are removed", %{
    conn: conn
  } do
    html = conn |> get(~p"/help/markdown") |> html_response(200)

    assert html =~ "<mark>highlighted text</mark>"
    assert html =~ "Inline styles (style attributes) are removed"
    refute html =~ "color: red"
  end
end
