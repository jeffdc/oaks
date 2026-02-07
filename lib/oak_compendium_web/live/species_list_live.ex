defmodule OakCompendiumWeb.SpeciesListLive do
  use OakCompendiumWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Species List")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <h1 class="text-2xl font-bold mb-4">Species List</h1>
      <p class="text-base-content/70">Species list coming soon.</p>
    </div>
    """
  end
end
