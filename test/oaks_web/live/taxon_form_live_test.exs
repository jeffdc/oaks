defmodule OaksWeb.TaxonFormLiveTest do
  @moduledoc """
  Tests for the TaxonFormLive LiveView (create/edit taxa).
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.AccountsFixtures
  import Oaks.TaxonomyFixtures

  alias Oaks.Taxonomy

  setup do
    %{taxon: taxon_fixture()}
  end

  defp authenticated_conn(conn) do
    log_in_user(conn, user_fixture())
  end

  # -- New (unauthenticated) --

  describe "GET /taxonomy/new (unauthenticated)" do
    test "redirects to taxonomy browser", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/taxonomy"}}} =
               live(conn, ~p"/taxonomy/new")
    end
  end

  # -- New (authenticated) --

  describe "GET /taxonomy/new (authenticated)" do
    test "renders create taxon form", %{conn: conn} do
      {:ok, _view, html} = conn |> authenticated_conn() |> live(~p"/taxonomy/new")

      assert html =~ "New taxon"
      assert html =~ "Level"
      assert html =~ "Name"
    end

    test "pre-selects level and parent from query params", %{conn: conn, taxon: taxon} do
      {:ok, _view, html} =
        conn
        |> authenticated_conn()
        |> live(~p"/taxonomy/new?level=section&parent_id=#{taxon.id}")

      assert html =~ "New taxon"
      # The parent dropdown should be present since level is section
      assert html =~ "Parent"
    end

    test "changing the level swaps the parent options to the ranks above", %{conn: conn} do
      %{subgenus: subgenus, section: section, subsection: subsection} = taxon_tree_fixture()
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/taxonomy/new")

      option = &~s(#taxon-form select[name="taxon[parent_id]"] option[value="#{&1.id}"])

      view |> form("#taxon-form", taxon: %{level: "section"}) |> render_change()
      assert has_element?(view, option.(subgenus))
      refute has_element?(view, option.(section))

      view |> form("#taxon-form", taxon: %{level: "subsection"}) |> render_change()
      assert has_element?(view, option.(subgenus))
      assert has_element?(view, option.(section))
      refute has_element?(view, option.(subsection))
    end

    test "creates taxon on submit", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/taxonomy/new")

      {:ok, _view, html} =
        view
        |> form("#taxon-form",
          taxon: %{
            name: unique_taxon_name(),
            level: "subgenus",
            parent_id: Taxonomy.get_genus().id
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Taxon created"
    end

    test "validates form on change", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/taxonomy/new")

      html =
        view
        |> form("#taxon-form", taxon: %{name: "", level: ""})
        |> render_change()

      assert html =~ "be blank"
    end

    test "shows error for duplicate name+level", %{conn: conn, taxon: taxon} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/taxonomy/new")

      html =
        view
        |> form("#taxon-form",
          taxon: %{
            name: taxon.name,
            level: "subgenus",
            parent_id: Taxonomy.get_genus().id
          }
        )
        |> render_submit()

      assert html =~ "has already been taken"
    end
  end

  # -- Edit (unauthenticated) --

  describe "GET /taxonomy/:id/edit (unauthenticated)" do
    test "redirects to taxonomy browser", %{conn: conn, taxon: taxon} do
      assert {:error, {:live_redirect, %{to: "/taxonomy"}}} =
               live(conn, ~p"/taxonomy/#{taxon.id}/edit")
    end
  end

  # -- Edit (authenticated) --

  describe "GET /taxonomy/:id/edit (authenticated)" do
    test "renders edit form with pre-populated data", %{conn: conn, taxon: taxon} do
      {:ok, _view, html} = conn |> authenticated_conn() |> live(~p"/taxonomy/#{taxon.id}/edit")

      assert html =~ "Edit"
      assert html =~ taxon.name
    end

    test "updates taxon on submit", %{conn: conn, taxon: taxon} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/taxonomy/#{taxon.id}/edit")

      {:ok, _view, html} =
        view
        |> form("#taxon-form", taxon: %{author: "Updated Author"})
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Taxon updated"
    end

    test "saving from the Preview tab keeps the edited content", %{conn: conn, taxon: taxon} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/taxonomy/#{taxon.id}/edit")

      view |> form("#taxon-form", taxon: %{content: "Edited **body**"}) |> render_change()
      render_click(view, "switch_content_tab", %{"tab" => "preview"})

      view |> form("#taxon-form") |> render_submit()

      assert Oaks.Taxonomy.get_taxon_by_id(taxon.id).content == "Edited **body**"
    end

    test "editing a field and saving keeps the taxon's parent", %{conn: conn} do
      %{subgenus: subgenus, section: section, subsection: subsection} = taxon_tree_fixture()
      conn = authenticated_conn(conn)

      for {taxon, path} <- [
            {section, [subgenus.name, section.name]},
            {subsection, [subgenus.name, section.name, subsection.name]}
          ] do
        {:ok, view, _html} = live(conn, ~p"/taxonomy/#{taxon.id}/edit")

        parent_option =
          ~s(#taxon-form select[name="taxon[parent_id]"] option[selected][value="#{taxon.parent_id}"])

        assert has_element?(view, parent_option)

        view |> form("#taxon-form", taxon: %{content: "Edited"}) |> render_change()
        assert has_element?(view, parent_option)

        {:ok, _view, html} =
          view |> form("#taxon-form") |> render_submit() |> follow_redirect(conn)

        assert html =~ "Taxon updated"
        assert Taxonomy.get_taxon_by_id(taxon.id).parent_id == taxon.parent_id
        assert {:ok, _taxa} = Taxonomy.resolve_path(path)
        assert {:ok, _view, _html} = live(conn, ~p"/taxonomy/#{path}")
      end
    end

    test "redirects for nonexistent taxon", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/taxonomy"}}} =
               conn |> authenticated_conn() |> live(~p"/taxonomy/0/edit")
    end
  end

  # -- Taxonomy page buttons --

  describe "taxonomy page admin buttons" do
    test "unauthenticated user does not see Create Taxon button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/taxonomy")
      refute html =~ "create-taxon-btn"
    end

    test "authenticated user sees Create Taxon button", %{conn: conn} do
      {:ok, view, html} = conn |> authenticated_conn() |> live(~p"/taxonomy")

      assert html =~ "create-taxon-btn"
      assert html =~ "Create taxon"

      assert has_element?(
               view,
               "#taxon-title .oc-title-actions #taxon-edit-menu #create-taxon-btn"
             )
    end

    test "delete taxon flow with confirmation", %{conn: conn} do
      taxon = taxon_fixture(name: "DeleteMe#{System.unique_integer([:positive])}")

      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/taxonomy")

      # Request delete
      html = render_click(view, "request_delete_taxon", %{"id" => to_string(taxon.id)})
      assert has_element?(view, "#delete-taxon-modal h2", "Delete #{taxon.level}")
      assert has_element?(view, "#confirm-delete-taxon-btn.oc-btn-danger")
      assert html =~ taxon.name

      # Confirm
      {:ok, _view, html} =
        view
        |> render_click("confirm_delete_taxon")
        |> follow_redirect(conn)

      assert html =~ "Taxon deleted"
      assert Taxonomy.get_taxon_by_id(taxon.id) == nil
    end

    test "cancel delete hides modal", %{conn: conn, taxon: taxon} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/taxonomy")

      html = render_click(view, "request_delete_taxon", %{"id" => to_string(taxon.id)})
      assert html =~ "delete-taxon-modal"

      html = render_click(view, "cancel_delete_taxon")
      refute html =~ "delete-taxon-modal"
    end
  end
end
