defmodule OaksWeb.TaxonFormLive do
  @moduledoc """
  LiveView for creating and editing taxa.

  Requires authentication — unauthenticated users are redirected
  to the taxonomy browser with a flash message.
  """

  use OaksWeb, :live_view

  import OaksWeb.FormComponents

  alias Oaks.Taxonomy
  alias Oaks.Taxonomy.Taxon
  alias OaksWeb.Params
  alias OaksWeb.TaxonomyOptions
  alias OaksWeb.TaxonPath

  @level_options [
    {"Subgenus", "subgenus"},
    {"Section", "section"},
    {"Subsection", "subsection"},
    {"Complex", "complex"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       taxon: nil,
       form: nil,
       parent_options: [],
       content_tab: "write",
       link_tags: []
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
       |> push_navigate(to: ~p"/taxonomy")}
    end
  end

  defp apply_action(socket, :new, params) do
    default_level = params["level"] || "subgenus"
    default_parent = Params.int(params["parent_id"])

    attrs = %{level: default_level, parent_id: default_parent}
    taxon = %Taxon{}
    changeset = Taxonomy.change_taxon(taxon, attrs)

    socket
    |> assign(
      page_title: "New taxon",
      taxon: taxon,
      form: to_form(changeset),
      parent_options: parent_options_for_level(default_level),
      link_tags: []
    )
  end

  defp apply_action(socket, :edit, %{"id" => id_str}) do
    id = Params.int(id_str)

    case id && Taxonomy.get_taxon_by_id(id) do
      nil ->
        socket
        |> put_flash(:error, "Taxon not found.")
        |> push_navigate(to: ~p"/taxonomy")

      taxon ->
        changeset = Taxonomy.change_taxon(taxon)

        socket
        |> assign(
          page_title:
            "Edit #{level_label(taxon.level)}: #{OaksWeb.SpeciesName.taxon_label(taxon.level, taxon.name)}",
          taxon: taxon,
          form: to_form(changeset),
          parent_options: parent_options_for_level(taxon.level),
          link_tags: parse_links(taxon.links)
        )
    end
  end

  @impl true
  def handle_event("validate", %{"taxon" => taxon_params}, socket) do
    if socket.assigns[:current_scope] do
      changeset =
        socket.assigns.taxon
        |> Taxonomy.change_taxon(taxon_params)
        |> Map.put(:action, :validate)

      # Update parent options when the level changes. Read the level from the
      # changesets, not the params: the edit form has no level field, so its
      # level is the taxon's own and its parent options must stay.
      new_level = Ecto.Changeset.get_field(changeset, :level)
      old_level = Ecto.Changeset.get_field(socket.assigns.form.source, :level)

      parent_options =
        if new_level != old_level do
          parent_options_for_level(new_level)
        else
          socket.assigns.parent_options
        end

      {:noreply, assign(socket, form: to_form(changeset), parent_options: parent_options)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("switch_content_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, content_tab: tab)}
  end

  def handle_event("add_link", %{"value" => value}, socket) do
    value = String.trim(value)

    if value != "" and value not in socket.assigns.link_tags do
      {:noreply, assign(socket, link_tags: socket.assigns.link_tags ++ [value])}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_link", %{"index" => index_str}, socket) do
    case Params.int(index_str) do
      nil ->
        {:noreply, socket}

      index ->
        {:noreply, assign(socket, link_tags: List.delete_at(socket.assigns.link_tags, index))}
    end
  end

  def handle_event("save", %{"taxon" => taxon_params}, socket) do
    if socket.assigns[:current_scope] do
      # Inject links JSON from tag input
      links_json =
        case socket.assigns.link_tags do
          [] -> nil
          tags -> Jason.encode!(tags)
        end

      taxon_params = Map.put(taxon_params, "links", links_json)
      save_taxon(socket, socket.assigns.live_action, taxon_params)
    else
      {:noreply,
       socket
       |> put_flash(:error, "You must be authenticated to perform this action.")
       |> push_navigate(to: ~p"/taxonomy")}
    end
  end

  defp save_taxon(socket, :new, taxon_params) do
    case Taxonomy.create_taxon(taxon_params) do
      {:ok, taxon} ->
        {:noreply,
         socket
         |> put_flash(:info, "Taxon created.")
         |> push_navigate(to: taxon_path(taxon))}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_taxon(socket, :edit, taxon_params) do
    case Taxonomy.update_taxon(socket.assigns.taxon, taxon_params) do
      {:ok, taxon} ->
        {:noreply,
         socket
         |> put_flash(:info, "Taxon updated.")
         |> push_navigate(to: taxon_path(taxon))}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp taxon_path(taxon) do
    path =
      taxon
      |> Taxonomy.ancestors()
      |> Enum.reject(&(&1.level == "genus"))
      |> Enum.map(& &1.name)

    TaxonPath.taxonomy_path(path)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page width="form">
      <div :if={@form == nil} class="py-s7">
        <p class="text-ink-3">Loading...</p>
      </div>

      <:head :if={@form}>
        <.back navigate={~p"/taxonomy"}>Back to taxonomy</.back>

        <.header>
          <%= if @live_action == :new do %>
            New taxon
          <% else %>
            Edit {level_label(@taxon.level)}:
            <.sci_name name={@taxon.name} level={@taxon.level} size="display" />
          <% end %>
        </.header>
      </:head>

      <div :if={@form}>
        <.form for={@form} id="taxon-form" phx-change="validate" phx-submit="save">
          <div class="space-y-s7">
            <%!-- Core fields --%>
            <section>
              <.section_heading>Core Information</.section_heading>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-x-s5">
                <div>
                  <%= if @live_action == :new do %>
                    <.input
                      field={@form[:level]}
                      type="select"
                      label="Level"
                      options={level_options()}
                      prompt="Select level..."
                    />
                  <% else %>
                    <div class="oc-field">
                      <span class="oc-label">Level</span>
                      <p class="py-[9px] font-frame text-[15px] font-semibold text-ink">
                        {level_label(@taxon.level)}
                      </p>
                      <p class="oc-hint">Level cannot be changed after creation</p>
                    </div>
                  <% end %>
                </div>
                <div>
                  <.input
                    field={@form[:name]}
                    type="text"
                    label="Name"
                    placeholder="e.g. Quercus"
                    phx-debounce="300"
                  />
                </div>
                <div :if={show_parent?(@form)}>
                  <.input
                    field={@form[:parent_id]}
                    type="select"
                    label="Parent"
                    options={@parent_options}
                    prompt="Select parent..."
                  />
                </div>
                <div>
                  <.input
                    field={@form[:author]}
                    type="text"
                    label="Author"
                    placeholder="e.g. (L.) Oerst."
                    phx-debounce="300"
                  />
                </div>
              </div>
            </section>

            <%!-- Content --%>
            <section>
              <.section_heading>Content</.section_heading>
              <div class="space-y-s4">
                <.markdown_editor
                  field={@form[:content]}
                  content_tab={@content_tab}
                  tab_event="switch_content_tab"
                  placeholder="Write about this taxon..."
                  label="Content"
                  hint="Markdown content for this taxon (descriptions, notes, etc.)"
                />
                <.tag_input
                  tags={@link_tags}
                  add_event="add_link"
                  remove_event="remove_link"
                  input_id="link-tag-input"
                  placeholder="Add URL..."
                  label="Links"
                  hint="Press Enter to add URLs"
                  display_fn={&link_display/1}
                />
              </div>
            </section>

            <%!-- Submit --%>
            <div class="flex items-center justify-end gap-s2 pt-s4 border-t border-rule">
              <.button navigate={~p"/taxonomy"}>Cancel</.button>
              <.button type="submit" variant="primary" phx-disable-with="Saving...">
                {if(@live_action == :new, do: "Create taxon", else: "Save changes")}
              </.button>
            </div>
          </div>
        </.form>
      </div>
    </.page>
    """
  end

  # -- Helpers --

  defp level_options, do: @level_options

  defp level_label("subgenus"), do: "Subgenus"
  defp level_label("section"), do: "Section"
  defp level_label("subsection"), do: "Subsection"
  defp level_label("complex"), do: "Complex"
  defp level_label(_), do: "Taxon"

  defp show_parent?(form) do
    level = form[:level].value
    level && level != "" && level != "genus"
  end

  defp parent_options_for_level(level), do: TaxonomyOptions.above(level)

  defp link_display(%{"label" => label, "url" => url}), do: "#{label} — #{url}"
  defp link_display(%{"url" => url}), do: url
  defp link_display(url) when is_binary(url), do: url
  defp link_display(_), do: ""

  defp parse_links(nil), do: []
  defp parse_links(""), do: []

  defp parse_links(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
  end
end
