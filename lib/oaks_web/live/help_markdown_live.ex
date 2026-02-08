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
        "[Link text](https://example.com)\n![Alt text](https://example.com/image.jpg)\nhttps://example.com (auto-linked)"
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
      description: "You can use HTML tags for formatting not covered by Markdown.",
      example:
        "<sup>superscript</sup> and <sub>subscript</sub>\n<mark>highlighted text</mark>\n<u>underlined text</u>\n<kbd>Ctrl</kbd> + <kbd>S</kbd>\n<span style=\"color: red;\">colored text</span>\n\n<details>\n<summary>Click to expand</summary>\nHidden content goes here.\n</details>"
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
    <div class="max-w-3xl mx-auto">
      <h2
        class="text-3xl font-bold mb-8"
        style="font-family: var(--font-serif); color: var(--color-forest-800, #165132);"
      >
        Markdown Formatting Guide
      </h2>

      <p
        class="leading-relaxed mb-8"
        style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
      >
        Text fields in the Oak Compendium support
        <a href="https://github.github.com/gfm/" target="_blank" rel="noopener noreferrer">
          GitHub Flavored Markdown
        </a>
        (GFM). Here's a quick reference of supported syntax.
      </p>

      <.md_section :for={section <- @sections} {section} />

      <div class="mt-10">
        <.link
          navigate={~p"/"}
          class="text-sm font-medium"
          style="color: var(--color-forest-600);"
        >
          &larr; Back to home
        </.link>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :example, :string, required: true
  attr :description, :string, default: nil

  defp md_section(assigns) do
    ~H"""
    <section class="mb-8">
      <h3 class="section-title">{@title}</h3>
      <p
        :if={@description}
        class="leading-relaxed mb-3"
        style="color: var(--color-text-primary); font-size: 1.0625rem; line-height: 1.7;"
      >
        {@description}
      </p>
      <div
        class="grid grid-cols-2 gap-4 max-[640px]:grid-cols-1"
        style="margin-bottom: 0.5rem;"
      >
        <div>
          <div
            class="text-xs font-semibold mb-1 uppercase tracking-wide"
            style="color: var(--color-text-tertiary);"
          >
            Syntax
          </div>
          <pre
            class="text-sm p-3 rounded-lg overflow-x-auto"
            style="background-color: var(--color-surface-alt, #f5f5f5); border: 1px solid var(--color-border); color: var(--color-text-primary); white-space: pre-wrap; word-wrap: break-word;"
          >{@example}</pre>
        </div>
        <div>
          <div
            class="text-xs font-semibold mb-1 uppercase tracking-wide"
            style="color: var(--color-text-tertiary);"
          >
            Result
          </div>
          <div
            class="text-sm p-3 rounded-lg prose-content"
            style="background-color: var(--color-surface); border: 1px solid var(--color-border);"
          >
            {raw(Markdown.render_html(@example))}
          </div>
        </div>
      </div>
    </section>
    """
  end
end
