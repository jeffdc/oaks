defmodule OaksWeb.SourceFormLiveTest do
  @moduledoc """
  Tests for SourceFormLive (create/edit sources).
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.AccountsFixtures

  alias Oaks.Sources

  defp authenticated_conn(conn) do
    log_in_user(conn, user_fixture())
  end

  describe "unauthenticated" do
    test "new redirects immediately", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/sources"}}} = live(conn, ~p"/sources/new")
    end

    test "edit redirects immediately", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/sources"}}} = live(conn, ~p"/sources/1/edit")
    end

    test "the static render redirects with a flash", %{conn: conn} do
      conn = get(conn, ~p"/sources/new")

      assert redirected_to(conn) == ~p"/sources"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must be authenticated"
    end
  end

  describe "new (authenticated)" do
    test "creates a source", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/sources/new")

      {:error, {:live_redirect, %{to: "/sources/" <> id}}} =
        view
        |> form("#source-form", source: %{name: "Field Notes", source_type: "Book"})
        |> render_submit()

      assert Sources.get_source(String.to_integer(id)).name == "Field Notes"
    end

    test "shows validation errors for a missing name", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/sources/new")

      html =
        view
        |> form("#source-form", source: %{name: "", source_type: "Book"})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "edit (authenticated)" do
    test "updates the source", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/sources/2/edit")

      assert {:error, {:live_redirect, %{to: "/sources/2"}}} =
               view
               |> form("#source-form", source: %{author: "Updated Author"})
               |> render_submit()

      assert Sources.get_source(2).author == "Updated Author"
    end

    test "redirects for unknown or invalid ids", %{conn: conn} do
      for path <- [~p"/sources/9999/edit", "/sources/abc/edit"] do
        assert {:error, {:live_redirect, %{to: "/sources"}}} =
                 conn |> authenticated_conn() |> live(path)
      end
    end
  end
end
