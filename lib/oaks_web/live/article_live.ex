defmodule OaksWeb.ArticleLive do
  @moduledoc """
  LiveView for displaying a single article.

  Renders article content from markdown to HTML. Shows edit/delete
  buttons for authenticated users. Handles not-found articles.
  """

  use OaksWeb, :live_view

  alias Oaks.Articles

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Article",
       article: nil,
       not_found: false,
       rendered_content: "",
       tags: [],
       confirm_delete: false
     )}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _uri, socket) do
    authenticated = socket.assigns[:authenticated] || false

    case Articles.get_article_by_slug(slug, authenticated) do
      nil ->
        {:noreply,
         assign(socket,
           article: nil,
           not_found: true,
           page_title: "Article Not Found"
         )}

      article ->
        {:noreply,
         assign(socket,
           article: article,
           not_found: false,
           rendered_content: Articles.render_markdown(article.content),
           tags: Articles.parse_tags(article.tags),
           page_title: article.title,
           confirm_delete: false
         )}
    end
  end

  @impl true
  def handle_event("confirm_delete", _params, socket) do
    {:noreply, assign(socket, confirm_delete: true)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, confirm_delete: false)}
  end

  def handle_event("delete", _params, socket) do
    article = socket.assigns.article

    case Articles.delete_article(article) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Article deleted.")
         |> push_navigate(to: ~p"/articles")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete article.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <.not_found_view :if={@not_found} />

      <div :if={@article}>
        <.article_header
          article={@article}
          tags={@tags}
          authenticated={@authenticated}
        />
        <.article_body content={@rendered_content} />
        <.article_footer article={@article} tags={@tags} />

        <.delete_modal :if={@confirm_delete} article={@article} />
      </div>
    </div>
    """
  end

  # -- Not Found --

  defp not_found_view(assigns) do
    ~H"""
    <div class="text-center py-16">
      <.icon name="hero-document-text" class="size-16 mx-auto mb-4 text-base-content/30" />
      <h1 class="text-2xl font-bold mb-2">Article Not Found</h1>
      <p class="mb-6" style="color: var(--color-text-secondary);">
        The article you're looking for doesn't exist or hasn't been published.
      </p>
      <.link
        navigate={~p"/articles"}
        class="inline-flex items-center gap-2 px-4 py-2 rounded-lg text-white"
        style="background-color: var(--color-forest-600); text-decoration: none;"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to Articles
      </.link>
    </div>
    """
  end

  # -- Header --

  attr :article, :any, required: true
  attr :tags, :list, required: true
  attr :authenticated, :boolean, required: true

  defp article_header(assigns) do
    ~H"""
    <div class="mb-8">
      <.link
        navigate={~p"/articles"}
        class="inline-flex items-center gap-1 text-sm mb-4"
        style="color: var(--color-forest-600); text-decoration: none;"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to Articles
      </.link>

      <div class="flex items-start justify-between gap-4">
        <div class="flex-1">
          <div class="flex items-center gap-3 mb-2">
            <h1
              class="text-3xl font-bold"
              style="font-family: var(--font-serif); color: var(--color-forest-900);"
            >
              {@article.title}
            </h1>
            <span
              :if={!@article.is_published}
              class="badge badge-uppercase"
              style="background-color: #fef3c7; color: #92400e;"
            >
              Draft
            </span>
          </div>
          <div
            class="flex flex-wrap items-center gap-2 text-sm"
            style="color: var(--color-text-tertiary);"
          >
            <span>By {@article.author}</span>
            <span :if={@article.published_at}>
              &middot; Published {format_date(@article.published_at)}
            </span>
          </div>
        </div>
        <div :if={@authenticated} class="flex items-center gap-2 flex-shrink-0">
          <.link
            navigate={~p"/articles/#{@article.slug}/edit"}
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium"
            style="background-color: var(--color-forest-50); color: var(--color-forest-700); border: 1px solid var(--color-forest-200); text-decoration: none;"
          >
            <.icon name="hero-pencil-square" class="size-4" /> Edit
          </.link>
          <button
            phx-click="confirm_delete"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium"
            style="background-color: #fef2f2; color: #991b1b; border: 1px solid #fecaca;"
          >
            <.icon name="hero-trash" class="size-4" /> Delete
          </button>
        </div>
      </div>

      <div :if={@tags != []} class="flex flex-wrap gap-1.5 mt-3">
        <.link
          :for={tag <- @tags}
          navigate={~p"/articles?tag=#{tag}"}
          class="badge badge-forest-light text-xs"
          style="text-decoration: none;"
        >
          {tag}
        </.link>
      </div>
    </div>
    """
  end

  # -- Body --

  attr :content, :string, required: true

  defp article_body(assigns) do
    ~H"""
    <div class="card p-6 sm:p-8">
      <div class="prose-content">
        {raw(@content)}
      </div>
    </div>
    """
  end

  # -- Footer --

  attr :article, :any, required: true
  attr :tags, :list, required: true

  defp article_footer(assigns) do
    ~H"""
    <div
      class="mt-6 pt-4 flex flex-wrap items-center justify-between gap-4 text-sm"
      style="border-top: 1px solid var(--color-border-light); color: var(--color-text-tertiary);"
    >
      <div>
        <span :if={@article.updated_at}>
          Last updated {format_date(@article.updated_at)}
        </span>
      </div>
      <.link
        navigate={~p"/articles"}
        class="inline-flex items-center gap-1"
        style="color: var(--color-forest-600); text-decoration: none;"
      >
        <.icon name="hero-arrow-left" class="size-4" /> All Articles
      </.link>
    </div>
    """
  end

  # -- Delete Modal --

  attr :article, :any, required: true

  defp delete_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 flex items-center justify-center p-4"
      style="background-color: rgba(0, 0, 0, 0.5);"
      phx-window-keydown="cancel_delete"
      phx-key="Escape"
    >
      <div class="card p-6 max-w-md w-full" style="background-color: var(--color-surface);">
        <h3 class="text-lg font-bold mb-2" style="color: var(--color-text-primary);">
          Delete Article
        </h3>
        <p class="mb-4" style="color: var(--color-text-secondary);">
          Are you sure you want to delete "<strong>{@article.title}</strong>"? This cannot be undone.
        </p>
        <div class="flex justify-end gap-3">
          <button
            phx-click="cancel_delete"
            class="px-4 py-2 rounded-lg text-sm font-medium"
            style="background-color: var(--color-base-200); color: var(--color-text-primary);"
          >
            Cancel
          </button>
          <button
            phx-click="delete"
            class="px-4 py-2 rounded-lg text-sm font-medium text-white"
            style="background-color: #dc2626;"
          >
            Delete
          </button>
        </div>
      </div>
    </div>
    """
  end

  # -- Helpers --

  defp format_date(nil), do: ""

  defp format_date(date_str) when is_binary(date_str) do
    case DateTime.from_iso8601(date_str) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%B %-d, %Y")
      _ -> date_str
    end
  end
end
