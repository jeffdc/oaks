defmodule OaksWeb.ArticleLive do
  @moduledoc """
  LiveView for displaying a single article.

  Renders article content from markdown to HTML. Shows edit/delete
  buttons for logged-in users. Handles not-found articles.
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
    editor? = socket.assigns[:current_scope] != nil

    case Articles.get_article_by_slug(slug, editor?) do
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
    {:noreply, assign(socket, confirm_delete: socket.assigns[:current_scope] != nil)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, confirm_delete: false)}
  end

  def handle_event("delete", _params, socket) do
    if socket.assigns[:current_scope] do
      case Articles.delete_article(socket.assigns.article) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Article deleted.")
           |> push_navigate(to: ~p"/articles")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete article.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page width="read">
      <:head :if={@not_found}><.not_found_view /></:head>
      <:head :if={@article}>
        <.article_header
          article={@article}
          tags={@tags}
          editor={@current_scope != nil}
        />
      </:head>

      <div :if={@article}>
        <.article_body content={@rendered_content} />
        <.article_footer article={@article} tags={@tags} />

        <.delete_modal :if={@confirm_delete} article={@article} />
      </div>
    </.page>
    """
  end

  # -- Not Found --

  defp not_found_view(assigns) do
    ~H"""
    <.header>
      Article Not Found
      <:subtitle>The article you're looking for doesn't exist or hasn't been published.</:subtitle>
    </.header>
    <.back navigate={~p"/articles"}>Back to Articles</.back>
    """
  end

  # -- Header --

  attr :article, :any, required: true
  attr :tags, :list, required: true
  attr :editor, :boolean, required: true

  defp article_header(assigns) do
    ~H"""
    <div class="mb-s6">
      <.back navigate={~p"/articles"}>Back to Articles</.back>

      <div class="mt-s4 pb-s4 border-b-2 border-ink flex flex-wrap sm:flex-nowrap items-start justify-between gap-y-s3 gap-x-s5">
        <div class="min-w-0 flex-auto">
          <div class="flex flex-wrap items-baseline gap-x-s4 gap-y-s2">
            <h1 class="font-serif text-[clamp(34px,4vw,50px)]/[1.05] font-semibold tracking-[-0.01em] text-balance">
              {@article.title}
            </h1>
            <.status_tag :if={!@article.is_published} class="border-dashed uppercase">
              Draft
            </.status_tag>
          </div>
          <p class="mt-s2 font-frame text-[15px] font-semibold text-ink-2 tabular-nums">
            By {@article.author}
            <span :if={@article.published_at}>
              &middot; Published {format_date(@article.published_at)}
            </span>
          </p>
          <p
            :if={@tags != []}
            class="mt-s2 flex flex-wrap gap-x-s2 font-frame text-[13px] font-semibold"
          >
            <.link
              :for={tag <- @tags}
              navigate={~p"/articles?tag=#{tag}"}
              class="not-last:after:content-[','] after:text-ink-3"
            >
              {tag}
            </.link>
          </p>
        </div>
        <div :if={@editor} class="flex items-center gap-s2 shrink-0 sm:mt-s2">
          <.button navigate={~p"/articles/#{@article.slug}/edit"} size="compact">Edit</.button>
          <.button phx-click="confirm_delete" size="compact">Delete</.button>
        </div>
      </div>
    </div>
    """
  end

  # -- Body --

  attr :content, :string, required: true

  defp article_body(assigns) do
    ~H"""
    <div class="card">
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
    <div class="mt-s7 pt-s3 flex flex-wrap items-center justify-between gap-s4 border-t border-rule font-frame text-[13px] font-medium text-ink-3 tabular-nums">
      <div>
        <span :if={@article.updated_at}>
          Last updated {format_date(@article.updated_at)}
        </span>
      </div>
      <.back navigate={~p"/articles"}>All Articles</.back>
    </div>
    """
  end

  # -- Delete Modal --

  attr :article, :any, required: true

  defp delete_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-ink/65"
      phx-window-keydown="cancel_delete"
      phx-key="Escape"
    >
      <div
        class="card p-6 max-w-md w-full"
        role="dialog"
        aria-modal="true"
        aria-labelledby="delete-article-title"
      >
        <h3 id="delete-article-title" class="mb-s3 font-serif text-[26px]/[1.15] font-semibold">
          Delete Article
        </h3>
        <p class="mb-s4 text-ink-2">
          Are you sure you want to delete <strong class="text-ink">{@article.title}</strong>? This cannot be undone.
        </p>
        <div class="flex flex-wrap justify-end gap-s2">
          <.button phx-click="cancel_delete">Cancel</.button>
          <.button phx-click="delete" variant="primary">Delete</.button>
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
