defmodule OakCompendiumWeb.HomeLive do
  use OakCompendiumWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Home")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto">
      <%!-- Welcome section --%>
      <section class="text-center mb-10">
        <h2
          class="text-3xl font-bold mb-3"
          style="font-family: var(--font-serif); color: var(--color-forest-800, #165132);"
        >
          Explore the World of Oaks
        </h2>
        <p class="text-lg" style="color: var(--color-text-secondary); line-height: 1.6;">
          A comprehensive database of oak species and hybrids from around the globe.
        </p>
      </section>

      <%!-- Quick links --%>
      <section class="mb-10">
        <h3 class="section-title">What would you like to do?</h3>
        <div class="grid gap-4 sm:grid-cols-2">
          <.link_card
            navigate={~p"/list"}
            icon="hero-list-bullet"
            title="Browse Species"
            description="View all oak species and hybrids"
          />
          <.link_card
            navigate={~p"/taxonomy"}
            icon="hero-squares-2x2"
            title="Taxonomy Tree"
            description="Explore by subgenus, section, and more"
          />
          <.link_card
            navigate={~p"/search"}
            icon="hero-magnifying-glass"
            title="Search"
            description="Find species by name or characteristics"
          />
          <.link_card
            navigate={~p"/sources"}
            icon="hero-book-open"
            title="Data Sources"
            description="View the sources behind the data"
          />
          <.link_card
            navigate={~p"/articles"}
            icon="hero-document-text"
            title="Articles"
            description="Read articles about oaks"
          />
          <.link_card
            navigate={~p"/about"}
            icon="hero-information-circle"
            title="About"
            description="Learn about this project"
          />
        </div>
      </section>
    </div>
    """
  end

  defp link_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="card card-interactive flex items-center gap-4 p-5"
      style="text-decoration: none;"
    >
      <div class="flex-shrink-0 w-12 h-12 rounded-lg bg-forest-50 flex items-center justify-center text-forest-600">
        <.icon name={@icon} class="size-6" />
      </div>
      <div>
        <h3 class="font-semibold" style="color: var(--color-text-primary);">
          {@title}
        </h3>
        <p class="text-sm" style="color: var(--color-text-secondary);">
          {@description}
        </p>
      </div>
    </.link>
    """
  end
end
