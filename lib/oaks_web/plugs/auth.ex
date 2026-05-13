defmodule OaksWeb.Plugs.Auth do
  @moduledoc """
  Authentication plug for API key validation.

  Extracts Bearer token from the Authorization header and validates it
  against the configured API key. The key is loaded in `runtime.exs`:
  prod reads `OAK_API_KEY` only; dev also accepts a `~/.oak/api_key`
  fallback for local convenience.

  Two modes:
  - `RequireAuth`: only enforces auth on write methods (POST/PUT/DELETE/PATCH).
    GET/HEAD/OPTIONS pass through freely (public reads).
  - `ForceAuth`: requires auth on ALL methods. Used for endpoints like /auth/verify.

  Designed to be replaceable with Auth0 later — the plug interface stays the same,
  only the validation logic changes.
  """

  import Plug.Conn

  @write_methods ~w(POST PUT DELETE PATCH)

  @doc """
  Plug that requires auth only for write methods.
  Read methods (GET, HEAD, OPTIONS) pass through without auth.
  """
  def require_auth(conn, _opts) do
    if conn.method in @write_methods do
      authenticate(conn)
    else
      conn
    end
  end

  @doc """
  Plug that requires auth for ALL methods.
  Use for endpoints that need auth regardless of HTTP method.
  """
  def force_auth(conn, _opts) do
    authenticate(conn)
  end

  defp authenticate(conn) do
    with {:ok, token} <- extract_bearer_token(conn),
         :ok <- validate_token(token) do
      assign(conn, :authenticated, true)
    else
      {:error, message} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: message}))
        |> halt()
    end
  end

  defp extract_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, String.trim(token)}
      [<<"bearer ", token::binary>>] -> {:ok, String.trim(token)}
      _ -> {:error, "Missing authorization header"}
    end
  end

  defp validate_token(token) do
    case api_key() do
      nil ->
        {:error, "API key not configured"}

      expected ->
        if Plug.Crypto.secure_compare(token, expected) do
          :ok
        else
          {:error, "Invalid API key"}
        end
    end
  end

  @doc """
  Returns the configured API key, checking env var then file.
  """
  def api_key do
    Application.get_env(:oaks, :api_key)
  end

  @doc """
  Loads the API key from OAK_API_KEY env var or ~/.oak/api_key file.
  Called at application startup from runtime.exs.
  """
  def load_api_key do
    case System.get_env("OAK_API_KEY") do
      nil -> load_api_key_from_file()
      "" -> load_api_key_from_file()
      key -> key
    end
  end

  defp load_api_key_from_file do
    path = Path.expand("~/.oak/api_key")

    case File.read(path) do
      {:ok, content} -> String.trim(content)
      {:error, _} -> nil
    end
  end

  @doc """
  Checks if a connection is authenticated (for optional auth checks).
  """
  def authenticated?(conn) do
    conn.assigns[:authenticated] == true
  end
end
