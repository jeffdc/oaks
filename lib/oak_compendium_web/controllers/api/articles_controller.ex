defmodule OakCompendiumWeb.API.ArticlesController do
  @moduledoc """
  API controller for articles endpoints.

  Visibility depends on authentication: unauthenticated users only see
  published articles.
  """

  use OakCompendiumWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OakCompendium.Articles
  alias OakCompendiumWeb.Plugs.Auth

  tags(["Articles"])

  operation(:index,
    summary: "List articles",
    description: "Returns articles. Unauthenticated users see published articles only.",
    parameters: [
      tag: [in: :query, type: :string, description: "Filter by tag"]
    ],
    responses: [
      ok:
        {"Articles list", "application/json",
         %OpenApiSpex.Schema{
           type: :array,
           items: OakCompendiumWeb.Schemas.Article
         }}
    ]
  )

  def index(conn, params) do
    authenticated = Auth.authenticated?(conn)
    articles = Articles.list_articles(params, authenticated)
    json(conn, Enum.map(articles, &Articles.to_map/1))
  end

  operation(:show,
    summary: "Get an article",
    description:
      "Returns a single article by slug. Returns 404 for unpublished articles when unauthenticated.",
    parameters: [
      slug: [in: :path, type: :string, description: "Article slug", required: true]
    ],
    responses: [
      ok: {"Article", "application/json", OakCompendiumWeb.Schemas.Article},
      not_found: {"Not found", "application/json", OakCompendiumWeb.Schemas.Error}
    ]
  )

  def show(conn, %{"slug" => slug}) do
    authenticated = Auth.authenticated?(conn)

    case Articles.get_article_by_slug(slug, authenticated) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Article not found"})

      article ->
        json(conn, Articles.to_map(article))
    end
  end

  operation(:tags,
    summary: "List article tags",
    description: "Returns all tags with article counts.",
    responses: [
      ok:
        {"Tags", "application/json",
         %OpenApiSpex.Schema{
           type: :array,
           items: %OpenApiSpex.Schema{
             type: :object,
             properties: %{
               tag: %OpenApiSpex.Schema{type: :string},
               count: %OpenApiSpex.Schema{type: :integer}
             }
           }
         }}
    ]
  )

  def tags(conn, _params) do
    authenticated = Auth.authenticated?(conn)
    tags = Articles.list_tags(authenticated)
    json(conn, tags)
  end
end
