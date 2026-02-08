defmodule Oaks.ArticlesTest do
  @moduledoc """
  Tests for the Articles context.
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """

  use Oaks.DataCase

  alias Oaks.Articles
  alias Oaks.Articles.Article

  describe "list_articles/2" do
    test "returns only published articles by default" do
      articles = Articles.list_articles()
      assert length(articles) == 1
      assert hd(articles).slug == "getting-started"
    end

    test "returns all articles when authenticated" do
      articles = Articles.list_articles(%{}, true)
      assert length(articles) == 2
      slugs = Enum.map(articles, & &1.slug)
      assert "getting-started" in slugs
      assert "advanced-taxonomy-draft" in slugs
    end

    test "filters by tag" do
      articles = Articles.list_articles(%{"tag" => "guide"})
      assert length(articles) == 1
      assert hd(articles).slug == "getting-started"
    end

    test "returns empty list for non-existent tag" do
      articles = Articles.list_articles(%{"tag" => "nonexistent"})
      assert articles == []
    end
  end

  describe "get_article_by_slug/2" do
    test "returns published article" do
      article = Articles.get_article_by_slug("getting-started")
      assert article.title == "Getting Started with Oak Identification"
    end

    test "returns nil for unpublished article when not authenticated" do
      assert nil == Articles.get_article_by_slug("advanced-taxonomy-draft")
    end

    test "returns unpublished article when authenticated" do
      article = Articles.get_article_by_slug("advanced-taxonomy-draft", true)
      assert article.title == "Advanced Oak Taxonomy"
    end

    test "returns nil for non-existent slug" do
      assert nil == Articles.get_article_by_slug("does-not-exist")
    end
  end

  describe "list_tags/1" do
    test "returns tags from published articles only by default" do
      tags = Articles.list_tags()
      tag_names = Enum.map(tags, & &1.tag)
      assert "guide" in tag_names
      assert "beginner" in tag_names
      refute "taxonomy" in tag_names
      refute "advanced" in tag_names
    end

    test "returns tags from all articles when authenticated" do
      tags = Articles.list_tags(true)
      tag_names = Enum.map(tags, & &1.tag)
      assert "guide" in tag_names
      assert "taxonomy" in tag_names
      assert "advanced" in tag_names
    end
  end

  describe "create_article/1" do
    test "creates article with valid attributes" do
      attrs = %{
        "title" => "Test Article",
        "author" => "Tester",
        "content" => "Some **bold** content",
        "tags" => ["test", "new"],
        "is_published" => "true"
      }

      assert {:ok, article} = Articles.create_article(attrs)
      assert article.title == "Test Article"
      assert article.slug == "test-article"
      assert article.author == "Tester"
      assert article.is_published == true
      assert article.published_at != nil
      assert article.created_at != nil
      assert article.updated_at != nil
    end

    test "auto-generates unique slug on collision" do
      attrs = %{
        "title" => "Getting Started",
        "author" => "Someone"
      }

      assert {:ok, article} = Articles.create_article(attrs)
      # "getting-started" already exists in seeds, so should get -2 suffix
      assert article.slug == "getting-started-2"
    end

    test "returns error for missing required fields" do
      assert {:error, changeset} = Articles.create_article(%{})
      assert %{title: _, author: _} = errors_on(changeset)
    end

    test "does not set published_at when is_published is false" do
      attrs = %{"title" => "Draft", "author" => "Me", "is_published" => "false"}
      assert {:ok, article} = Articles.create_article(attrs)
      assert article.published_at == nil
    end
  end

  describe "update_article/2" do
    test "updates article fields" do
      article = Articles.get_article_by_slug("getting-started")

      assert {:ok, updated} =
               Articles.update_article(article, %{
                 "title" => "Updated Title",
                 "is_published" => "true"
               })

      assert updated.title == "Updated Title"
      assert updated.slug == "updated-title"
    end

    test "sets published_at when transitioning to published" do
      article = Articles.get_article_by_slug("advanced-taxonomy-draft", true)
      assert article.published_at == nil

      assert {:ok, updated} =
               Articles.update_article(article, %{"is_published" => "true"})

      assert updated.published_at != nil
      assert updated.is_published == true
    end

    test "preserves slug when title unchanged" do
      article = Articles.get_article_by_slug("getting-started")
      original_slug = article.slug

      assert {:ok, updated} =
               Articles.update_article(article, %{
                 "content" => "New content",
                 "is_published" => "true"
               })

      assert updated.slug == original_slug
    end
  end

  describe "delete_article/1" do
    test "deletes an article" do
      article = Articles.get_article_by_slug("getting-started")
      assert {:ok, _} = Articles.delete_article(article)
      assert nil == Articles.get_article_by_slug("getting-started")
    end
  end

  describe "change_article/2" do
    test "returns a changeset" do
      article = %Article{}
      changeset = Articles.change_article(article)
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "render_markdown/1" do
    test "renders markdown to HTML" do
      html = Articles.render_markdown("# Hello\n\n**Bold** text")
      assert html =~ "<h1>"
      assert html =~ "Hello"
      assert html =~ "<strong>Bold</strong>"
    end

    test "returns empty string for nil" do
      assert Articles.render_markdown(nil) == ""
    end

    test "returns empty string for empty string" do
      assert Articles.render_markdown("") == ""
    end
  end

  describe "generate_slug/1" do
    test "converts title to slug" do
      assert Articles.generate_slug("Hello World") == "hello-world"
    end

    test "removes special characters" do
      assert Articles.generate_slug("Hello, World! #1") == "hello-world-1"
    end

    test "handles multiple spaces and hyphens" do
      assert Articles.generate_slug("  too   many   spaces  ") == "too-many-spaces"
    end
  end

  describe "parse_tags/1" do
    test "parses JSON array" do
      assert Articles.parse_tags(~s(["a","b"])) == ["a", "b"]
    end

    test "returns empty list for nil" do
      assert Articles.parse_tags(nil) == []
    end

    test "returns empty list for empty string" do
      assert Articles.parse_tags("") == []
    end

    test "returns empty list for invalid JSON" do
      assert Articles.parse_tags("not json") == []
    end
  end
end
