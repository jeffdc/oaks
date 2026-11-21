defmodule OaksWeb.UserSessionController do
  @moduledoc """
  Logging in and out. Login takes two steps:

    1. email and password (`create/2`); on success the user is remembered
       in the session as a pending login for five minutes;
    2. a TOTP or recovery code (`verify_code/2`), which starts the session.

  Both steps are rate limited (`OaksWeb.LoginLimiter`), and failures say
  nothing about which part was wrong.
  """
  use OaksWeb, :controller

  alias Oaks.Accounts
  alias OaksWeb.{LoginLimiter, UserAuth}

  plug :put_layout, html: {OaksWeb.Layouts, :app}

  @pending_login_seconds 300

  def new(conn, _params) do
    render(conn, :new, form: login_form(%{}), error: nil, page_title: "Log in")
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    with :ok <- LoginLimiter.hit(conn, :password, email),
         {:ok, user} <- Accounts.authenticate_by_password(email, password) do
      conn
      |> put_session(:pending_login, %{"user_id" => user.id, "at" => now()})
      |> redirect(to: ~p"/users/log-in/code")
    else
      :deny -> render_login_error(conn, email, :too_many)
      :error -> render_login_error(conn, email, :invalid)
    end
  end

  def create(conn, _params), do: render_login_error(conn, "", :invalid)

  def code(conn, _params) do
    case pending_user(conn) do
      nil -> restart_login(conn)
      _user -> render(conn, :code, error: nil, page_title: "Log in")
    end
  end

  def verify_code(conn, %{"code" => code}) when is_binary(code) do
    case pending_user(conn) do
      nil ->
        restart_login(conn)

      user ->
        with :ok <- LoginLimiter.hit(conn, :code, "user:#{user.id}"),
             :ok <- Accounts.verify_second_factor(user, code) do
          conn
          |> delete_session(:pending_login)
          |> UserAuth.log_in_user(user)
        else
          :deny -> render(conn, :code, error: :too_many, page_title: "Log in")
          :error -> render(conn, :code, error: :invalid, page_title: "Log in")
        end
    end
  end

  def verify_code(conn, _params), do: restart_login(conn)

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out.")
    |> UserAuth.log_out_user()
  end

  defp render_login_error(conn, email, error) do
    conn
    |> put_status(if error == :too_many, do: 429, else: 200)
    |> render(:new, form: login_form(%{"email" => email}), error: error, page_title: "Log in")
  end

  defp login_form(params), do: Phoenix.Component.to_form(params, as: "user")

  defp pending_user(conn) do
    with %{"user_id" => id, "at" => at} <- get_session(conn, :pending_login),
         true <- now() - at <= @pending_login_seconds,
         %Accounts.User{} = user <- Accounts.get_user(id) do
      user
    else
      _ -> nil
    end
  end

  defp restart_login(conn) do
    conn
    |> delete_session(:pending_login)
    |> put_flash(:error, "Your login timed out. Start again.")
    |> redirect(to: ~p"/users/log-in")
  end

  defp now, do: System.os_time(:second)
end
