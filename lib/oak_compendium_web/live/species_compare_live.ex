defmodule OakCompendiumWeb.SpeciesCompareLive do
  @moduledoc """
  LiveView for comparing data from multiple sources for a single species.

  Displays a side-by-side grid of source data with toggleable source selection,
  matching the V1 SourceComparison component behavior.
  """

  use OakCompendiumWeb, :live_view

  alias OakCompendium.Markdown
  alias OakCompendium.Species

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
        {:noreply,
         assign(socket,
           species: nil,
           not_found: true,
           page_title: "Species Not Found"
         )}

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
    source_id = String.to_integer(id_str)
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

  # -- Render --

  @impl true
  def render(assigns) do
    selected_sources =
      Enum.filter(assigns.all_sources, &(&1.source.id in assigns.selected_ids))

    assigns = assign(assigns, :selected_sources, selected_sources)

    ~H"""
    <div class="source-comparison-page">
      <div :if={@not_found} class="text-center py-16">
        <h1 class="text-2xl font-bold" style="color: var(--color-text-primary);">
          Species Not Found
        </h1>
        <p class="mt-2" style="color: var(--color-text-secondary);">
          Could not find the requested species.
        </p>
        <.link
          navigate={~p"/list"}
          class="inline-flex items-center gap-2 mt-4 px-4 py-2 rounded-lg text-white"
          style="background-color: var(--color-forest-600); text-decoration: none;"
        >
          <.icon name="hero-arrow-left" class="size-4" /> Back to Species List
        </.link>
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

          <div
            :if={@all_sources == []}
            class="source-comparison-empty"
          >
            <p>No source data available for this species.</p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # -- Components --

  attr :species, :any, required: true

  defp comparison_header(assigns) do
    ~H"""
    <header class="comparison-header">
      <.link
        navigate={~p"/species/#{@species.scientific_name}"}
        class="comparison-back-link"
      >
        <svg class="size-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
        </svg>
        Back to species
      </.link>
      <h1 class="comparison-title">
        <span class="comparison-title-prefix">Compare sources for</span>
        <em class="species-name">{format_species_name(@species)}</em>
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
        >
          {ss.source.name}
          <span :if={ss.is_preferred} class="source-chip-star" title="Preferred source">
            &#9733;
          </span>
        </button>
      </div>
      <span :if={length(@sources) > 4} class="source-picker-hint">
        (max 4 sources)
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
          <span class="comparison-source-name">{ss.source.name}</span>
          <span :if={ss.is_preferred} class="comparison-preferred-badge">&#9733;</span>
          <a
            :if={ss.source.url}
            href={ss.source.url}
            target="_blank"
            rel="noopener noreferrer"
            class="comparison-source-link"
            title="Visit source"
          >
            <svg
              class="size-3.5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
              />
            </svg>
          </a>
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
        <span class="comparison-no-data">&mdash;</span>
      <% {:text, text} -> %>
        <div class="comparison-text-content">{text}</div>
      <% {:html, html} -> %>
        <div class="prose-content prose-content-compact">{raw(html)}</div>
    <% end %>
    """
  end

  # -- Data helpers --

  defp get_source_value(species_source, %{key: :local_names, type: :array}) do
    names = Species.parse_json_array(species_source.local_names)

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

  defp format_species_name(species) do
    if species.is_hybrid do
      "Quercus \u00D7 #{species.scientific_name}"
    else
      "Quercus #{species.scientific_name}"
    end
  end
end
