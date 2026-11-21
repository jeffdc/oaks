defmodule OaksWeb.UserSettingsControllerTest do
  use OaksWeb.ConnCase

  import Oaks.AccountsFixtures

  alias Oaks.Accounts

  describe "logged out" do
    test "every page sends you to log in", %{conn: conn} do
      for {method, path} <- [
            {:get, ~p"/users/settings/password"},
            {:put, ~p"/users/settings/password"},
            {:get, ~p"/users/settings/recovery-codes"},
            {:post, ~p"/users/settings/recovery-codes"}
          ] do
        assert conn |> dispatch(@endpoint, method, path, %{}) |> redirected_to() ==
                 ~p"/users/log-in"
      end
    end
  end

  describe "an older login" do
    setup :register_and_log_in_user
    @tag token_authenticated_at: DateTime.add(DateTime.utc_now(:second), -30, :minute)
    test "has to log in again first", %{conn: conn} do
      conn = get(conn, ~p"/users/settings/password")
      assert redirected_to(conn) == ~p"/users/log-in"
      assert get_session(conn, :user_return_to) == "/users/settings/password"
    end
  end

  describe "a recent login" do
    setup :register_and_log_in_user

    test "changes the password, ends other sessions and stays logged in", %{
      conn: conn,
      user: user
    } do
      other_session = Accounts.generate_user_session_token(user)
      new = "a brand new long password"

      assert conn |> get(~p"/users/settings/password") |> html_response(200) =~ "Change password"

      conn =
        put(conn, ~p"/users/settings/password", %{
          "user" => %{"password" => new, "password_confirmation" => new}
        })

      assert redirected_to(conn) == ~p"/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Password changed"
      assert {found, _} = Accounts.get_user_by_session_token(get_session(conn, :user_token))
      assert found.id == user.id
      refute Accounts.get_user_by_session_token(other_session)
      assert {:ok, _} = Accounts.authenticate_by_password(user.email, new)
    end

    test "shows password errors", %{conn: conn} do
      html =
        conn
        |> put(~p"/users/settings/password", %{
          "user" => %{"password" => "short", "password_confirmation" => "other"}
        })
        |> html_response(200)

      assert html =~ "should be at least 12 character"
      assert html =~ "does not match password"
    end

    test "shows the unused code count and makes new codes", %{conn: conn, user: user} do
      html = conn |> get(~p"/users/settings/recovery-codes") |> html_response(200)
      assert html =~ ~s(<strong id="recovery-codes-remaining">10</strong>)

      html = conn |> post(~p"/users/settings/recovery-codes") |> html_response(200)
      assert html =~ "Your old recovery codes no longer work."
      assert Accounts.verify_second_factor(user, hd(recovery_codes(user))) == :error
    end
  end
end
