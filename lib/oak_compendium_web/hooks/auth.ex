defmodule OakCompendiumWeb.Hooks.Auth do
  @moduledoc """
  LiveView on_mount hook for authentication.

  Reads the API key from LiveSocket connect_params (set by the client
  from localStorage) and validates it against the configured server key.
  Assigns `:authenticated` (boolean) to the socket for UI gating.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias OakCompendiumWeb.Plugs.Auth, as: AuthPlug

  def on_mount(:default, _params, _session, socket) do
    authenticated =
      case get_connect_params(socket) do
        %{"api_key" => key} when is_binary(key) and key != "" ->
          validate_key(key)

        _ ->
          false
      end

    {:cont, assign(socket, :authenticated, authenticated)}
  end

  defp validate_key(key) do
    case AuthPlug.api_key() do
      nil -> false
      expected -> Plug.Crypto.secure_compare(key, expected)
    end
  end
end
