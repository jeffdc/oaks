defmodule Oaks.ArticlesTest do
  @moduledoc """
  Tests for the Articles context.
  """

  use Oaks.DataCase

  import Oaks.ArticlesFixtures

  alias Oaks.Articles
  alias Oaks.Articles.Article

  defp unique_tag, do: "tag#{System.unique_integer([:positive])}"

  describe "list_articles/2" do
    setup do
      tag = unique_tag()
      published = article_fixture(tags: [tag])
      draft = article_fixture(tags: [tag], is_published: false)
      %{tag: tag, published: published, draft: draft}
    end

    test "returns only published articles by default", %{published: published, draft: draft} do
      slugs = Enum.map(Articles.list_articles(), & &1.slug)
      assert published.slug in slugs
      refute draft.slug in slugs
    end

    test "returns all articles when authenticated", %{published: published, draft: draft} do
      slugs = Enum.map(Articles.list_articles(%{}, true), & &1.slug)
      assert published.slug in slugs
      assert draft.slug in slugs
    end

    test "filters by tag", %{tag: tag, published: published} do
      assert [%Article{slug: slug}] = Articles.list_articles(%{"tag" => tag})
      assert slug == published.slug
    end

    test "returns empty list for non-existent tag" do
      assert Articles.list_articles(%{"tag" => unique_tag()}) == []
    end
  end

  describe "get_article_by_slug/2" do
    setup do
      %{published: article_fixture(), draft: article_fixture(is_published: false)}
    end

    test "returns published article", %{published: published} do
      assert Articles.get_article_by_slug(published.slug).title == published.title
    end

    test "returns nil for unpublished article when not authenticated", %{draft: draft} do
      assert nil == Articles.get_article_by_slug(draft.slug)
    end

    test "returns unpublished article when authenticated", %{draft: draft} do
      assert Articles.get_article_by_slug(draft.slug, true).title == draft.title
    end

    test "returns nil for non-existent slug" do
      assert nil == Articles.get_article_by_slug("does-not-exist")
    end
  end

  describe "list_tags/1" do
    setup do
      published_tag = unique_tag()
      draft_tag = unique_tag()
      article_fixture(tags: [published_tag])
      article_fixture(tags: [draft_tag], is_published: false)
      %{published_tag: published_tag, draft_tag: draft_tag}
    end

    test "returns tags from published articles only by default", ctx do
      tag_names = Enum.map(Articles.list_tags(), & &1.tag)
      assert ctx.published_tag in tag_names
      refute ctx.draft_tag in tag_names
    end

    test "returns tags from all articles when authenticated", ctx do
      tag_names = Enum.map(Articles.list_tags(true), & &1.tag)
      assert ctx.published_tag in tag_names
      assert ctx.draft_tag in tag_names
    end
  end

  describe "create_article/1" do
    test "creates article with valid attributes" do
      title = "Test Article #{System.unique_integer([:positive])}"

      attrs = %{
        "title" => title,
        "author" => "Tester",
        "content" => "Some **bold** content",
        "tags" => ["test", "new"],
        "is_published" => "true"
      }

      assert {:ok, article} = Articles.create_article(attrs)
      assert article.title == title
      assert article.slug == Articles.generate_slug(title)
      assert article.author == "Tester"
      assert article.is_published == true
      assert article.published_at != nil
      assert article.created_at != nil
      assert article.updated_at != nil
    end

    test "auto-generates unique slug on collision" do
      existing = article_fixture()

      assert {:ok, article} =
               Articles.create_article(%{"title" => existing.title, "author" => "Someone"})

      assert article.slug == existing.slug <> "-2"
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
      article = article_fixture()

      assert {:ok, updated} =
               Articles.update_article(article, %{
                 "title" => "Updated Title",
                 "is_published" => "true"
               })

      assert updated.title == "Updated Title"
      assert updated.slug == article.slug
    end

    test "regenerates the slug when a never-published draft is retitled" do
      article = article_fixture(is_published: false)
      title = "Section Notes #{System.unique_integer([:positive])}"

      {:ok, updated} = Articles.update_article(article, %{"title" => title})
      assert updated.slug == Articles.generate_slug(title)
    end

    test "sets published_at when transitioning to published" do
      article = article_fixture(is_published: false)
      assert article.published_at == nil

      assert {:ok, updated} =
               Articles.update_article(article, %{"is_published" => "true"})

      assert updated.published_at != nil
      assert updated.is_published == true
    end

    test "preserves slug when title unchanged" do
      article = article_fixture()

      assert {:ok, updated} =
               Articles.update_article(article, %{
                 "content" => "New content",
                 "is_published" => "true"
               })

      assert updated.slug == article.slug
    end
  end

  describe "delete_article/1" do
    test "deletes an article" do
      article = article_fixture()
      assert {:ok, _} = Articles.delete_article(article)
      assert nil == Articles.get_article_by_slug(article.slug)
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

    test "transliterates accented letters" do
      assert Articles.generate_slug("Chênes du Québec") == "chenes-du-quebec"
    end
  end

  describe "slug edge cases on create" do
    defp create(title) do
      Articles.create_article(%{"title" => title, "author" => "Jeff", "content" => "x"})
    end

    test "falls back to a generic slug when the title has no Latin letters" do
      assert {:ok, %{slug: "article"}} = create("日本のオーク")
      assert {:ok, %{slug: "article-2"}} = create("!!!")
    end

    test "never uses slugs reserved by routes" do
      assert {:ok, %{slug: "new-2"}} = create("New")
      assert {:ok, %{slug: "tags-2"}} = create("Tags")
    end

    test "rejects overlong titles with a title error" do
      assert {:error, changeset} = create(String.duplicate("a", 201))
      assert changeset.errors[:title]
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
