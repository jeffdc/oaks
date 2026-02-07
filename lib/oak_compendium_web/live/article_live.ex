defmodule OakCompendiumWeb.ArticleLive do
  use OakCompendiumWeb, :live_view

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    {:ok, assign(socket, page_title: slug, article_slug: slug)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <h1 class="text-2xl font-bold mb-4">{@article_slug}</h1>
      <p class="text-base-content/70">Article detail coming soon.</p>
    </div>
    """
  end
end
