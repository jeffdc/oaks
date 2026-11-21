defmodule OaksWeb.DevLoginController do
  @moduledoc """
  One-click login for local development (item 4ab9): logs in as
  `dev@localhost`, creating that user if needed, with no password or code.

  Its route exists only when `config :oaks, dev_routes: true` (dev and test),
  checked when the router is compiled, so a production release has no route
  to it. The action checks the setting again in case the module is ever
  routed by mistake.

  The session is a normal one (`OaksWeb.UserAuth.log_in_user/2`), so editing
  gates and sudo mode behave as in production. Sudo mode lapses after 20
  minutes as usual; the login page's dev button logs in again in one click.
  """
  use OaksWeb, :controller

  alias Oaks.Accounts
  alias OaksWeb.UserAuth

  @dev_email "dev@localhost"

  @doc "The dev user's email."
  def dev_email, do: @dev_email

  def create(conn, _params) do
    if Application.get_env(:oaks, :dev_routes) do
      {:ok, user} = Accounts.get_or_create_user_by_email(@dev_email)

      conn
      |> put_flash(:info, "Logged in as the dev user (#{@dev_email}).")
      |> UserAuth.log_in_user(user)
    else
      conn |> put_status(:not_found) |> text("Not found")
    end
  end
end
