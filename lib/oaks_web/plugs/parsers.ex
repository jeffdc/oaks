defmodule OaksWeb.Plugs.Parsers do
  @moduledoc """
  `Plug.Parsers`, with the private API's error shape for the requests it
  refuses (item 254e). Takes `Plug.Parsers`' options.

  `Plug.Parsers` runs in the endpoint, before the router, and raises for a
  request it can't take: a body that isn't valid JSON (400), a body over its
  length limit (413), a bad query string (400, or 414 when too long), and a
  few rarer cases. Phoenix renders those with `OaksWeb.ErrorHTML` or
  `OaksWeb.ErrorJSON`, picked by the `accept` header, so an agent would get an
  HTML page or `{"errors": {"detail": ...}}`.

  For requests under `/api/private/` this plug answers instead, the way
  `OaksWeb.Plugs.ApiToken` does: JSON `{"error": ...}` with the exception's
  status, whatever the `accept` header says. Every other request raises as
  before, so the rest of the site keeps Phoenix's error pages.

  The refusal comes before the router, so before the agent token is checked:
  a bad body is a 400 or 413 even without a valid token, as it was before.
  """

  @behaviour Plug

  import Plug.Conn

  alias Plug.Parsers

  # Plug.Conn.read_body/2's default, which the JSON parser uses when the
  # endpoint sets no :length.
  @default_length 8_000_000

  @impl Plug
  def init(opts), do: {Parsers.init(opts), Keyword.get(opts, :length, @default_length)}

  @impl Plug
  def call(conn, {parsers_opts, json_length}) do
    Parsers.call(conn, parsers_opts)
  rescue
    exception ->
      message = private_api?(conn) && message(exception, json_length)

      if message do
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(Plug.Exception.status(exception), Jason.encode!(%{error: message}))
        |> halt()
      else
        reraise exception, __STACKTRACE__
      end
  end

  defp private_api?(%Plug.Conn{path_info: ["api", "private" | _]}), do: true
  defp private_api?(_conn), do: false

  defp message(%Parsers.ParseError{exception: %Jason.DecodeError{} = error}, _json_length),
    do: "The body isn't valid JSON: #{Exception.message(error)}."

  defp message(%Parsers.ParseError{exception: error}, _json_length),
    do: "The body couldn't be parsed: #{Exception.message(error)}."

  defp message(%Parsers.RequestTooLargeError{}, json_length),
    do: "The body is too large: a JSON body may be at most #{json_length} bytes."

  defp message(%Parsers.UnsupportedMediaTypeError{media_type: media_type}, _json_length),
    do: "The body's content type (#{media_type}) isn't supported. Send JSON."

  defp message(%Parsers.BadEncodingError{message: detail}, _json_length),
    do: "The request isn't valid UTF-8: #{detail}."

  defp message(%Plug.Conn.InvalidQueryError{message: detail}, _json_length),
    do: "The query string is invalid: #{detail}."

  defp message(%Plug.BadRequestError{}, _json_length), do: "The body couldn't be read."

  defp message(%Plug.TimeoutError{}, _json_length),
    do: "The body took too long to arrive. Send it again."

  defp message(_exception, _json_length), do: nil
end
