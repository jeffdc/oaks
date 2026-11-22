defmodule OaksWeb.SettingsLiveTest do
  @moduledoc """
  Tests for SettingsLive: the account links when logged in, and the
  redirect to the login page when logged out.
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "logged in" do
    setup :register_and_log_in_user

    test "shows the account email and account links", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, ~p"/settings")

      assert html =~ "Logged in as"
      assert html =~ user.email
      assert has_element?(view, ~s(a[href="/users/settings/password"]), "Change password")
      assert has_element?(view, ~s(a[href="/users/settings/recovery-codes"]), "Recovery codes")

      assert has_element?(
               view,
               ~s(a[href="/users/log-out"][data-method="delete"]),
               "Log out"
             )

      refute has_element?(view, ~s(a[href="/users/log-in"]))
    end
  end

  describe "logged out" do
    test "redirects to the login page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in", flash: flash}}} =
               live(conn, ~p"/settings")

      assert flash["error"] == "You must log in to access this page."
    end
  end
end
