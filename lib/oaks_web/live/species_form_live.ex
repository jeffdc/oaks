defmodule OaksWeb.SpeciesFormLive do
  @moduledoc """
  LiveView for creating and editing species.

  Requires authentication — unauthenticated users are redirected
  to the species list with a flash message.
  """

  use OaksWeb, :live_view

  alias Oaks.Species
  alias Oaks.Species.Species, as: SpeciesSchema
  alias Oaks.Taxonomy
  alias OaksWeb.SpeciesName
  alias OaksWeb.TaxonomyOptions

  @impl true
  def mount(_params, _session, socket) do
    # Auth check happens in handle_params
    genus = Taxonomy.get_genus()

    {:ok,
     assign(socket,
       placements: TaxonomyOptions.all(),
       genus_id: genus && genus.id,
       species: nil,
       form: nil
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    if socket.assigns[:current_scope] do
      {:noreply, apply_action(socket, socket.assigns.live_action, params)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "You must be authenticated to perform this action.")
       |> push_navigate(to: ~p"/species")}
    end
  end

  defp apply_action(socket, :new, _params) do
    species = %SpeciesSchema{}
    attrs = if socket.assigns.genus_id, do: %{taxon_id: socket.assigns.genus_id}, else: %{}
    changeset = Species.change_species(species, attrs)

    socket
    |> assign(
      page_title: "New species",
      species: species,
      form: to_form(changeset)
    )
  end

  defp apply_action(socket, :edit, %{"name" => name}) do
    case Species.get_species_with_parents(name) do
      nil ->
        socket
        |> put_flash(:error, "Species not found.")
        |> push_navigate(to: ~p"/species")

      species ->
        changeset = Species.change_species(species)

        socket
        |> assign(
          page_title: "Edit #{SpeciesName.full_name(species.scientific_name, species.is_hybrid)}",
          species: species,
          form: to_form(changeset)
        )
    end
  end

  @impl true
  def handle_event("validate", %{"species" => species_params}, socket) do
    if socket.assigns[:current_scope] do
      changeset =
        socket.assigns.species
        |> Species.change_species(species_params)
        |> Map.put(:action, :validate)

      {:noreply, assign(socket, form: to_form(changeset))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("save", %{"species" => species_params}, socket) do
    if socket.assigns[:current_scope] do
      save_species(socket, socket.assigns.live_action, species_params)
    else
      {:noreply,
       socket
       |> put_flash(:error, "You must be authenticated to perform this action.")
       |> push_navigate(to: ~p"/species")}
    end
  end

  defp save_species(socket, :new, species_params) do
    case Species.create_species(species_params) do
      {:ok, species} ->
        {:noreply,
         socket
         |> put_flash(:info, "Species created.")
         |> push_navigate(to: ~p"/species/#{species.scientific_name}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_species(socket, :edit, species_params) do
    case Species.update_species(socket.assigns.species, species_params) do
      {:ok, species} ->
        {:noreply,
         socket
         |> put_flash(:info, "Species updated.")
         |> push_navigate(to: ~p"/species/#{species.scientific_name}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page width="form">
      <div :if={@form == nil} class="py-s7">
        <p class="oc-empty">Loading...</p>
      </div>

      <:head :if={@form}>
        <.back navigate={cancel_path(@live_action, @species)}>Back to species</.back>

        <.header>
          <span :if={@live_action == :new}>New species</span>
          <span :if={@live_action == :edit}>
            Edit
            <.sci_name name={@species.scientific_name} hybrid={@species.is_hybrid} size="display" />
          </span>
        </.header>
      </:head>

      <div :if={@form}>
        <.form for={@form} id="species-form" phx-change="validate" phx-submit="save">
          <div class="species-form-sections">
            <%!-- Core fields --%>
            <section>
              <.section_heading>Basic Information</.section_heading>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div class="sm:col-span-2">
                  <.input
                    field={@form[:scientific_name]}
                    type="text"
                    label="Scientific Name"
                    placeholder="e.g. alba"
                    phx-debounce="300"
                  />
                  <p :if={@live_action == :edit} class="oc-hint species-form-note">
                    Renaming keeps the old name as a synonym.
                  </p>
                </div>
                <div>
                  <.input
                    field={@form[:author]}
                    type="text"
                    label="Author"
                    placeholder="e.g. L. 1753"
                    phx-debounce="300"
                  />
                </div>
                <div>
                  <.input
                    field={@form[:conservation_status]}
                    type="select"
                    label="Conservation Status"
                    options={conservation_options()}
                    prompt="Select status..."
                  />
                </div>
                <div>
                  <.input field={@form[:is_hybrid]} type="checkbox" label="Is Hybrid" />
                </div>
              </div>
            </section>

            <%!-- Placement --%>
            <section>
              <.section_heading>Taxonomy</.section_heading>
              <div class="grid grid-cols-1 gap-4">
                <.input
                  field={@form[:taxon_id]}
                  type="select"
                  label="Placement"
                  options={@placements}
                  prompt="Select placement..."
                />
              </div>
            </section>

            <%!-- Hybrid parentage (shown when is_hybrid is checked) --%>
            <section>
              <.section_heading>Hybrid Parentage</.section_heading>
              <p class="oc-hint species-form-lede">
                Only relevant for hybrid species.
              </p>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <.input
                    field={@form[:parent1_name]}
                    type="text"
                    label="Parent 1"
                    placeholder="e.g. alba"
                    phx-debounce="300"
                  />
                </div>
                <div>
                  <.input
                    field={@form[:parent2_name]}
                    type="text"
                    label="Parent 2"
                    placeholder="e.g. macrocarpa"
                    phx-debounce="300"
                  />
                </div>
              </div>
            </section>

            <%!-- Relationships (JSON arrays stored as comma-separated text) --%>
            <section>
              <.section_heading>Relationships</.section_heading>
              <p class="oc-hint species-form-lede">
                Enter names separated by commas. JSON arrays are also accepted.
              </p>
              <div class="species-form-stack">
                <.input
                  field={@form[:synonyms]}
                  type="text"
                  label="Synonyms"
                  placeholder={~s(e.g. ["alba var. repanda"])}
                  phx-debounce="300"
                />
              </div>
            </section>

            <%!-- Submit --%>
            <div class="species-form-actions">
              <.button navigate={cancel_path(@live_action, @species)}>Cancel</.button>
              <.button type="submit" variant="primary" phx-disable-with="Saving...">
                {if(@live_action == :new, do: "Create species", else: "Save changes")}
              </.button>
            </div>
          </div>
        </.form>
      </div>
    </.page>
    """
  end

  # -- Helpers --

  defp cancel_path(:new, _species), do: ~p"/species"

  defp cancel_path(:edit, species) do
    ~p"/species/#{species.scientific_name}"
  end

  defp conservation_options do
    [
      {"Least Concern (LC)", "LC"},
      {"Near Threatened (NT)", "NT"},
      {"Vulnerable (VU)", "VU"},
      {"Endangered (EN)", "EN"},
      {"Critically Endangered (CR)", "CR"},
      {"Extinct in the Wild (EW)", "EW"},
      {"Extinct (EX)", "EX"},
      {"Data Deficient (DD)", "DD"},
      {"Not Evaluated (NE)", "NE"}
    ]
  end
end
