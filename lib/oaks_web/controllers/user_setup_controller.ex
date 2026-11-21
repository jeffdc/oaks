defmodule OaksWeb.UserSetupController do
  @moduledoc """
  Account setup and recovery from a one-time setup link
  (`Oaks.Release.setup_link/1`).

  Opening the link (`start/2`) moves its token, and a new TOTP secret, into
  the encrypted session and redirects, so the token leaves the address bar.
  The form (`edit/2`) shows the secret as a QR code; submitting it
  (`update/2`) sets the password, enrolls the secret, ends every other
  session, logs the user in and shows the recovery codes once.
  """
  use OaksWeb, :controller

  alias Oaks.Accounts
  alias Oaks.Accounts.SecondFactor
  alias OaksWeb.UserAuth

  plug :put_layout, html: {OaksWeb.Layouts, :app}

  def start(conn, %{"token" => token}) do
    case Accounts.get_user_by_setup_token(token) do
      nil ->
        invalid_link(conn)

      _user ->
        secret = SecondFactor.new_totp_secret()

        conn
        |> put_session(:setup, %{"token" => token, "secret" => Base.encode64(secret)})
        |> redirect(to: ~p"/users/setup")
    end
  end

  def edit(conn, _params) do
    with_setup(conn, fn user, _token, secret ->
      render_form(conn, user, secret, Accounts.change_setup())
    end)
  end

  def update(conn, %{"setup" => attrs}) do
    with_setup(conn, fn user, token, secret ->
      case Accounts.complete_setup(user, token, secret, attrs) do
        {:ok, %{user: user, recovery_codes: codes, expired_tokens: expired}} ->
          UserAuth.disconnect_sessions(expired)

          conn
          |> delete_session(:setup)
          |> UserAuth.put_new_session(user)
          |> render(:done, codes: codes, page_title: "Setup complete")

        {:error, %Ecto.Changeset{} = changeset} ->
          render_form(conn, user, secret, changeset)

        {:error, :invalid_token} ->
          invalid_link(conn)
      end
    end)
  end

  def update(conn, _params), do: redirect(conn, to: ~p"/users/setup")

  defp with_setup(conn, fun) do
    with %{"token" => token, "secret" => encoded} <- get_session(conn, :setup),
         {:ok, secret} <- Base.decode64(encoded),
         %Accounts.User{} = user <- Accounts.get_user_by_setup_token(token) do
      fun.(user, token, secret)
    else
      _ -> invalid_link(conn)
    end
  end

  defp render_form(conn, user, secret, changeset) do
    uri = SecondFactor.otpauth_uri(secret, user.email)

    render(conn, :edit,
      user: user,
      form: Phoenix.Component.to_form(changeset, as: "setup"),
      # Generated here from the URI: only shapes, no text from the user.
      qr_svg: {:safe, SecondFactor.qr_svg(uri)},
      display_secret: SecondFactor.display_secret(secret),
      page_title: "Set up login"
    )
  end

  defp invalid_link(conn) do
    conn
    |> delete_session(:setup)
    |> put_flash(:error, "This setup link is invalid or has expired. Ask for a new one.")
    |> redirect(to: ~p"/")
  end
end
