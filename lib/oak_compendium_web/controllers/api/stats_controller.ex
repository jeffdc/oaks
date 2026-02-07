defmodule OakCompendiumWeb.API.StatsController do
  @moduledoc """
  API controller for database statistics.
  """

  use OakCompendiumWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OakCompendium.Stats

  tags(["Stats"])

  operation(:index,
    summary: "Get database statistics",
    description: "Returns aggregate counts for species, hybrids, taxa, and sources.",
    responses: [
      ok: {"Stats", "application/json", OakCompendiumWeb.Schemas.StatsResponse}
    ]
  )

  def index(conn, _params) do
    json(conn, Stats.get_stats())
  end
end
