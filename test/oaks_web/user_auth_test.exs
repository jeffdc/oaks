defmodule OaksWeb.UserAuthTest do
  use OaksWeb.ConnCase

  import Oaks.AccountsFixtures

  alias Oaks.Accounts
  alias Oaks.Accounts.{Scope, UserToken}
  alias OaksWeb.UserAuth
  alias Phoenix.LiveView

  @remember_me_cookie "_oaks_web_user_remember_me"
  @remember_me_cookie_max_age 60 * 60 * 24 * 14

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, OaksWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})
      |> assign(:current_scope, nil)

    %{user: user_fixture(), conn: conn}
  end

  defp topic(token), do: "users_sessions:#{Base.url_encode64(UserToken.hash(token))}"

  describe "log_in_user/2" do
    test "stores a session token, writes the remember-me cookie and redirects home", %{
      conn: conn,
      user: user
    } do
      conn = UserAuth.log_in_user(conn, user)

      assert token = get_session(conn, :user_token)
      assert get_session(conn, :live_socket_id) == topic(token)
      assert redirected_to(conn) == ~p"/"
      assert {found, _} = Accounts.get_user_by_session_token(token)
      assert found.id == user.id

      assert %{value: signed, max_age: @remember_me_cookie_max_age, http_only: true} =
               conn.resp_cookies[@remember_me_cookie]

      refute signed == token
    end

    test "records the login time for sudo mode", %{conn: conn, user: user} do
      token = conn |> UserAuth.log_in_user(user) |> get_session(:user_token)
      {found, _} = Accounts.get_user_by_session_token(token)
      assert Accounts.sudo_mode?(found)
    end

    test "clears everything previously stored in the session", %{conn: conn, user: user} do
      conn = conn |> put_session(:to_be_removed, "value") |> UserAuth.log_in_user(user)
      refute get_session(conn, :to_be_removed)
    end

    test "keeps the session when the same user logs in again", %{conn: conn, user: user} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_user(user))
        |> put_session(:to_be_removed, "value")
        |> UserAuth.log_in_user(user)

      assert get_session(conn, :to_be_removed)
    end

    test "redirects to the stored return-to path and clears it", %{conn: conn, user: user} do
      conn = conn |> put_session(:user_return_to, "/hello") |> UserAuth.log_in_user(user)
      assert redirected_to(conn) == "/hello"
      refute get_session(conn, :user_return_to)
    end
  end

  describe "log_out_user/1" do
    test "erases the session and the cookie and ends the token", %{conn: conn, user: user} do
      token = Accounts.generate_user_session_token(user)

      conn =
        conn
        |> put_session(:user_token, token)
        |> put_req_cookie(@remember_me_cookie, token)
        |> fetch_cookies()
        |> UserAuth.log_out_user()

      refute get_session(conn, :user_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Accounts.get_user_by_session_token(token)
    end

    test "disconnects the session's LiveViews", %{conn: conn} do
      live_socket_id = "users_sessions:abcdef-token"
      OaksWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> UserAuth.log_out_user()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works when already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> UserAuth.log_out_user()
      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_scope_for_user/2" do
    test "finds the user from the session", %{conn: conn, user: user} do
      token = Accounts.generate_user_session_token(user)

      conn =
        conn |> put_session(:user_token, token) |> UserAuth.fetch_current_scope_for_user([])

      assert conn.assigns.current_scope.user.id == user.id
      assert UserAuth.editor?(conn.assigns)
    end

    test "finds the user from the remember-me cookie when the session is gone", %{
      conn: conn,
      user: user
    } do
      logged_in = UserAuth.log_in_user(conn, user)
      cookie = logged_in.resp_cookies[@remember_me_cookie]
      %{value: encrypted} = cookie

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, encrypted)
        |> UserAuth.fetch_current_scope_for_user([])

      assert conn.assigns.current_scope.user.id == user.id
      assert get_session(conn, :user_token) == get_session(logged_in, :user_token)
    end

    test "ignores a forged remember-me cookie", %{conn: conn, user: user} do
      token = Accounts.generate_user_session_token(user)

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, Base.encode64(token))
        |> UserAuth.fetch_current_scope_for_user([])

      refute conn.assigns.current_scope
    end

    test "assigns nil with no token or an expired one", %{conn: conn, user: user} do
      refute UserAuth.fetch_current_scope_for_user(conn, []).assigns.current_scope

      token = Accounts.generate_user_session_token(user)
      offset_user_token(token, -15, :day)

      conn =
        conn |> put_session(:user_token, token) |> UserAuth.fetch_current_scope_for_user([])

      refute conn.assigns.current_scope
      refute UserAuth.editor?(conn.assigns)
    end

    test "replaces a token older than a week, keeping the login time", %{conn: conn, user: user} do
      token = Accounts.generate_user_session_token(user)
      offset_user_token(token, -8, :day)
      {old_user, _} = Accounts.get_user_by_session_token(token)

      conn =
        conn
        |> put_session(:user_token, token)
        |> UserAuth.fetch_current_scope_for_user([])

      new_token = get_session(conn, :user_token)
      refute new_token == token
      assert {new_user, _} = Accounts.get_user_by_session_token(new_token)
      assert new_user.authenticated_at == old_user.authenticated_at
      assert conn.resp_cookies[@remember_me_cookie]
    end
  end

  describe "on_mount :mount_current_scope" do
    setup %{conn: conn} do
      %{conn: UserAuth.fetch_current_scope_for_user(conn, [])}
    end

    test "assigns the scope from a valid session token", %{conn: conn, user: user} do
      token = Accounts.generate_user_session_token(user)
      session = conn |> put_session(:user_token, token) |> get_session()

      {:cont, socket} =
        UserAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert socket.assigns.current_scope.user.id == user.id
    end

    test "assigns nil without a valid token", %{conn: conn} do
      session = conn |> put_session(:user_token, "bad") |> get_session()

      {:cont, socket} =
        UserAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert socket.assigns.current_scope == nil

      {:cont, socket} = UserAuth.on_mount(:mount_current_scope, %{}, %{}, %LiveView.Socket{})
      assert socket.assigns.current_scope == nil
    end
  end

  describe "require_authenticated_user/2" do
    setup %{conn: conn} do
      %{conn: UserAuth.fetch_current_scope_for_user(conn, [])}
    end

    test "sends a logged-out visitor to the login page, remembering a GET path", %{conn: conn} do
      conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/users/log-in"
      assert get_session(conn, :user_return_to) == "/foo?bar=baz"
    end

    test "doesn't remember a non-GET path", %{conn: conn} do
      conn =
        %{conn | path_info: ["foo"], method: "POST"}
        |> fetch_flash()
        |> UserAuth.require_authenticated_user([])

      assert conn.halted
      refute get_session(conn, :user_return_to)
    end

    test "lets a logged-in user through", %{conn: conn, user: user} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_user(user))
        |> UserAuth.require_authenticated_user([])

      refute conn.halted
    end
  end

  describe "require_sudo_mode/2" do
    test "lets a recent login through", %{conn: conn, user: user} do
      user = %{user | authenticated_at: DateTime.utc_now(:second)}

      conn =
        conn |> assign(:current_scope, Scope.for_user(user)) |> UserAuth.require_sudo_mode([])

      refute conn.halted
    end

    test "sends an older login back to the login page", %{conn: conn, user: user} do
      user = %{user | authenticated_at: DateTime.add(DateTime.utc_now(:second), -30, :minute)}

      conn =
        %{conn | path_info: ["users", "settings", "password"]}
        |> fetch_flash()
        |> assign(:current_scope, Scope.for_user(user))
        |> UserAuth.require_sudo_mode([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/users/log-in"
      assert get_session(conn, :user_return_to) == "/users/settings/password"
    end
  end

  describe "disconnect_sessions/1" do
    test "broadcasts a disconnect for each ended token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      row = Oaks.Repo.get_by!(UserToken, token: UserToken.hash(token))
      OaksWeb.Endpoint.subscribe(topic(token))

      UserAuth.disconnect_sessions([row])

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect"}
    end
  end
end
