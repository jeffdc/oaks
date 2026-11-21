defmodule OaksWeb.DevLoginControllerTest do
  use OaksWeb.ConnCase

  alias Oaks.Accounts
  alias OaksWeb.DevLoginController

  test "logs in as the dev user, creating it once", %{conn: conn} do
    conn = post(conn, ~p"/dev/log-in")
    assert redirected_to(conn) == ~p"/"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ DevLoginController.dev_email()

    {user, _} = Accounts.get_user_by_session_token(get_session(conn, :user_token))
    assert user.email == DevLoginController.dev_email()

    conn = build_conn() |> post(~p"/dev/log-in")
    {again, _} = Accounts.get_user_by_session_token(get_session(conn, :user_token))
    assert again.id == user.id
  end

  test "returns to the page that asked for a login, in sudo mode", %{conn: conn} do
    conn = get(conn, ~p"/users/settings/password")
    assert redirected_to(conn) == ~p"/users/log-in"

    conn = conn |> recycle() |> post(~p"/dev/log-in")
    assert redirected_to(conn) == ~p"/users/settings/password"

    conn = conn |> recycle() |> get(~p"/users/settings/password")
    assert html_response(conn, 200) =~ "Change password"
  end

  test "the login page offers it", %{conn: conn} do
    html = conn |> get(~p"/users/log-in") |> html_response(200)
    assert html =~ ~s(id="dev-login")
    assert html =~ "Log in as dev user"
  end

  test "refuses when dev routes are off", %{conn: conn} do
    Application.put_env(:oaks, :dev_routes, false)
    on_exit(fn -> Application.put_env(:oaks, :dev_routes, true) end)

    conn = post(conn, ~p"/dev/log-in")
    assert text_response(conn, 404) == "Not found"
    refute get_session(conn, :user_token)
  end

  test "production config leaves dev routes off" do
    config = Config.Reader.read!("config/config.exs", env: :prod, target: :host)
    refute get_in(config, [:oaks, :dev_routes])
  end
end
