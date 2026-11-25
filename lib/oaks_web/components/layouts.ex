defmodule OaksWeb.Layouts do
  @moduledoc """
  Layouts and the site shell for the Oak Compendium.

  Two layouts are provided:

  * `:root` — the HTML skeleton (head, body, scripts). Set via
    `put_root_layout` in the router pipeline.
  * `:app`  — the site shell, from `app.html.heex`: the skip link, the
    masthead (`site_header/1`), the page frame (`<main>`), the site footer
    (`site_footer/1`) and the flash group. LiveViews get it from
    `use OaksWeb, :live_view`; the login and settings controllers set it
    with `put_layout`.

  The shell follows DESIGN.md (Layout, Navigation) and the masthead and
  footer of `design/prototype/oc.css`. Its CSS is
  `assets/css/system/shell.css`.
  """
  use OaksWeb, :html

  embed_templates "layouts/*"

  # The main nav, in DESIGN.md order. Identify joins it when the ID tool
  # has a page (item 3248).
  @nav [
    {"Species", "/species"},
    {"Taxonomy", "/taxonomy"},
    {"Sources", "/sources"},
    {"About", "/about"}
  ]

  # Pages that belong to the editor menu rather than a public nav item.
  @editor_paths ["/species/new", "/settings", "/users/settings"]

  @doc """
  The ink masthead: the acorn mark, the main nav, the editor marks when
  someone is logged in, and the search field.

  Both attrs are read tolerantly: a page without a logged-in user or a
  known path still gets the full masthead, with no item marked current.
  `shortcut={false}` leaves out the search's "/" key hint, for a page that
  loads no script (the error pages), where the key does nothing.
  """
  attr :current_scope, :any, default: nil, doc: "the `Oaks.Accounts.Scope`, or nil"
  attr :current_path, :string, default: nil, doc: "the request path, for the current item"
  attr :shortcut, :boolean, default: true, doc: "show the \"/\" key hint (app.js binds it)"

  def site_header(assigns) do
    assigns = assign(assigns, :nav, @nav)

    ~H"""
    <header class="oc-mast" id="site-header">
      <div class="oc-mast-in">
        <.link navigate={~p"/"} class="oc-mark">
          <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
            <path class="oc-mark-cap" d="M5 9.5C5 6 8 4 12 4s7 2 7 5.5H5Z" />
            <path class="oc-mark-nut" d="M6.5 10.5h11c0 5-2.5 9-5.5 9.5-3-.5-5.5-4.5-5.5-9.5Z" />
            <path class="oc-mark-stem" d="M12 1.5v2.5" />
          </svg>
          Oak Compendium
        </.link>

        <nav class="oc-nav" aria-label="Main">
          <.link
            :for={{label, path} <- @nav}
            navigate={path}
            aria-current={nav_current(@current_path, path)}
          >
            <span>{label}</span>
          </.link>
        </nav>

        <div :if={@current_scope} class="oc-mast-editor">
          <details
            id="editor-menu"
            class="oc-mast-menu"
            data-menu
            phx-mounted={JS.ignore_attributes(["open"])}
          >
            <summary aria-current={editor_current(@current_path)}><span>Editor</span></summary>
            <ul class="oc-mast-menu-list">
              <li><.link navigate={~p"/species/new"}>Add species</.link></li>
              <li><.link navigate={~p"/settings"}>Settings</.link></li>
              <li><.link href={~p"/users/log-out"} method="delete">Log out</.link></li>
            </ul>
          </details>
          <span class="oc-who" title={"Logged in as #{@current_scope.user.email}"}>
            {who(@current_scope)}
          </span>
        </div>

        <form action={~p"/search"} method="get" role="search" class="oc-search">
          <label for="header-search" class="sr-only">Search</label>
          <input
            type="search"
            id="header-search"
            name="q"
            placeholder="Name, common name or synonym"
            autocomplete="off"
            spellcheck="false"
            aria-keyshortcuts={@shortcut && "/"}
          />
          <kbd :if={@shortcut} aria-hidden="true">/</kbd>
        </form>
      </div>
    </header>
    """
  end

  @doc """
  The site footer: the licensing line (Oak Compendium's prose, the facts, other
  sources) and the pages that have no place in the main nav.
  """
  attr :current_scope, :any, default: nil, doc: "the `Oaks.Accounts.Scope`, or nil"

  def site_footer(assigns) do
    ~H"""
    <footer class="oc-footer" id="site-footer">
      <div class="oc-footer-in">
        <p class="oc-footer-terms">
          <span>Oak Compendium’s prose is © all rights reserved</span>
          <span>All facts are free to use</span>
          <span>Other sources are under their own terms</span>
        </p>
        <nav class="oc-footer-nav" aria-label="More">
          <.link navigate={~p"/articles"}>Articles</.link>
          <.link navigate={~p"/privacy"}>Privacy</.link>
          <.link navigate={~p"/analytics"}>Analytics</.link>
          <a href="/api/v1/docs">API</a>
          <.link :if={!@current_scope} href={~p"/users/log-in"}>Log in</.link>
        </nav>
      </div>
    </footer>
    """
  end

  @doc """
  The value of `aria-current` for a main nav item: `"page"` on the item's
  own page, `"true"` anywhere else in its part of the site, `nil` outside
  it. Species covers the species pages, but not the editor's Add species.
  """
  @spec nav_current(String.t() | nil, String.t()) :: String.t() | nil
  def nav_current(nil, _link_path), do: nil
  def nav_current(path, path), do: "page"

  def nav_current(current_path, link_path) do
    if String.starts_with?(current_path, link_path <> "/") and not editor_path?(current_path),
      do: "true"
  end

  @doc false
  @spec editor_current(String.t() | nil) :: String.t() | nil
  def editor_current(current_path) do
    if current_path && editor_path?(current_path), do: "true"
  end

  defp editor_path?(path) do
    Enum.any?(@editor_paths, &(path == &1 or String.starts_with?(path, &1 <> "/")))
  end

  # The editor's name in the masthead. Users have only an email, so it is
  # the email's local part, capitalized ("jeff@..." reads "Jeff").
  defp who(%{user: %{email: email}}) when is_binary(email) do
    email |> String.split("@") |> hd() |> String.capitalize()
  end

  defp who(_scope), do: "Editor"

  # The path for the shell: LiveViews set @current_path (OaksWeb.Hooks.ActiveNav);
  # controller pages have only the conn.
  defp shell_path(%{current_path: path}) when is_binary(path), do: path
  defp shell_path(%{conn: %Plug.Conn{request_path: path}}), do: path
  defp shell_path(_assigns), do: nil

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
