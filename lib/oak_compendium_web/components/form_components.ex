defmodule OakCompendiumWeb.FormComponents do
  @moduledoc """
  Reusable form components for the Oak Compendium admin forms.

  Provides a tabbed markdown editor (Write/Preview) and a chip-style
  tag input, both used across taxon and article forms.
  """

  use Phoenix.Component

  import Phoenix.HTML, only: [raw: 1]
  import OakCompendiumWeb.CoreComponents, only: [icon: 1]

  alias OakCompendium.Markdown

  @doc """
  Renders a tabbed Write/Preview markdown editor.

  The Write tab shows a textarea bound to the given form field.
  The Preview tab renders the current value as HTML via `OakCompendium.Markdown`.

  ## Attributes

    * `field` — The `Phoenix.HTML.FormField` to bind the textarea to.
    * `content_tab` — Current tab, `"write"` or `"preview"`.
    * `tab_event` — The `phx-click` event name for switching tabs.
    * `placeholder` — Placeholder text for the textarea.
    * `rows` — Number of textarea rows (default 8).
    * `label` — Optional label text displayed above the editor.
    * `hint` — Optional hint text displayed below the label.
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :content_tab, :string, required: true
  attr :tab_event, :string, required: true
  attr :placeholder, :string, default: "Write content..."
  attr :rows, :integer, default: 8
  attr :label, :string, default: nil
  attr :hint, :string, default: nil

  def markdown_editor(assigns) do
    ~H"""
    <div>
      <label :if={@label} class="block text-sm font-semibold leading-6 text-zinc-800 mb-1">
        {@label}
      </label>
      <p :if={@hint} class="text-xs mb-2" style="color: var(--color-text-tertiary);">
        {@hint}
      </p>
      <div class="markdown-editor">
        <div class="markdown-editor-tabs">
          <button
            type="button"
            class={"markdown-tab #{if @content_tab == "write", do: "markdown-tab-active"}"}
            phx-click={@tab_event}
            phx-value-tab="write"
          >
            <.icon name="hero-pencil-square" class="size-3.5" /> Write
          </button>
          <button
            type="button"
            class={"markdown-tab #{if @content_tab == "preview", do: "markdown-tab-active"}"}
            phx-click={@tab_event}
            phx-value-tab="preview"
          >
            <.icon name="hero-eye" class="size-3.5" /> Preview
          </button>
        </div>
        <div :if={@content_tab == "write"}>
          <textarea
            id={@field.id}
            name={@field.name}
            rows={@rows}
            class="markdown-editor-textarea"
            placeholder={@placeholder}
            phx-debounce="300"
          >{Phoenix.HTML.Form.normalize_value("textarea", @field.value)}</textarea>
        </div>
        <div
          :if={@content_tab == "preview"}
          class="markdown-editor-preview prose-content"
        >
          {raw(preview_content(@field.value))}
        </div>
        <div class="markdown-editor-hint">
          Markdown supported &mdash;
          <a
            href="/help/markdown"
            target="_blank"
            style="color: var(--color-forest-600); text-decoration: underline;"
          >
            formatting guide
          </a>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a chip-style tag input with an Enter-to-add text field.

  Each tag is shown as a chip with a remove button. The text input uses
  the `TagInput` JS hook to capture Enter keypresses.

  ## Attributes

    * `tags` — List of current tag values (strings or maps).
    * `add_event` — The `phx-hook` data-add-event name for adding tags.
    * `remove_event` — The `phx-click` event name for removing tags.
    * `input_id` — Unique DOM ID for the text input element.
    * `placeholder` — Placeholder text for the input field.
    * `label` — Optional label text displayed above the input.
    * `hint` — Optional hint text displayed below the label.
    * `display_fn` — Optional function to format a tag for display.
      Defaults to `to_string/1`.
  """
  attr :tags, :list, required: true
  attr :add_event, :string, required: true
  attr :remove_event, :string, required: true
  attr :input_id, :string, required: true
  attr :placeholder, :string, default: "Add item..."
  attr :label, :string, default: nil
  attr :hint, :string, default: nil
  attr :display_fn, :any, default: nil

  def tag_input(assigns) do
    assigns = update(assigns, :display_fn, fn fun -> fun || (&to_string/1) end)

    ~H"""
    <div>
      <label :if={@label} class="block text-sm font-semibold leading-6 text-zinc-800 mb-1">
        {@label}
      </label>
      <p :if={@hint} class="text-xs mb-2" style="color: var(--color-text-tertiary);">
        {@hint}
      </p>
      <div class="tag-input-container">
        <div :if={@tags != []} class="tag-list">
          <span :for={{tag, idx} <- Enum.with_index(@tags)} class="tag-chip">
            <span class="tag-chip-text">{@display_fn.(tag)}</span>
            <button
              type="button"
              class="tag-chip-remove"
              phx-click={@remove_event}
              phx-value-index={idx}
              aria-label={"Remove #{@display_fn.(tag)}"}
            >
              <.icon name="hero-x-mark" class="size-3" />
            </button>
          </span>
        </div>
        <input
          type="text"
          id={@input_id}
          class="tag-input-field"
          placeholder={@placeholder}
          autocomplete="off"
          phx-hook="TagInput"
          data-add-event={@add_event}
        />
      </div>
    </div>
    """
  end

  defp preview_content(nil),
    do:
      "<p style=\"color: var(--color-text-tertiary); font-style: italic;\">Nothing to preview</p>"

  defp preview_content(""),
    do:
      "<p style=\"color: var(--color-text-tertiary); font-style: italic;\">Nothing to preview</p>"

  defp preview_content(content), do: Markdown.render_html(content)
end
