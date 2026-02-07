defmodule OakCompendiumWeb.AuthController do
  use OakCompendiumWeb, :controller

  @doc """
  Verifies the provided API key is valid.
  Protected by ForceAuth — requires auth on all methods.
  """
  def verify(conn, _params) do
    json(conn, %{authenticated: true})
  end
end
