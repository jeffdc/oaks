defmodule Oaks.MarkdownTest do
  use ExUnit.Case

  alias Oaks.Markdown

  test "renders links and bare URLs" do
    html =
      Markdown.render_html("See https://www.inaturalist.org/taxa/47851 and [alba](/species/alba)")

    assert html =~ ~s(href="https://www.inaturalist.org/taxa/47851")
    assert html =~ ~s(href="/species/alba")
  end

  test "keeps safe inline HTML such as a table of photos" do
    html =
      Markdown.render_html("""
      <table><tr><td style="padding:5px;"><b>Q. montana?</b></td>
      <td><img src="https://inaturalist-open-data.s3.amazonaws.com/photos/1/large.jpeg" width="200" /></td></tr></table>
      """)

    assert html =~ "<table>"
    assert html =~ "<b>Q. montana?</b>"
    assert html =~ ~s(src="https://inaturalist-open-data.s3.amazonaws.com/photos/1/large.jpeg")
    refute html =~ "style="
  end

  test "strips scripts, event handlers, iframes, and javascript: URLs" do
    for evil <- [
          ~S|<script>alert(1)</script>|,
          ~S|<img src="x" onerror="alert(1)">|,
          ~S|<iframe src="https://evil.example"></iframe>|,
          ~S|[click](javascript:alert(1))|,
          ~S|<a href="javascript:alert(1)">x</a>|
        ] do
      html = Markdown.render_html(evil)

      refute html =~ "<script", evil
      refute html =~ "onerror", evil
      refute html =~ "<iframe", evil
      refute html =~ "javascript:", evil
    end
  end
end
