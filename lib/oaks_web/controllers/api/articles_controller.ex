defmodule OaksWeb.API.ArticlesController do
  @moduledoc """
  API controller for articles endpoints.

  The API is read-only and public: it returns published articles only.
  """

  use OaksWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Oaks.Articles

  tags(["Articles"])

  operation(:index,
    summary: "List articles",
    description: "Returns published articles.",
    parameters: [
      tag: [in: :query, type: :string, description: "Filter by tag"]
    ],
    responses: [
      ok:
        {"Articles list", "application/json",
         %OpenApiSpex.Schema{
           type: :array,
           items: OaksWeb.Schemas.Article
         }}
    ]
  )

  def index(conn, params) do
    articles = Articles.list_articles(params, false)
    json(conn, Enum.map(articles, &Articles.to_map/1))
  end

  operation(:show,
    summary: "Get an article",
    description:
      "Returns a single published article by slug. Returns 404 for unpublished articles.",
    parameters: [
      slug: [in: :path, type: :string, description: "Article slug", required: true]
    ],
    responses: [
      ok: {"Article", "application/json", OaksWeb.Schemas.Article},
      not_found: {"Not found", "application/json", OaksWeb.Schemas.Error}
    ]
  )

  def show(conn, %{"slug" => slug}) do
    case Articles.get_article_by_slug(slug, false) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Article not found"})

      article ->
        json(conn, Articles.to_map(article))
    end
  end

  operation(:tags,
    summary: "List article tags",
    description: "Returns all tags with published article counts.",
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
    tags = Articles.list_tags(false)
    json(conn, tags)
  end
end
