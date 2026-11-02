defmodule OaksWeb.InputHardeningTest do
  @moduledoc """
  Malformed query params and event values must not crash requests or
  LiveViews, and pagination params must stay within bounds.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

  defp authenticated_conn(conn) do
    put_connect_params(conn, %{"api_key" => Application.get_env(:oaks, :api_key)})
  end

  describe "API pagination bounds" do
    test "species search clamps a negative limit", %{conn: conn} do
      conn = get(conn, "/api/v1/species/search?q=a&limit=-1")
      assert %{"limit" => 50} = json_response(conn, 200)
    end

    test "species search caps the limit at 500", %{conn: conn} do
      conn = get(conn, "/api/v1/species/search?q=a&limit=10000")
      assert %{"limit" => 500} = json_response(conn, 200)
    end

    test "species index reports the clamped limit and offset", %{conn: conn} do
      conn = get(conn, "/api/v1/species?limit=-3&offset=-5")
      assert %{"limit" => 50, "offset" => 0} = json_response(conn, 200)
    end
  end

  describe "API list-valued params" do
    test "species search rejects a list q", %{conn: conn} do
      conn = get(conn, "/api/v1/species/search?q[]=alba")
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "unified search rejects a list q", %{conn: conn} do
      conn = get(conn, "/api/v1/search?q[]=alba")
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "unified search ignores a list limit", %{conn: conn} do
      conn = get(conn, "/api/v1/search?q=alba&limit[]=1")
      assert %{"species" => [_ | _]} = json_response(conn, 200)
    end

    test "species index ignores list-valued filters", %{conn: conn} do
      %{"count" => total} = conn |> get("/api/v1/species") |> json_response(200)

      conn = get(conn, "/api/v1/species?limit[]=1&offset[]=2&hybrid[]=1&subgenus[]=Quercus")
      assert %{"count" => ^total, "limit" => 50, "offset" => 0} = json_response(conn, 200)
    end

    test "articles index ignores a list tag", %{conn: conn} do
      conn = get(conn, "/api/v1/articles?tag[]=leaves")
      assert is_list(json_response(conn, 200))
    end
  end

  describe "LiveView list-valued params" do
    test "species list renders with list params", %{conn: conn} do
      assert {:ok, _view, _html} = live(conn, "/list?q[]=alba&subgenus[]=Quercus")
    end

    test "search page renders with a list q", %{conn: conn} do
      assert {:ok, _view, _html} = live(conn, "/search?q[]=alba")
    end

    test "articles page renders with a list tag", %{conn: conn} do
      assert {:ok, _view, _html} = live(conn, "/articles?tag[]=leaves")
    end
  end

  describe "LiveView event and URL values" do
    test "species detail ignores a non-numeric source tab id", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/species/alba")
      assert render_click(view, "select_source", %{"id" => "abc"}) =~ "alba"
    end

    test "species compare ignores a non-numeric source id", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/species/alba/compare")
      assert render_click(view, "toggle_source", %{"id" => "abc"})
    end

    test "taxon edit with a non-numeric id redirects instead of crashing", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/taxonomy"}}} =
               conn |> authenticated_conn() |> live("/taxonomy/abc/edit")
    end

    test "species source edit with a non-numeric source id redirects", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/species/alba"}}} =
               conn |> authenticated_conn() |> live("/species/alba/sources/abc/edit")
    end

    test "merge ignores unknown fields", %{conn: conn} do
      {:ok, view, _html} =
        conn |> authenticated_conn() |> live("/species/rubra/merge/alba")

      assert render_click(view, "copy_field", %{"field" => "not_a_field"})
      assert render_click(view, "update_field", %{"field" => "scientific_name", "value" => "x"})
      assert render_click(view, "toggle_source", %{"source-id" => "abc"})
    end
  end
end
