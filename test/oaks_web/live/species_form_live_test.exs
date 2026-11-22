defmodule OaksWeb.SpeciesFormLiveTest do
  @moduledoc """
  Tests for the SpeciesFormLive LiveView (create/edit species).
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oaks.AccountsFixtures
  import Oaks.SpeciesFixtures

  alias Oaks.Species

  setup do
    stellata = species_fixture()
    alba = species_fixture(closely_related_to: [stellata.scientific_name])
    %{alba: alba.scientific_name, stellata: stellata.scientific_name}
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

      assert html =~ "New Species"
      assert html =~ "Scientific Name"
      assert html =~ "Create Species"
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
      assert html =~ "Save Changes"
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

    test "saves comma-separated relationship names as a list", %{conn: conn, alba: alba} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/#{alba}/edit")

      view
      |> form("#species-form", species: %{hybrids: "×bebbiana, ×jackiana"})
      |> render_submit()

      assert Oaks.Species.get_species_by_name(alba).hybrids == ~s(["×bebbiana","×jackiana"])
    end

    test "shows an error instead of saving an invalid list", %{conn: conn} = ctx do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/#{ctx.alba}/edit")

      html =
        view
        |> form("#species-form", species: %{closely_related_to: "[1, 2]"})
        |> render_submit()

      assert html =~ "must contain only names"

      assert Oaks.Species.get_species_by_name(ctx.alba).closely_related_to ==
               Jason.encode!([ctx.stellata])
    end

    test "keeps a taxonomy value that has no taxa row when saving", %{conn: conn, alba: alba} do
      subsection = "Erythromexicanae#{System.unique_integer([:positive])}"

      Oaks.Species.get_species_by_name(alba)
      |> Ecto.Changeset.change(subsection: subsection)
      |> Oaks.Repo.update!()

      {:ok, view, html} = conn |> authenticated_conn() |> live(~p"/species/#{alba}/edit")
      assert html =~ "#{subsection} (not in taxonomy)"

      view |> form("#species-form", species: %{author: "L."}) |> render_submit()

      species = Oaks.Species.get_species_by_name(alba)
      assert species.author == "L."
      assert species.subsection == subsection
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
      {:ok, _view, html} = conn |> authenticated_conn() |> live(~p"/species")

      assert html =~ "new-species-btn"
      assert html =~ "New Species"
    end
  end

  describe "species detail edit/delete buttons" do
    test "unauthenticated user does not see edit/delete buttons", %{conn: conn, alba: alba} do
      {:ok, _view, html} = live(conn, ~p"/species/#{alba}")
      refute html =~ "edit-species-btn"
      refute html =~ "delete-species-btn"
    end

    test "authenticated user sees edit/delete buttons", %{conn: conn, alba: alba} do
      {:ok, _view, html} = conn |> authenticated_conn() |> live(~p"/species/#{alba}")

      assert html =~ "edit-species-btn"
      assert html =~ "delete-species-btn"
    end

    test "delete flow works with confirmation", %{conn: conn} do
      %{scientific_name: name} = species_fixture()

      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/species/#{name}")

      # Click delete button
      html = render_click(view, "request_delete")
      assert html =~ "Delete species"
      assert html =~ "Are you sure"

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
