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

  @impl true
  def mount(_params, _session, socket) do
    # Auth check happens in handle_params
    subgenera = taxonomy_names("subgenus")
    sections = taxonomy_names("section")
    subsections = taxonomy_names("subsection")
    complexes = taxonomy_names("complex")

    {:ok,
     assign(socket,
       subgenera: subgenera,
       sections: sections,
       subsections: subsections,
       complexes: complexes,
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
    changeset = Species.change_species(species)

    socket
    |> assign(
      page_title: "New Species",
      species: species,
      form: to_form(changeset)
    )
  end

  defp apply_action(socket, :edit, %{"name" => name}) do
    case Species.get_species_by_name(name) do
      nil ->
        socket
        |> put_flash(:error, "Species not found.")
        |> push_navigate(to: ~p"/species")

      species ->
        changeset = Species.change_species(species)

        socket
        |> assign(
          page_title: "Edit Quercus #{epithet(species.scientific_name)}",
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
        <.back navigate={cancel_path(@live_action, @species)}>Back</.back>

        <.header class="species-form-title">
          <span :if={@live_action == :new}>New Species</span>
          <span :if={
            @live_action == :edit && !hybrid_sign?(@species.scientific_name, @species.is_hybrid)
          }>
            Edit <i>Quercus {epithet(@species.scientific_name)}</i>
          </span>
          <span :if={
            @live_action == :edit && hybrid_sign?(@species.scientific_name, @species.is_hybrid)
          }>
            Edit <i>Quercus</i> &times; <i>{epithet(@species.scientific_name)}</i>
          </span>
        </.header>
      </:head>

      <div :if={@form}>
        <.form for={@form} id="species-form" phx-change="validate" phx-submit="save">
          <div class="species-form-sections">
            <%!-- Core fields --%>
            <div class="card">
              <h2 class="section-title section-title-sm mb-4">Basic Information</h2>
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
                    Renaming updates every species that mentions this name and keeps the old name as a synonym.
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
            </div>

            <%!-- Taxonomy fields --%>
            <div class="card">
              <h2 class="section-title section-title-sm mb-4">Taxonomy</h2>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <.input
                    field={@form[:subgenus]}
                    type="select"
                    label="Subgenus"
                    options={taxon_options(@subgenera, @form[:subgenus].value)}
                    prompt="Select subgenus..."
                  />
                </div>
                <div>
                  <.input
                    field={@form[:section]}
                    type="select"
                    label="Section"
                    options={taxon_options(@sections, @form[:section].value)}
                    prompt="Select section..."
                  />
                </div>
                <div>
                  <.input
                    field={@form[:subsection]}
                    type="select"
                    label="Subsection"
                    options={taxon_options(@subsections, @form[:subsection].value)}
                    prompt="Select subsection..."
                  />
                </div>
                <div>
                  <.input
                    field={@form[:complex]}
                    type="select"
                    label="Complex"
                    options={taxon_options(@complexes, @form[:complex].value)}
                    prompt="Select complex..."
                  />
                </div>
              </div>
            </div>

            <%!-- Hybrid parentage (shown when is_hybrid is checked) --%>
            <div class="card">
              <h2 class="section-title section-title-sm mb-4">Hybrid Parentage</h2>
              <p class="oc-hint species-form-lede">
                Only relevant for hybrid species.
              </p>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <.input
                    field={@form[:parent1]}
                    type="text"
                    label="Parent 1"
                    placeholder="e.g. alba"
                    phx-debounce="300"
                  />
                </div>
                <div>
                  <.input
                    field={@form[:parent2]}
                    type="text"
                    label="Parent 2"
                    placeholder="e.g. macrocarpa"
                    phx-debounce="300"
                  />
                </div>
              </div>
            </div>

            <%!-- Relationships (JSON arrays stored as comma-separated text) --%>
            <div class="card">
              <h2 class="section-title section-title-sm mb-4">Relationships</h2>
              <p class="oc-hint species-form-lede">
                Enter names separated by commas. JSON arrays are also accepted.
              </p>
              <div class="species-form-stack">
                <.input
                  field={@form[:hybrids]}
                  type="text"
                  label="Known Hybrids"
                  placeholder={~s(e.g. ["×bebbiana","×jackiana"])}
                  phx-debounce="300"
                />
                <.input
                  field={@form[:closely_related_to]}
                  type="text"
                  label="Closely Related To"
                  placeholder={~s(e.g. ["stellata","macrocarpa"])}
                  phx-debounce="300"
                />
                <.input
                  field={@form[:subspecies_varieties]}
                  type="text"
                  label="Subspecies & Varieties"
                  placeholder={~s(e.g. ["alba var. latiloba"])}
                  phx-debounce="300"
                />
                <.input
                  field={@form[:synonyms]}
                  type="text"
                  label="Synonyms"
                  placeholder={~s(e.g. ["alba var. repanda"])}
                  phx-debounce="300"
                />
              </div>
            </div>

            <%!-- Submit --%>
            <div class="species-form-actions">
              <.button navigate={cancel_path(@live_action, @species)}>Cancel</.button>
              <.button type="submit" variant="primary" phx-disable-with="Saving...">
                {if(@live_action == :new, do: "Create Species", else: "Save Changes")}
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

  # Keeps a stored value selectable when it has no taxa row; otherwise the
  # select falls back to the prompt and saving silently clears the field.
  defp taxon_options(names, current) when is_binary(current) and current != "" do
    if current in names, do: names, else: [{"#{current} (not in taxonomy)", current} | names]
  end

  defp taxon_options(names, _current), do: names

  defp taxonomy_names(level) do
    level
    |> Taxonomy.list_taxa_by_level()
    |> Enum.map(& &1.name)
    |> Enum.uniq()
    |> Enum.sort()
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
