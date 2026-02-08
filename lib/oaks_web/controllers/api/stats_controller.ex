defmodule OaksWeb.API.StatsController do
  @moduledoc """
  API controller for database statistics.
  """

  use OaksWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Oaks.Stats

  tags(["Stats"])

  operation(:index,
    summary: "Get database statistics",
    description: "Returns aggregate counts for species, hybrids, taxa, and sources.",
    responses: [
      ok: {"Stats", "application/json", OaksWeb.Schemas.StatsResponse}
    ]
  )

  def index(conn, _params) do
    json(conn, Stats.get_stats())
  end
end
