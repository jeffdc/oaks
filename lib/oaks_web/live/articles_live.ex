defmodule OaksWeb.ArticlesLive do
  @moduledoc """
  LiveView for browsing articles.

  Displays published articles in a card list with title, author, date, and tags.
  Supports tag filtering via URL query params. Authenticated users see draft
  articles and a "New Article" button.
  """

  use OaksWeb, :live_view

  alias Oaks.Articles
  alias OaksWeb.Params

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
    tag = Params.string(params["tag"], nil)
    editor? = socket.assigns[:current_scope] != nil

    filter = if tag, do: %{"tag" => tag}, else: %{}
    articles = Articles.list_articles(filter, editor?)
    tags = Articles.list_tags(editor?)

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
    <.page>
      <:head>
        <.header>
          Articles
          <:subtitle>Guides, reviews, and notes about oak identification and taxonomy.</:subtitle>
          <:actions :if={@current_scope}>
            <.edit_menu id="articles-edit-menu">
              <:item navigate={~p"/articles/new"} id="new-article-btn">New article</:item>
            </.edit_menu>
          </:actions>
        </.header>
      </:head>

      <.tag_filter :if={@tags != []} tags={@tags} selected={@selected_tag} />

      <div :if={@articles == []} class="py-s7">
        <p class="font-serif italic text-ink-3">No articles found.</p>
        <p :if={@selected_tag} class="mt-s2 font-frame text-sm font-semibold">
          <.link navigate={~p"/articles"}>Clear filter</.link>
        </p>
      </div>

      <div :if={@articles != []}>
        <.article_card :for={article <- @articles} article={article} />
      </div>
    </.page>
    """
  end

  # -- Components --

  attr :tags, :list, required: true
  attr :selected, :string, default: nil

  defp tag_filter(assigns) do
    ~H"""
    <nav class="flex flex-wrap gap-s2 mb-s3" aria-label="Filter by tag">
      <.link
        navigate={~p"/articles"}
        class={["badge", if(!@selected, do: "badge-forest-dark", else: "badge-muted")]}
        aria-current={!@selected && "page"}
        style="text-decoration: none;"
      >
        All
      </.link>
      <.link
        :for={%{tag: tag, count: count} <- @tags}
        navigate={~p"/articles?tag=#{tag}"}
        class={["badge", if(@selected == tag, do: "badge-forest-dark", else: "badge-muted")]}
        aria-current={@selected == tag && "page"}
        style="text-decoration: none;"
      >
        {tag} <span class="ml-1 tabular-nums">({count})</span>
      </.link>
    </nav>
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
      class="article-row group"
    >
      <div class="flex items-baseline justify-between gap-s3">
        <h2 class="font-serif text-[21px]/[1.25] font-semibold text-ink text-balance group-hover:underline group-hover:decoration-1 group-hover:underline-offset-4">
          {@article.title}
        </h2>
        <.status_tag :if={!@article.is_published} class="shrink-0 border-dashed uppercase">
          Draft
        </.status_tag>
      </div>
      <p class="mt-s1 font-frame text-sm font-medium text-ink-2 tabular-nums">
        {@article.author} &middot; {format_date(@article.published_at || @article.updated_at)}
      </p>
      <p :if={@preview != ""} class="mt-s2 max-w-[68ch] font-serif text-base text-ink-2 line-clamp-2">
        {@preview}
      </p>
      <p :if={@tags != []} class="mt-s2 font-frame text-[13px] font-semibold text-ink-3">
        {Enum.join(@tags, ", ")}
      </p>
    </.link>
    """
  end

  # -- Helpers --

  defp get_preview(nil), do: ""
  defp get_preview(""), do: ""

  @preview_length 150

  defp get_preview(content) do
    text =
      content
      |> String.replace(~r/[#*`>\[\]()_~\-]/, "")
      |> String.replace(~r/\s+/, " ")
      |> String.trim()

    if String.length(text) > @preview_length do
      cut = String.slice(text, 0, @preview_length)
      # Cut at the last word boundary and mark the cut.
      String.replace(cut, ~r/\s+\S*$/, "") <> "…"
    else
      text
    end
  end

  defp format_date(nil), do: ""

  defp format_date(date_str) when is_binary(date_str) do
    case DateTime.from_iso8601(date_str) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%B %-d, %Y")
      _ -> date_str
    end
  end
end
