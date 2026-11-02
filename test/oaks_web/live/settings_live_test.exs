defmodule OaksWeb.SettingsLiveTest do
  @moduledoc """
  Tests for SettingsLive. Authentication status must come from the server-side
  auth hook, never from what the browser reports.
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

  defp authenticated_conn(conn) do
    put_connect_params(conn, %{"api_key" => Application.get_env(:oaks, :api_key)})
  end

  test "shows authenticated when the connect param key is valid", %{conn: conn} do
    {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/settings")

    assert has_element?(view, ".settings-status-authenticated")
    assert has_element?(view, "#session-time-remaining")
  end

  test "shows not authenticated without a key", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    assert has_element?(view, ".settings-status-not-authenticated")
  end

  test "a wrong key is not authenticated", %{conn: conn} do
    {:ok, view, _html} =
      conn |> put_connect_params(%{"api_key" => "wrong"}) |> live(~p"/settings")

    assert has_element?(view, ".settings-status-not-authenticated")
  end

  test "client save reports show a message without changing auth status", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    html = render_hook(view, "save_result", %{"status" => "saved"})

    assert html =~ "API key verified and saved."
    assert has_element?(view, ".settings-status-not-authenticated")
  end

  test "ignores unknown client statuses", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    assert render_hook(view, "save_result", %{"status" => "bogus"})
    assert render_hook(view, "verify_result", %{"status" => "ok"})
    assert has_element?(view, ".settings-status-not-authenticated")
  end
end
