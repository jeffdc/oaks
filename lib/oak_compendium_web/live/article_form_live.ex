defmodule OakCompendiumWeb.ArticleFormLive do
  @moduledoc """
  LiveView for creating and editing articles.

  Handles both `:new` and `:edit` actions. Form includes title, author,
  content (markdown textarea), tags (comma-separated), and is_published
  checkbox. Requires authentication — redirects unauthenticated users.
  """

  use OakCompendiumWeb, :live_view

  alias OakCompendium.Articles
  alias OakCompendium.Articles.Article

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Article",
       article: nil,
       form: nil,
       live_action: nil,
       tags_input: "",
       preview_html: ""
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    if not (socket.assigns[:authenticated] || false) do
      {:noreply,
       socket
       |> put_flash(:error, "You must be authenticated to manage articles.")
       |> push_navigate(to: ~p"/articles")}
    else
      apply_action(socket, socket.assigns.live_action, params)
    end
  end

  defp apply_action(socket, :new, _params) do
    article = %Article{}
    changeset = Articles.change_article(article)

    {:noreply,
     assign(socket,
       page_title: "New Article",
       article: article,
       form: to_form(changeset),
       tags_input: "",
       preview_html: ""
     )}
  end

  defp apply_action(socket, :edit, %{"slug" => slug}) do
    case Articles.get_article_by_slug(slug, true) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Article not found.")
         |> push_navigate(to: ~p"/articles")}

      article ->
        tags_str = article.tags |> Articles.parse_tags() |> Enum.join(", ")

        changeset =
          Articles.change_article(article, %{
            "title" => article.title,
            "author" => article.author,
            "content" => article.content,
            "is_published" => article.is_published
          })

        {:noreply,
         assign(socket,
           page_title: "Edit: #{article.title}",
           article: article,
           form: to_form(changeset),
           tags_input: tags_str,
           preview_html: Articles.render_markdown(article.content)
         )}
    end
  end

  @impl true
  def handle_event("validate", %{"article" => params}, socket) do
    changeset =
      socket.assigns.article
      |> Articles.change_article(params)
      |> Map.put(:action, :validate)

    preview_html = Articles.render_markdown(params["content"])

    {:noreply,
     assign(socket,
       form: to_form(changeset),
       preview_html: preview_html
     )}
  end

  def handle_event("update_tags", %{"value" => value}, socket) do
    {:noreply, assign(socket, tags_input: value)}
  end

  def handle_event("save", %{"article" => params}, socket) do
    tags =
      socket.assigns.tags_input
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    params = Map.put(params, "tags", tags)

    case socket.assigns.live_action do
      :new -> create_article(socket, params)
      :edit -> update_article(socket, params)
    end
  end

  defp create_article(socket, params) do
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

  defp update_article(socket, params) do
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
    <div class="max-w-4xl mx-auto">
      <.link
        navigate={cancel_path(@live_action, @article)}
        class="inline-flex items-center gap-1 text-sm mb-6"
        style="color: var(--color-forest-600); text-decoration: none;"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Cancel
      </.link>

      <h1
        class="text-3xl font-bold mb-6"
        style="font-family: var(--font-serif); color: var(--color-forest-800);"
      >
        {if @live_action == :new, do: "New Article", else: "Edit Article"}
      </h1>

      <div :if={@form} class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div class="card p-6">
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-5">
            <div>
              <label
                for="article_title"
                class="block text-sm font-medium mb-1"
                style="color: var(--color-text-primary);"
              >
                Title <span style="color: #dc2626;">*</span>
              </label>
              <input
                type="text"
                id="article_title"
                name="article[title]"
                value={@form[:title].value}
                class="w-full rounded-lg border px-3 py-2 text-sm focus:outline-none focus:ring-2"
                style={"border-color: #{if(@form[:title].errors != [], do: "#dc2626", else: "var(--color-border)")}; focus-ring-color: var(--color-forest-500);"}
                phx-debounce="300"
              />
              <.form_error :for={{msg, _} <- @form[:title].errors} message={msg} />
            </div>

            <div>
              <label
                for="article_author"
                class="block text-sm font-medium mb-1"
                style="color: var(--color-text-primary);"
              >
                Author <span style="color: #dc2626;">*</span>
              </label>
              <input
                type="text"
                id="article_author"
                name="article[author]"
                value={@form[:author].value}
                class="w-full rounded-lg border px-3 py-2 text-sm focus:outline-none focus:ring-2"
                style={"border-color: #{if(@form[:author].errors != [], do: "#dc2626", else: "var(--color-border)")}; focus-ring-color: var(--color-forest-500);"}
                phx-debounce="300"
              />
              <.form_error :for={{msg, _} <- @form[:author].errors} message={msg} />
            </div>

            <div>
              <label
                for="article_content"
                class="block text-sm font-medium mb-1"
                style="color: var(--color-text-primary);"
              >
                Content
                <span class="text-xs font-normal" style="color: var(--color-text-tertiary);">
                  (Markdown)
                </span>
              </label>
              <textarea
                id="article_content"
                name="article[content]"
                rows="16"
                class="w-full rounded-lg border px-3 py-2 text-sm font-mono focus:outline-none focus:ring-2"
                style="border-color: var(--color-border);"
                phx-debounce="500"
              >{@form[:content].value}</textarea>
            </div>

            <div>
              <label
                for="article_tags"
                class="block text-sm font-medium mb-1"
                style="color: var(--color-text-primary);"
              >
                Tags
                <span class="text-xs font-normal" style="color: var(--color-text-tertiary);">
                  (comma-separated)
                </span>
              </label>
              <input
                type="text"
                id="article_tags"
                value={@tags_input}
                class="w-full rounded-lg border px-3 py-2 text-sm focus:outline-none focus:ring-2"
                style="border-color: var(--color-border);"
                placeholder="guide, beginner, identification"
                phx-keyup="update_tags"
                phx-debounce="300"
              />
            </div>

            <div class="flex items-center gap-2">
              <input
                type="hidden"
                name="article[is_published]"
                value="false"
              />
              <input
                type="checkbox"
                id="article_is_published"
                name="article[is_published]"
                value="true"
                checked={to_string(@form[:is_published].value) == "true"}
                class="rounded border"
                style="accent-color: var(--color-forest-600);"
              />
              <label
                for="article_is_published"
                class="text-sm"
                style="color: var(--color-text-primary);"
              >
                Published
              </label>
            </div>

            <div class="flex justify-end gap-3 pt-2">
              <.link
                navigate={cancel_path(@live_action, @article)}
                class="px-4 py-2 rounded-lg text-sm font-medium"
                style="background-color: var(--color-base-200); color: var(--color-text-primary); text-decoration: none;"
              >
                Cancel
              </.link>
              <button
                type="submit"
                class="px-4 py-2 rounded-lg text-sm font-medium text-white"
                style="background-color: var(--color-forest-600);"
              >
                {if @live_action == :new, do: "Create Article", else: "Save Changes"}
              </button>
            </div>
          </.form>
        </div>

        <div class="hidden lg:block">
          <h3 class="text-sm font-medium mb-3" style="color: var(--color-text-tertiary);">
            Preview
          </h3>
          <div class="card p-6">
            <div
              :if={@preview_html == ""}
              class="text-center py-8"
              style="color: var(--color-text-tertiary);"
            >
              <.icon name="hero-eye" class="size-8 mx-auto mb-2 opacity-40" />
              <p class="text-sm">Start typing to see a preview</p>
            </div>
            <div :if={@preview_html != ""} class="prose-content">
              {raw(@preview_html)}
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # -- Components --

  attr :message, :string, required: true

  defp form_error(assigns) do
    ~H"""
    <p class="text-xs mt-1" style="color: #dc2626;">
      {@message}
    </p>
    """
  end

  # -- Helpers --

  defp cancel_path(:edit, article) when not is_nil(article) and article.slug != nil do
    ~p"/articles/#{article.slug}"
  end

  defp cancel_path(_, _), do: ~p"/articles"
end
