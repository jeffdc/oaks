defmodule OaksWeb.SpeciesFormLiveTest do
  @moduledoc """
  Tests for the SpeciesFormLive LiveView (create/edit species).
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.AccountsFixtures
  import Oaks.SpeciesFixtures
  import Oaks.TaxonomyFixtures

  alias Oaks.Species
  alias Oaks.Taxonomy

  setup do
    tree = taxon_tree_fixture()
    alba = species_fixture(taxon_id: tree.section.id)
    %{alba: alba.scientific_name, alba_species: alba, tree: tree}
  end

  defp authenticated_conn(conn) do
    log_in_user(conn, user_fixture())
  end

  describe "GET /species/new (unauthenticated)" do
    test "redirects to species list", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/species"}}} =
               live(conn, ~p"/species/new")
    end
  end

  describe "GET /species/new (authenticated)" do
    test "renders new species form", %{conn: conn} do
      {:ok, _view, html} = conn |> authenticated_conn() |> live(~p"/species/new")

      assert html =~ "New species"
      assert html =~ "Scientific Name"
      assert html =~ "Create species"
    end

    test "validates form on change", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/new")

      html =
        view
        |> form("#species-form", species: %{scientific_name: "", is_hybrid: false})
        |> render_change()

      assert html =~ "be blank"
    end

    test "creates species on submit", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/new")
      name = unique_species_name()

      {:ok, _view, html} =
        view
        |> form("#species-form",
          species: %{scientific_name: name, is_hybrid: false, author: "Muenchh."}
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ name
      assert html =~ "Species created"
    end

    test "shows error for duplicate name", %{conn: conn, alba: alba} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/new")

      html =
        view
        |> form("#species-form", species: %{scientific_name: alba, is_hybrid: false})
        |> render_submit()

      assert html =~ "has already been taken"
    end
  end

  describe "GET /species/:name/edit (unauthenticated)" do
    test "redirects to species list", %{conn: conn, alba: alba} do
      assert {:error, {:live_redirect, %{to: "/species"}}} =
               live(conn, ~p"/species/#{alba}/edit")
    end
  end

  describe "GET /species/:name/edit (authenticated)" do
    test "renders edit form with pre-populated data", %{conn: conn, alba: alba} do
      {:ok, _view, html} = conn |> authenticated_conn() |> live(~p"/species/#{alba}/edit")

      assert html =~ "Edit"
      assert html =~ alba
      assert html =~ "Save changes"
    end

    test "updates species on submit", %{conn: conn, alba: alba} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/#{alba}/edit")

      {:ok, _view, html} =
        view
        |> form("#species-form", species: %{author: "Linnaeus 1753"})
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Linnaeus 1753"
      assert html =~ "Species updated"
    end

    test "the placement select lists every taxon in tree order and saves a key", %{
      conn: conn,
      alba: alba,
      tree: tree
    } do
      {:ok, view, html} = conn |> authenticated_conn() |> live(~p"/species/#{alba}/edit")

      assert html =~ "Genus Quercus"
      assert html =~ "Subgenus #{tree.subgenus.name}"
      assert html =~ "Subsection #{tree.subsection.name}"

      view
      |> form("#species-form", species: %{taxon_id: tree.subsection.id})
      |> render_submit()

      assert Oaks.Species.get_species_by_name(alba).taxon_id == tree.subsection.id
    end

    test "a new species defaults to the genus", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/new")
      genus = Taxonomy.get_genus()

      assert has_element?(
               view,
               ~s(#species-form select[name="species[taxon_id]"] option[selected][value="#{genus.id}"])
             )
    end

    test "an unknown parent name is a field error, not a silent blank", %{
      conn: conn,
      alba: alba
    } do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/#{alba}/edit")

      html =
        view
        |> form("#species-form", species: %{parent1_name: "nowhere at all"})
        |> render_submit()

      assert html =~ "does not match any species"
      assert Oaks.Species.get_species_by_name(alba).parent1_id == nil
    end

    test "stores the key of a typed parent name", %{conn: conn, alba: _alba} do
      parent = species_fixture()
      hybrid = hybrid_fixture()

      {:ok, view, _html} =
        conn |> authenticated_conn() |> live(~p"/species/#{hybrid.scientific_name}/edit")

      view
      |> form("#species-form",
        species: %{parent1_name: "  #{String.upcase(parent.scientific_name)}  "}
      )
      |> render_submit()

      assert Oaks.Species.get_species_by_name(hybrid.scientific_name).parent1_id == parent.id
    end

    test "redirects for nonexistent species", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/species"}}} =
               conn |> authenticated_conn() |> live(~p"/species/zzz_nonexistent/edit")
    end
  end

  describe "species list new button" do
    test "unauthenticated user does not see New Species button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/species")
      refute html =~ "new-species-btn"
    end

    test "authenticated user sees New Species button", %{conn: conn} do
      {:ok, view, html} = conn |> authenticated_conn() |> live(~p"/species")

      assert html =~ "new-species-btn"
      assert html =~ "New species"

      assert has_element?(
               view,
               "#species-list-title .oc-title-actions #species-list-edit-menu #new-species-btn"
             )
    end
  end

  describe "species detail edit/delete buttons" do
    test "unauthenticated user does not see edit/delete buttons", %{conn: conn, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/species/#{alba}")
      refute html =~ "edit-species-btn"
      refute html =~ "delete-species-btn"
    end

    test "authenticated user sees edit/delete buttons", %{conn: conn, alba: alba} do
      {:ok, view, html} = conn |> authenticated_conn() |> live(~p"/species/#{alba}")

      assert html =~ "edit-species-btn"
      assert html =~ "delete-species-btn"

      for id <- ~w(edit-species-btn delete-species-btn) do
        assert has_element?(view, "#species-title .oc-title-actions #species-edit-menu ##{id}")
      end
    end

    test "delete flow works with confirmation", %{conn: conn} do
      %{scientific_name: name} = species_fixture()

      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/#{name}")

      # Click delete button
      html = render_click(view, "request_delete")
      assert html =~ "Delete species"
      assert html =~ "from the Compendium?"

      # Confirm delete
      {:ok, _view, html} =
        view
        |> render_click("confirm_delete")
        |> follow_redirect(conn)

      assert html =~ "Species deleted"
      assert Species.get_species_by_name(name) == nil
    end

    test "cancel delete hides modal", %{conn: conn, alba: alba} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/#{alba}")

      # Open delete confirmation
      html = render_click(view, "request_delete")
      assert html =~ "delete-confirm-modal"

      # Cancel
      html = render_click(view, "cancel_delete")
      refute html =~ "delete-confirm-modal"
    end
  end
end
