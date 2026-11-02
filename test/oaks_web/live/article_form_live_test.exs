defmodule OaksWeb.ArticleFormLiveTest do
  @moduledoc """
  Tests for ArticleFormLive (create/edit articles).
  Uses seeded test data (see priv/repo/test_seeds.sql).
  """
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oaks.Articles

  defp authenticated_conn(conn) do
    put_connect_params(conn, %{"api_key" => Application.get_env(:oaks, :api_key)})
  end

  describe "unauthenticated" do
    test "new redirects on connected mount", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/articles"}}} = live(conn, ~p"/articles/new")
    end

    test "edit redirects on connected mount", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/articles"}}} =
               live(conn, ~p"/articles/getting-started/edit")
    end
  end

  describe "new (authenticated)" do
    test "creates an article with tags", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/articles/new")

      render_hook(view, "add_tag", %{"value" => "acorns"})

      assert {:error, {:live_redirect, %{to: "/articles/acorn-notes"}}} =
               view
               |> form("#article-form",
                 article: %{title: "Acorn Notes", author: "Jeff", content: "Body"}
               )
               |> render_submit()

      article = Articles.get_article_by_slug("acorn-notes", true)
      assert article.content == "Body"
      assert Articles.parse_tags(article.tags) == ["acorns"]
    end

    test "shows validation errors for a missing title", %{conn: conn} do
      {:ok, view, _html} = conn |> authenticated_conn() |> live(~p"/articles/new")

      html =
        view
        |> form("#article-form", article: %{title: "", author: "Jeff"})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "edit (authenticated)" do
    test "updates the article and keeps its published slug", %{conn: conn} do
      {:ok, view, _html} =
        conn |> authenticated_conn() |> live(~p"/articles/getting-started/edit")

      assert {:error, {:live_redirect, %{to: "/articles/getting-started"}}} =
               view
               |> form("#article-form", article: %{title: "Getting Started, Revised"})
               |> render_submit()

      assert Articles.get_article_by_slug("getting-started").title == "Getting Started, Revised"
    end

    test "redirects for an unknown slug", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/articles"}}} =
               conn |> authenticated_conn() |> live(~p"/articles/nope/edit")
    end
  end
end
