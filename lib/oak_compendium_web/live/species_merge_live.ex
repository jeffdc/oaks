defmodule OakCompendiumWeb.SpeciesMergeLive do
  @moduledoc """
  LiveView for merging (synonymizing) one species into another.

  Displays side-by-side comparison of source (synonym) and target species,
  allows editing target fields, transferring source data, and executing
  the merge in a transaction. Requires authentication.
  """

  use OakCompendiumWeb, :live_view

  alias OakCompendium.Species
  alias OakCompendium.Species.Merge

  @scalar_fields ~w(author conservation_status subgenus section subsection complex parent1 parent2)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Merge Species",
       source_name: nil,
       target_name: nil,
       preview: nil,
       loading: true,
       error: nil,
       edited_fields: %{},
       source_checkboxes: %{},
       references_expanded: true,
       show_confirm: false,
       merging: false,
       merge_error: nil,
       completed_steps: []
     )}
  end

  @impl true
  def handle_params(%{"name" => source_name, "target" => target_name}, _uri, socket) do
    if socket.assigns.authenticated do
      socket =
        assign(socket,
          source_name: source_name,
          target_name: target_name,
          loading: true,
          error: nil
        )

      case Merge.preview_merge(source_name, target_name) do
        {:ok, preview} ->
          edited_fields = initialize_edited_fields(preview.target)

          source_checkboxes =
            preview.synonym_only_sources
            |> Map.new(&{&1.source_id, true})

          {:noreply,
           assign(socket,
             preview: preview,
             edited_fields: edited_fields,
             source_checkboxes: source_checkboxes,
             loading: false,
             page_title: "Merge: #{source_name} \u2192 #{target_name}"
           )}

        {:error, :same_species} ->
          {:noreply,
           assign(socket, loading: false, error: "A species cannot be merged with itself.")}

        {:error, _reason} ->
          {:noreply,
           assign(socket,
             loading: false,
             error: "One or both species could not be found."
           )}
      end
    else
      if connected?(socket) do
        {:noreply,
         socket
         |> put_flash(:error, "Authentication required to access the merge tool.")
         |> push_navigate(to: ~p"/species/#{source_name}")}
      else
        # Static render — don't redirect yet, wait for connected mount
        {:noreply, socket}
      end
    end
  end

  # -- Events --

  @impl true
  def handle_event("copy_field", %{"field" => field}, socket) do
    source = socket.assigns.preview.source
    value = Map.get(source, String.to_existing_atom(field))

    edited = Map.put(socket.assigns.edited_fields, field, value)
    {:noreply, assign(socket, edited_fields: edited)}
  end

  def handle_event("update_field", %{"field" => field, "value" => value}, socket) do
    value = if value == "", do: nil, else: value
    edited = Map.put(socket.assigns.edited_fields, field, value)
    {:noreply, assign(socket, edited_fields: edited)}
  end

  def handle_event("toggle_source", %{"source-id" => id_str}, socket) do
    source_id = String.to_integer(id_str)
    current = Map.get(socket.assigns.source_checkboxes, source_id, true)
    checkboxes = Map.put(socket.assigns.source_checkboxes, source_id, !current)
    {:noreply, assign(socket, source_checkboxes: checkboxes)}
  end

  def handle_event("toggle_references", _params, socket) do
    {:noreply, assign(socket, references_expanded: !socket.assigns.references_expanded)}
  end

  def handle_event("show_confirm", _params, socket) do
    {:noreply, assign(socket, show_confirm: true, merge_error: nil, completed_steps: [])}
  end

  def handle_event("cancel_confirm", _params, socket) do
    {:noreply, assign(socket, show_confirm: false, merge_error: nil)}
  end

  def handle_event("execute_merge", _params, socket) do
    socket = assign(socket, merging: true, merge_error: nil, completed_steps: [])

    include_sources =
      socket.assigns.source_checkboxes
      |> Enum.filter(fn {_id, checked} -> checked end)
      |> Enum.map(fn {id, _} -> id end)

    merge_opts = %{
      "edited_fields" => socket.assigns.edited_fields,
      "include_sources" => include_sources
    }

    case Merge.execute_merge(
           socket.assigns.source_name,
           socket.assigns.target_name,
           merge_opts
         ) do
      {:ok, _target} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Successfully merged #{socket.assigns.source_name} into #{socket.assigns.target_name}."
         )
         |> push_navigate(to: ~p"/species/#{socket.assigns.target_name}")}

      {:error, step, reason} ->
        error_msg = format_merge_error(step, reason)

        {:noreply,
         assign(socket,
           merging: false,
           merge_error: error_msg
         )}
    end
  end

  # -- Render --

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto">
      <.loading_state :if={@loading} />
      <.error_state :if={@error} error={@error} source_name={@source_name} />

      <div :if={@preview && !@loading && !@error}>
        <.merge_header preview={@preview} />
        <.column_headers preview={@preview} source_name={@source_name} target_name={@target_name} />

        <.field_comparison_section
          preview={@preview}
          edited_fields={@edited_fields}
        />

        <.source_transfer_section
          preview={@preview}
          source_checkboxes={@source_checkboxes}
        />

        <.references_section
          preview={@preview}
          expanded={@references_expanded}
        />

        <.warnings_section
          preview={@preview}
          edited_fields={@edited_fields}
          source_checkboxes={@source_checkboxes}
        />

        <.action_bar
          preview={@preview}
          edited_fields={@edited_fields}
          merging={@merging}
          source_name={@source_name}
        />
      </div>

      <.confirm_dialog
        :if={@show_confirm}
        preview={@preview}
        source_checkboxes={@source_checkboxes}
        merging={@merging}
        merge_error={@merge_error}
        completed_steps={@completed_steps}
      />
    </div>
    """
  end

  # -- Loading / Error states --

  defp loading_state(assigns) do
    ~H"""
    <div class="card p-16 text-center">
      <div class="loading-spinner mx-auto mb-4"></div>
      <p style="color: var(--color-text-secondary);">Loading species data...</p>
    </div>
    """
  end

  attr :error, :string, required: true
  attr :source_name, :string, default: nil

  defp error_state(assigns) do
    ~H"""
    <div class="card p-12 text-center">
      <.icon name="hero-exclamation-circle" class="size-16 mx-auto mb-4 text-red-400" />
      <h1 class="text-xl font-bold mb-2">Unable to Load Merge</h1>
      <p class="mb-6" style="color: var(--color-text-secondary);">{@error}</p>
      <.link
        navigate={~p"/list"}
        class="inline-flex items-center gap-2 px-4 py-2 rounded-lg text-white"
        style="background-color: var(--color-forest-600); text-decoration: none;"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to Species List
      </.link>
    </div>
    """
  end

  # -- Header --

  attr :preview, :map, required: true

  defp merge_header(assigns) do
    ~H"""
    <div
      class="card p-6 mb-6"
      style="background: linear-gradient(135deg, var(--color-forest-50) 0%, var(--color-surface) 100%);"
    >
      <h1
        class="text-2xl font-bold flex items-center flex-wrap gap-2"
        style="font-family: var(--font-serif); color: var(--color-forest-900);"
      >
        Merge:
        <span style="color: var(--color-text-secondary);">
          <em>{format_species_name(@preview.source)}</em>
        </span>
        <span style="color: var(--color-text-tertiary);">&rarr;</span>
        <span style="color: var(--color-forest-700);">
          <em>{format_species_name(@preview.target)}</em>
        </span>
      </h1>
      <p class="mt-2" style="color: var(--color-text-secondary);">
        The synonym will be deleted and its data merged into the target species.
      </p>
    </div>
    """
  end

  # -- Column headers --

  attr :preview, :map, required: true
  attr :source_name, :string, required: true
  attr :target_name, :string, required: true

  defp column_headers(assigns) do
    ~H"""
    <div class="hidden md:grid grid-cols-[1fr_2.5rem_1fr] gap-3 mb-4 px-3">
      <div>
        <span
          class="text-xs font-semibold uppercase tracking-wide"
          style="color: var(--color-text-tertiary);"
        >
          Synonym (Read-only)
        </span>
        <div class="mt-1">
          <.link
            navigate={~p"/species/#{@source_name}"}
            style="color: var(--color-forest-600); font-family: var(--font-serif); font-style: italic; text-decoration: none;"
          >
            {format_species_name(@preview.source)}
          </.link>
        </div>
      </div>
      <div></div>
      <div>
        <span
          class="text-xs font-semibold uppercase tracking-wide"
          style="color: var(--color-forest-600);"
        >
          Target (Editable)
        </span>
        <div class="mt-1">
          <.link
            navigate={~p"/species/#{@target_name}"}
            style="color: var(--color-forest-600); font-family: var(--font-serif); font-style: italic; text-decoration: none;"
          >
            {format_species_name(@preview.target)}
          </.link>
        </div>
      </div>
    </div>
    """
  end

  # -- Field comparison --

  attr :preview, :map, required: true
  attr :edited_fields, :map, required: true

  defp field_comparison_section(assigns) do
    ~H"""
    <div class="card p-6 mb-6 space-y-3">
      <h2 class="section-title mb-4">Species Fields</h2>

      <.merge_field_row
        :for={field <- ~w(author conservation_status)}
        field={field}
        label={field_label(field)}
        source_value={Map.get(@preview.source, String.to_existing_atom(field))}
        target_value={Map.get(@edited_fields, field)}
      />

      <h3
        class="text-sm font-semibold mt-4 pt-2 border-t border-base-200"
        style="color: var(--color-text-secondary);"
      >
        Taxonomy
      </h3>

      <.merge_field_row
        :for={field <- ~w(subgenus section subsection complex)}
        field={field}
        label={field_label(field)}
        source_value={Map.get(@preview.source, String.to_existing_atom(field))}
        target_value={Map.get(@edited_fields, field)}
      />

      <div :if={@preview.source.is_hybrid || @preview.target.is_hybrid}>
        <h3
          class="text-sm font-semibold mt-4 pt-2 border-t border-base-200"
          style="color: var(--color-text-secondary);"
        >
          Hybrid Parents
        </h3>

        <.merge_field_row
          :for={field <- ~w(parent1 parent2)}
          field={field}
          label={field_label(field)}
          source_value={Map.get(@preview.source, String.to_existing_atom(field))}
          target_value={Map.get(@edited_fields, field)}
        />
      </div>

      <div :if={@preview.synonyms_to_add != []} class="mt-4 pt-4 border-t border-base-200">
        <h3 class="text-sm font-semibold mb-2" style="color: var(--color-text-secondary);">
          Synonyms to Add
        </h3>
        <div class="flex flex-wrap gap-2">
          <span
            :for={syn <- @preview.synonyms_to_add}
            class="badge badge-forest-light"
          >
            + {syn}
          </span>
        </div>
      </div>
    </div>
    """
  end

  attr :field, :string, required: true
  attr :label, :string, required: true
  attr :source_value, :string, default: nil
  attr :target_value, :string, default: nil

  defp merge_field_row(assigns) do
    differs = normalize_val(assigns.source_value) != normalize_val(assigns.target_value)
    has_source_value = assigns.source_value && String.trim(to_string(assigns.source_value)) != ""
    assigns = assign(assigns, differs: differs, has_source_value: has_source_value)

    ~H"""
    <div class={[
      "rounded-lg p-3",
      @differs && "border-l-3 border-l-[var(--color-forest-500)]",
      @differs && "bg-[color-mix(in_srgb,var(--color-forest-50)_50%,transparent)]"
    ]}>
      <div class="text-sm font-semibold mb-2" style="color: var(--color-text-primary);">
        {@label}
      </div>
      <div class="grid grid-cols-1 md:grid-cols-[1fr_2.5rem_1fr] gap-3 items-start">
        <%!-- Synonym value (read-only) --%>
        <div
          class="px-3 py-2 rounded-lg text-sm min-h-[2.5rem] break-words"
          style="background-color: var(--color-background); border: 1px solid var(--color-border); color: var(--color-text-secondary); opacity: 0.7;"
        >
          {@source_value || raw("&mdash;")}
        </div>

        <%!-- Copy button --%>
        <div class="flex items-center justify-center pt-1">
          <button
            :if={@has_source_value}
            phx-click="copy_field"
            phx-value-field={@field}
            class="flex items-center justify-center w-8 h-8 rounded-md transition-colors"
            style="background-color: var(--color-forest-100); color: var(--color-forest-700); border: 1px solid var(--color-forest-300);"
            title="Copy to target"
          >
            <.icon name="hero-arrow-right" class="size-4" />
          </button>
          <div :if={!@has_source_value} class="w-8 h-8"></div>
        </div>

        <%!-- Target value (editable) --%>
        <input
          type="text"
          value={@target_value || ""}
          phx-blur="update_field"
          phx-value-field={@field}
          class="px-3 py-2 rounded-lg text-sm w-full"
          style="background-color: var(--color-surface); border: 1px solid var(--color-border); color: var(--color-text-primary);"
        />
      </div>
    </div>
    """
  end

  # -- Source transfer section --

  attr :preview, :map, required: true
  attr :source_checkboxes, :map, required: true

  defp source_transfer_section(assigns) do
    synonym_only = assigns.preview.synonym_only_sources

    assigns = assign(assigns, synonym_only: synonym_only)

    ~H"""
    <div :if={@synonym_only != []} class="card p-6 mb-6">
      <h2 class="section-title mb-4">Source Data Transfer</h2>
      <p class="text-sm mb-4" style="color: var(--color-text-secondary);">
        These sources exist only on the synonym. Check the ones you want to transfer to the target.
      </p>

      <div class="space-y-3">
        <div
          :for={ss <- @synonym_only}
          class="p-4 rounded-lg"
          style="background-color: var(--color-background); border: 1px solid var(--color-border);"
        >
          <label class="flex items-start gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={Map.get(@source_checkboxes, ss.source_id, true)}
              phx-click="toggle_source"
              phx-value-source-id={ss.source_id}
              class="mt-1 accent-[var(--color-forest-600)]"
            />
            <div class="flex-1 min-w-0">
              <div class="font-medium text-sm">{source_name(ss)}</div>
              <.source_preview_fields source={ss} />
            </div>
          </label>
        </div>
      </div>
    </div>
    """
  end

  attr :source, :any, required: true

  defp source_preview_fields(assigns) do
    fields =
      [
        {"Range", assigns.source.range},
        {"Growth Habit", assigns.source.growth_habit},
        {"Leaves", assigns.source.leaves},
        {"Fruits", assigns.source.fruits}
      ]
      |> Enum.reject(fn {_label, val} -> is_nil(val) || val == "" end)
      |> Enum.take(3)

    local_names = Species.parse_json_array(assigns.source.local_names)
    assigns = assign(assigns, fields: fields, local_names: local_names)

    ~H"""
    <div class="mt-2 space-y-1 text-xs" style="color: var(--color-text-tertiary);">
      <div :if={@local_names != []}>
        Common names: {Enum.join(@local_names, ", ")}
      </div>
      <div :for={{label, val} <- @fields}>
        <span class="font-medium">{label}:</span> {String.slice(val, 0..80)}{if(
          String.length(val) > 80,
          do: "...",
          else: ""
        )}
      </div>
    </div>
    """
  end

  # -- References section --

  attr :preview, :map, required: true
  attr :expanded, :boolean, required: true

  defp references_section(assigns) do
    refs = assigns.preview.references
    parent_refs = Enum.filter(refs, &(&1.reference_type in ["parent1", "parent2"]))
    hybrid_refs = Enum.filter(refs, &(&1.reference_type == "hybrids"))
    related_refs = Enum.filter(refs, &(&1.reference_type == "closely_related_to"))
    ref_count = length(refs)

    assigns =
      assign(assigns,
        parent_refs: parent_refs,
        hybrid_refs: hybrid_refs,
        related_refs: related_refs,
        ref_count: ref_count
      )

    ~H"""
    <div class="card mb-6" style="border: 1px solid var(--color-border);">
      <button
        phx-click="toggle_references"
        class="flex items-center gap-2 w-full p-4 text-left hover:bg-base-100 transition-colors rounded-xl"
        aria-expanded={to_string(@expanded)}
      >
        <span style="color: var(--color-text-tertiary);">
          <.icon
            name="hero-chevron-right"
            class={["size-4 transition-transform", @expanded && "rotate-90"]}
          />
        </span>
        <h2 class="text-base font-semibold" style="color: var(--color-text-secondary);">
          References to Update
          <span class="font-normal" style="color: var(--color-text-tertiary);">
            ({@ref_count} species)
          </span>
        </h2>
      </button>

      <div :if={@expanded} class="px-4 pb-4 border-t" style="border-color: var(--color-border);">
        <p
          :if={@ref_count == 0}
          class="text-sm italic mt-3"
          style="color: var(--color-text-tertiary);"
        >
          No other species reference "{@preview.source.scientific_name}"
        </p>

        <div :if={@ref_count > 0}>
          <p class="text-sm mt-3 mb-3" style="color: var(--color-text-secondary);">
            These species will be updated to reference "{@preview.target.scientific_name}" instead.
          </p>

          <.reference_group
            :if={@parent_refs != []}
            title="As Parent"
            refs={@parent_refs}
          />
          <.reference_group
            :if={@hybrid_refs != []}
            title="In Hybrids"
            refs={@hybrid_refs}
          />
          <.reference_group
            :if={@related_refs != []}
            title="In Closely Related"
            refs={@related_refs}
          />
        </div>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :refs, :list, required: true

  defp reference_group(assigns) do
    ~H"""
    <div class="mb-3">
      <h3
        class="text-xs font-semibold uppercase tracking-wide mb-2"
        style="color: var(--color-text-secondary);"
      >
        {@title} ({length(@refs)})
      </h3>
      <ul class="space-y-1">
        <li :for={ref <- @refs} class="flex items-baseline gap-2 text-sm">
          <span style="color: var(--color-text-tertiary);">&bull;</span>
          <span style="font-family: var(--font-serif); font-style: italic;">
            {ref.species.scientific_name}
          </span>
          <span
            :if={ref.reference_type in ["parent1", "parent2"]}
            class="text-xs"
            style="color: var(--color-text-tertiary);"
          >
            ({ref.reference_type})
          </span>
        </li>
      </ul>
    </div>
    """
  end

  # -- Warnings --

  attr :preview, :map, required: true
  attr :edited_fields, :map, required: true
  attr :source_checkboxes, :map, required: true

  defp warnings_section(assigns) do
    unchecked_sources =
      assigns.preview.synonym_only_sources
      |> Enum.reject(&Map.get(assigns.source_checkboxes, &1.source_id, true))
      |> Enum.map(&source_name/1)

    self_ref_issues =
      Merge.detect_self_references(
        assigns.preview.target,
        assigns.preview.source.scientific_name
      )

    has_warnings = unchecked_sources != [] || self_ref_issues != []

    assigns =
      assign(assigns,
        unchecked_sources: unchecked_sources,
        self_ref_issues: self_ref_issues,
        has_warnings: has_warnings
      )

    ~H"""
    <div :if={@has_warnings} class="space-y-4 mb-6">
      <.data_loss_warning :if={@unchecked_sources != []} sources={@unchecked_sources} />
      <.self_reference_warning :if={@self_ref_issues != []} issues={@self_ref_issues} />
    </div>
    """
  end

  attr :sources, :list, required: true

  defp data_loss_warning(assigns) do
    ~H"""
    <div
      class="p-4 rounded-xl border-l-4"
      style="background-color: #fef3c7; border-left-color: #f59e0b;"
    >
      <div class="flex items-center gap-2 mb-2">
        <span style="color: #f59e0b;"><.icon name="hero-exclamation-triangle" class="size-5" /></span>
        <span class="font-semibold text-sm" style="color: #92400e;">Data Loss Warning</span>
      </div>
      <p class="text-sm mb-2" style="color: #92400e;">
        The following source data will NOT be transferred and will be permanently lost:
      </p>
      <ul class="list-disc pl-5 text-sm space-y-1" style="color: #92400e;">
        <li :for={name <- @sources} class="font-medium">{name}</li>
      </ul>
      <p class="text-xs mt-2 opacity-80" style="color: #92400e;">
        To include this data, check the source checkboxes above.
      </p>
    </div>
    """
  end

  attr :issues, :list, required: true

  defp self_reference_warning(assigns) do
    ~H"""
    <div
      class="p-4 rounded-xl border-l-4"
      style="background-color: #fef3c7; border-left-color: #f59e0b;"
    >
      <div class="flex items-center gap-2 mb-2">
        <span style="color: #f59e0b;"><.icon name="hero-exclamation-triangle" class="size-5" /></span>
        <span class="font-semibold text-sm" style="color: #92400e;">Self-Reference Warning</span>
      </div>
      <p class="text-sm mb-2" style="color: #92400e;">
        After merge, this species would reference itself:
      </p>
      <div class="space-y-2">
        <div
          :for={issue <- @issues}
          class="p-3 rounded-lg text-sm"
          style="background-color: rgba(255,255,255,0.5);"
        >
          <div style="color: #92400e;">
            "<strong>{issue.field}</strong>" contains "<em style="font-family: var(--font-serif);">{issue.value}</em>"
          </div>
          <div
            class="text-xs mt-1 pl-2 border-l-2"
            style="color: #92400e; opacity: 0.85; border-left-color: #f59e0b;"
          >
            {issue.hint}
          </div>
        </div>
      </div>
    </div>
    """
  end

  # -- Action bar --

  attr :preview, :map, required: true
  attr :edited_fields, :map, required: true
  attr :merging, :boolean, required: true
  attr :source_name, :string, required: true

  defp action_bar(assigns) do
    self_ref_issues =
      Merge.detect_self_references(
        assigns.preview.target,
        assigns.preview.source.scientific_name
      )

    has_self_refs = self_ref_issues != []
    assigns = assign(assigns, has_self_refs: has_self_refs)

    ~H"""
    <div
      class="sticky bottom-0 flex justify-end gap-3 p-4 rounded-xl"
      style="background-color: var(--color-surface); box-shadow: var(--shadow-lg);"
    >
      <.link
        navigate={~p"/species/#{@source_name}"}
        class="px-5 py-2.5 rounded-lg text-sm font-medium transition-colors"
        style="color: var(--color-text-primary); background-color: var(--color-background); border: 1px solid var(--color-border); text-decoration: none;"
      >
        Cancel
      </.link>
      <button
        phx-click="show_confirm"
        disabled={@merging || @has_self_refs}
        class={[
          "px-5 py-2.5 rounded-lg text-sm font-medium text-white transition-colors",
          (@merging || @has_self_refs) && "opacity-50 cursor-not-allowed"
        ]}
        style="background-color: var(--color-forest-600);"
        id="merge-save-btn"
      >
        Save Merge
      </button>
    </div>
    """
  end

  # -- Confirm dialog --

  attr :preview, :map, required: true
  attr :source_checkboxes, :map, required: true
  attr :merging, :boolean, required: true
  attr :merge_error, :string, default: nil
  attr :completed_steps, :list, default: []

  defp confirm_dialog(assigns) do
    synonyms_count = length(assigns.preview.synonyms_to_add)
    ref_count = length(assigns.preview.references)

    sources_to_transfer =
      assigns.preview.synonym_only_sources
      |> Enum.filter(&Map.get(assigns.source_checkboxes, &1.source_id, true))
      |> length()

    assigns =
      assign(assigns,
        synonyms_count: synonyms_count,
        ref_count: ref_count,
        sources_to_transfer: sources_to_transfer
      )

    ~H"""
    <div
      class="fixed inset-0 z-50 flex items-center justify-center p-4"
      style="background-color: rgba(0, 0, 0, 0.5);"
      phx-window-keydown="cancel_confirm"
      phx-key="Escape"
    >
      <div
        class="card p-6 max-w-lg w-full max-h-[90vh] overflow-y-auto"
        phx-click-away="cancel_confirm"
      >
        <%= cond do %>
          <% @merge_error -> %>
            <h2 class="text-lg font-bold text-red-700 mb-4">Merge Failed</h2>
            <div class="p-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-800 mb-4">
              {@merge_error}
            </div>
            <p class="text-sm mb-4" style="color: var(--color-text-secondary);">
              The synonym was NOT deleted. You can fix the issue and try again.
            </p>
            <div class="flex justify-end">
              <button
                phx-click="cancel_confirm"
                class="px-4 py-2 rounded-lg text-sm font-medium"
                style="color: var(--color-text-secondary);"
              >
                Close
              </button>
            </div>
          <% @merging -> %>
            <h2 class="text-lg font-bold mb-4">Merging Species...</h2>
            <div class="flex justify-center mb-4">
              <div class="loading-spinner"></div>
            </div>
          <% true -> %>
            <h2 class="text-lg font-bold mb-4">Confirm Merge</h2>
            <p class="text-sm mb-4" style="color: var(--color-text-secondary);">
              You are about to merge "<em>{format_species_name(@preview.source)}</em>"
              into "<em>{format_species_name(@preview.target)}</em>". This will:
            </p>

            <ul class="space-y-2 mb-4">
              <li :if={@synonyms_count > 0} class="flex items-start gap-2 text-sm">
                <span style="color: var(--color-forest-600);">
                  <.icon name="hero-check" class="size-5 flex-shrink-0" />
                </span>
                <span>Add {@synonyms_count} synonym(s) to {@preview.target.scientific_name}</span>
              </li>
              <li class="flex items-start gap-2 text-sm">
                <span style="color: var(--color-forest-600);">
                  <.icon name="hero-check" class="size-5 flex-shrink-0" />
                </span>
                <span>Update {@preview.target.scientific_name} with merged field values</span>
              </li>
              <li :if={@sources_to_transfer > 0} class="flex items-start gap-2 text-sm">
                <span style="color: var(--color-forest-600);">
                  <.icon name="hero-check" class="size-5 flex-shrink-0" />
                </span>
                <span>Transfer {@sources_to_transfer} source record(s)</span>
              </li>
              <li :if={@ref_count > 0} class="flex items-start gap-2 text-sm">
                <span style="color: var(--color-forest-600);">
                  <.icon name="hero-check" class="size-5 flex-shrink-0" />
                </span>
                <span>
                  Update {@ref_count} other species that reference {@preview.source.scientific_name}
                </span>
              </li>
              <li class="flex items-start gap-2 text-sm text-red-600">
                <.icon name="hero-x-mark" class="size-5 flex-shrink-0" />
                <span>Delete "{format_species_name(@preview.source)}" permanently</span>
              </li>
            </ul>

            <div
              class="flex items-center gap-2 p-3 rounded-lg mb-4"
              style="background-color: rgba(234, 179, 8, 0.1);"
            >
              <span style="color: #ca8a04;">
                <.icon name="hero-exclamation-triangle" class="size-5 flex-shrink-0" />
              </span>
              <span class="text-sm font-medium" style="color: #a16207;">
                This action cannot be undone.
              </span>
            </div>

            <div class="flex justify-end gap-3">
              <button
                phx-click="cancel_confirm"
                class="px-4 py-2 rounded-lg text-sm font-medium"
                style="color: var(--color-text-secondary);"
              >
                Cancel
              </button>
              <button
                phx-click="execute_merge"
                class="px-4 py-2 rounded-lg text-sm font-medium text-white bg-red-600 hover:bg-red-700 transition-colors"
                id="confirm-merge-btn"
              >
                Confirm Merge
              </button>
            </div>
        <% end %>
      </div>
    </div>
    """
  end

  # -- Helpers --

  defp initialize_edited_fields(target) do
    Map.new(@scalar_fields, fn field ->
      {field, Map.get(target, String.to_existing_atom(field))}
    end)
  end

  defp format_species_name(species) do
    name = species.scientific_name

    if species.is_hybrid && !String.starts_with?(name, "\u00D7") do
      "\u00D7 #{name}"
    else
      name
    end
  end

  defp field_label("author"), do: "Author"
  defp field_label("conservation_status"), do: "Conservation Status"
  defp field_label("subgenus"), do: "Subgenus"
  defp field_label("section"), do: "Section"
  defp field_label("subsection"), do: "Subsection"
  defp field_label("complex"), do: "Complex"
  defp field_label("parent1"), do: "Parent 1"
  defp field_label("parent2"), do: "Parent 2"
  defp field_label(other), do: other

  defp source_name(species_source) do
    if Ecto.assoc_loaded?(species_source.source) do
      species_source.source.name
    else
      "Source #{species_source.source_id}"
    end
  end

  defp normalize_val(nil), do: ""
  defp normalize_val(val) when is_binary(val), do: String.trim(val)
  defp normalize_val(val), do: val

  defp format_merge_error(step, %Ecto.Changeset{} = changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    "Step #{step} failed: #{inspect(errors)}"
  end

  defp format_merge_error(step, reason) do
    "Step #{step} failed: #{inspect(reason)}"
  end
end
