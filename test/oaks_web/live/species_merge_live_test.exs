defmodule OaksWeb.SpeciesMergeLiveTest do
  @moduledoc """
  Tests for the SpeciesMergeLive LiveView.
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.AccountsFixtures
  import Oaks.SourcesFixtures
  import Oaks.SpeciesFixtures

  alias Oaks.Species

  setup do
    alba = species_fixture(author: "L. 1753")
    stellata = species_fixture(author: "Wangenh. 1787")
    species_source_fixture(alba, source_fixture())
    species_source_fixture(stellata, source_fixture())

    %{
      alba: alba.scientific_name,
      stellata: stellata.scientific_name,
      rubra: species_fixture().scientific_name,
      velutina: species_fixture().scientific_name
    }
  end

  defp authenticated_conn(conn) do
    log_in_user(conn, user_fixture())
  end

  describe "unauthenticated access" do
    test "redirects to species detail page", %{conn: conn, stellata: stellata, alba: alba} do
      path = "/species/#{stellata}"

      assert {:error, {:live_redirect, %{to: ^path}}} =
               live(conn, ~p"/species/#{stellata}/merge/#{alba}")
    end
  end

  describe "authenticated merge page" do
    test "renders merge page with both species", %{conn: conn, stellata: stellata, alba: alba} do
      {:ok, _view, html} =
        conn |> authenticated_conn() |> live(~p"/species/#{stellata}/merge/#{alba}")

      assert html =~ stellata
      assert html =~ alba
      assert html =~ "Synonym"
      assert html =~ "Target"
    end

    test "shows field comparison rows", %{conn: conn, stellata: stellata, alba: alba} do
      {:ok, _view, html} =
        conn |> authenticated_conn() |> live(~p"/species/#{stellata}/merge/#{alba}")

      assert html =~ "Author"
      assert html =~ "Conservation Status"
      assert html =~ "Subgenus"
    end

    test "marks a field that differs with the differs mark", %{
      conn: conn,
      stellata: stellata,
      alba: alba
    } do
      {:ok, view, _html} =
        conn |> authenticated_conn() |> live(~p"/species/#{stellata}/merge/#{alba}")

      # The two authors differ, so the Author row carries the mark.
      assert has_element?(view, ".merge-row-differs [data-standing='differs']", "differs")
    end

    test "sets the synonyms to add as italic names", %{conn: conn, stellata: stellata, alba: alba} do
      {:ok, view, _html} =
        conn |> authenticated_conn() |> live(~p"/species/#{stellata}/merge/#{alba}")

      assert has_element?(view, ".merge-synonyms .oc-sci .oc-sci-g", "Q.")
      assert has_element?(view, ".merge-synonyms .oc-sci .oc-sci-e", stellata)
    end

    test "shows source transfer section", %{conn: conn, stellata: stellata, alba: alba} do
      {:ok, _view, html} =
        conn |> authenticated_conn() |> live(~p"/species/#{stellata}/merge/#{alba}")

      assert html =~ "Source Data"
    end

    test "shows error for same species", %{conn: conn, alba: alba} do
      {:ok, _view, html} =
        conn |> authenticated_conn() |> live(~p"/species/#{alba}/merge/#{alba}")

      assert html =~ "cannot be merged with itself"
    end

    test "a nonexistent species is a 404 with the not-found page", %{conn: conn, alba: alba} do
      conn = authenticated_conn(conn)

      {404, _headers, html} =
        assert_error_sent 404, fn -> get(conn, ~p"/species/nonexistent/merge/#{alba}") end

      assert html =~ ~r{<h1>\s*Species not found\s*</h1>}
      assert html =~ ~s(value="nonexistent")

      {404, _headers, html} =
        assert_error_sent 404, fn -> get(conn, ~p"/species/#{alba}/merge/nonexistent") end

      assert html =~ ~s(value="nonexistent")

      assert_raise OaksWeb.NotFoundError, fn ->
        live(conn, ~p"/species/nonexistent/merge/#{alba}")
      end
    end
  end

  describe "merge execution" do
    test "executes merge and redirects to target", %{conn: conn, velutina: velutina, rubra: rubra} do
      {:ok, view, _html} =
        conn |> authenticated_conn() |> live(~p"/species/#{velutina}/merge/#{rubra}")

      # Show confirmation dialog
      render_click(view, "show_confirm")

      path = "/species/#{rubra}"

      # Execute merge: the dialog shows its merging state before the merge runs
      assert render_click(view, "execute_merge") =~ "Merging species…"
      assert_redirect(view, path, 1000)

      # Verify source was deleted
      assert Species.get_species_by_name(velutina) == nil

      # Verify synonym was added
      target = Species.get_species_full(rubra)
      synonyms = Species.parse_json_array(target.synonyms)
      assert velutina in synonyms
    end
  end

  describe "species detail merge picker" do
    test "unauthenticated user does not see merge button", %{conn: conn, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/species/#{alba}")
      refute html =~ "merge-species-btn"
    end

    test "authenticated user sees merge button", %{conn: conn, alba: alba} do
      {:ok, _view, html} = conn |> authenticated_conn() |> live(~p"/species/#{alba}")
      assert html =~ "merge-species-btn"
    end
  end
end
