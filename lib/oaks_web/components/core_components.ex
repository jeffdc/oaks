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
  paper. `variant="danger"` is the ink plate for the one action in a
  confirmation dialog that deletes something or can't be undone: paper on
  ink, easing to ink-2 on hover. Its label names what goes ("Delete
  species", never "OK" or "Yes"). `size="compact"` is the smaller size
  used for Compare.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button phx-click="confirm_delete" variant="danger">Delete species</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global,
    include: ~w(href navigate patch method download name value disabled type form)

  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(primary ghost danger), default: "ghost"
  attr :size, :string, values: ~w(regular compact), default: "regular"
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    assigns =
      assign(assigns, :class, [
        "oc-btn",
        assigns.variant == "primary" && "oc-btn-primary",
        assigns.variant == "danger" && "oc-btn-danger",
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

  ## Faces (DESIGN.md, Form Fields: the Field Face Rule)

  A field takes the face of what goes in it. A prose field, where
  someone writes sentences to be read (a description, notes, a source's
  account of a trait), is `type="textarea"` and set in the serif, as the
  text will read. Every other field (names, authors, years, URLs,
  choices, codes) is one line in Archivo. Pick the type by that rule:
  never a one-line input for prose, never a textarea for a short value.
  Long Markdown text uses `FormComponents.markdown_editor/1`, also serif.

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

  ## A button beside the field

  A text field's `:action` is its one button, on the field's line at the
  right, such as Load beside an observation's address.

  ```heex
  <.input name="observation" label="iNaturalist observation" value={@query}>
    <:action><.button type="submit">Load</.button></:action>
  </.input>
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

  slot :action,
    doc: "a text field's one button, on its line at the right (Load beside an observation field)"

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

  # A text field with its button on the same line: the label is its own
  # element, so the button isn't part of it.
  def input(%{action: [_ | _]} = assigns) do
    assigns = assign_new(assigns, :id, fn -> nil end)

    ~H"""
    <div class="oc-field">
      <label :if={@label} for={@id} class="oc-label">{@label}</label>
      <div class="oc-input-row">
        <input
          type={@type}
          name={@name}
          id={@id}
          value={HtmlForm.normalize_value(@type, @value)}
          class={[@class || "oc-input", @errors != [] && @error_class]}
          aria-invalid={@errors != [] && "true"}
          {@rest}
        />
        {render_slot(@action)}
      </div>
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
  Renders a page's title row, the one title row every page uses: the
  title on a 2px ink rule, its meta on the title's line, a subtitle under
  them, and the page's edit menu at the right.

  The row's one rule (DESIGN.md, Components, Title Row; item 7838):

    * `:meta` sits on the title's line, after the title (and a species'
      authority), on its baseline, in Archivo 600 14px ink-2 with lining
      figures, no separators, in this order: the kind word (or the record
      a form edits, `<.sci_name size="meta">`), counts, a byline and date,
      stamps (`<.status_tag>`, `<.iucn_status>`), links. It wraps under
      the title only when the line has no room for it. Each entry is one
      item, so `:if` works per entry.
    * `:subtitle` is a sentence describing the page, under the title line.
    * `:actions` holds the page's `<.edit_menu>`, editor-only, at the
      right on the title's first baseline. It never wraps: the title and
      meta take the rest of the row, and with no actions (logged out) the
      whole row.

  The title is set in the serif, roman; a scientific name in it is
  `<.sci_name size="display">`. A back link goes before the row in the
  page's `:head` (`<.back>`), which spaces it from the title.

  ## Examples

      <.header>
        Sources
        <:subtitle>Every work the Compendium cites.</:subtitle>
      </.header>

      <.header>
        <.sci_name name="Quercus shumardii" author="Buckley" size="display" />
        <:meta>Species</:meta>
        <:meta><.iucn_status code="LC" /></:meta>
        <:actions :if={@editor}>
          <.edit_menu id="species-edit-menu">
            <:item navigate={~p"/species/shumardii/edit"}>Edit species</:item>
          </.edit_menu>
        </:actions>
      </.header>
  """
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  slot :meta,
    doc: "one item on the title's line, after the title: a kind word, count, byline or stamp"

  slot :subtitle, doc: "a sentence describing the page, under the title line"
  slot :actions, doc: "the page's `<.edit_menu>`, at the right on the title's first baseline"

  def header(assigns) do
    ~H"""
    <header class={["oc-title", @class]} {@rest}>
      <div class="oc-title-text">
        <div class="oc-title-line">
          <h1>{render_slot(@inner_block)}</h1>
          <div :if={@meta != []} class="oc-title-meta">
            <span :for={meta <- @meta}>{render_slot(meta)}</span>
          </div>
        </div>
        <p :if={@subtitle != []} class="oc-title-sub">{render_slot(@subtitle)}</p>
      </div>
      <div :if={@actions != []} class="oc-title-actions">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders an editor's actions for a page as one small disclosure, "Edit",
  in the title row's `:actions` (item 7838). Only an editor sees it, so the
  page gates it (`<:actions :if={@editor}>`), and a logged-out title row
  keeps no space for it.

  Built on `<details data-menu>`, as the masthead's Editor menu: the
  summary is a compact button that Enter or Space opens, and app.js closes
  it on Escape (focus back on the summary), on a click outside and when an
  item is chosen. The list opens under the trigger, on its right edge.

  Each `:item` is a link (`navigate`, or `href` with `method`) or, with
  `click`, a button sending that event (`values` become `phx-value-*`). A
  destructive item opens the page's confirmation `<.modal>`; the menu's
  trigger keeps its place on the focus stack, so closing the dialog puts
  focus back on it.

  `quiet` is the same menu for an editor's actions on one part of a page
  (a source's data, a row in a list; item c13c): the trigger is small
  Archivo text with the chevron, no outline, no taller than a line of
  14px text, so it never shapes the reader's layout. Give it an
  `aria_label` that names its object ("Edit Agrifoliae") when several sit
  on one page.

  ## Examples

      <.edit_menu id="species-edit-menu">
        <:item navigate={~p"/species/shumardii/edit"} id="edit-species-btn">Edit species</:item>
        <:item click="show_merge_picker">Make synonym of…</:item>
        <:item click="open_manage_photos" note="1 failed">Manage photos…</:item>
        <:item click="request_delete_taxon" values={%{id: 12}}>Delete taxon</:item>
      </.edit_menu>

      <.edit_menu id="taxon-12-menu" quiet aria_label="Edit Agrifoliae">
        <:item navigate={~p"/taxonomy/12/edit"}>Edit subsection</:item>
        <:item click="request_delete_taxon" values={%{id: 12}}>Delete subsection</:item>
      </.edit_menu>
  """
  attr :id, :string, required: true
  attr :label, :string, default: "Edit", doc: "the trigger's label"
  attr :quiet, :boolean, default: false, doc: "a small text trigger, for a part of a page"
  attr :aria_label, :string, default: nil, doc: "the trigger's accessible name, naming its object"

  slot :item, required: true, doc: "one action: a link or an event" do
    attr :id, :string
    attr :navigate, :string, doc: "a LiveView path to go to"
    attr :href, :string, doc: "a plain link, with `method` for a delete link"
    attr :method, :string
    attr :click, :string, doc: "the event the item's button sends"
    attr :values, :map, doc: "phx-value-* params sent with `click`"
    attr :note, :string, doc: "a short note after the label, such as \"1 failed\""
  end

  def edit_menu(assigns) do
    ~H"""
    <details
      id={@id}
      class={["oc-edit-menu", @quiet && "oc-edit-menu-quiet"]}
      data-menu
      phx-mounted={JS.ignore_attributes(["open"])}
    >
      <summary
        class={if @quiet, do: "oc-edit-menu-trigger", else: "oc-btn oc-btn-compact"}
        aria-label={@aria_label}
      >
        {@label}
      </summary>
      <ul class="oc-edit-menu-list">
        <li :for={item <- @item}>
          <.link :if={item[:navigate]} id={item[:id]} navigate={item[:navigate]}>
            {render_slot(item)}<.menu_note note={item[:note]} />
          </.link>
          <.link
            :if={!item[:navigate] && item[:href]}
            id={item[:id]}
            href={item[:href]}
            method={item[:method] || "get"}
          >
            {render_slot(item)}<.menu_note note={item[:note]} />
          </.link>
          <button
            :if={!item[:navigate] && !item[:href]}
            type="button"
            id={item[:id]}
            phx-click={JS.push_focus(to: "##{@id} > summary") |> JS.push(item[:click])}
            {phx_values(item[:values])}
          >
            {render_slot(item)}<.menu_note note={item[:note]} />
          </button>
        </li>
      </ul>
    </details>
    """
  end

  attr :note, :string, default: nil

  defp menu_note(assigns) do
    ~H"""
    <span :if={@note} class="oc-edit-menu-note">{@note}</span>
    """
  end

  defp phx_values(nil), do: []
  defp phx_values(values), do: Enum.map(values, fn {k, v} -> {"phx-value-#{k}", v} end)

  @doc """
  Renders a ruled table: rows on hairlines under a 2px head rule, Archivo
  with lining tabular figures (the field-marks table in DESIGN.md).

  Column options:

    * `row_header` makes the column's cells row headers (`<th scope="row">`),
      as for the trait column of a field-marks table.
    * `voice` sets the column in the reading serif, for Oak Compendium's own text.

  With `stack`, each row becomes one block on phones, every cell labelled
  with its column's label; without it the table scrolls sideways.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>

      <.table id="field-marks" rows={@traits} stack>
        <:col :let={t} label="Trait" row_header>{t.name}</:col>
        <:col :let={t} label="Oak Compendium" voice>...</:col>
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
  Renders a dialog, the one every page uses for confirmations, pickers and
  "can't" notices (item c13c): a square paper panel with a 2px ink border
  over an ink wash, centred, at most 34rem wide.

  Its parts, top to bottom:

    * `:title`: what the dialog is about, in sentence case, in the serif
      on a 2px rule ("Delete species", "Can't delete source").
    * the body (the inner block): what will happen, in the reading
      serif. A scientific name in it is `<.sci_name weight="regular">`.
    * `:note`: each a consequence, in Archivo 600 14px ink-2 under the
      body ("This can't be undone."); `<strong>` in a note is 700 ink.
    * the actions row: the dialog's one close control first, a ghost
      button labelled `cancel` ("Cancel", or "Close" when the dialog only
      tells), then the `:actions` slot: the one action, a
      `<.button variant="danger">` that names what goes, or primary for
      an action that destroys nothing.

  Esc, a click outside the panel and the close button all close it, and
  each runs `on_cancel`. Focus goes into the panel when it opens and is
  held there; when it closes, focus returns to what pushed it (an
  `<.edit_menu>` item pushes its trigger). A long body scrolls inside the
  panel, so the title and actions stay in view.

  A page shows it from its own state: render it `:if` the state is set,
  with `show`, and an `on_cancel` that clears the state. Removing it from
  the page (the server answer to a cancel or a confirm) fades it out.

  ## Examples

      <.modal
        :if={@show_delete_confirm}
        id="delete-confirm-modal"
        show
        on_cancel={JS.push("cancel_delete")}
      >
        <:title>Delete species</:title>
        Delete <.sci_name name="Quercus shumardii" weight="regular" />?
        <:note>This can't be undone.</:note>
        <:actions>
          <.button variant="danger" phx-click="confirm_delete">Delete species</.button>
        </:actions>
      </.modal>

  A dialog shown from the browser alone (the gallery's) is left out with
  no `show`: `show_modal("id")` shows it and
  `JS.exec("data-cancel", to: "#id")` hides it.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false, doc: "open when it mounts (a dialog the page shows)"
  attr :on_cancel, JS, default: %JS{}, doc: "run on Esc, a click outside and the close button"
  attr :cancel, :string, default: "Cancel", doc: "the close button's label"

  slot :title, required: true, doc: "what the dialog is about, in sentence case"
  slot :inner_block, required: true, doc: "the body: what will happen"
  slot :note, doc: "a consequence, in the frame face, under the body"
  slot :actions, doc: "the dialog's one action, after the close button"

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-show={show_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="hidden relative z-50"
    >
      <div id={"#{@id}-bg"} class="oc-modal-backdrop" aria-hidden="true" />
      <div
        class="oc-modal-frame"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
      >
        <.focus_wrap
          id={"#{@id}-wrap"}
          class="oc-modal-panel"
          phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
          phx-key="escape"
          phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
        >
          <h2 id={"#{@id}-title"} class="oc-modal-title">{render_slot(@title)}</h2>
          <div id={"#{@id}-description"} class="oc-modal-body">
            {render_slot(@inner_block)}
            <div :for={note <- @note} class="oc-modal-note">{render_slot(note)}</div>
          </div>
          <div class="oc-modal-actions">
            <.button
              type="button"
              id={"#{@id}-cancel"}
              phx-click={JS.exec("data-cancel", to: "##{@id}")}
            >
              {@cancel}
            </.button>
            {render_slot(@actions)}
          </div>
        </.focus_wrap>
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
  Renders a page: its content in a centred column or the full page frame,
  with an optional full-bleed part that spans the window above it. Every
  page wraps its content in one `page/1`; a page never sets its own
  max-width or centring.

  Which width a page takes (DESIGN.md, Layout; decision a0ac):

    * `column` (the default): one centred 960px column. Every
      single-column page: lists, taxon pages, search, a record such as a
      source, analytics.
    * `read`: a narrower centred column at the 720px reading measure.
      Prose: articles, about, privacy and help pages.
    * `form`: a narrower centred column at the 760px form measure. Forms
      that create or edit something, and the account pages (log in,
      setup, settings).
    * `frame`: the 1400px frame, only for pages that set columns side by
      side: the source comparison, a merge.

  All four have 32px gutters (16px under 760px). The `:head` slot (a back
  link and the title row) spans the page's width, so its 2px rule runs
  the column, or for `read` and `form` their measure: the title and the
  content under it share one centred measure. (The home page is set
  centred in the frame, as a title page and contents.)

  The `:bleed` slot runs the full width of the window, edge to edge,
  above the page's content: a title page, a band. Its content sets its
  own frame inside (as the masthead does).

  The layout's `<main>` is the frame for any page that doesn't use this
  component; around a `page/1` it steps aside
  (`.oc-page:has(.oc-pg)` in shell.css).

  ## Examples

      <.page>
        <.header>Species</.header>
        ...
      </.page>

      <.page width="read">
        <:head><.header>About</.header></:head>
        ...
      </.page>

      <.page width="form">
        <:head>
          <.back navigate={~p"/sources"}>Back to sources</.back>
          <.header>Edit source</.header>
        </:head>
        <.form ...>...</.form>
      </.page>

      <.page>
        <:bleed><.taxonomy_band>...</.taxonomy_band></:bleed>
        ...
      </.page>

      <.page width="frame">
        <.header>Compare sources</.header>
        ...
      </.page>
  """
  attr :width, :string, values: ~w(column read form frame), default: "column"
  attr :class, :any, default: nil, doc: "classes for the content under the head"
  attr :rest, :global
  slot :bleed, doc: "full-width content above the page"
  slot :head, doc: "the title row, and a back link above it, across the page's width"
  slot :inner_block, required: true

  def page(assigns) do
    ~H"""
    <div class="oc-pg" {@rest}>
      <div :for={bleed <- @bleed} class="oc-pg-bleed">{render_slot(bleed)}</div>
      <div class={["oc-pg-body", "oc-pg-#{@width}"]}>
        <div :for={head <- @head} class="oc-pg-head">{render_slot(head)}</div>
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
    # The panel is a flex column (.oc-modal-panel): shown as a block, its
    # body wouldn't scroll and a tall dialog's actions would fall off the
    # window.
    |> JS.show(
      to: "##{id}-wrap",
      display: "flex",
      time: 150,
      transition: {"transition-opacity ease-out duration-150", "opacity-0", "opacity-100"}
    )
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
