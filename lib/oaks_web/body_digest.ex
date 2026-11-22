defmodule OaksWeb.BodyDigest do
  @moduledoc """
  A `Plug.Parsers` body reader that hashes the raw body of an import request
  (`POST /api/private/v1/import`) as it is read, and puts the SHA-256 in
  `conn.private[:body_sha256]`. The import's dry-run token is bound to that
  hash: the exact bytes, before JSON decoding (decision 62ae).

  Other requests are read as usual, without hashing.
  """

  @import_path ["api", "private", "v1", "import"]

  @doc false
  @spec read_body(Plug.Conn.t(), keyword()) ::
          {:ok, binary(), Plug.Conn.t()} | {:more, binary(), Plug.Conn.t()} | {:error, term()}
  def read_body(%Plug.Conn{path_info: @import_path} = conn, opts) do
    hash = conn.private[:body_sha256_state] || :crypto.hash_init(:sha256)

    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        digest = hash |> :crypto.hash_update(body) |> :crypto.hash_final()
        {:ok, body, Plug.Conn.put_private(conn, :body_sha256, digest)}

      # A reader called again for the rest of the body carries on the hash.
      {:more, body, conn} ->
        state = :crypto.hash_update(hash, body)
        {:more, body, Plug.Conn.put_private(conn, :body_sha256_state, state)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def read_body(conn, opts), do: Plug.Conn.read_body(conn, opts)
end
