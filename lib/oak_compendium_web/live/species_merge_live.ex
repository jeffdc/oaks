defmodule OakCompendiumWeb.SpeciesMergeLive do
  use OakCompendiumWeb, :live_view

  @impl true
  def mount(%{"name" => name, "target" => target}, _session, socket) do
    {:ok, assign(socket, page_title: "Merge Species", source_name: name, target_name: target)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <h1 class="text-2xl font-bold mb-4">Merge Species</h1>
      <p class="text-base-content/70">
        Merge <em>{@source_name}</em> into <em>{@target_name}</em> — coming soon.
      </p>
    </div>
    """
  end
end
