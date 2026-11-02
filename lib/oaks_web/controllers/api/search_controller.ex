defmodule OaksWeb.API.SearchController do
  @moduledoc """
  API controller for unified search.
  """

  use OaksWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Oaks.Search
  alias OaksWeb.Params

  tags(["Search"])

  operation(:search,
    summary: "Unified search",
    description: "Searches across species, taxa, and sources.",
    parameters: [
      q: [in: :query, type: :string, description: "Search query", required: true],
      limit: [
        in: :query,
        type: :integer,
        description: "Max results per category (default 50, max 500)"
      ]
    ],
    responses: [
      ok: {"Search results", "application/json", OaksWeb.Schemas.SearchResponse}
    ]
  )

  def search(conn, %{"q" => query} = params) when is_binary(query) do
    limit = Params.int(params["limit"]) || 50

    results = Search.search(query, limit)
    json(conn, results)
  end

  def search(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "Missing required parameter: q"})
  end
end
