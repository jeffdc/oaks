defmodule OaksWeb.SpeciesSourceFormLive do
  @moduledoc """
  LiveView for creating and editing per-source data (species_sources).

  Requires authentication — unauthenticated users are redirected
  to the species detail page with a flash message.
  """

  use OaksWeb, :live_view

  alias Oaks.Sources
  alias Oaks.Sources.SpeciesSource
  alias Oaks.Species
  alias OaksWeb.Params

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
    if socket.assigns[:current_scope] do
      {:noreply, apply_action(socket, socket.assigns.live_action, params)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "You must be authenticated to perform this action.")
       |> push_navigate(to: ~p"/species")}
    end
  end

  defp apply_action(socket, :new, %{"name" => name}) do
    case Species.get_species_by_name(name) do
      nil ->
        socket
        |> put_flash(:error, "Species not found.")
        |> push_navigate(to: ~p"/species")

      species ->
        available = Sources.available_sources_for_species(species.id)
        species_source = %SpeciesSource{species_id: species.id}
        changeset = Sources.change_species_source(species_source)

        socket
        |> assign(
          page_title: "Add source data — Quercus #{epithet(species.scientific_name)}",
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
        |> push_navigate(to: ~p"/species")

      species ->
        source_id = Params.int(source_id_str)

        case source_id && find_species_source(species.id, source_id) do
          nil ->
            socket
            |> put_flash(:error, "Source data not found.")
            |> push_navigate(to: ~p"/species/#{name}")

          species_source ->
            changeset = Sources.change_species_source(species_source)

            socket
            |> assign(
              page_title: "Edit source data — Quercus #{epithet(species.scientific_name)}",
              species: species,
              species_source: species_source,
              form: to_form(changeset)
            )
        end
    end
  end

  defp find_species_source(species_id, source_id) do
    import Ecto.Query

    Oaks.Repo.one(
      from(ss in SpeciesSource,
        where: ss.species_id == ^species_id and ss.source_id == ^source_id,
        preload: [:source, :species]
      )
    )
  end

  @impl true
  def handle_event("validate", %{"species_source" => params}, socket) do
    if socket.assigns[:current_scope] do
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
    if socket.assigns[:current_scope] do
      save_species_source(socket, socket.assigns.live_action, params)
    else
      {:noreply,
       socket
       |> put_flash(:error, "You must be authenticated to perform this action.")
       |> push_navigate(to: ~p"/species")}
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
    <.page width="form">
      <div :if={@form == nil} class="py-s7">
        <p class="oc-empty">Loading...</p>
      </div>

      <:head :if={@form}>
        <div class="mb-s5">
          <.back navigate={~p"/species/#{@species.scientific_name}"}>Back to species</.back>
        </div>

        <.header>
          {if(@live_action == :new, do: "Add source data", else: "Edit source data")}
          <:subtitle>
            <i class="font-serif text-lg">
              Quercus{" "}
              <span
                :if={hybrid_sign?(@species.scientific_name, @species.is_hybrid)}
                class="not-italic"
              >
                &times;
              </span>
              {epithet(@species.scientific_name)}
            </i>
          </:subtitle>
        </.header>
      </:head>

      <div :if={@form}>
        <.form for={@form} id="species-source-form" phx-change="validate" phx-submit="save">
          <div class="flex flex-col gap-s7">
            <%!-- Source selection (new only) --%>
            <section :if={@live_action == :new}>
              <.section_heading>Source</.section_heading>
              <.input
                field={@form[:source_id]}
                type="select"
                label="Data Source"
                options={Enum.map(@available_sources, &{&1.name, &1.id})}
                prompt="Select a source..."
              />
            </section>

            <section :if={@live_action == :edit}>
              <.section_heading>Source</.section_heading>
              <p class="m-0 font-frame text-[15px] font-bold text-ink">
                {@species_source.source.name}
              </p>
            </section>

            <%!-- Descriptive fields --%>
            <section>
              <.section_heading>Morphology & Description</.section_heading>
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
            </section>

            <%!-- Additional info --%>
            <section>
              <.section_heading>Additional Information</.section_heading>
              <div class="space-y-4">
                <.input
                  field={@form[:local_names]}
                  type="text"
                  label="Common Names"
                  placeholder="e.g. white oak, eastern white oak"
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
            </section>

            <%!-- Submit --%>
            <div class="flex flex-wrap items-center justify-end gap-s2 pt-s4 border-t-2 border-ink">
              <.button navigate={~p"/species/#{@species.scientific_name}"}>Cancel</.button>
              <.button type="submit" variant="primary" phx-disable-with="Saving...">
                {if(@live_action == :new, do: "Add source data", else: "Save changes")}
              </.button>
            </div>
          </div>
        </.form>
      </div>
    </.page>
    """
  end
end
