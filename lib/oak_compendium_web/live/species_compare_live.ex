defmodule OakCompendiumWeb.SpeciesCompareLive do
  use OakCompendiumWeb, :live_view

  @impl true
  def mount(%{"name" => name}, _session, socket) do
    {:ok, assign(socket, page_title: "Compare #{name}", species_name: name)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <h1 class="text-2xl font-bold mb-4">Compare Species</h1>
      <p class="text-base-content/70">
        Compare <em>{@species_name}</em> with other species — coming soon.
      </p>
    </div>
    """
  end
end
