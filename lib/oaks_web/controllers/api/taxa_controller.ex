defmodule OaksWeb.API.TaxaController do
  @moduledoc """
  API controller for taxonomy endpoints.
  """

  use OaksWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Oaks.Taxonomy

  tags(["Taxa"])

  operation(:index,
    summary: "List taxa",
    description: "Returns all taxa, optionally filtered by level and/or parent.",
    parameters: [
      level: [
        in: :query,
        type: :string,
        description: "Filter by level (subgenus, section, subsection, complex)"
      ],
      parent: [in: :query, type: :string, description: "Filter by parent taxon name"]
    ],
    responses: [
      ok:
        {"Taxa list", "application/json",
         %OpenApiSpex.Schema{
           type: :array,
           items: OaksWeb.Schemas.Taxon
         }}
    ]
  )

  def index(conn, params) do
    taxa = Taxonomy.list_taxa(params)
    json(conn, Enum.map(taxa, &Taxonomy.to_map/1))
  end

  operation(:show,
    summary: "Get a taxon",
    description: "Returns a single taxon by level and name.",
    parameters: [
      level: [
        in: :path,
        type: :string,
        description: "Taxonomic level",
        required: true
      ],
      name: [in: :path, type: :string, description: "Taxon name", required: true]
    ],
    responses: [
      ok: {"Taxon", "application/json", OaksWeb.Schemas.Taxon},
      bad_request: {"Invalid level", "application/json", OaksWeb.Schemas.Error},
      not_found: {"Not found", "application/json", OaksWeb.Schemas.Error}
    ]
  )

  def show(conn, %{"level" => level, "name" => name}) do
    name = URI.decode(name)

    if level in Taxonomy.valid_levels() do
      case Taxonomy.get_taxon(level, name) do
        nil ->
          conn |> put_status(:not_found) |> json(%{error: "Taxon not found"})

        taxon ->
          json(conn, Taxonomy.to_map(taxon))
      end
    else
      conn |> put_status(:bad_request) |> json(%{error: "Invalid taxonomic level: #{level}"})
    end
  end
end
