defmodule OaksWeb.ArticleFormLive do
  @moduledoc """
  LiveView for creating and editing articles.

  Handles both `:new` and `:edit` actions. Uses the reusable markdown editor
  and tag input components. Requires authentication — redirects unauthenticated users.
  """

  use OaksWeb, :live_view

  import OaksWeb.FormComponents

  alias Oaks.Articles
  alias Oaks.Articles.Article
  alias OaksWeb.Params

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       article: nil,
       form: nil,
       content_tab: "write",
       tags: []
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    if socket.assigns[:current_scope] do
      {:noreply, apply_action(socket, socket.assigns.live_action, params)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "You must be authenticated to manage articles.")
       |> push_navigate(to: ~p"/articles")}
    end
  end

  defp apply_action(socket, :new, _params) do
    article = %Article{}
    changeset = Articles.change_article(article)

    socket
    |> assign(
      page_title: "New Article",
      article: article,
      form: to_form(changeset),
      tags: []
    )
  end

  defp apply_action(socket, :edit, %{"slug" => slug}) do
    case Articles.get_article_by_slug(slug, true) do
      nil ->
        socket
        |> put_flash(:error, "Article not found.")
        |> push_navigate(to: ~p"/articles")

      article ->
        changeset = Articles.change_article(article)

        socket
        |> assign(
          page_title: "Edit: #{article.title}",
          article: article,
          form: to_form(changeset),
          tags: Articles.parse_tags(article.tags)
        )
    end
  end

  @impl true
  def handle_event("validate", %{"article" => params}, socket) do
    if socket.assigns[:current_scope] do
      changeset =
        socket.assigns.article
        |> Articles.change_article(params)
        |> Map.put(:action, :validate)

      {:noreply, assign(socket, form: to_form(changeset))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("switch_content_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, content_tab: tab)}
  end

  def handle_event("add_tag", %{"value" => value}, socket) do
    value = String.trim(value)

    if value != "" and value not in socket.assigns.tags do
      {:noreply, assign(socket, tags: socket.assigns.tags ++ [value])}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_tag", %{"index" => index_str}, socket) do
    case Params.int(index_str) do
      nil -> {:noreply, socket}
      index -> {:noreply, assign(socket, tags: List.delete_at(socket.assigns.tags, index))}
    end
  end

  def handle_event("save", %{"article" => params}, socket) do
    if socket.assigns[:current_scope] do
      params = Map.put(params, "tags", socket.assigns.tags)

      case socket.assigns.live_action do
        :new -> save_article(socket, :new, params)
        :edit -> save_article(socket, :edit, params)
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "You must be authenticated to manage articles.")
       |> push_navigate(to: ~p"/articles")}
    end
  end

  defp save_article(socket, :new, params) do
    case Articles.create_article(params) do
      {:ok, article} ->
        {:noreply,
         socket
         |> put_flash(:info, "Article created.")
         |> push_navigate(to: ~p"/articles/#{article.slug}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_article(socket, :edit, params) do
    case Articles.update_article(socket.assigns.article, params) do
      {:ok, article} ->
        {:noreply,
         socket
         |> put_flash(:info, "Article updated.")
         |> push_navigate(to: ~p"/articles/#{article.slug}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page width="form">
      <div :if={@form == nil} class="py-s7">
        <p class="font-frame text-ink-3">Loading...</p>
      </div>

      <:head :if={@form}>
        <.back navigate={cancel_path(@live_action, @article)}>Back to articles</.back>

        <.header>{@page_title}</.header>
      </:head>

      <div :if={@form}>
        <.form for={@form} id="article-form" phx-change="validate" phx-submit="save">
          <div class="grid grid-cols-1 gap-s7">
            <%!-- Core fields --%>
            <section>
              <.section_heading>Article Details</.section_heading>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-x-s4">
                <div>
                  <.input
                    field={@form[:title]}
                    type="text"
                    label="Title"
                    placeholder="Article title"
                    phx-debounce="300"
                  />
                </div>
                <div>
                  <.input
                    field={@form[:author]}
                    type="text"
                    label="Author"
                    placeholder="Author name"
                    phx-debounce="300"
                  />
                </div>
              </div>
              <div class="mt-4">
                <.input
                  field={@form[:is_published]}
                  type="checkbox"
                  label="Published"
                />
                <p class="-mt-s3 pl-6 font-frame text-[13px] font-medium text-ink-3">
                  Uncheck to save as draft (only visible to logged-in users)
                </p>
              </div>
            </section>

            <%!-- Content --%>
            <section>
              <.section_heading>Content</.section_heading>
              <div class="space-y-4">
                <.markdown_editor
                  field={@form[:content]}
                  content_tab={@content_tab}
                  tab_event="switch_content_tab"
                  placeholder="Write your article content..."
                  rows={16}
                  label="Body"
                  hint="Markdown content for this article"
                />
                <.tag_input
                  tags={@tags}
                  add_event="add_tag"
                  remove_event="remove_tag"
                  input_id="article-tag-input"
                  placeholder="Add tag..."
                  label="Tags"
                  hint="Press Enter to add tags"
                />
              </div>
            </section>

            <%!-- Submit --%>
            <div class="flex flex-wrap items-center justify-end gap-s2 pt-s4 border-t border-rule">
              <.button navigate={cancel_path(@live_action, @article)}>Cancel</.button>
              <.button type="submit" variant="primary" phx-disable-with="Saving...">
                {if(@live_action == :new, do: "Create Article", else: "Save Changes")}
              </.button>
            </div>
          </div>
        </.form>
      </div>
    </.page>
    """
  end

  # -- Helpers --

  defp cancel_path(:edit, article) when not is_nil(article) and article.slug != nil do
    ~p"/articles/#{article.slug}"
  end

  defp cancel_path(_, _), do: ~p"/articles"
end
