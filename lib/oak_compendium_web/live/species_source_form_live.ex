defmodule OakCompendiumWeb.SpeciesSourceFormLive do
  @moduledoc """
  LiveView for creating and editing per-source data (species_sources).

  Requires authentication — unauthenticated users are redirected
  to the species detail page with a flash message.
  """

  use OakCompendiumWeb, :live_view

  alias OakCompendium.Sources
  alias OakCompendium.Sources.SpeciesSource
  alias OakCompendium.Species

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       species: nil,
       species_source: nil,
       form: nil,
       available_sources: []
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
        {:noreply, socket}
      end
    end
  end

  defp apply_action(socket, :new, %{"name" => name}) do
    case Species.get_species_by_name(name) do
      nil ->
        socket
        |> put_flash(:error, "Species not found.")
        |> push_navigate(to: ~p"/list")

      species ->
        available = Sources.available_sources_for_species(species.id)
        species_source = %SpeciesSource{species_id: species.id}
        changeset = Sources.change_species_source(species_source)

        socket
        |> assign(
          page_title: "Add Source Data — Quercus #{display_name(species.scientific_name)}",
          species: species,
          species_source: species_source,
          available_sources: available,
          form: to_form(changeset)
        )
    end
  end

  defp apply_action(socket, :edit, %{"name" => name, "source_id" => source_id_str}) do
    case Species.get_species_by_name(name) do
      nil ->
        socket
        |> put_flash(:error, "Species not found.")
        |> push_navigate(to: ~p"/list")

      species ->
        source_id = String.to_integer(source_id_str)

        case find_species_source(species.id, source_id) do
          nil ->
            socket
            |> put_flash(:error, "Source data not found.")
            |> push_navigate(to: ~p"/species/#{name}")

          species_source ->
            changeset = Sources.change_species_source(species_source)

            socket
            |> assign(
              page_title: "Edit Source Data — Quercus #{display_name(species.scientific_name)}",
              species: species,
              species_source: species_source,
              form: to_form(changeset)
            )
        end
    end
  end

  defp find_species_source(species_id, source_id) do
    import Ecto.Query

    OakCompendium.Repo.one(
      from(ss in SpeciesSource,
        where: ss.species_id == ^species_id and ss.source_id == ^source_id,
        preload: [:source, :species]
      )
    )
  end

  @impl true
  def handle_event("validate", %{"species_source" => params}, socket) do
    if socket.assigns[:authenticated] do
      changeset =
        socket.assigns.species_source
        |> Sources.change_species_source(params)
        |> Map.put(:action, :validate)

      {:noreply, assign(socket, form: to_form(changeset))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("save", %{"species_source" => params}, socket) do
    if socket.assigns[:authenticated] do
      save_species_source(socket, socket.assigns.live_action, params)
    else
      {:noreply,
       socket
       |> put_flash(:error, "You must be authenticated to perform this action.")
       |> push_navigate(to: ~p"/list")}
    end
  end

  defp save_species_source(socket, :new, params) do
    species = socket.assigns.species

    params =
      params
      |> Map.put("species_id", to_string(species.id))

    case Sources.create_species_source(params) do
      {:ok, _species_source} ->
        {:noreply,
         socket
         |> put_flash(:info, "Source data added.")
         |> push_navigate(to: ~p"/species/#{species.scientific_name}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_species_source(socket, :edit, params) do
    species = socket.assigns.species

    case Sources.update_species_source(socket.assigns.species_source, params) do
      {:ok, _species_source} ->
        {:noreply,
         socket
         |> put_flash(:info, "Source data updated.")
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
        navigate={~p"/species/#{@species.scientific_name}"}
        class="inline-flex items-center gap-1 text-sm mb-4"
        style="color: var(--color-forest-700);"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to species
      </.link>

      <h1
        class="text-2xl font-bold mb-6"
        style="font-family: var(--font-serif); color: var(--color-forest-800);"
      >
        {@page_title}
      </h1>

      <.form for={@form} id="species-source-form" phx-change="validate" phx-submit="save">
        <div class="space-y-6">
          <%!-- Source selection (new only) --%>
          <div :if={@live_action == :new} class="card p-6">
            <h2 class="section-title section-title-sm mb-4">Source</h2>
            <.input
              field={@form[:source_id]}
              type="select"
              label="Data Source"
              options={Enum.map(@available_sources, &{&1.name, &1.id})}
              prompt="Select a source..."
            />
          </div>

          <div :if={@live_action == :edit} class="card p-6">
            <h2 class="section-title section-title-sm mb-4">Source</h2>
            <p style="color: var(--color-text-secondary);">
              {@species_source.source.name}
            </p>
          </div>

          <%!-- Descriptive fields --%>
          <div class="card p-6">
            <h2 class="section-title section-title-sm mb-4">Morphology & Description</h2>
            <div class="space-y-4">
              <.input
                field={@form[:range]}
                type="textarea"
                label="Geographic Range"
                phx-debounce="300"
              />
              <.input
                field={@form[:growth_habit]}
                type="textarea"
                label="Growth Habit"
                phx-debounce="300"
              />
              <.input
                field={@form[:leaves]}
                type="textarea"
                label="Leaves"
                phx-debounce="300"
              />
              <.input
                field={@form[:flowers]}
                type="textarea"
                label="Flowers"
                phx-debounce="300"
              />
              <.input
                field={@form[:fruits]}
                type="textarea"
                label="Fruits"
                phx-debounce="300"
              />
              <.input
                field={@form[:bark]}
                type="textarea"
                label="Bark"
                phx-debounce="300"
              />
              <.input
                field={@form[:twigs]}
                type="textarea"
                label="Twigs"
                phx-debounce="300"
              />
              <.input
                field={@form[:buds]}
                type="textarea"
                label="Buds"
                phx-debounce="300"
              />
            </div>
          </div>

          <%!-- Additional info --%>
          <div class="card p-6">
            <h2 class="section-title section-title-sm mb-4">Additional Information</h2>
            <div class="space-y-4">
              <.input
                field={@form[:local_names]}
                type="text"
                label="Common Names (JSON array)"
                placeholder={~s(e.g. ["white oak","eastern white oak"])}
                phx-debounce="300"
              />
              <.input
                field={@form[:hardiness_habitat]}
                type="textarea"
                label="Hardiness & Habitat"
                phx-debounce="300"
              />
              <.input
                field={@form[:miscellaneous]}
                type="textarea"
                label="Miscellaneous"
                phx-debounce="300"
              />
              <.input
                field={@form[:url]}
                type="text"
                label="Source URL"
                placeholder="https://..."
                phx-debounce="300"
              />
              <.input
                field={@form[:is_preferred]}
                type="checkbox"
                label="Preferred source for display"
              />
            </div>
          </div>

          <%!-- Submit --%>
          <div class="flex items-center justify-end gap-3">
            <.link
              navigate={~p"/species/#{@species.scientific_name}"}
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
              {if(@live_action == :new, do: "Add Source Data", else: "Save Changes")}
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  defp display_name("\u00D7" <> rest), do: rest
  defp display_name(name), do: name
end
