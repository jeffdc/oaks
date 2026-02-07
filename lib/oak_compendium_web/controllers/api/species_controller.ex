defmodule OakCompendiumWeb.API.SpeciesController do
  @moduledoc """
  API controller for species endpoints.
  """

  use OakCompendiumWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OakCompendium.Species

  tags(["Species"])

  operation(:index,
    summary: "List species",
    description: "Returns a paginated list of species with optional filters.",
    parameters: [
      limit: [in: :query, type: :integer, description: "Max results (default 50, max 500)"],
      offset: [in: :query, type: :integer, description: "Number of results to skip"],
      subgenus: [in: :query, type: :string, description: "Filter by subgenus"],
      section: [in: :query, type: :string, description: "Filter by section"],
      subsection: [in: :query, type: :string, description: "Filter by subsection"],
      complex: [in: :query, type: :string, description: "Filter by complex"],
      hybrid: [in: :query, type: :string, description: "Filter by hybrid status (true/false)"]
    ],
    responses: [
      ok: {"Species list", "application/json", OakCompendiumWeb.Schemas.SpeciesListResponse}
    ]
  )

  def index(conn, params) do
    {species, count} = Species.list_species(params)
    limit = parse_int(params["limit"]) || 50
    offset = parse_int(params["offset"]) || 0

    json(conn, %{
      data: Enum.map(species, &Species.to_map/1),
      count: count,
      limit: limit,
      offset: offset
    })
  end

  operation(:show,
    summary: "Get a species",
    description: "Returns a single species by scientific name. Checks synonyms if not found.",
    parameters: [
      name: [in: :path, type: :string, description: "Scientific name", required: true]
    ],
    responses: [
      ok: {"Species", "application/json", OakCompendiumWeb.Schemas.Species},
      not_found: {"Not found", "application/json", OakCompendiumWeb.Schemas.Error}
    ]
  )

  def show(conn, %{"name" => name}) do
    name = URI.decode(name)

    case Species.get_species_by_name(name) do
      nil ->
        case Species.find_synonym(name) do
          nil ->
            conn |> put_status(:not_found) |> json(%{error: "Species not found"})

          species ->
            conn
            |> put_resp_header(
              "location",
              "/api/v1/species/#{URI.encode(species.scientific_name)}"
            )
            |> put_status(:moved_permanently)
            |> json(Species.to_map(species))
        end

      species ->
        json(conn, Species.to_map(species))
    end
  end

  operation(:full,
    summary: "Get species with all source data",
    description: "Returns a species with embedded source data (morphology, range, etc.).",
    parameters: [
      name: [in: :path, type: :string, description: "Scientific name", required: true]
    ],
    responses: [
      ok: {"Species full", "application/json", OakCompendiumWeb.Schemas.SpeciesFull},
      not_found: {"Not found", "application/json", OakCompendiumWeb.Schemas.Error}
    ]
  )

  def full(conn, %{"name" => name}) do
    name = URI.decode(name)

    case Species.get_species_full(name) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Species not found"})

      species ->
        json(conn, Species.to_full_map(species))
    end
  end

  operation(:search,
    summary: "Search species",
    description: "Search species by name (case-insensitive substring match).",
    parameters: [
      q: [in: :query, type: :string, description: "Search query", required: true],
      limit: [in: :query, type: :integer, description: "Max results (default 50)"]
    ],
    responses: [
      ok: {"Search results", "application/json", OakCompendiumWeb.Schemas.SpeciesListResponse}
    ]
  )

  def search(conn, %{"q" => query} = params) do
    limit = parse_int(params["limit"]) || 50
    species = Species.search_species(query, limit)

    json(conn, %{
      data: Enum.map(species, &Species.to_map/1),
      count: length(species),
      limit: limit,
      offset: 0
    })
  end

  def search(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "Missing required parameter: q"})
  end

  defp parse_int(nil), do: nil

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_int(val) when is_integer(val), do: val
end
