defmodule Oaks.ArticlesFixtures do
  @moduledoc """
  Articles for tests (`Oaks.Articles`).
  """

  alias Oaks.Articles
  alias Oaks.Articles.Article

  @doc """
  Creates an article through `Articles.create_article/1`, which sets its
  slug and timestamps. Defaults: a unique `title`, `author: "Jeff"`,
  `content: "Body"`, no tags, published. Pass `tags` as a list.
  """
  @spec article_fixture(map() | keyword()) :: Article.t()
  def article_fixture(attrs \\ %{}) do
    defaults = %{
      title: "Article #{System.unique_integer([:positive])}",
      author: "Jeff",
      content: "Body",
      tags: [],
      is_published: true
    }

    {:ok, article} = defaults |> Map.merge(Map.new(attrs)) |> Articles.create_article()
    article
  end
end
