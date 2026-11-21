defmodule OaksWeb.UserSettingsController do
  @moduledoc """
  Security settings for a logged-in user: changing the password and
  replacing the recovery codes. Both need a login in the last 20 minutes
  (`OaksWeb.UserAuth.require_sudo_mode/2`).

  To replace the authenticator app, use a setup link
  (`Oaks.Release.setup_link/1`).
  """
  use OaksWeb, :controller

  alias Oaks.Accounts
  alias OaksWeb.UserAuth

  plug :put_layout, html: {OaksWeb.Layouts, :app}

  def edit_password(conn, _params) do
    render_password(conn, Accounts.change_user_password(user(conn)))
  end

  def update_password(conn, %{"user" => attrs}) do
    case Accounts.update_user_password(user(conn), attrs) do
      {:ok, {user, expired}} ->
        UserAuth.disconnect_sessions(expired)

        conn
        |> UserAuth.put_new_session(user)
        |> put_flash(:info, "Password changed. Other sessions were logged out.")
        |> redirect(to: ~p"/settings")

      {:error, changeset} ->
        render_password(conn, changeset)
    end
  end

  def update_password(conn, _params), do: redirect(conn, to: ~p"/users/settings/password")

  def recovery_codes(conn, _params) do
    render(conn, :recovery_codes,
      remaining: Accounts.count_unused_recovery_codes(user(conn)),
      page_title: "Recovery codes"
    )
  end

  def regenerate_recovery_codes(conn, _params) do
    codes = Accounts.regenerate_recovery_codes(user(conn))
    render(conn, :new_recovery_codes, codes: codes, page_title: "Recovery codes")
  end

  defp render_password(conn, changeset) do
    render(conn, :password,
      form: Phoenix.Component.to_form(changeset, as: "user"),
      page_title: "Change password"
    )
  end

  defp user(conn), do: conn.assigns.current_scope.user
end
