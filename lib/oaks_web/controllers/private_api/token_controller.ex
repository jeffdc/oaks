defmodule OaksWeb.PrivateAPI.TokenController do
  @moduledoc """
  The private API's whoami: what the agent token in the request is, so an
  agent can check its token before relying on it. Needs no scope.

  The private API serves agents with tokens (`OaksWeb.Plugs.ApiToken`) and is
  not in the public OpenAPI spec.
  """
  use OaksWeb, :controller

  def show(conn, _params) do
    token = conn.assigns.current_api_token

    json(conn, %{
      name: token.name,
      scopes: token.scopes,
      expires_at: token.expires_at,
      created_at: token.inserted_at
    })
  end
end
