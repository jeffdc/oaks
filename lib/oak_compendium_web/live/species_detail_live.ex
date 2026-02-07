defmodule OakCompendiumWeb.SpeciesDetailLive do
  use OakCompendiumWeb, :live_view

  @impl true
  def mount(%{"name" => name}, _session, socket) do
    {:ok, assign(socket, page_title: "Quercus #{name}", species_name: name)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <h1 class="text-2xl font-bold mb-4">
        Quercus <em>{@species_name}</em>
      </h1>
      <p class="text-base-content/70">Species detail coming soon.</p>
    </div>
    """
  end
end
