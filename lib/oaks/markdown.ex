defmodule Oaks.Markdown do
  @moduledoc """
  Shared markdown rendering using MDEx (cmark-gfm).

  Raw HTML in the source is allowed (some articles use tables of photos),
  but the rendered output is sanitized: scripts, event handlers, iframes,
  inline styles, and `javascript:` URLs are removed, while links, images,
  tables, and basic formatting are kept. The result is rendered with `raw/1`,
  so sanitizing here is what keeps stored content from running script.
  """

  @spec render_html(String.t() | nil) :: String.t()
  def render_html(nil), do: ""
  def render_html(""), do: ""

  def render_html(content) when is_binary(content) do
    case MDEx.to_html(content,
           extension: [autolink: true, table: true, strikethrough: true],
           parse: [smart: true],
           render: [hardbreaks: true, unsafe_: true],
           sanitize: MDEx.Document.default_sanitize_options()
         ) do
      {:ok, html} -> html
      {:error, _reason} -> content
    end
  end
end
