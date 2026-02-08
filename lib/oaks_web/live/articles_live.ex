defmodule OaksWeb.ArticlesLive do
  @moduledoc """
  LiveView for browsing articles.

  Displays published articles in a card list with title, author, date, and tags.
  Supports tag filtering via URL query params. Authenticated users see draft
  articles and a "New Article" button.
  """

  use OaksWeb, :live_view

  alias Oaks.Articles

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Articles",
       articles: [],
       tags: [],
       selected_tag: nil
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tag = params["tag"]
    authenticated = socket.assigns[:authenticated] || false

    filter = if tag, do: %{"tag" => tag}, else: %{}
    articles = Articles.list_articles(filter, authenticated)
    tags = Articles.list_tags(authenticated)

    {:noreply,
     assign(socket,
       articles: articles,
       tags: tags,
       selected_tag: tag
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <header class="mb-8 flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
        <div>
          <h1
            class="text-3xl font-bold mb-2"
            style="font-family: var(--font-serif); color: var(--color-forest-800);"
          >
            Articles
          </h1>
          <p style="color: var(--color-text-secondary); line-height: 1.6;">
            Guides, reviews, and notes about oak identification and taxonomy.
          </p>
        </div>
        <.link
          :if={@authenticated}
          navigate={~p"/articles/new"}
          class="inline-flex items-center gap-2 px-4 py-2 rounded-lg text-white text-sm font-medium flex-shrink-0"
          style="background-color: var(--color-forest-600); color: white; text-decoration: none;"
        >
          <.icon name="hero-plus" class="size-4" /> New Article
        </.link>
      </header>

      <.tag_filter :if={@tags != []} tags={@tags} selected={@selected_tag} />

      <div :if={@articles == []} class="text-center py-12" style="color: var(--color-text-tertiary);">
        <.icon name="hero-document-text" class="size-12 mx-auto mb-4 opacity-50" />
        <p class="text-lg">No articles found.</p>
        <p :if={@selected_tag} class="mt-2">
          <.link navigate={~p"/articles"} style="color: var(--color-forest-600);">
            Clear filter
          </.link>
        </p>
      </div>

      <div :if={@articles != []} class="space-y-4">
        <.article_card :for={article <- @articles} article={article} />
      </div>
    </div>
    """
  end

  # -- Components --

  attr :tags, :list, required: true
  attr :selected, :string, default: nil

  defp tag_filter(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-2 mb-6">
      <.link
        navigate={~p"/articles"}
        class={["badge", if(!@selected, do: "badge-forest-dark", else: "badge-muted")]}
        style="text-decoration: none; cursor: pointer;"
      >
        All
      </.link>
      <.link
        :for={%{tag: tag, count: count} <- @tags}
        navigate={~p"/articles?tag=#{tag}"}
        class={["badge", if(@selected == tag, do: "badge-forest-dark", else: "badge-muted")]}
        style="text-decoration: none; cursor: pointer;"
      >
        {tag} <span class="ml-1 opacity-60">({count})</span>
      </.link>
    </div>
    """
  end

  attr :article, :any, required: true

  defp article_card(assigns) do
    tags = Articles.parse_tags(assigns.article.tags)
    preview = get_preview(assigns.article.content)
    assigns = assign(assigns, tags: tags, preview: preview)

    ~H"""
    <.link
      navigate={~p"/articles/#{@article.slug}"}
      class="card card-interactive block p-5"
      style={"text-decoration: none;#{unless @article.is_published, do: " border-left: 3px solid var(--color-warning, #f59e0b);", else: ""}"}
    >
      <div class="flex items-start justify-between gap-3">
        <h2
          class="text-xl font-semibold"
          style="font-family: var(--font-serif); color: var(--color-forest-800);"
        >
          {@article.title}
        </h2>
        <span
          :if={!@article.is_published}
          class="badge badge-uppercase"
          style="background-color: #fef3c7; color: #92400e; flex-shrink: 0;"
        >
          Draft
        </span>
      </div>
      <div
        class="flex flex-wrap items-center gap-2 mt-2 text-sm"
        style="color: var(--color-text-tertiary);"
      >
        <span>{@article.author}</span>
        <span>|</span>
        <span>{format_date(@article.published_at || @article.updated_at)}</span>
      </div>
      <p
        :if={@preview != ""}
        class="mt-3 text-sm line-clamp-2"
        style="color: var(--color-text-secondary);"
      >
        {@preview}
      </p>
      <div :if={@tags != []} class="flex flex-wrap gap-1.5 mt-3">
        <span :for={tag <- @tags} class="badge badge-forest-light text-xs">
          {tag}
        </span>
      </div>
    </.link>
    """
  end

  # -- Helpers --

  defp get_preview(nil), do: ""
  defp get_preview(""), do: ""

  defp get_preview(content) do
    content
    |> String.replace(~r/[#*`>\[\]()_~\-]/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, 150)
  end

  defp format_date(nil), do: ""

  defp format_date(date_str) when is_binary(date_str) do
    case DateTime.from_iso8601(date_str) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%B %-d, %Y")
      _ -> date_str
    end
  end
end
