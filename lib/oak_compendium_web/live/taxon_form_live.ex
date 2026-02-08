defmodule OakCompendiumWeb.TaxonFormLive do
  @moduledoc """
  LiveView for creating and editing taxa.

  Requires authentication — unauthenticated users are redirected
  to the taxonomy browser with a flash message.
  """

  use OakCompendiumWeb, :live_view

  import OakCompendiumWeb.FormComponents

  alias OakCompendium.Taxonomy
  alias OakCompendium.Taxonomy.Taxon

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
    if socket.assigns[:authenticated] do
      {:noreply, apply_action(socket, socket.assigns.live_action, params)}
    else
      if connected?(socket) do
        {:noreply,
         socket
         |> put_flash(:error, "You must be authenticated to perform this action.")
         |> push_navigate(to: ~p"/taxonomy")}
      else
        {:noreply, socket}
      end
    end
  end

  defp apply_action(socket, :new, params) do
    default_level = params["level"] || "subgenus"
    default_parent = params["parent"]

    attrs = %{level: default_level, parent: default_parent}
    taxon = %Taxon{}
    changeset = Taxonomy.change_taxon(taxon, attrs)

    socket
    |> assign(
      page_title: "Create Taxon",
      taxon: taxon,
      form: to_form(changeset),
      parent_options: parent_options_for_level(default_level),
      link_tags: []
    )
  end

  defp apply_action(socket, :edit, %{"id" => id_str}) do
    id = String.to_integer(id_str)

    case Taxonomy.get_taxon_by_id(id) do
      nil ->
        socket
        |> put_flash(:error, "Taxon not found.")
        |> push_navigate(to: ~p"/taxonomy")

      taxon ->
        changeset = Taxonomy.change_taxon(taxon)

        socket
        |> assign(
          page_title: "Edit #{level_label(taxon.level)}: #{taxon.name}",
          taxon: taxon,
          form: to_form(changeset),
          parent_options: parent_options_for_level(taxon.level),
          link_tags: parse_links(taxon.links)
        )
    end
  end

  @impl true
  def handle_event("validate", %{"taxon" => taxon_params}, socket) do
    if socket.assigns[:authenticated] do
      # Update parent options when level changes
      new_level = taxon_params["level"] || ""

      old_level =
        socket.assigns.form.source.changes[:level] ||
          (socket.assigns.taxon && socket.assigns.taxon.level) || ""

      parent_options =
        if new_level != old_level do
          parent_options_for_level(new_level)
        else
          socket.assigns.parent_options
        end

      changeset =
        socket.assigns.taxon
        |> Taxonomy.change_taxon(taxon_params)
        |> Map.put(:action, :validate)

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
    index = String.to_integer(index_str)
    tags = List.delete_at(socket.assigns.link_tags, index)
    {:noreply, assign(socket, link_tags: tags)}
  end

  def handle_event("save", %{"taxon" => taxon_params}, socket) do
    if socket.assigns[:authenticated] do
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

  defp taxon_path(%{level: "subgenus"} = taxon) do
    ~p"/taxonomy/#{taxon.name}"
  end

  defp taxon_path(%{level: "section"} = taxon) do
    parent = taxon.parent || "unknown"
    ~p"/taxonomy/#{parent}/#{taxon.name}"
  end

  defp taxon_path(%{level: "subsection"} = taxon) do
    parent = taxon.parent || "unknown"
    parent_taxon = Taxonomy.get_taxon("section", parent)
    grandparent = if parent_taxon, do: parent_taxon.parent || "unknown", else: "unknown"
    segments = Enum.map_join([grandparent, parent, taxon.name], "/", &URI.encode_www_form/1)
    "/taxonomy/#{segments}"
  end

  defp taxon_path(_taxon), do: ~p"/taxonomy"

  @impl true
  def render(assigns) do
    ~H"""
    <div :if={@form == nil} class="max-w-3xl mx-auto py-12 text-center">
      <p style="color: var(--color-text-tertiary);">Loading...</p>
    </div>

    <div :if={@form} class="max-w-3xl mx-auto">
      <.link
        navigate={~p"/taxonomy"}
        class="inline-flex items-center gap-1 text-sm mb-4"
        style="color: var(--color-forest-700);"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to taxonomy
      </.link>

      <h1
        class="text-2xl font-bold mb-6"
        style="font-family: var(--font-serif); color: var(--color-forest-800);"
      >
        {@page_title}
      </h1>

      <.form for={@form} id="taxon-form" phx-change="validate" phx-submit="save">
        <div class="space-y-6">
          <%!-- Core fields --%>
          <div class="card p-6">
            <h2 class="section-title section-title-sm mb-4">Core Information</h2>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
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
                  <div>
                    <label class="block text-sm font-semibold leading-6 text-zinc-800 mb-2">
                      Level
                    </label>
                    <p
                      class="px-3 py-2 rounded-lg text-sm"
                      style="background-color: var(--color-background); color: var(--color-text-secondary); border: 1px solid var(--color-border);"
                    >
                      {level_label(@taxon.level)}
                    </p>
                    <p class="text-xs mt-1" style="color: var(--color-text-tertiary);">
                      Level cannot be changed after creation
                    </p>
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
                  field={@form[:parent]}
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
          </div>

          <%!-- Content --%>
          <div class="card p-6">
            <h2 class="section-title section-title-sm mb-4">Content</h2>
            <div class="space-y-4">
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
          </div>

          <%!-- Submit --%>
          <div class="flex items-center justify-end gap-3">
            <.link
              navigate={~p"/taxonomy"}
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
              {if(@live_action == :new, do: "Create Taxon", else: "Save Changes")}
            </button>
          </div>
        </div>
      </.form>
    </div>
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
    level && level != "" && level != "subgenus"
  end

  defp parent_options_for_level("section") do
    "subgenus"
    |> Taxonomy.list_taxa_by_level()
    |> Enum.map(&{&1.name, &1.name})
    |> Enum.sort()
  end

  defp parent_options_for_level("subsection") do
    "section"
    |> Taxonomy.list_taxa_by_level()
    |> Enum.map(&{&1.name, &1.name})
    |> Enum.sort()
  end

  defp parent_options_for_level("complex") do
    sections = Taxonomy.list_taxa_by_level("section")
    subsections = Taxonomy.list_taxa_by_level("subsection")

    (Enum.map(sections, &{&1.name, &1.name}) ++
       Enum.map(subsections, &{&1.name, &1.name}))
    |> Enum.sort()
  end

  defp parent_options_for_level(_), do: []

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
