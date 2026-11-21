defmodule OaksWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs. The 403, 404 and 500 pages are DESIGN.md pages
  (`error_page/1`). They stand alone, with their own masthead and footer
  rather than the app layout: on an unmatched route no pipeline has run, so
  there is no session, flash or current scope, and on a 500 the layout's
  data may be what failed. They run no script.

  Any other status falls back to its plain status message.
  """
  use OaksWeb, :html

  embed_templates "error_html/*"

  @doc """
  A standalone error page: the head, the stylesheet, a masthead with the
  acorn mark linking home, the title row with the status, what happened,
  the ways on and the site footer.
  """
  attr :status, :string, required: true
  attr :title, :string, required: true, doc: "the page's h1 and its head title"
  attr :description, :string, required: true, doc: "the head description"
  attr :back, :string, default: nil, doc: "where Go back goes (`back_href/1`); nil for none"
  slot :inner_block, required: true, doc: "what happened"
  slot :search, doc: "a search form under the message"
  slot :actions, required: true, doc: "the ways on; Go back follows them"

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
      <body class="flex min-h-screen flex-col">
        <header class="dark-bg bg-ink text-paper">
          <div class="mx-auto flex min-h-[60px] max-w-frame items-center px-s6 max-[760px]:px-s4">
            <a
              href={~p"/"}
              aria-label="Oak Compendium home"
              class="flex items-center gap-s2 font-frame text-[19px] font-extrabold leading-none tracking-[0.01em] text-paper no-underline"
            >
              <svg viewBox="0 0 24 24" class="size-[22px]" aria-hidden="true">
                <path d="M5 9.5C5 6 8 4 12 4s7 2 7 5.5H5Z" class="fill-ochre" />
                <path
                  d="M6.5 10.5h11c0 5-2.5 9-5.5 9.5-3-.5-5.5-4.5-5.5-9.5Z"
                  class="fill-paper"
                />
                <path d="M12 1.5v2.5" class="stroke-paper" stroke-width="1.6" />
              </svg>
              Oak Compendium
            </a>
          </div>
        </header>

        <main class="mx-auto w-full max-w-frame flex-1 px-s6 pt-s8 pb-s8 max-[760px]:px-s4 max-[760px]:pt-s6">
          <div class="max-w-[46rem]">
            <.header>
              {@title}
              <:actions>
                <.status_tag title={"HTTP status #{@status}"}>Error {@status}</.status_tag>
              </:actions>
            </.header>

            <p class="max-w-[68ch] text-pretty">{render_slot(@inner_block)}</p>

            {render_slot(@search)}

            <div class="mt-s6 flex flex-wrap gap-s3">
              {render_slot(@actions)}
              <.button :if={@back} href={@back}>Go back</.button>
            </div>
          </div>
        </main>

        <footer class="border-t border-rule">
          <div class="mx-auto flex max-w-frame flex-wrap gap-x-s5 gap-y-s1 px-s6 py-s5 font-frame text-[13px] leading-normal font-medium text-ink-3 max-[760px]:px-s4">
            <span>Jeff Clark’s text © all rights reserved</span>
            <span>Facts free to use</span>
            <span>Other sources under their own terms</span>
          </div>
        </footer>
      </body>
    </html>
    """
  end

  @doc """
  The search form on the 404: a plain GET to /search, so it works with no
  script.
  """
  def search_form(assigns) do
    ~H"""
    <form action={~p"/search"} method="get" role="search" class="mt-s6">
      <label for="error-search" class="oc-label">Search the Compendium</label>
      <div class="flex gap-s2">
        <input
          id="error-search"
          type="search"
          name="q"
          class="oc-input min-w-0 flex-1"
          placeholder="Scientific or common name"
        />
        <.button type="submit" variant="primary">Search</.button>
      </div>
    </form>
    """
  end

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
