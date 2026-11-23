defmodule OaksWeb.UserAuth do
  @moduledoc """
  Login sessions for editors (item 0249), from `phx.gen.auth`.

  A login session is a `"session"` token (`Oaks.Accounts.UserToken`): the raw
  token is in the session cookie (encrypted, HttpOnly; see `OaksWeb.Endpoint`)
  and in a remember-me cookie that outlives the browser session, and only its
  hash is in the database. A session lasts 14 days and is renewed each week it
  is used. Logging out, changing the password or completing setup again ends
  sessions and disconnects their LiveViews.

  `@current_scope` is assigned on every browser request and LiveView mount:
  an `Oaks.Accounts.Scope` for the logged-in user, or nil. Editing is allowed
  when it is set (`editor?/1`).
  """
  use OaksWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Oaks.Accounts
  alias Oaks.Accounts.{Scope, UserToken}

  @max_cookie_age_in_days UserToken.session_validity_in_days()
  @remember_me_cookie "_oaks_web_user_remember_me"
  @remember_me_options [
    encrypt: true,
    max_age: @max_cookie_age_in_days * 24 * 60 * 60,
    same_site: "Lax",
    http_only: true,
    secure: Application.compile_env(:oaks, :secure_cookies, false)
  ]

  # A session token older than this is replaced on the next request, so a
  # session in use keeps going.
  @session_reissue_age_in_days 7

  @doc "Whether `scope` (or the assigns holding it) belongs to a logged-in editor."
  def editor?(%Scope{user: %Accounts.User{}}), do: true
  def editor?(%{current_scope: scope}), do: editor?(scope)
  def editor?(_), do: false

  @doc """
  Logs the user in after both login steps, and redirects to the page they
  were sent from (`:user_return_to`) or the home page.
  """
  def log_in_user(conn, user) do
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> create_or_extend_session(%{user | authenticated_at: DateTime.utc_now(:second)})
    |> redirect(to: user_return_to || ~p"/")
  end

  @doc """
  Starts a session for `user` without redirecting: after setup or a password
  change, where the response then shows a page. It also assigns the
  user's `:current_scope`, so that page renders with the logged-in shell.
  """
  def put_new_session(conn, user) do
    user = %{user | authenticated_at: DateTime.utc_now(:second)}

    conn
    |> create_or_extend_session(user)
    |> assign(:current_scope, Scope.for_user(user))
  end

  @doc "Logs the user out: ends the session, its LiveViews and the remember-me cookie."
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      OaksWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session(nil)
    |> delete_resp_cookie(@remember_me_cookie, @remember_me_options)
    |> redirect(to: ~p"/")
  end

  @doc """
  Assigns `:current_scope` from the session token, or from the remember-me
  cookie when the browser session has ended. Renews an old session token.
  """
  def fetch_current_scope_for_user(conn, _opts) do
    with {token, conn} <- ensure_user_token(conn),
         {user, token_inserted_at} <- Accounts.get_user_by_session_token(token) do
      conn
      |> assign(:current_scope, Scope.for_user(user))
      |> maybe_reissue_user_session_token(user, token_inserted_at)
    else
      nil -> assign(conn, :current_scope, Scope.for_user(nil))
    end
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, encrypted: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        nil
      end
    end
  end

  defp maybe_reissue_user_session_token(conn, user, token_inserted_at) do
    token_age = DateTime.diff(DateTime.utc_now(:second), token_inserted_at, :day)

    if token_age >= @session_reissue_age_in_days do
      create_or_extend_session(conn, user)
    else
      conn
    end
  end

  # Issues a session token and stores it in the session and the remember-me
  # cookie. A new login (not a renewal) clears the session first, against
  # session fixation.
  defp create_or_extend_session(conn, user) do
    token = Accounts.generate_user_session_token(user)

    conn
    |> renew_session(user)
    |> put_token_in_session(token)
    |> put_resp_cookie(@remember_me_cookie, token, @remember_me_options)
  end

  # Renewing for the user already logged in keeps the session, so open tabs
  # keep their CSRF tokens.
  defp renew_session(conn, %{id: id}) when conn.assigns.current_scope.user.id == id, do: conn

  defp renew_session(conn, _user) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, user_session_topic(UserToken.hash(token)))
  end

  @doc "Disconnects the LiveViews of the given (ended) session tokens."
  def disconnect_sessions(tokens) do
    Enum.each(tokens, fn %UserToken{token: hashed} ->
      OaksWeb.Endpoint.broadcast(user_session_topic(hashed), "disconnect", %{})
    end)
  end

  defp user_session_topic(hashed_token), do: "users_sessions:#{Base.url_encode64(hashed_token)}"

  @doc """
  LiveView `on_mount` callbacks:

    * `:mount_current_scope` - assigns `:current_scope` from the session
      (nil when logged out). On every page.
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      {user, _} =
        if user_token = session["user_token"] do
          Accounts.get_user_by_session_token(user_token)
        end || {nil, nil}

      Scope.for_user(user)
    end)
  end

  @doc "Plug for routes that need a logged-in user; others go to the login page."
  def require_authenticated_user(conn, _opts) do
    if editor?(conn.assigns.current_scope) do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log-in")
      |> halt()
    end
  end

  @doc """
  Plug for sensitive pages (changing the password, recovery codes): the user
  must have logged in within the last 20 minutes, or log in again.
  """
  def require_sudo_mode(conn, _opts) do
    if Accounts.sudo_mode?(conn.assigns.current_scope.user) do
      conn
    else
      conn
      |> put_flash(:info, "Log in again to change security settings.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log-in")
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn
end
