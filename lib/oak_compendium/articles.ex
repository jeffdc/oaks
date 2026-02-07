defmodule OakCompendium.Articles do
  @moduledoc """
  The Articles context.

  Provides functions for querying articles (guides, reviews, etc.).
  Visibility depends on authentication: unauthenticated users only see
  published articles.
  """

  import Ecto.Query

  alias OakCompendium.Articles.Article
  alias OakCompendium.Repo

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

  defp parse_tags(nil), do: []
  defp parse_tags(""), do: []

  defp parse_tags(str) when is_binary(str) do
    case Jason.decode(str) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
  end
end
