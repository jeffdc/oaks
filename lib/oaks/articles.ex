defmodule Oaks.Articles do
  @moduledoc """
  The Articles context.

  Provides functions for querying and managing articles (guides, reviews, etc.).
  Visibility depends on authentication: unauthenticated users only see
  published articles.
  """

  import Ecto.Query

  alias Oaks.Articles.Article
  alias Oaks.Repo

  # -- List --

  @doc """
  Returns articles, optionally filtered by tag and publication status.

  When `authenticated` is false, only published articles are returned.
  """
  @spec list_articles(map(), boolean()) :: [Article.t()]
  def list_articles(params \\ %{}, authenticated \\ false) do
    Article
    |> maybe_filter_published(authenticated)
    |> maybe_filter_tag(params["tag"])
    |> order_by([a], desc: a.updated_at)
    |> Repo.all()
  end

  @doc """
  Returns an article by slug, or nil if not found.

  When `authenticated` is false, returns nil for unpublished articles.
  """
  @spec get_article_by_slug(String.t(), boolean()) :: Article.t() | nil
  def get_article_by_slug(slug, authenticated \\ false) do
    article = Repo.get_by(Article, slug: slug)

    case article do
      nil -> nil
      %{is_published: false} when not authenticated -> nil
      _ -> article
    end
  end

  @doc """
  Returns all tags with their counts. Only counts published articles
  when not authenticated.
  """
  @spec list_tags(boolean()) :: [%{tag: String.t(), count: integer()}]
  def list_tags(authenticated \\ false) do
    articles =
      Article
      |> maybe_filter_published(authenticated)
      |> Repo.all()

    articles
    |> Enum.flat_map(fn a -> parse_tags(a.tags) end)
    |> Enum.frequencies()
    |> Enum.map(fn {tag, count} -> %{tag: tag, count: count} end)
    |> Enum.sort_by(& &1.tag)
  end

  # -- CRUD --

  @doc """
  Creates an article from the given attributes.

  Auto-generates a unique slug from the title and sets timestamps.
  If `is_published` is true, sets `published_at`.
  """
  @spec create_article(map()) :: {:ok, Article.t()} | {:error, Ecto.Changeset.t()}
  def create_article(attrs) do
    now = now_iso8601()
    title = attrs["title"] || attrs[:title] || ""
    slug = generate_unique_slug(title)

    is_published = to_boolean(attrs["is_published"] || attrs[:is_published])

    db_attrs =
      attrs
      |> stringify_keys()
      |> Map.merge(%{
        "slug" => slug,
        "created_at" => now,
        "updated_at" => now,
        "published_at" => if(is_published, do: now, else: nil),
        "tags" => encode_tags(attrs["tags"] || attrs[:tags])
      })

    %Article{}
    |> Article.changeset(db_attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an article with the given attributes.

  Regenerates the slug if the title changed. Sets `published_at` when
  transitioning from unpublished to published.
  """
  @spec update_article(Article.t(), map()) :: {:ok, Article.t()} | {:error, Ecto.Changeset.t()}
  def update_article(%Article{} = article, attrs) do
    now = now_iso8601()
    attrs = stringify_keys(attrs)

    new_title = attrs["title"] || article.title

    slug =
      if new_title != article.title do
        generate_unique_slug(new_title, article.id)
      else
        article.slug
      end

    new_published = to_boolean(attrs["is_published"])

    published_at =
      if new_published && !article.is_published do
        now
      else
        article.published_at
      end

    db_attrs =
      attrs
      |> Map.merge(%{
        "slug" => slug,
        "updated_at" => now,
        "published_at" => published_at,
        "tags" => encode_tags(attrs["tags"] || article.tags)
      })

    article
    |> Article.changeset(db_attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an article.
  """
  @spec delete_article(Article.t()) :: {:ok, Article.t()} | {:error, Ecto.Changeset.t()}
  def delete_article(%Article{} = article) do
    Repo.delete(article)
  end

  @doc """
  Returns a changeset for form validation (no slug/timestamps required).
  """
  @spec change_article(Article.t(), map()) :: Ecto.Changeset.t()
  def change_article(%Article{} = article, attrs \\ %{}) do
    Article.form_changeset(article, attrs)
  end

  # -- Markdown --

  @doc """
  Renders markdown content to HTML using Earmark.
  Returns safe HTML string or empty string if content is nil.
  """
  @spec render_markdown(String.t() | nil) :: String.t()
  defdelegate render_markdown(content), to: Oaks.Markdown, as: :render_html

  # -- Serialization --

  @doc """
  Converts an article struct to an API response map.
  """
  @spec to_map(Article.t()) :: map()
  def to_map(article) do
    %{
      id: article.id,
      slug: article.slug,
      title: article.title,
      author: article.author,
      content: article.content,
      tags: parse_tags(article.tags),
      is_published: article.is_published,
      created_at: article.created_at,
      updated_at: article.updated_at,
      published_at: article.published_at
    }
  end

  # -- Slug Generation --

  @doc """
  Generates a URL-safe slug from a title.
  """
  def generate_slug(title) when is_binary(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/[\s_]+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  def generate_slug(_), do: ""

  # -- Tag Parsing --

  @doc """
  Parses a JSON-encoded tags string into a list.
  """
  def parse_tags(nil), do: []
  def parse_tags(""), do: []

  def parse_tags(str) when is_binary(str) do
    case Jason.decode(str) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
  end

  # -- Private --

  defp maybe_filter_published(query, true), do: query

  defp maybe_filter_published(query, false) do
    where(query, [a], a.is_published == true)
  end

  defp maybe_filter_tag(query, nil), do: query
  defp maybe_filter_tag(query, ""), do: query

  defp maybe_filter_tag(query, tag) do
    search = "%\"#{tag}\"%"
    where(query, [a], fragment("? LIKE ?", a.tags, ^search))
  end

  defp generate_unique_slug(title, exclude_id \\ nil) do
    base_slug = generate_slug(title)
    find_available_slug(base_slug, exclude_id, 0)
  end

  defp find_available_slug(base_slug, exclude_id, 0) do
    if slug_taken?(base_slug, exclude_id) do
      find_available_slug(base_slug, exclude_id, 2)
    else
      base_slug
    end
  end

  defp find_available_slug(base_slug, exclude_id, n) do
    candidate = "#{base_slug}-#{n}"

    if slug_taken?(candidate, exclude_id) do
      find_available_slug(base_slug, exclude_id, n + 1)
    else
      candidate
    end
  end

  defp slug_taken?(slug, nil) do
    Repo.exists?(from a in Article, where: a.slug == ^slug)
  end

  defp slug_taken?(slug, exclude_id) do
    Repo.exists?(from a in Article, where: a.slug == ^slug and a.id != ^exclude_id)
  end

  defp encode_tags(nil), do: nil
  defp encode_tags(tags) when is_binary(tags), do: tags
  defp encode_tags(tags) when is_list(tags), do: Jason.encode!(tags)

  defp now_iso8601 do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp to_boolean(true), do: true
  defp to_boolean("true"), do: true
  defp to_boolean(_), do: false
end
