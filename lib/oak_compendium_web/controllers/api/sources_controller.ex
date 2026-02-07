defmodule OakCompendiumWeb.API.SourcesController do
  @moduledoc """
  API controller for data source endpoints.
  """

  use OakCompendiumWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OakCompendium.Sources

  tags(["Sources"])

  operation(:index,
    summary: "List sources",
    description: "Returns all data sources.",
    responses: [
      ok:
        {"Sources list", "application/json",
         %OpenApiSpex.Schema{
           type: :array,
           items: OakCompendiumWeb.Schemas.Source
         }}
    ]
  )

  def index(conn, _params) do
    sources = Sources.list_sources()
    json(conn, Enum.map(sources, &Sources.to_map/1))
  end

  operation(:show,
    summary: "Get a source",
    description: "Returns a single source by ID.",
    parameters: [
      id: [in: :path, type: :integer, description: "Source ID", required: true]
    ],
    responses: [
      ok: {"Source", "application/json", OakCompendiumWeb.Schemas.Source},
      bad_request: {"Invalid ID", "application/json", OakCompendiumWeb.Schemas.Error},
      not_found: {"Not found", "application/json", OakCompendiumWeb.Schemas.Error}
    ]
  )

  def show(conn, %{"id" => id}) do
    case parse_int(id) do
      nil ->
        conn |> put_status(:bad_request) |> json(%{error: "Invalid source ID"})

      id ->
        case Sources.get_source(id) do
          nil ->
            conn |> put_status(:not_found) |> json(%{error: "Source not found"})

          source ->
            json(conn, Sources.to_map(source))
        end
    end
  end

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_int(val) when is_integer(val), do: val
end
