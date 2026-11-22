defmodule OaksWeb.CoreComponents do
  @moduledoc """
  Provides core UI components for the Oak Compendium.

  Components follow DESIGN.md: ink on paper, square corners, no shadows,
  Archivo for the frame and Source Serif 4 for reading. Their CSS is in
  `assets/css/system/components.css` (classes prefixed `oc-`). The content
  components of the design system (taxonomy band, marks, section heading)
  are in `OaksWeb.DesignComponents`.

  References:

    * [Tailwind CSS](https://tailwindcss.com) - utility-first CSS framework
    * [Heroicons](https://heroicons.com) - see `icon/1` for usage
    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      component system (`<.link>`, `<.form>`, etc.)

  """
  use Phoenix.Component

  alias Phoenix.HTML.Form, as: HtmlForm
  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={["oc-flash", @kind == :error && "oc-flash-error"]}
      {@rest}
    >
      <div class="oc-flash-body">
        <p :if={@title} class="oc-flash-title">{@title}</p>
        <p>{msg}</p>
      </div>
      <button type="button" class="oc-flash-close" aria-label="Close">
        <svg viewBox="0 0 12 12" aria-hidden="true">
          <path d="M1 1l10 10M11 1 1 11" fill="none" stroke="currentColor" stroke-width="2" />
        </svg>
      </button>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  Square, with a 1.5px ink outline. `variant="primary"` is the ochre fill
  for the one call to action in a view; it inverts to ink on hover. The
  default, `variant="ghost"`, is the outline alone and inverts to ink on
  paper. `size="compact"` is the smaller size used for Compare.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global,
    include: ~w(href navigate patch method download name value disabled type form)

  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(primary ghost), default: "ghost"
  attr :size, :string, values: ~w(regular compact), default: "regular"
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    assigns =
      assign(assigns, :class, [
        "oc-btn",
        assigns.variant == "primary" && "oc-btn-primary",
        assigns.size == "compact" && "oc-btn-compact",
        assigns.class
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to HtmlForm.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        HtmlForm.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="oc-field">
      <label class="oc-check">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={@class}
          aria-invalid={@errors != [] && "true"}
          {@rest}
        />
        <span>{@label}</span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="oc-field">
      <label>
        <span :if={@label} class="oc-label">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "oc-input", @errors != [] && @error_class]}
          aria-invalid={@errors != [] && "true"}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {HtmlForm.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="oc-field">
      <label>
        <span :if={@label} class="oc-label">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[@class || "oc-input", @errors != [] && @error_class]}
          aria-invalid={@errors != [] && "true"}
          {@rest}
        >{HtmlForm.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="oc-field">
      <label>
        <span :if={@label} class="oc-label">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={HtmlForm.normalize_value(@type, @value)}
          class={[@class || "oc-input", @errors != [] && @error_class]}
          aria-invalid={@errors != [] && "true"}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="oc-error">
      <svg viewBox="0 0 14 14" aria-hidden="true">
        <circle cx="7" cy="7" r="6" fill="none" stroke="currentColor" stroke-width="1.6" />
        <path d="M7 3.6v4.2" stroke="currentColor" stroke-width="1.8" />
        <circle cx="7" cy="10.2" r="1" fill="currentColor" />
      </svg>
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a page's title row: the title on a 2px ink rule, an optional
  subtitle under it and actions at the right.

  The title is set in the serif, roman. Wrap a scientific name in `<i>`
  (the Botanical Italic Rule).

  ## Examples

      <.header>
        Sources
        <:subtitle>Every work the Compendium cites.</:subtitle>
        <:actions><.button navigate={~p"/sources/new"}>Add source</.button></:actions>
      </.header>
  """
  attr :class, :any, default: nil
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={["oc-title", @class]}>
      <div>
        <h1>{render_slot(@inner_block)}</h1>
        <p :if={@subtitle != []} class="oc-title-sub">{render_slot(@subtitle)}</p>
      </div>
      <div :if={@actions != []} class="oc-title-actions">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a ruled table: rows on hairlines under a 2px head rule, Archivo
  with lining tabular figures (the field-marks table in DESIGN.md).

  Column options:

    * `row_header` makes the column's cells row headers (`<th scope="row">`),
      as for the trait column of a field-marks table.
    * `voice` sets the column in the reading serif, for Jeff's words.

  With `stack`, each row becomes one block on phones, every cell labelled
  with its column's label; without it the table scrolls sideways.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>

      <.table id="field-marks" rows={@traits} stack>
        <:col :let={t} label="Trait" row_header>{t.name}</:col>
        <:col :let={t} label="Jeff Clark" voice>...</:col>
        <:col :let={t} label="Other sources">...</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"
  attr :stack, :boolean, default: false, doc: "one labelled block per row on phones"
  attr :class, :any, default: nil

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
    attr :row_header, :boolean
    attr :voice, :boolean
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class={["oc-table-wrap", @stack && "oc-table-stack", @class]}>
      <table class="oc-table">
        <thead>
          <tr>
            <th :for={col <- @col} scope="col">{col[:label]}</th>
            <th :if={@action != []} scope="col"><span class="sr-only">Actions</span></th>
          </tr>
        </thead>
        <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
            <%= for col <- @col do %>
              <th
                :if={col[:row_header]}
                scope="row"
                phx-click={@row_click && @row_click.(row)}
                class={@row_click && "oc-clickable"}
              >
                {render_slot(col, @row_item.(row))}
              </th>
              <td
                :if={!col[:row_header]}
                data-label={col[:label]}
                phx-click={@row_click && @row_click.(row)}
                class={[col[:voice] && "oc-voice", @row_click && "oc-clickable"]}
              >
                {render_slot(col, @row_item.(row))}
              </td>
            <% end %>
            <td :if={@action != []} class="w-0">
              <div class="oc-table-actions">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list: each term beside its value, on hairlines.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <dl class="oc-list">
      <div :for={item <- @item}>
        <dt>{item.title}</dt>
        <dd>{render_slot(item)}</dd>
      </div>
    </dl>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Renders a modal dialog: a square paper panel with a 2px ink border over
  an ink wash. Esc, a click outside and the Close button all close it.

  ## Examples

      <.modal id="confirm-modal">
        Are you sure?
        <:actions>
          <.button phx-click="confirm" variant="primary">OK</.button>
        </:actions>
      </.modal>

  JS.exec("data-show", to: "#confirm-modal") to show it.
  JS.exec("data-cancel", to: "#confirm-modal") to hide it.
  """
  attr :id, :string, required: true
  attr :on_cancel, JS, default: %JS{}

  slot :inner_block, required: true
  slot :title
  slot :actions

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@id == "confirm-modal" && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-show={show_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="hidden relative z-50"
    >
      <div id={"#{@id}-bg"} class="oc-modal-backdrop" aria-hidden="true" />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={@title != [] && "#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center p-s4">
          <.focus_wrap
            id={"#{@id}-wrap"}
            class="oc-modal-panel"
            phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
            phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
          >
            <div class="oc-modal-head">
              <h2 :if={@title != []} id={"#{@id}-title"}>{render_slot(@title)}</h2>
              <.button
                type="button"
                size="compact"
                class="ml-auto"
                phx-click={JS.exec("data-cancel", to: "##{@id}")}
              >
                Close <kbd>Esc</kbd>
              </.button>
            </div>
            <div id={"#{@id}-description"} class="oc-modal-body">
              {render_slot(@inner_block)}
            </div>
            <div :if={@actions != []} class="oc-modal-actions">
              {render_slot(@actions)}
            </div>
          </.focus_wrap>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a back navigation link, with a drawn chevron.

  ## Examples

      <.back navigate={~p"/species"}>Back to species list</.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <.link navigate={@navigate} class="oc-back">
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders a page: its content in the page frame at one of three named
  widths, with an optional full-bleed part that spans the window above it.
  Every page wraps its content in one `page/1`; a page never sets its own
  max-width or centring.

  Widths (DESIGN.md, Layout):

    * `frame` (the default): the 1400px frame with 32px gutters (16px under
      760px). Taxon pages, lists, tables, comparisons.
    * `read`: a 70ch reading measure, for articles, about and help pages.
    * `form`: a 640px measure, for forms and settings.

  `read` and `form` start at the frame's left gutter, so every page's
  content lines up with the masthead's mark at every width; they are
  narrower, never centred.

  The `:bleed` slot runs the full width of the window, edge to edge,
  above the framed content: a title page, a band. Its content sets its
  own frame inside (as the masthead does).

  The layout's `<main>` is the frame for pages that don't use this
  component yet; around a `page/1` it steps aside (`.oc-page:has(.oc-pg)`
  in shell.css).

  ## Examples

      <.page>
        <.header>Species</.header>
        ...
      </.page>

      <.page width="read">
        <.header>About</.header>
        ...
      </.page>

      <.page>
        <:bleed><.taxonomy_band>...</.taxonomy_band></:bleed>
        ...
      </.page>
  """
  attr :width, :string, values: ~w(frame read form), default: "frame"
  attr :class, :any, default: nil, doc: "classes for the framed content"
  attr :rest, :global
  slot :bleed, doc: "full-width content above the frame"
  slot :inner_block, required: true

  def page(assigns) do
    ~H"""
    <div class="oc-pg" {@rest}>
      <div :for={bleed <- @bleed} class="oc-pg-bleed">{render_slot(bleed)}</div>
      <div class={["oc-pg-body", "oc-pg-#{@width}"]}>
        <div class={["oc-pg-measure", @class]}>{render_slot(@inner_block)}</div>
      </div>
    </div>
    """
  end

  ## JS Commands

  # Notices and dialogs fade in and out; the design keeps its one authored
  # motion for the comparison, so nothing here slides or scales.

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 150,
      transition: {"transition-opacity ease-out duration-150", "opacity-0", "opacity-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 100,
      transition: {"transition-opacity ease-in duration-100", "opacity-100", "opacity-0"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 150,
      transition: {"transition-opacity ease-out duration-150", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-wrap")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-wrap")
  end

  def hide_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      time: 100,
      transition: {"transition-opacity ease-in duration-100", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-wrap")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # You can make use of gettext to translate error messages by
    # uncommenting and adjusting the following code:

    # if count = opts[:count] do
    #   Gettext.dngettext(OaksWeb.Gettext, "errors", msg, msg, count, opts)
    # else
    #   Gettext.dgettext(OaksWeb.Gettext, "errors", msg, opts)
    # end

    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
