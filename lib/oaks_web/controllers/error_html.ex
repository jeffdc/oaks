defmodule OaksWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs. The 403, 404 and 500 pages are DESIGN.md pages in
  the site shell (`error_page/1`): the layout's masthead and footer
  (`Layouts.site_header/1`, `Layouts.site_footer/1`) around a `page/1` at
  the reading measure, holding an `error_notice/1` or, for the 404,
  `not_found/1`.

  The 404 is every not-found page: an address with no route, and a
  LiveView that finds nothing at its address and raises
  `OaksWeb.NotFoundError`, whose `kind` the page reads (`not_found_kind/1`).

  `error_page/1` is its own document rather than the root and app layouts,
  and reads nothing a pipeline sets: on an unmatched route no pipeline has
  run, so there is no session, flash or current scope, and on a 500 the
  layout's data may be what failed. The masthead is shown logged out, so
  nothing on the page needs a session or a script. The pages run no
  script.

  Any other status falls back to its plain status message.
  """
  use OaksWeb, :html

  alias OaksWeb.NotFoundError

  embed_templates "error_html/*"

  @doc """
  An error page: the head and the stylesheet, the skip link, the site's
  masthead, the content in a `page/1` at the reading measure, and the site
  footer.
  """
  attr :title, :string, required: true, doc: "the head title, before \" · Oak Compendium\""
  attr :description, :string, required: true, doc: "the head description"
  attr :path, :string, default: nil, doc: "the address asked for, for the masthead's nav"
  slot :inner_block, required: true, doc: "the error notice"

  def error_page(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>{@title} · Oak Compendium</title>
        <meta name="description" content={@description} />
        <link rel="icon" href={~p"/favicon.ico"} sizes="any" />
        <link rel="apple-touch-icon" href={~p"/images/oakcompendium-180.png"} />
        <link
          rel="preload"
          href={~p"/fonts/source-serif-4/source-serif-4-latin-opsz-normal.woff2"}
          as="font"
          type="font/woff2"
          crossorigin
        />
        <link
          rel="preload"
          href={~p"/fonts/archivo/archivo-latin-wght-normal.woff2"}
          as="font"
          type="font/woff2"
          crossorigin
        />
        <link rel="stylesheet" href={~p"/assets/css/app.css"} />
      </head>
      <body class="min-h-screen flex flex-col">
        <a href="#main" class="oc-skip">Skip to content</a>

        <Layouts.site_header current_path={@path} shortcut={false} />

        <main id="main" class="oc-page" tabindex="-1">
          <.page width="read">
            {render_slot(@inner_block)}
          </.page>
        </main>

        <Layouts.site_footer />
      </body>
    </html>
    """
  end

  @doc """
  What kind of thing the 404 is about: the `kind` of the
  `OaksWeb.NotFoundError` a LiveView raised, or `:page` for an address
  with no route.
  """
  @spec not_found_kind(map()) :: NotFoundError.kind()
  def not_found_kind(%{reason: %NotFoundError{kind: kind}}), do: kind
  def not_found_kind(_assigns), do: :page

  @doc """
  The search the 404 fills in: the `query` of the `OaksWeb.NotFoundError`
  raised (the species name asked for, say), or nil.
  """
  @spec not_found_query(map()) :: String.t() | nil
  def not_found_query(%{reason: %NotFoundError{query: query}}), do: query
  def not_found_query(_assigns), do: nil

  @doc """
  The address that was asked for, for the 404's message; nil when the page
  is rendered without a request.
  """
  @spec requested_path(map()) :: String.t() | nil
  def requested_path(%{conn: %Plug.Conn{request_path: path}}), do: path
  def requested_path(_assigns), do: nil

  @doc """
  Where Go back goes: the page the visitor came from (the request's
  `Referer`), when it is a web address; nil otherwise (a bookmark, a typed
  address), and the page has no Go back. A link, not `history.back()`, so
  the page runs no script (the CSP allows none inline).
  """
  @spec back_href(map()) :: String.t() | nil
  def back_href(%{conn: %Plug.Conn{} = conn}) do
    case Plug.Conn.get_req_header(conn, "referer") do
      [referer | _] -> if web_address?(referer), do: referer
      [] -> nil
    end
  end

  def back_href(_assigns), do: nil

  @doc """
  Renders any status without a template as its plain status message, as
  the generator default does (for example "Bad Request" for 400).
  """
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end

  defp web_address?(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) ->
        true

      _ ->
        false
    end
  end
end
