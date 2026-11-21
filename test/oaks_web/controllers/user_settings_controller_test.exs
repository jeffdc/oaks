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
            {:post, ~p"/users/settings/recovery-codes"},
            {:get, ~p"/users/settings/api-tokens"},
            {:post, ~p"/users/settings/api-tokens"},
            {:delete, ~p"/users/settings/api-tokens/1"}
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

  describe "agent tokens" do
    setup :register_and_log_in_user

    test "makes a token and shows it once", %{conn: conn, user: user} do
      html = conn |> get(~p"/users/settings/api-tokens") |> html_response(200)
      assert html =~ "No tokens yet."
      assert html =~ "materials:read"

      html =
        conn
        |> post(~p"/users/settings/api-tokens", %{
          "api_token" => %{
            "name" => "importer",
            "scopes" => ["", "packages:submit"],
            "lifetime_in_days" => "30"
          }
        })
        |> html_response(200)

      [raw] = Regex.run(~r/oak_[A-Za-z0-9_-]{43}/, html)
      assert html =~ "won't be shown again"
      assert html =~ ~s(data-copy="#{raw}")
      assert {:ok, token} = Accounts.fetch_api_token(raw)
      assert token.user.id == user.id
      assert token.scopes == ["packages:submit"]

      html = conn |> get(~p"/users/settings/api-tokens") |> html_response(200)
      assert html =~ ~s(id="api-token-#{token.id}")
      assert html =~ "importer"
      refute html =~ raw
    end

    test "shows form errors", %{conn: conn} do
      html =
        conn
        |> post(~p"/users/settings/api-tokens", %{
          "api_token" => %{"name" => "", "scopes" => [""], "lifetime_in_days" => "90"}
        })
        |> html_response(200)

      assert html =~ "can&#39;t be blank"
      assert html =~ "pick at least one"
      refute html =~ ~r/oak_[A-Za-z0-9_-]{43}/
    end

    test "shows expired tokens as expired", %{conn: conn, user: user} do
      {_raw, token} = api_token_fixture(user)
      set_api_token_expiry(token, -1, :day)

      html = conn |> get(~p"/users/settings/api-tokens") |> html_response(200)
      assert html =~ "expired"
    end

    test "revokes a token", %{conn: conn, user: user} do
      {raw, token} = api_token_fixture(user)

      conn = delete(conn, ~p"/users/settings/api-tokens/#{token.id}")
      assert redirected_to(conn) == ~p"/users/settings/api-tokens"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Token revoked"
      assert Accounts.fetch_api_token(raw) == :error
    end

    test "can't revoke another user's token", %{conn: conn} do
      {raw, token} = api_token_fixture(user_fixture())

      for id <- [token.id, "nope"] do
        conn = delete(conn, ~p"/users/settings/api-tokens/#{id}")
        assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "already revoked"
      end

      assert {:ok, _} = Accounts.fetch_api_token(raw)
    end
  end
end
