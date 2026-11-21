defmodule OaksWeb.UserSessionControllerTest do
  use OaksWeb.ConnCase

  import Oaks.AccountsFixtures

  alias Oaks.Accounts

  setup do
    %{user: user_fixture()}
  end

  defp log_in_password(conn, user, password \\ valid_user_password()) do
    post(conn, ~p"/users/log-in", %{"user" => %{"email" => user.email, "password" => password}})
  end

  describe "GET /users/log-in" do
    test "shows the login form", %{conn: conn} do
      html = conn |> get(~p"/users/log-in") |> html_response(200)
      assert html =~ "Log in"
      assert html =~ ~s(autocomplete="current-password")
    end
  end

  describe "the two login steps" do
    test "password then TOTP code logs in and returns home", %{conn: conn, user: user} do
      conn = log_in_password(conn, user)
      assert redirected_to(conn) == ~p"/users/log-in/code"
      refute get_session(conn, :user_token)

      conn = get(conn, ~p"/users/log-in/code")
      assert html_response(conn, 200) =~ "authenticator app"

      conn = post(conn, ~p"/users/log-in/code", %{"code" => next_totp_code(user)})
      assert redirected_to(conn) == ~p"/"
      assert token = get_session(conn, :user_token)
      refute get_session(conn, :pending_login)
      assert {found, _} = Accounts.get_user_by_session_token(token)
      assert found.id == user.id
    end

    test "a recovery code works in place of the TOTP code", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_password(user)
        |> post(~p"/users/log-in/code", %{"code" => hd(recovery_codes(user))})

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_token)
    end

    test "goes back to the page that asked for a login", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(%{user_return_to: "/species/new"})
        |> log_in_password(user)
        |> post(~p"/users/log-in/code", %{"code" => next_totp_code(user)})

      assert redirected_to(conn) == "/species/new"
    end

    test "a wrong password says nothing about which part was wrong", %{conn: conn, user: user} do
      html = conn |> log_in_password(user, "not the password") |> html_response(200)
      assert html =~ "Invalid email or password."

      html =
        conn
        |> post(~p"/users/log-in", %{
          "user" => %{"email" => "nobody@example.com", "password" => valid_user_password()}
        })
        |> html_response(200)

      assert html =~ "Invalid email or password."
    end

    test "a user who hasn't finished setup can't log in", %{conn: conn} do
      {pending, _token} = pending_user_fixture()
      html = conn |> log_in_password(pending, "") |> html_response(200)
      assert html =~ "Invalid email or password."
    end

    test "a wrong code doesn't log in", %{conn: conn, user: user} do
      conn = conn |> log_in_password(user) |> post(~p"/users/log-in/code", %{"code" => "000000"})
      assert html_response(conn, 200) =~ "That code didn't work."
      refute get_session(conn, :user_token)
    end

    test "the code step needs a recent password step", %{conn: conn, user: user} do
      conn = get(conn, ~p"/users/log-in/code")
      assert redirected_to(conn) == ~p"/users/log-in"

      stale = %{"user_id" => user.id, "at" => System.os_time(:second) - 301}

      conn =
        build_conn()
        |> init_test_session(%{pending_login: stale})
        |> post(~p"/users/log-in/code", %{"code" => next_totp_code(user)})

      assert redirected_to(conn) == ~p"/users/log-in"
      refute get_session(conn, :user_token)
    end
  end

  describe "rate limits" do
    setup do
      previous = Application.get_env(:oaks, :login_rate_limits)
      Application.put_env(:oaks, :login_rate_limits, per_ip: 3, per_account: 5)
      on_exit(fn -> Application.put_env(:oaks, :login_rate_limits, previous) end)
    end

    defp from_ip(conn, ip), do: put_req_header(conn, "fly-client-ip", ip)

    test "too many password attempts from one IP are refused, even with the right password", %{
      user: user
    } do
      ip = "203.0.113.#{System.unique_integer([:positive]) |> rem(250)}"

      for _ <- 1..3 do
        build_conn() |> from_ip(ip) |> log_in_password(user, "wrong password")
      end

      conn = build_conn() |> from_ip(ip) |> log_in_password(user)
      assert html_response(conn, 429) =~ "Too many login attempts"
      refute get_session(conn, :pending_login)
    end

    test "too many attempts on one account are refused from any IP", %{user: user} do
      for n <- 1..5 do
        build_conn() |> from_ip("198.51.100.#{n}") |> log_in_password(user, "wrong password")
      end

      conn = build_conn() |> from_ip("198.51.100.99") |> log_in_password(user)
      assert html_response(conn, 429) =~ "Too many login attempts"
    end

    test "too many code attempts are refused", %{conn: conn, user: user} do
      conn = conn |> from_ip("192.0.2.77") |> log_in_password(user)

      conn =
        Enum.reduce(1..3, conn, fn _, conn ->
          conn
          |> recycle()
          |> from_ip("192.0.2.77")
          |> post(~p"/users/log-in/code", %{"code" => "000000"})
        end)

      conn =
        conn
        |> recycle()
        |> from_ip("192.0.2.77")
        |> post(~p"/users/log-in/code", %{"code" => next_totp_code(user)})

      assert html_response(conn, 200) =~ "Too many attempts"
      refute get_session(conn, :user_token)
    end
  end

  describe "DELETE /users/log-out" do
    test "logs out and ends the session", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      token = get_session(conn, :user_token)
      conn = delete(conn, ~p"/users/log-out")

      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      refute Accounts.get_user_by_session_token(token)
    end
  end
end
