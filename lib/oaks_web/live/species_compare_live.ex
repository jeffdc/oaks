defmodule OaksWeb.SpeciesCompareLive do
  @moduledoc """
  LiveView for comparing data from multiple sources for a single species.

  Displays a side-by-side grid of source data with toggleable source selection,
  matching the V1 SourceComparison component behavior.
  """

  use OaksWeb, :live_view

  alias Oaks.Markdown
  alias Oaks.Species
  alias OaksWeb.Params

  @max_sources 4

  @fields [
    %{key: :local_names, label: "Common Names", type: :array},
    %{key: :range, label: "Geographic Range", type: :markdown},
    %{key: :growth_habit, label: "Growth Habit", type: :markdown},
    %{key: :leaves, label: "Leaves", type: :markdown},
    %{key: :fruits, label: "Fruits (Acorns)", type: :markdown},
    %{key: :flowers, label: "Flowers", type: :markdown},
    %{key: :bark, label: "Bark", type: :markdown},
    %{key: :twigs, label: "Twigs", type: :markdown},
    %{key: :buds, label: "Buds", type: :markdown},
    %{key: :hardiness_habitat, label: "Hardiness & Habitat", type: :markdown},
    %{key: :miscellaneous, label: "Additional Information", type: :markdown}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Compare Sources",
       species: nil,
       not_found: false,
       all_sources: [],
       selected_ids: [],
       fields: @fields
     )}
  end

  @impl true
  def handle_params(%{"name" => name}, _uri, socket) do
    case Species.get_species_full(name) do
      nil ->
        case Species.find_synonym(name) do
          nil ->
            {:noreply,
             assign(socket,
               species: nil,
               not_found: true,
               page_title: "Species Not Found"
             )}

          canonical ->
            {:noreply,
             push_navigate(socket, to: ~p"/species/#{canonical.scientific_name}/compare")}
        end

      species ->
        sources = species.species_sources
        # Default: select up to 3 sources
        default_ids = sources |> Enum.take(3) |> Enum.map(& &1.source.id)

        {:noreply,
         assign(socket,
           species: species,
           not_found: false,
           all_sources: sources,
           selected_ids: default_ids,
           page_title: "Compare Sources — Quercus #{species.scientific_name}"
         )}
    end
  end

  @impl true
  def handle_event("toggle_source", %{"id" => id_str}, socket) do
    source_id = Params.int(id_str)
    selected = socket.assigns.selected_ids

    new_selected =
      if source_id in selected do
        # Don't deselect if only one remaining
        if length(selected) > 1,
          do: List.delete(selected, source_id),
          else: selected
      else
        # Limit to max sources
        if length(selected) < @max_sources,
          do: selected ++ [source_id],
          else: selected
      end

    {:noreply, assign(socket, selected_ids: new_selected)}
  end

  def handle_event("toggle_source", _params, socket), do: {:noreply, socket}

  # -- Render --

  @impl true
  def render(assigns) do
    selected_sources =
      Enum.filter(assigns.all_sources, &(&1.source.id in assigns.selected_ids))

    assigns = assign(assigns, :selected_sources, selected_sources)

    ~H"""
    <.page>
      <div :if={@not_found} class="source-comparison-missing">
        <.back navigate={~p"/species"}>Back to Species List</.back>
        <.header>
          Species Not Found
          <:subtitle>Could not find the requested species.</:subtitle>
        </.header>
      </div>

      <div :if={@species} class="source-comparison-card">
        <div class="source-comparison">
          <.comparison_header species={@species} />

          <.source_picker
            :if={@all_sources != []}
            sources={@all_sources}
            selected_ids={@selected_ids}
          />

          <.comparison_grid
            :if={@selected_sources != []}
            sources={@selected_sources}
            fields={@fields}
          />

          <p :if={@all_sources == []} class="source-comparison-empty">
            No source data available for this species.
          </p>
        </div>
      </div>
    </.page>
    """
  end

  # -- Components --

  attr :species, :any, required: true

  defp comparison_header(assigns) do
    ~H"""
    <header class="comparison-header">
      <.back navigate={~p"/species/#{@species.scientific_name}"}>Back to species</.back>
      <h1 class="comparison-title">
        <span class="comparison-title-prefix">Compare sources for</span>
        <.species_binomial species={@species} />
      </h1>
    </header>
    """
  end

  attr :sources, :list, required: true
  attr :selected_ids, :list, required: true

  defp source_picker(assigns) do
    ~H"""
    <div class="source-picker">
      <span class="source-picker-label">Select sources to compare:</span>
      <div class="source-picker-chips">
        <button
          :for={ss <- @sources}
          type="button"
          phx-click="toggle_source"
          phx-value-id={ss.source.id}
          class={["source-chip", ss.source.id in @selected_ids && "selected"]}
          aria-pressed={to_string(ss.source.id in @selected_ids)}
        >
          {ss.source.name}
          <span :if={ss.is_preferred} class="source-chip-note">preferred</span>
        </button>
      </div>
      <span :if={length(@sources) > 4} class="source-picker-hint">
        Up to 4 at once
      </span>
    </div>
    """
  end

  attr :sources, :list, required: true
  attr :fields, :list, required: true

  defp comparison_grid(assigns) do
    column_count = length(assigns.sources)
    assigns = assign(assigns, :column_count, column_count)

    ~H"""
    <div class="comparison-grid" style={"--column-count: #{@column_count}"}>
      <%!-- Column headers --%>
      <div class="comparison-grid-header">
        <div class="comparison-field-label comparison-header-cell">Field</div>
        <div :for={ss <- @sources} class="comparison-source-header comparison-header-cell">
          <a
            :if={ss.source.url}
            href={ss.source.url}
            target="_blank"
            rel="noopener noreferrer"
            class="comparison-source-name"
            title="Visit source"
          >
            {ss.source.name}
          </a>
          <span :if={!ss.source.url} class="comparison-source-name">{ss.source.name}</span>
          <span :if={ss.is_preferred} class="comparison-preferred-badge">Preferred source</span>
        </div>
      </div>

      <%!-- Field rows --%>
      <%= for field <- @fields do %>
        <.comparison_row :if={field_has_data?(@sources, field)} field={field} sources={@sources} />
      <% end %>
    </div>
    """
  end

  attr :field, :map, required: true
  attr :sources, :list, required: true

  defp comparison_row(assigns) do
    ~H"""
    <div class="comparison-row">
      <div class="comparison-field-label">{@field.label}</div>
      <div :for={ss <- @sources} class="comparison-value-cell" data-source={ss.source.name}>
        <.render_cell source={ss} field={@field} />
      </div>
    </div>
    """
  end

  attr :source, :any, required: true
  attr :field, :map, required: true

  defp render_cell(assigns) do
    value = get_source_value(assigns.source, assigns.field)
    assigns = assign(assigns, :value, value)

    ~H"""
    <%= case @value do %>
      <% nil -> %>
        <.no_statement />
      <% {:text, text} -> %>
        <div class="comparison-text-content">{text}</div>
      <% {:html, html} -> %>
        <div class="prose-content prose-content-compact">{raw(html)}</div>
    <% end %>
    """
  end

  attr :species, :any, required: true

  # The whole binomial is italic; a named hybrid's sign stays roman.
  defp species_binomial(assigns) do
    assigns =
      assign(
        assigns,
        :sign,
        hybrid_sign?(assigns.species.scientific_name, assigns.species.is_hybrid)
      )

    ~H"""
    <span class="species-name">
      <i :if={!@sign}>Quercus {epithet(@species.scientific_name)}</i>
      <span :if={@sign}><i>Quercus</i> &times; <i>{epithet(@species.scientific_name)}</i></span>
    </span>
    """
  end

  # -- Data helpers --

  defp get_source_value(species_source, %{key: :local_names, type: :array}) do
    names = Species.parse_name_list(species_source.local_names)

    if names == [],
      do: nil,
      else: {:text, Enum.join(names, ", ")}
  end

  defp get_source_value(species_source, %{type: :markdown} = field) do
    value = Map.get(species_source, field.key)

    if value && String.trim(value) != "" do
      {:html, Markdown.render_html(value)}
    else
      nil
    end
  end

  defp field_has_data?(sources, field) do
    Enum.any?(sources, fn ss ->
      get_source_value(ss, field) != nil
    end)
  end
end
