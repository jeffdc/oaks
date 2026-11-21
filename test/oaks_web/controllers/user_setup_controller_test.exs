defmodule OaksWeb.UserSetupControllerTest do
  use OaksWeb.ConnCase

  import Oaks.AccountsFixtures

  alias Oaks.Accounts

  defp setup_secret(conn) do
    %{"secret" => encoded} = get_session(conn, :setup)
    Base.decode64!(encoded)
  end

  defp finish(conn, secret, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          "password" => valid_user_password(),
          "password_confirmation" => valid_user_password(),
          "code" => NimbleTOTP.verification_code(secret)
        },
        overrides
      )

    post(conn, ~p"/users/setup", %{"setup" => attrs})
  end

  test "a setup link leads to the form, which sets up the login and shows recovery codes", %{
    conn: conn
  } do
    {user, token} = pending_user_fixture("editor@example.com")

    conn = get(conn, ~p"/users/setup/#{token}")
    assert redirected_to(conn) == ~p"/users/setup"
    secret = setup_secret(conn)

    conn = get(conn, ~p"/users/setup")
    html = html_response(conn, 200)
    assert html =~ "editor@example.com"
    assert html =~ "<svg"
    assert html =~ Accounts.SecondFactor.display_secret(secret)

    conn = finish(conn, secret)
    html = html_response(conn, 200)
    assert html =~ "Setup complete"
    assert [_ | _] = Regex.scan(~r/[A-Z2-7]{4}-[A-Z2-7]{4}-[A-Z2-7]{4}-[A-Z2-7]{4}/, html)

    assert token = get_session(conn, :user_token)
    refute get_session(conn, :setup)
    assert {found, _} = Accounts.get_user_by_session_token(token)
    assert found.id == user.id
    assert {:ok, _} = Accounts.authenticate_by_password(user.email, valid_user_password())
  end

  test "the link works once", %{conn: conn} do
    {_user, token} = pending_user_fixture()
    conn = get(conn, ~p"/users/setup/#{token}")
    conn |> recycle() |> finish(setup_secret(conn))

    conn = build_conn() |> get(~p"/users/setup/#{token}")
    assert redirected_to(conn) == ~p"/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid or has expired"
  end

  test "a bad link, or the form without a link, goes home", %{conn: conn} do
    assert conn |> get(~p"/users/setup/nonsense") |> redirected_to() == ~p"/"
    assert build_conn() |> get(~p"/users/setup") |> redirected_to() == ~p"/"
  end

  test "errors show on the form and nothing changes", %{conn: conn} do
    {user, token} = pending_user_fixture()
    conn = get(conn, ~p"/users/setup/#{token}")
    secret = setup_secret(conn)

    html = conn |> finish(secret, %{"code" => "000000"}) |> html_response(200)
    assert html =~ "is not the current code from your authenticator app"

    html =
      conn
      |> finish(secret, %{"password" => "short", "password_confirmation" => "short"})
      |> html_response(200)

    assert html =~ "should be at least 12 character"

    refute Accounts.User.set_up?(Accounts.get_user!(user.id))
  end

  test "recovering an existing user logs out its other sessions", %{conn: conn} do
    user = user_fixture()
    other_session = Accounts.generate_user_session_token(user)
    {:ok, _, token} = Accounts.create_setup_link(user.email)

    conn = get(conn, ~p"/users/setup/#{token}")
    conn |> finish(setup_secret(conn)) |> html_response(200)

    refute Accounts.get_user_by_session_token(other_session)
  end
end
