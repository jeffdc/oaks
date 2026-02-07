defmodule OakCompendiumWeb.ApiSpec do
  @moduledoc """
  OpenAPI specification for the Oak Compendium API.
  """

  alias OpenApiSpex.{Info, OpenApi, Paths, Server}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "Oak Compendium API",
        version: "1.0.0",
        description: "API for the Quercus (oak) species database"
      },
      servers: [
        %Server{url: "/"}
      ],
      paths: Paths.from_router(OakCompendiumWeb.Router)
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
