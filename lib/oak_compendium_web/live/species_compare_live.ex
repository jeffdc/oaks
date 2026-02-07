defmodule OakCompendiumWeb.SpeciesCompareLive do
  @moduledoc """
  LiveView for side-by-side comparison of multiple oak species.

  Allows users to compare taxonomy, morphology, and descriptive data
  across 2-4 species simultaneously. Species selection is URL-based
  (shareable/bookmarkable).
  """

  use OakCompendiumWeb, :live_view

  alias OakCompendium.Species

  @max_species 4

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Compare Species",
       species_list: [],
       not_found: [],
       search_query: "",
       search_results: [],
       show_picker: false,
       max_species: @max_species
     )}
  end

  @impl true
  def handle_params(%{"name" => names_param}, _uri, socket) do
    names =
      names_param
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    if Enum.empty?(names) do
      {:noreply, assign(socket, species_list: [], not_found: [])}
    else
      load_species(socket, names)
    end
  end

  # -- Events --

  @impl true
  def handle_event("show_picker", _params, socket) do
    {:noreply, assign(socket, show_picker: true, search_query: "", search_results: [])}
  end

  def handle_event("close_picker", _params, socket) do
    {:noreply, assign(socket, show_picker: false)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    if String.length(String.trim(query)) >= 2 do
      results = Species.search_species(query, 10)

      # Filter out species already in the comparison
      current_names = Enum.map(socket.assigns.species_list, & &1.scientific_name)
      results = Enum.reject(results, &(&1.scientific_name in current_names))

      {:noreply, assign(socket, search_query: query, search_results: results)}
    else
      {:noreply, assign(socket, search_query: query, search_results: [])}
    end
  end

  def handle_event("add_species", %{"name" => name}, socket) do
    current_names =
      socket.assigns.species_list
      |> Enum.map(& &1.scientific_name)

    if length(current_names) >= @max_species do
      {:noreply,
       socket
       |> put_flash(:error, "Maximum of #{@max_species} species can be compared at once.")
       |> assign(show_picker: false)}
    else
      new_names = current_names ++ [name]
      path = ~p"/compare/#{Enum.join(new_names, ",")}"

      {:noreply,
       socket
       |> assign(show_picker: false)
       |> push_patch(to: path)}
    end
  end

  def handle_event("remove_species", %{"name" => name}, socket) do
    remaining_names =
      socket.assigns.species_list
      |> Enum.map(& &1.scientific_name)
      |> Enum.reject(&(&1 == name))

    if Enum.empty?(remaining_names) do
      {:noreply, push_navigate(socket, to: ~p"/list")}
    else
      path = ~p"/compare/#{Enum.join(remaining_names, ",")}"
      {:noreply, push_patch(socket, to: path)}
    end
  end

  # -- Helpers --

  defp load_species(socket, names) do
    results =
      Enum.map(names, fn name ->
        {name, Species.get_species_full(name)}
      end)

    species_list = for {_name, sp} <- results, sp != nil, do: sp
    not_found = for {name, nil} <- results, do: name

    {:noreply,
     assign(socket,
       species_list: species_list,
       not_found: not_found,
       page_title: build_title(species_list)
     )}
  end

  defp build_title([]), do: "Compare Species"
  defp build_title([sp]), do: "Compare Quercus #{sp.scientific_name}"

  defp build_title(species) do
    names = Enum.map(species, & &1.scientific_name) |> Enum.take(2)
    "Compare #{Enum.join(names, " vs ")}"
  end

  # Get preferred source for a species, or nil if no sources
  defp preferred_source(species) do
    Enum.find(species.species_sources, & &1.is_preferred) ||
      List.first(species.species_sources)
  end

  # Format species name with hybrid indicator
  defp format_species_name(species) do
    if species.is_hybrid do
      "Quercus × #{species.scientific_name}"
    else
      "Quercus #{species.scientific_name}"
    end
  end

  # Get field value, returning nil if not present
  defp get_field(species, :local_names) do
    source = preferred_source(species)

    if source do
      # Parse JSON array string to list
      Species.parse_json_array(source.local_names)
    else
      nil
    end
  end

  defp get_field(species, field)
       when field in [
              :range,
              :growth_habit,
              :leaves,
              :fruits,
              :flowers,
              :bark,
              :twigs,
              :buds,
              :hardiness_habitat,
              :miscellaneous
            ] do
    source = preferred_source(species)
    if source, do: Map.get(source, field), else: nil
  end

  defp get_field(species, field) do
    Map.get(species, field)
  end

  # Check if any species has data for this field
  defp field_has_data?(species_list, field) do
    Enum.any?(species_list, fn sp ->
      case get_field(sp, field) do
        nil -> false
        "" -> false
        [] -> false
        _ -> true
      end
    end)
  end

  # Render field value based on type
  defp render_field_value(_assigns, value, :array) when is_list(value) do
    case value do
      [] -> nil
      list -> Enum.join(list, ", ")
    end
  end

  defp render_field_value(_assigns, value, type) when type in [:markdown, :text] do
    if value && String.trim(value) != "" do
      value
    else
      nil
    end
  end

  defp render_field_value(_assigns, _value, _type), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 py-6">
      <!-- Header -->
      <div class="mb-6">
        <.link
          navigate={~p"/list"}
          class="inline-flex items-center gap-2 text-sm text-forest-700 hover:text-forest-500 mb-3"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to species list
        </.link>
        <h1 class="text-3xl font-bold font-serif text-forest-900">
          Compare Oak Species
        </h1>
      </div>
      
    <!-- Error messages for species not found -->
      <%= if @not_found != [] do %>
        <div class="alert alert-warning mb-4">
          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
          <div>
            <p class="font-semibold">Species not found:</p>
            <ul class="list-disc list-inside">
              <%= for name <- @not_found do %>
                <li><em>Quercus {name}</em></li>
              <% end %>
            </ul>
          </div>
        </div>
      <% end %>

      <%= if @species_list == [] do %>
        <!-- Empty state -->
        <div class="text-center py-16">
          <p class="text-base-content/60 mb-4">
            No species selected for comparison.
          </p>
          <.link navigate={~p"/list"} class="btn btn-primary">
            Browse Species
          </.link>
        </div>
      <% else %>
        <!-- Species picker button -->
        <div class="mb-4 flex justify-between items-center">
          <p class="text-sm text-base-content/70">
            Comparing {length(@species_list)} {if length(@species_list) == 1,
              do: "species",
              else: "species"}
          </p>
          <%= if length(@species_list) < @max_species do %>
            <button
              type="button"
              phx-click="show_picker"
              class="btn btn-sm btn-outline"
            >
              <.icon name="hero-plus" class="w-4 h-4" /> Add species
            </button>
          <% end %>
        </div>
        
    <!-- Comparison table -->
        <div class="overflow-x-auto">
          <table class="table table-zebra w-full">
            <thead>
              <tr>
                <th class="bg-forest-100 text-forest-800">Field</th>
                <%= for species <- @species_list do %>
                  <th class="bg-forest-100 text-forest-800">
                    <div class="flex items-center justify-between gap-2">
                      <div>
                        <div class="font-semibold">
                          {format_species_name(species)}
                        </div>
                        <%= if species.author do %>
                          <div class="text-xs font-normal opacity-70">
                            {species.author}
                          </div>
                        <% end %>
                      </div>
                      <button
                        type="button"
                        phx-click="remove_species"
                        phx-value-name={species.scientific_name}
                        class="btn btn-ghost btn-xs"
                        title="Remove from comparison"
                      >
                        <.icon name="hero-x-mark" class="w-4 h-4" />
                      </button>
                    </div>
                  </th>
                <% end %>
              </tr>
            </thead>
            <tbody>
              <!-- Taxonomy fields -->
              <%= if field_has_data?(@species_list, :subgenus) do %>
                <tr>
                  <td class="font-semibold">Subgenus</td>
                  <%= for species <- @species_list do %>
                    <td>{get_field(species, :subgenus) || "—"}</td>
                  <% end %>
                </tr>
              <% end %>

              <%= if field_has_data?(@species_list, :section) do %>
                <tr>
                  <td class="font-semibold">Section</td>
                  <%= for species <- @species_list do %>
                    <td>{get_field(species, :section) || "—"}</td>
                  <% end %>
                </tr>
              <% end %>

              <%= if field_has_data?(@species_list, :subsection) do %>
                <tr>
                  <td class="font-semibold">Subsection</td>
                  <%= for species <- @species_list do %>
                    <td>{get_field(species, :subsection) || "—"}</td>
                  <% end %>
                </tr>
              <% end %>

              <%= if field_has_data?(@species_list, :complex) do %>
                <tr>
                  <td class="font-semibold">Complex</td>
                  <%= for species <- @species_list do %>
                    <td>{get_field(species, :complex) || "—"}</td>
                  <% end %>
                </tr>
              <% end %>

              <%= if field_has_data?(@species_list, :conservation_status) do %>
                <tr>
                  <td class="font-semibold">Conservation Status</td>
                  <%= for species <- @species_list do %>
                    <td>{get_field(species, :conservation_status) || "—"}</td>
                  <% end %>
                </tr>
              <% end %>
              
    <!-- Hybrid parent info -->
              <%= if Enum.any?(@species_list, & &1.is_hybrid) do %>
                <tr>
                  <td class="font-semibold">Hybrid Parents</td>
                  <%= for species <- @species_list do %>
                    <td>
                      <%= if species.is_hybrid and (species.parent1 or species.parent2) do %>
                        <%= if species.parent1 do %>
                          <.link navigate={~p"/species/#{species.parent1}"} class="link">
                            {species.parent1}
                          </.link>
                        <% end %>
                        {if species.parent1 and species.parent2, do: " × "}
                        <%= if species.parent2 do %>
                          <.link navigate={~p"/species/#{species.parent2}"} class="link">
                            {species.parent2}
                          </.link>
                        <% end %>
                      <% else %>
                        —
                      <% end %>
                    </td>
                  <% end %>
                </tr>
              <% end %>
              
    <!-- Descriptive fields from preferred source -->
              <%= if field_has_data?(@species_list, :local_names) do %>
                <tr>
                  <td class="font-semibold">Common Names</td>
                  <%= for species <- @species_list do %>
                    <td>
                      {render_field_value(assigns, get_field(species, :local_names), :array) || "—"}
                    </td>
                  <% end %>
                </tr>
              <% end %>

              <%= if field_has_data?(@species_list, :range) do %>
                <tr>
                  <td class="font-semibold">Geographic Range</td>
                  <%= for species <- @species_list do %>
                    <td class="prose prose-sm max-w-none">
                      {render_field_value(assigns, get_field(species, :range), :markdown) || "—"}
                    </td>
                  <% end %>
                </tr>
              <% end %>

              <%= if field_has_data?(@species_list, :growth_habit) do %>
                <tr>
                  <td class="font-semibold">Growth Habit</td>
                  <%= for species <- @species_list do %>
                    <td class="prose prose-sm max-w-none">
                      {render_field_value(assigns, get_field(species, :growth_habit), :markdown) ||
                        "—"}
                    </td>
                  <% end %>
                </tr>
              <% end %>

              <%= if field_has_data?(@species_list, :leaves) do %>
                <tr>
                  <td class="font-semibold">Leaves</td>
                  <%= for species <- @species_list do %>
                    <td class="prose prose-sm max-w-none">
                      {render_field_value(assigns, get_field(species, :leaves), :markdown) || "—"}
                    </td>
                  <% end %>
                </tr>
              <% end %>

              <%= if field_has_data?(@species_list, :fruits) do %>
                <tr>
                  <td class="font-semibold">Fruits (Acorns)</td>
                  <%= for species <- @species_list do %>
                    <td class="prose prose-sm max-w-none">
                      {render_field_value(assigns, get_field(species, :fruits), :markdown) || "—"}
                    </td>
                  <% end %>
                </tr>
              <% end %>

              <%= if field_has_data?(@species_list, :bark) do %>
                <tr>
                  <td class="font-semibold">Bark</td>
                  <%= for species <- @species_list do %>
                    <td class="prose prose-sm max-w-none">
                      {render_field_value(assigns, get_field(species, :bark), :markdown) || "—"}
                    </td>
                  <% end %>
                </tr>
              <% end %>

              <%= if field_has_data?(@species_list, :twigs) do %>
                <tr>
                  <td class="font-semibold">Twigs</td>
                  <%= for species <- @species_list do %>
                    <td class="prose prose-sm max-w-none">
                      {render_field_value(assigns, get_field(species, :twigs), :markdown) || "—"}
                    </td>
                  <% end %>
                </tr>
              <% end %>

              <%= if field_has_data?(@species_list, :buds) do %>
                <tr>
                  <td class="font-semibold">Buds</td>
                  <%= for species <- @species_list do %>
                    <td class="prose prose-sm max-w-none">
                      {render_field_value(assigns, get_field(species, :buds), :markdown) || "—"}
                    </td>
                  <% end %>
                </tr>
              <% end %>

              <%= if field_has_data?(@species_list, :hardiness_habitat) do %>
                <tr>
                  <td class="font-semibold">Hardiness & Habitat</td>
                  <%= for species <- @species_list do %>
                    <td class="prose prose-sm max-w-none">
                      {render_field_value(assigns, get_field(species, :hardiness_habitat), :markdown) ||
                        "—"}
                    </td>
                  <% end %>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
      
    <!-- Species picker modal -->
      <%= if @show_picker do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">Add Species to Comparison</h3>
            
    <!-- Search input -->
            <input
              type="text"
              placeholder="Search species..."
              class="input input-bordered w-full mb-4"
              value={@search_query}
              phx-change="search"
              name="query"
              autofocus
            />
            
    <!-- Search results -->
            <div class="max-h-64 overflow-y-auto">
              <%= if @search_query == "" or String.length(@search_query) < 2 do %>
                <p class="text-sm text-base-content/60 text-center py-4">
                  Type at least 2 characters to search
                </p>
              <% else %>
                <%= if @search_results == [] do %>
                  <p class="text-sm text-base-content/60 text-center py-4">
                    No species found matching "{@search_query}"
                  </p>
                <% else %>
                  <ul class="menu">
                    <%= for species <- @search_results do %>
                      <li>
                        <button
                          type="button"
                          phx-click="add_species"
                          phx-value-name={species.scientific_name}
                          class="justify-start"
                        >
                          <span class="font-italic">
                            <%= if species.is_hybrid do %>
                              × {species.scientific_name}
                            <% else %>
                              {species.scientific_name}
                            <% end %>
                          </span>
                          <%= if species.author do %>
                            <span class="text-xs opacity-70">{species.author}</span>
                          <% end %>
                        </button>
                      </li>
                    <% end %>
                  </ul>
                <% end %>
              <% end %>
            </div>
            
    <!-- Modal actions -->
            <div class="modal-action">
              <button type="button" phx-click="close_picker" class="btn">
                Close
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
