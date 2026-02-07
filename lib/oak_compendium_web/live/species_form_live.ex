defmodule OakCompendiumWeb.SpeciesFormLive do
  @moduledoc """
  LiveView for creating and editing species.

  Requires authentication — unauthenticated users are redirected
  to the species list with a flash message.
  """

  use OakCompendiumWeb, :live_view

  alias OakCompendium.Species
  alias OakCompendium.Species.Species, as: SpeciesSchema
  alias OakCompendium.Taxonomy

  @impl true
  def mount(_params, _session, socket) do
    # Auth check deferred to handle_params (after connected mount sets authenticated)
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
    if socket.assigns[:authenticated] do
      {:noreply, apply_action(socket, socket.assigns.live_action, params)}
    else
      if connected?(socket) do
        {:noreply,
         socket
         |> put_flash(:error, "You must be authenticated to perform this action.")
         |> push_navigate(to: ~p"/list")}
      else
        # Static render — don't redirect yet, wait for connected mount
        {:noreply, socket}
      end
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
        |> push_navigate(to: ~p"/list")

      species ->
        changeset = Species.change_species(species)

        socket
        |> assign(
          page_title: "Edit Quercus #{display_name(species.scientific_name)}",
          species: species,
          form: to_form(changeset)
        )
    end
  end

  @impl true
  def handle_event("validate", %{"species" => species_params}, socket) do
    if socket.assigns[:authenticated] do
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
    if socket.assigns[:authenticated] do
      save_species(socket, socket.assigns.live_action, species_params)
    else
      {:noreply,
       socket
       |> put_flash(:error, "You must be authenticated to perform this action.")
       |> push_navigate(to: ~p"/list")}
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
    <div :if={@form == nil} class="max-w-3xl mx-auto py-12 text-center">
      <p style="color: var(--color-text-tertiary);">Loading...</p>
    </div>

    <div :if={@form} class="max-w-3xl mx-auto">
      <.link
        navigate={cancel_path(@live_action, @species)}
        class="inline-flex items-center gap-1 text-sm mb-4"
        style="color: var(--color-forest-700);"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back
      </.link>

      <h1
        class="text-2xl font-bold mb-6"
        style="font-family: var(--font-serif); color: var(--color-forest-800);"
      >
        {@page_title}
      </h1>

      <.form for={@form} id="species-form" phx-change="validate" phx-submit="save">
        <div class="space-y-6">
          <%!-- Core fields --%>
          <div class="card p-6">
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
          <div class="card p-6">
            <h2 class="section-title section-title-sm mb-4">Taxonomy</h2>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <.input
                  field={@form[:subgenus]}
                  type="select"
                  label="Subgenus"
                  options={@subgenera}
                  prompt="Select subgenus..."
                />
              </div>
              <div>
                <.input
                  field={@form[:section]}
                  type="select"
                  label="Section"
                  options={@sections}
                  prompt="Select section..."
                />
              </div>
              <div>
                <.input
                  field={@form[:subsection]}
                  type="select"
                  label="Subsection"
                  options={@subsections}
                  prompt="Select subsection..."
                />
              </div>
              <div>
                <.input
                  field={@form[:complex]}
                  type="select"
                  label="Complex"
                  options={@complexes}
                  prompt="Select complex..."
                />
              </div>
            </div>
          </div>

          <%!-- Hybrid parentage (shown when is_hybrid is checked) --%>
          <div class="card p-6">
            <h2 class="section-title section-title-sm mb-4">Hybrid Parentage</h2>
            <p class="text-sm mb-4" style="color: var(--color-text-tertiary);">
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
          <div class="card p-6">
            <h2 class="section-title section-title-sm mb-4">Relationships</h2>
            <p class="text-sm mb-4" style="color: var(--color-text-tertiary);">
              Enter names separated by commas. JSON arrays are also accepted.
            </p>
            <div class="space-y-4">
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
          <div class="flex items-center justify-end gap-3">
            <.link
              navigate={cancel_path(@live_action, @species)}
              class="px-4 py-2 rounded-lg text-sm font-medium"
              style="color: var(--color-text-secondary);"
            >
              Cancel
            </.link>
            <button
              type="submit"
              phx-disable-with="Saving..."
              class="px-6 py-2 rounded-lg text-sm font-medium text-white"
              style="background-color: var(--color-forest-600);"
            >
              {if(@live_action == :new, do: "Create Species", else: "Save Changes")}
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  # -- Helpers --

  defp cancel_path(:new, _species), do: ~p"/list"

  defp cancel_path(:edit, species) do
    ~p"/species/#{species.scientific_name}"
  end

  defp display_name("\u00D7" <> rest), do: rest
  defp display_name(name), do: name

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
