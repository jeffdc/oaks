defmodule OakCompendiumWeb.SourceDetailLive do
  use OakCompendiumWeb, :live_view

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok, assign(socket, page_title: "Source #{id}", source_id: id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <h1 class="text-2xl font-bold mb-4">Source {@source_id}</h1>
      <p class="text-base-content/70">Source detail coming soon.</p>
    </div>
    """
  end
end
