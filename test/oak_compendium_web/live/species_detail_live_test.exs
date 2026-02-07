defmodule OakCompendiumWeb.SpeciesDetailLiveTest do
  @moduledoc """
  Tests for the SpeciesDetailLive LiveView.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OakCompendiumWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "GET /species/:name" do
    test "renders species detail page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species/alba")
      assert html =~ "alba"
      assert html =~ "L. 1753"
    end

    test "shows species header with name and author", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species/alba")
      assert html =~ "Quercus"
      assert html =~ "alba"
      assert html =~ "L. 1753"
    end

    test "shows Species badge for non-hybrids", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species/alba")
      assert html =~ "Species"
    end

    test "shows conservation status badge", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species/alba")
      assert html =~ "LC"
      assert html =~ "Least Concern"
    end

    test "shows taxonomy breadcrumb", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species/alba")
      assert html =~ "subg."
      assert html =~ "sect."
    end

    test "shows source data from preferred source", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species/alba")
      assert html =~ "Oaks of the World"
      assert html =~ "Eastern North America"
      assert html =~ "Reaches 25 m high"
      assert html =~ "8-20 cm long, obovate"
    end

    test "shows common names from preferred source", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species/alba")
      assert html =~ "white oak"
      assert html =~ "eastern white oak"
    end

    test "shows source tabs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species/alba")
      assert html =~ "Oaks of the World"
      assert html =~ "iNaturalist"
    end

    test "preferred source has star indicator", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species/alba")
      # ★ character for preferred source
      assert html =~ "\u2605"
    end

    test "shows relationship sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species/alba")
      assert html =~ "Known Hybrids"
      assert html =~ "bebbiana"
      assert html =~ "Closely Related"
      assert html =~ "stellata"
      assert html =~ "Synonyms"
      assert html =~ "alba var. repanda"
      assert html =~ "Subspecies"
      assert html =~ "alba var. latiloba"
    end

    test "relationship links point to detail pages", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species/alba")
      # URL-encoded × in href
      assert html =~ ~s(href="/species/%C3%97bebbiana")
      assert html =~ ~s(href="/species/stellata")
    end
  end

  describe "hybrid species" do
    test "shows Hybrid badge", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/species/%C3%97bebbiana")
      assert html =~ "Hybrid"
    end

    test "shows hybrid multiply symbol", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/species/%C3%97bebbiana")
      # &times; renders as Unicode ×
      assert html =~ "\u00D7"
    end

    test "shows parent species section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/species/%C3%97bebbiana")
      assert html =~ "Parent Species"
      assert html =~ "alba"
      assert html =~ "macrocarpa"
    end

    test "parent links point to detail pages", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/species/%C3%97bebbiana")
      assert html =~ ~s(href="/species/alba")
      assert html =~ ~s(href="/species/macrocarpa")
    end
  end

  describe "source tab switching" do
    test "clicking a source tab shows that source's data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/species/alba")

      # Initially shows preferred source (Oaks of the World, source_id=2)
      assert render(view) =~ "Data from Oaks of the World"

      # Click iNaturalist tab (source_id=1)
      view
      |> element("button[phx-value-id='1']")
      |> render_click()

      html = render(view)
      assert html =~ "Data from iNaturalist"
    end
  end

  describe "not found" do
    test "shows not found for unknown species", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species/nonexistent")
      assert html =~ "Species Not Found"
      assert html =~ "Back to Species List"
    end

    test "not found page has link back to list", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species/nonexistent")
      assert html =~ ~s(href="/list")
    end
  end

  describe "synonym redirect" do
    test "redirects to canonical species when synonym is found", %{conn: conn} do
      # "alba var. repanda" is a synonym for alba in test seeds
      # push_navigate causes a live_redirect which we must follow
      assert {:error, {:live_redirect, %{to: "/species/alba"}}} =
               live(conn, "/species/alba%20var.%20repanda")
    end
  end

  describe "species without sources" do
    test "shows no source data message", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species/velutina")
      assert html =~ "No source data available"
    end
  end
end
