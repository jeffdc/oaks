defmodule OakCompendiumWeb.SourceDetailLiveTest do
  @moduledoc """
  Tests for the SourceDetailLive LiveView.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OakCompendiumWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "GET /sources/:id" do
    test "renders source detail page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources/2")
      assert html =~ "Oaks of the World"
    end

    test "shows source metadata", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources/2")
      assert html =~ "website"
      assert html =~ "https://oaksoftheworld.fr"
    end

    test "shows description", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources/2")
      assert html =~ "Rich descriptive data"
    end

    test "shows source URL as clickable link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources/2")
      assert html =~ ~s(href="https://oaksoftheworld.fr")
      assert html =~ "target=\"_blank\""
    end

    test "shows species count in coverage section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources/2")
      assert html =~ "Coverage"
      assert html =~ "Species"
    end

    test "lists associated species", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources/2")
      assert html =~ "Species with Data from This Source"
      assert html =~ "alba"
      assert html =~ "rubra"
    end

    test "species link to detail pages", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources/2")
      assert html =~ ~s(href="/species/alba")
      assert html =~ ~s(href="/species/rubra")
    end

    test "source 3 shows species with data", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources/3")
      assert html =~ "Oak Compendium"
      assert html =~ "Species with Data from This Source"
      assert html =~ "stellata"
    end
  end

  describe "not found" do
    test "shows not found for unknown source ID", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources/999")
      assert html =~ "Source Not Found"
      assert html =~ "Back to Sources"
    end

    test "shows not found for invalid ID", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources/abc")
      assert html =~ "Source Not Found"
    end

    test "not found page has link back to sources list", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sources/999")
      assert html =~ ~s(href="/sources")
    end
  end
end
