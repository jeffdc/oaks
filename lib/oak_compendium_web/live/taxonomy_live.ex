defmodule OakCompendiumWeb.TaxonomyLive do
  use OakCompendiumWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Taxonomy")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    path = params["path"] || []
    {:noreply, assign(socket, taxonomy_path: path)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <h1 class="text-2xl font-bold mb-4">Taxonomy</h1>
      <p :if={@taxonomy_path == []} class="text-base-content/70">
        Taxonomy browser coming soon.
      </p>
      <p :if={@taxonomy_path != []} class="text-base-content/70">
        Viewing: {Enum.join(@taxonomy_path, " / ")}
      </p>
    </div>
    """
  end
end
