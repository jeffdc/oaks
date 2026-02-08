defmodule OakCompendium.Markdown do
  @moduledoc """
  Shared markdown rendering using MDEx (cmark-gfm).
  """

  @spec render_html(String.t() | nil) :: String.t()
  def render_html(nil), do: ""
  def render_html(""), do: ""

  def render_html(content) when is_binary(content) do
    case MDEx.to_html(content,
           extension: [autolink: true, table: true, strikethrough: true],
           parse: [smart: true],
           render: [hardbreaks: true, unsafe_: true]
         ) do
      {:ok, html} -> html
      {:error, _reason} -> content
    end
  end
end
