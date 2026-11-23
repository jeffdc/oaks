defmodule OaksWeb.HelpMarkdownLive do
  use OaksWeb, :live_view

  import Phoenix.HTML, only: [raw: 1]

  alias Oaks.Markdown

  @sections [
    %{
      title: "Basic Formatting",
      description: nil,
      example: "**bold text**\n*italic text*\n~~strikethrough~~\n## Heading 2\n### Heading 3"
    },
    %{
      title: "Links & Images",
      description: nil,
      example:
        "[Link text](https://example.com)\n![Oak Compendium logo](/images/oakcompendium-192.png)\nhttps://example.com (auto-linked)"
    },
    %{
      title: "Lists",
      description: nil,
      example: "- Unordered item 1\n- Unordered item 2\n\n1. Ordered item 1\n2. Ordered item 2"
    },
    %{
      title: "Code",
      description: nil,
      example: "Inline `code` with backticks.\n\n```\nFenced code block\nfor multi-line code\n```"
    },
    %{
      title: "Tables",
      description: nil,
      example:
        "| Column 1 | Column 2 |\n|----------|----------|\n| Cell A   | Cell B   |\n| Cell C   | Cell D   |"
    },
    %{
      title: "Inline HTML",
      description:
        "You can use HTML tags for formatting not covered by Markdown. Inline styles (style attributes) are removed, so text keeps the site's colours and fonts.",
      example:
        "<sup>superscript</sup> and <sub>subscript</sub>\n<mark>highlighted text</mark>\n<u>underlined text</u>\n<kbd>Ctrl</kbd> + <kbd>S</kbd>\n\n<details>\n<summary>Click to expand</summary>\nHidden content goes here.\n</details>"
    },
    %{
      title: "Line Breaks",
      description:
        "Single newlines create line breaks (hardbreaks are enabled). No need for trailing spaces or <br> tags.",
      example: "Line one\nLine two (new line, same paragraph)"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Markdown Guide", sections: @sections)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page width="read" class="space-y-s7">
      <:head>
        <.header>Markdown Formatting Guide</.header>
      </:head>

      <section class="oc-prose">
        <p>
          Text fields in the Oak Compendium support
          <a href="https://github.github.com/gfm/" target="_blank" rel="noopener noreferrer">GitHub Flavored Markdown</a>
          (GFM). Here's a quick reference of supported syntax.
        </p>
      </section>

      <.md_section :for={section <- @sections} {section} />

      <.back navigate={~p"/"}>Back to home</.back>
    </.page>
    """
  end

  attr :title, :string, required: true
  attr :example, :string, required: true
  attr :description, :string, default: nil

  defp md_section(assigns) do
    ~H"""
    <section>
      <.section_heading>{@title}</.section_heading>
      <div :if={@description} class="oc-prose">
        <p>{@description}</p>
      </div>
      <div class="page-md-example">
        <div>
          <div class="page-md-label">Syntax</div>
          <pre class="page-md-syntax">{@example}</pre>
        </div>
        <div>
          <div class="page-md-label">Result</div>
          <div class="page-md-result oc-prose">
            {raw(Markdown.render_html(@example))}
          </div>
        </div>
      </div>
    </section>
    """
  end
end
