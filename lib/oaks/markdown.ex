defmodule Oaks.Markdown do
  @moduledoc """
  Shared markdown rendering using MDEx (cmark-gfm).

  Raw HTML in the source is allowed (some articles use tables of photos),
  but the rendered output is sanitized: scripts, event handlers, iframes,
  inline styles, and `javascript:` URLs are removed, while links, images,
  tables, and basic formatting are kept. The result is rendered with `raw/1`,
  so sanitizing here is what keeps stored content from running script.

  Inline styles go so that stored content can't set its own colours, sizes
  or fonts against DESIGN.md (item 65d4): MDEx's default allowlist keeps
  `style` on a few tags (`code`, `div`, `pre`, `span`), and it is taken off
  every tag here.
  """

  @sanitize_options Keyword.update!(
                      MDEx.Document.default_sanitize_options(),
                      :tag_attributes,
                      &Map.new(&1, fn {tag, attributes} ->
                        {tag, List.delete(attributes, "style")}
                      end)
                    )

  @spec render_html(String.t() | nil) :: String.t()
  def render_html(nil), do: ""
  def render_html(""), do: ""

  def render_html(content) when is_binary(content) do
    case MDEx.to_html(content,
           extension: [autolink: true, table: true, strikethrough: true],
           parse: [smart: true],
           render: [hardbreaks: true, unsafe_: true],
           sanitize: @sanitize_options
         ) do
      {:ok, html} -> html
      {:error, _reason} -> content
    end
  end
end
