defmodule OaksWeb.Plugs.SecurityHeaders do
  @moduledoc """
  The site's browser security headers: Phoenix's secure defaults
  (`Phoenix.Controller.put_secure_browser_headers/2`) with the site's
  content security policy.

  Two uses:

    * `plug OaksWeb.Plugs.SecurityHeaders` in the router's `:browser`
      pipeline puts them on every page.
    * `plug OaksWeb.Plugs.SecurityHeaders, :errors` in the endpoint, before
      anything that can raise, puts them on every error response (status 400
      and up) as it is sent (item 8be6). An error page from an unmatched
      route, or from a request refused before the router, never passes
      through a pipeline, so it would go out without them. Error responses
      only, so the API docs' Swagger UI, which loads from a CDN, keeps
      working.
  """

  @behaviour Plug

  import Phoenix.Controller, only: [put_secure_browser_headers: 2]
  import Plug.Conn

  # Scripts only from our own origin, so injected markup can't run code even if
  # it slips past markdown sanitizing. Inline styles are allowed because the
  # templates use style attributes; images may come from any HTTPS host
  # (iNaturalist photos in articles).
  @content_security_policy [
    "default-src 'self'",
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: https:",
    "font-src 'self' data:",
    "connect-src 'self'",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'self'"
  ]

  @headers %{"content-security-policy" => Enum.join(@content_security_policy, "; ")}

  @impl Plug
  def init(:errors), do: :errors
  def init(_opts), do: :always

  @impl Plug
  def call(conn, :always), do: put_headers(conn)

  def call(conn, :errors) do
    register_before_send(conn, fn
      %Plug.Conn{status: status} = conn when status >= 400 -> put_headers(conn)
      conn -> conn
    end)
  end

  defp put_headers(conn), do: put_secure_browser_headers(conn, @headers)
end
