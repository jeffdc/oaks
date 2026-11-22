defmodule OaksWeb.FormComponents do
  @moduledoc """
  Reusable form components for the Oak Compendium admin forms.

  Provides a tabbed markdown editor (Write/Preview) and a tag input,
  both used across taxon and article forms. They are styled as the
  DESIGN.md input field (`oc-md`, `oc-tags` in
  assets/css/system/components.css).
  """

  use Phoenix.Component

  import Phoenix.HTML, only: [raw: 1]
  import OaksWeb.CoreComponents, only: [icon: 1]

  alias Oaks.Markdown

  @doc """
  Renders a tabbed Write/Preview markdown editor.

  The Write tab shows a textarea bound to the given form field.
  The Preview tab renders the current value as HTML via `Oaks.Markdown`.

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
    <div class="oc-field">
      <label :if={@label} for={@field.id} class="oc-label">{@label}</label>
      <p :if={@hint} class="oc-hint">{@hint}</p>
      <div class="oc-md">
        <div class="oc-md-tabs">
          <button
            type="button"
            class="oc-md-tab"
            aria-pressed={to_string(@content_tab == "write")}
            phx-click={@tab_event}
            phx-value-tab="write"
          >
            Write
          </button>
          <button
            type="button"
            class="oc-md-tab"
            aria-pressed={to_string(@content_tab == "preview")}
            phx-click={@tab_event}
            phx-value-tab="preview"
          >
            Preview
          </button>
        </div>
        <%!-- Keep the textarea in the DOM while previewing so the form still submits it. --%>
        <div class={@content_tab != "write" && "hidden"}>
          <textarea
            id={@field.id}
            name={@field.name}
            rows={@rows}
            class="oc-md-text"
            placeholder={@placeholder}
            phx-debounce="300"
          >{Phoenix.HTML.Form.normalize_value("textarea", @field.value)}</textarea>
        </div>
        <div :if={@content_tab == "preview"} class="oc-md-preview prose-content">
          {raw(preview_content(@field.value))}
        </div>
        <div class="oc-md-foot">
          Markdown supported: <a href="/help/markdown" target="_blank">formatting guide</a>
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
    <div class="oc-field">
      <label :if={@label} for={@input_id} class="oc-label">{@label}</label>
      <p :if={@hint} class="oc-hint">{@hint}</p>
      <div class="oc-tags">
        <span :for={{tag, idx} <- Enum.with_index(@tags)} class="oc-tag">
          <span class="oc-tag-text">{@display_fn.(tag)}</span>
          <button
            type="button"
            class="oc-tag-remove"
            phx-click={@remove_event}
            phx-value-index={idx}
            aria-label={"Remove #{@display_fn.(tag)}"}
          >
            <.icon name="hero-x-mark" class="size-3" />
          </button>
        </span>
        <input
          type="text"
          id={@input_id}
          class="oc-tags-input"
          placeholder={@placeholder}
          autocomplete="off"
          phx-hook="TagInput"
          data-add-event={@add_event}
        />
      </div>
    </div>
    """
  end

  defp preview_content(nil), do: ~s(<p class="oc-empty">Nothing to preview</p>)
  defp preview_content(""), do: ~s(<p class="oc-empty">Nothing to preview</p>)
  defp preview_content(content), do: Markdown.render_html(content)
end
