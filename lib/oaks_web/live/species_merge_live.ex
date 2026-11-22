defmodule OaksWeb.SpeciesMergeLive do
  @moduledoc """
  LiveView for merging (synonymizing) one species into another.

  Displays side-by-side comparison of source (synonym) and target species,
  allows editing target fields, transferring source data, and executing
  the merge in a transaction. Requires authentication.
  """

  use OaksWeb, :live_view

  alias Oaks.Species
  alias Oaks.Species.Merge
  alias OaksWeb.Params

  @scalar_fields ~w(author conservation_status subgenus section subsection complex parent1 parent2)
  # Fields whose values are scientific names, set italic when shown as text.
  @name_fields ~w(subgenus section subsection complex parent1 parent2)

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
    if socket.assigns[:current_scope] do
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
      {:noreply,
       socket
       |> put_flash(:error, "Authentication required to access the merge tool.")
       |> push_navigate(to: ~p"/species/#{source_name}")}
    end
  end

  # -- Events --

  @impl true
  def handle_event("copy_field", %{"field" => field}, socket) when field in @scalar_fields do
    source = socket.assigns.preview.source
    value = Map.get(source, String.to_existing_atom(field))

    edited = Map.put(socket.assigns.edited_fields, field, value)
    {:noreply, assign(socket, edited_fields: edited)}
  end

  def handle_event("update_field", %{"field" => field, "value" => value}, socket)
      when field in @scalar_fields and is_binary(value) do
    value = if value == "", do: nil, else: value
    edited = Map.put(socket.assigns.edited_fields, field, value)
    {:noreply, assign(socket, edited_fields: edited)}
  end

  def handle_event(event, _params, socket) when event in ["copy_field", "update_field"] do
    {:noreply, socket}
  end

  def handle_event("toggle_source", %{"source-id" => id_str}, socket) do
    case Params.int(id_str) do
      nil ->
        {:noreply, socket}

      source_id ->
        current = Map.get(socket.assigns.source_checkboxes, source_id, true)
        checkboxes = Map.put(socket.assigns.source_checkboxes, source_id, !current)
        {:noreply, assign(socket, source_checkboxes: checkboxes)}
    end
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
    if socket.assigns[:current_scope] do
      execute_merge(socket)
    else
      {:noreply, socket}
    end
  end

  defp execute_merge(socket) do
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
    <.page>
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
    </.page>
    """
  end

  # -- Loading / Error states --

  defp loading_state(assigns) do
    ~H"""
    <div class="card p-16 text-center">
      <div class="loading-spinner mx-auto mb-4"></div>
      <p class="merge-muted">Loading species data...</p>
    </div>
    """
  end

  attr :error, :string, required: true
  attr :source_name, :string, default: nil

  defp error_state(assigns) do
    ~H"""
    <div class="merge-error-state">
      <.back navigate={~p"/species"}>Back to Species List</.back>
      <.header>
        Unable to Load Merge
        <:subtitle>{@error}</:subtitle>
      </.header>
    </div>
    """
  end

  # -- Header --

  attr :preview, :map, required: true

  defp merge_header(assigns) do
    ~H"""
    <.header class="merge-title">
      Merge:
      <.sci_name
        name={@preview.source.scientific_name}
        hybrid={@preview.source.is_hybrid}
        size="display"
      />
      <span class="merge-title-arrow">&rarr;</span>
      <.sci_name
        name={@preview.target.scientific_name}
        hybrid={@preview.target.is_hybrid}
        size="display"
      />
      <:subtitle>The synonym will be deleted and its data merged into the target species.</:subtitle>
    </.header>
    """
  end

  # -- Column headers --

  attr :preview, :map, required: true
  attr :source_name, :string, required: true
  attr :target_name, :string, required: true

  defp column_headers(assigns) do
    ~H"""
    <div class="merge-cols">
      <div></div>
      <div class="merge-col">
        <.link navigate={~p"/species/#{@source_name}"} class="merge-col-name">
          <.sci_name
            name={@preview.source.scientific_name}
            hybrid={@preview.source.is_hybrid}
            abbreviate
            size="headline"
          />
        </.link>
        <span class="merge-col-role">Synonym, read-only</span>
      </div>
      <div></div>
      <div class="merge-col">
        <.link navigate={~p"/species/#{@target_name}"} class="merge-col-name">
          <.sci_name
            name={@preview.target.scientific_name}
            hybrid={@preview.target.is_hybrid}
            abbreviate
            size="headline"
          />
        </.link>
        <span class="merge-col-role">Target, editable</span>
      </div>
    </div>
    """
  end

  # -- Field comparison --

  attr :preview, :map, required: true
  attr :edited_fields, :map, required: true

  defp field_comparison_section(assigns) do
    ~H"""
    <div class="card mb-6">
      <h2 class="section-title">Species Fields</h2>

      <.merge_field_row
        :for={field <- ~w(author conservation_status)}
        field={field}
        label={field_label(field)}
        source_value={Map.get(@preview.source, String.to_existing_atom(field))}
        target_value={Map.get(@edited_fields, field)}
      />

      <h3 class="merge-subhead">Taxonomy</h3>

      <.merge_field_row
        :for={field <- ~w(subgenus section subsection complex)}
        field={field}
        label={field_label(field)}
        source_value={Map.get(@preview.source, String.to_existing_atom(field))}
        target_value={Map.get(@edited_fields, field)}
      />

      <div :if={@preview.source.is_hybrid || @preview.target.is_hybrid}>
        <h3 class="merge-subhead">Hybrid Parents</h3>

        <.merge_field_row
          :for={field <- ~w(parent1 parent2)}
          field={field}
          label={field_label(field)}
          source_value={Map.get(@preview.source, String.to_existing_atom(field))}
          target_value={Map.get(@edited_fields, field)}
        />
      </div>

      <div :if={@preview.synonyms_to_add != []}>
        <h3 class="merge-subhead">Synonyms to Add</h3>
        <p class="merge-synonyms">
          <span :for={{name, i} <- Enum.with_index(@preview.synonyms_to_add, 1)}><.sci_name
            name={name}
            genus={nil}
          />{if i < length(@preview.synonyms_to_add), do: ", "}</span>
        </p>
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

    assigns =
      assign(assigns,
        differs: differs,
        has_source_value: has_source_value,
        name_fields: @name_fields
      )

    ~H"""
    <div class={["merge-row", @differs && "merge-row-differs"]}>
      <div class="merge-row-label">
        <span>{@label}</span>
        <.standing_mark :if={@differs} standing="differs">differs</.standing_mark>
      </div>

      <%!-- Synonym value (read-only) --%>
      <div class="merge-row-source" data-label="Synonym">
        <%= cond do %>
          <% !@has_source_value -> %>
            &mdash;
          <% @field in @name_fields -> %>
            <.sci_name name={@source_value} genus={nil} weight="regular" />
          <% true -> %>
            {@source_value}
        <% end %>
      </div>

      <%!-- Copy button --%>
      <div class="merge-row-copy">
        <button
          :if={@has_source_value}
          type="button"
          phx-click="copy_field"
          phx-value-field={@field}
          class="merge-copy-btn"
          title="Copy to target"
          aria-label={"Copy the synonym's #{String.downcase(@label)} to the target"}
        >
          <.icon name="hero-arrow-right" class="size-4" />
        </button>
      </div>

      <%!-- Target value (editable) --%>
      <div class="merge-row-target" data-label="Target">
        <input
          type="text"
          value={@target_value || ""}
          phx-blur="update_field"
          phx-value-field={@field}
          class="oc-input"
          aria-label={"Target #{String.downcase(@label)}"}
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
    <div :if={@synonym_only != []} class="card mb-6">
      <h2 class="section-title">Source Data Transfer</h2>
      <p class="merge-lede">
        These sources exist only on the synonym. Check the ones you want to transfer to the target.
      </p>

      <div>
        <div :for={ss <- @synonym_only} class="merge-source">
          <label class="merge-source-label">
            <input
              type="checkbox"
              checked={Map.get(@source_checkboxes, ss.source_id, true)}
              phx-click="toggle_source"
              phx-value-source-id={ss.source_id}
            />
            <div class="flex-1 min-w-0">
              <div class="merge-source-name">{source_name(ss)}</div>
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

    local_names = Species.parse_name_list(assigns.source.local_names)
    assigns = assign(assigns, fields: fields, local_names: local_names)

    ~H"""
    <div class="merge-source-preview">
      <div :if={@local_names != []}>
        Common names: {Enum.join(@local_names, ", ")}
      </div>
      <div :for={{label, val} <- @fields}>
        <span class="merge-source-preview-label">{label}:</span> {String.slice(val, 0..80)}{if(
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

    related_refs =
      Enum.filter(refs, &(&1.reference_type in ["closely_related_to", "subspecies_varieties"]))

    ref_count = length(refs)

    assigns =
      assign(assigns,
        parent_refs: parent_refs,
        hybrid_refs: hybrid_refs,
        related_refs: related_refs,
        ref_count: ref_count
      )

    ~H"""
    <section class="merge-refs">
      <h2 class="merge-refs-title">
        <button
          type="button"
          phx-click="toggle_references"
          class="merge-refs-toggle"
          aria-expanded={to_string(@expanded)}
        >
          References to Update <span class="merge-refs-count">({@ref_count} species)</span>
        </button>
      </h2>

      <div :if={@expanded} class="merge-refs-body">
        <p :if={@ref_count == 0} class="merge-empty">
          No other species reference
          <.sci_name
            name={@preview.source.scientific_name}
            hybrid={@preview.source.is_hybrid}
            abbreviate
            weight="regular"
          />
        </p>

        <div :if={@ref_count > 0}>
          <p class="merge-lede">
            These species will be updated to reference
            <.sci_name
              name={@preview.target.scientific_name}
              hybrid={@preview.target.is_hybrid}
              abbreviate
              weight="regular"
            /> instead.
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
    </section>
    """
  end

  attr :title, :string, required: true
  attr :refs, :list, required: true

  defp reference_group(assigns) do
    ~H"""
    <div class="merge-ref-group">
      <h3 class="merge-subhead">{@title} ({length(@refs)})</h3>
      <ul class="merge-ref-list">
        <li :for={ref <- @refs}>
          <.sci_name
            name={ref.species.scientific_name}
            hybrid={ref.species.is_hybrid}
            abbreviate
            size="title"
          />
          <span :if={ref.reference_type in ["parent1", "parent2"]} class="merge-ref-type">
            {ref.reference_type}
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
        with_edits(assigns.preview.target, assigns.edited_fields),
        assigns.preview.source.scientific_name
      )

    shared_sources = Enum.map(assigns.preview.shared_sources, &source_name/1)

    has_warnings =
      unchecked_sources != [] || self_ref_issues != [] || shared_sources != [] ||
        assigns.preview.same_parent_hybrids != [] || assigns.preview.list_additions != %{}

    assigns =
      assign(assigns,
        unchecked_sources: unchecked_sources,
        self_ref_issues: self_ref_issues,
        shared_sources: shared_sources,
        has_warnings: has_warnings
      )

    ~H"""
    <div :if={@has_warnings} class="space-y-4 mb-6">
      <.data_loss_warning :if={@unchecked_sources != []} sources={@unchecked_sources} />
      <.merge_notice
        :if={@shared_sources != []}
        id="shared-sources-notice"
        title="Sources both species have"
        items={Enum.map(@shared_sources, &{nil, &1, false})}
      >
        The target keeps its own text for these sources; the synonym's text for them is not carried over.
      </.merge_notice>
      <.merge_notice
        :if={@preview.same_parent_hybrids != []}
        id="same-parent-hybrids-notice"
        title="Hybrids of these two species"
        items={Enum.map(@preview.same_parent_hybrids, &{nil, &1.scientific_name, true})}
      >
        After merging, both parents of these hybrids will be
        <.sci_name
          name={@preview.target.scientific_name}
          hybrid={@preview.target.is_hybrid}
          abbreviate
          weight="regular"
        />. Review their parents afterwards.
      </.merge_notice>
      <.merge_notice
        :if={@preview.list_additions != %{}}
        id="list-additions-notice"
        title="Added to the target from the synonym"
        items={list_addition_items(@preview.list_additions)}
      >
        These entries from the synonym are added to
        <.sci_name
          name={@preview.target.scientific_name}
          hybrid={@preview.target.is_hybrid}
          abbreviate
          weight="regular"
        />.
      </.merge_notice>
      <.self_reference_warning :if={@self_ref_issues != []} issues={@self_ref_issues} />
    </div>
    """
  end

  attr :sources, :list, required: true

  defp data_loss_warning(assigns) do
    ~H"""
    <div class="merge-notice merge-notice-warn">
      <p class="merge-notice-title">
        <.icon name="hero-exclamation-triangle" class="size-5" /> Data Loss Warning
      </p>
      <p class="merge-notice-text">
        The following source data will NOT be transferred and will be permanently lost:
      </p>
      <ul class="merge-notice-list">
        <li :for={name <- @sources}>{name}</li>
      </ul>
      <p class="merge-notice-foot">
        To include this data, check the source checkboxes above.
      </p>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :items, :list, required: true
  slot :inner_block, required: true

  defp merge_notice(assigns) do
    ~H"""
    <div id={@id} class="merge-notice">
      <p class="merge-notice-title">{@title}</p>
      <p class="merge-notice-text">{render_slot(@inner_block)}</p>
      <ul class="merge-notice-list">
        <li :for={{label, text, name?} <- @items}>
          <span :if={label}>{label}:</span>
          <.sci_name :if={name?} name={text} abbreviate />
          <span :if={!name?}>{text}</span>
        </li>
      </ul>
    </div>
    """
  end

  defp list_addition_items(additions) do
    labels = %{
      hybrids: "Hybrid",
      closely_related_to: "Closely related",
      subspecies_varieties: "Subspecies/variety",
      external_links: "External link"
    }

    for {field, entries} <- additions, entry <- entries do
      text =
        case entry do
          %{"name" => name} -> name
          %{"url" => url} -> url
          other when is_binary(other) -> other
          other -> inspect(other)
        end

      {labels[field], text, field != :external_links}
    end
  end

  # The target as it will be saved: edited scalar fields override stored ones.
  defp with_edits(target, edited_fields) do
    Enum.reduce(@scalar_fields, target, fn field, acc ->
      case Map.fetch(edited_fields, field) do
        {:ok, value} -> Map.put(acc, String.to_existing_atom(field), value)
        :error -> acc
      end
    end)
  end

  attr :issues, :list, required: true

  defp self_reference_warning(assigns) do
    ~H"""
    <div class="merge-notice merge-notice-warn">
      <p class="merge-notice-title">
        <.icon name="hero-exclamation-triangle" class="size-5" /> Self-Reference Warning
      </p>
      <p class="merge-notice-text">
        After the merge these would point at the species itself, so they will be cleared:
      </p>
      <div class="merge-issues">
        <div :for={issue <- @issues} class="merge-issue">
          <div>
            "<strong>{issue.field}</strong>" contains "<.sci_name
              name={issue.value}
              genus={nil}
              weight="regular"
            />"
          </div>
          <div class="merge-issue-hint">{issue.hint}</div>
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
    ~H"""
    <div class="merge-actions">
      <.button navigate={~p"/species/#{@source_name}"}>Cancel</.button>
      <.button
        variant="primary"
        phx-click="show_confirm"
        disabled={@merging}
        id="merge-save-btn"
      >
        Save Merge
      </.button>
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
      class="merge-dialog fixed inset-0 z-50 flex items-center justify-center p-4"
      phx-window-keydown="cancel_confirm"
      phx-key="Escape"
    >
      <div
        class="card p-6 max-w-lg w-full max-h-[90vh] overflow-y-auto"
        role="dialog"
        aria-modal="true"
        aria-labelledby="merge-dialog-title"
        phx-click-away="cancel_confirm"
      >
        <%= cond do %>
          <% @merge_error -> %>
            <h2 id="merge-dialog-title" class="merge-dialog-title">Merge Failed</h2>
            <p class="merge-dialog-error">{@merge_error}</p>
            <p class="merge-dialog-text">
              The synonym was NOT deleted. You can fix the issue and try again.
            </p>
            <div class="merge-dialog-actions">
              <.button phx-click="cancel_confirm">Close</.button>
            </div>
          <% @merging -> %>
            <h2 id="merge-dialog-title" class="merge-dialog-title">Merging Species...</h2>
            <div class="flex justify-center mb-4">
              <div class="loading-spinner"></div>
            </div>
          <% true -> %>
            <h2 id="merge-dialog-title" class="merge-dialog-title">Confirm Merge</h2>
            <p class="merge-dialog-text">
              You are about to merge
              <.sci_name
                name={@preview.source.scientific_name}
                hybrid={@preview.source.is_hybrid}
                weight="regular"
              /> into
              <.sci_name
                name={@preview.target.scientific_name}
                hybrid={@preview.target.is_hybrid}
                weight="regular"
              />. This will:
            </p>

            <ul class="merge-dialog-steps">
              <li :if={@synonyms_count > 0}>
                <.icon name="hero-check" class="size-5 flex-shrink-0" />
                <span>
                  Add {count_noun(@synonyms_count, "synonym", "synonyms")} to
                  <.sci_name
                    name={@preview.target.scientific_name}
                    hybrid={@preview.target.is_hybrid}
                    abbreviate
                    weight="regular"
                  />
                </span>
              </li>
              <li>
                <.icon name="hero-check" class="size-5 flex-shrink-0" />
                <span>
                  Update
                  <.sci_name
                    name={@preview.target.scientific_name}
                    hybrid={@preview.target.is_hybrid}
                    abbreviate
                    weight="regular"
                  /> with merged field values
                </span>
              </li>
              <li :if={@sources_to_transfer > 0}>
                <.icon name="hero-check" class="size-5 flex-shrink-0" />
                <span>
                  Transfer {count_noun(@sources_to_transfer, "source record", "source records")}
                </span>
              </li>
              <li :if={@ref_count > 0}>
                <.icon name="hero-check" class="size-5 flex-shrink-0" />
                <span>
                  Update {@ref_count} other species that reference
                  <.sci_name
                    name={@preview.source.scientific_name}
                    hybrid={@preview.source.is_hybrid}
                    abbreviate
                    weight="regular"
                  />
                </span>
              </li>
              <li class="merge-dialog-delete">
                <.icon name="hero-x-mark" class="size-5 flex-shrink-0" />
                <span>Delete
                <.sci_name
                  name={@preview.source.scientific_name}
                  hybrid={@preview.source.is_hybrid}
                  abbreviate
                  weight="regular"
                /> permanently</span>
              </li>
            </ul>

            <p class="merge-dialog-warn">
              <.icon name="hero-exclamation-triangle" class="size-5 flex-shrink-0" />
              This action cannot be undone.
            </p>

            <div class="merge-dialog-actions">
              <.button phx-click="cancel_confirm">Cancel</.button>
              <.button variant="primary" phx-click="execute_merge" id="confirm-merge-btn">
                Confirm Merge
              </.button>
            </div>
        <% end %>
      </div>
    </div>
    """
  end

  # -- Helpers --

  defp count_noun(1, singular, _plural), do: "1 #{singular}"
  defp count_noun(n, _singular, plural), do: "#{n} #{plural}"

  defp initialize_edited_fields(target) do
    Map.new(@scalar_fields, fn field ->
      {field, Map.get(target, String.to_existing_atom(field))}
    end)
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
