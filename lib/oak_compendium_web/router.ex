defmodule OakCompendiumWeb.Router do
  use OakCompendiumWeb, :router

  import OakCompendiumWeb.Plugs.Auth, only: [require_auth: 2, force_auth: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OakCompendiumWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug OakCompendiumWeb.Plugs.CORS
    plug OpenApiSpex.Plug.PutApiSpec, module: OakCompendiumWeb.ApiSpec
    plug :require_auth
  end

  pipeline :api_force_auth do
    plug :accepts, ["json"]
    plug OakCompendiumWeb.Plugs.CORS
    plug :force_auth
  end

  # Health check (no pipeline — lightweight for load balancers)
  get "/health", OakCompendiumWeb.HealthController, :check

  # Public browser routes
  scope "/", OakCompendiumWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/list", SpeciesListLive
    live "/species/:name", SpeciesDetailLive
    live "/species/:name/merge/:target", SpeciesMergeLive
    live "/compare/:name", SpeciesCompareLive
    live "/taxonomy", TaxonomyLive
    live "/taxonomy/*path", TaxonomyLive
    live "/articles", ArticlesLive
    live "/articles/:slug", ArticleLive
    live "/sources", SourcesLive
    live "/sources/:id", SourceDetailLive
    live "/search", SearchLive
    live "/settings", SettingsLive
    live "/about", AboutLive
  end

  # Auth verification (requires auth on all methods)
  scope "/api/v1/auth", OakCompendiumWeb do
    pipe_through :api_force_auth

    get "/verify", AuthController, :verify
    post "/verify", AuthController, :verify
  end

  # API routes (public reads, auth required for writes)
  scope "/api/v1", OakCompendiumWeb.API do
    pipe_through :api

    # Species
    get "/species", SpeciesController, :index
    get "/species/search", SpeciesController, :search
    get "/species/:name", SpeciesController, :show
    get "/species/:name/full", SpeciesController, :full

    # Taxa
    get "/taxa", TaxaController, :index
    get "/taxa/:level/:name", TaxaController, :show

    # Sources
    get "/sources", SourcesController, :index
    get "/sources/:id", SourcesController, :show

    # Articles
    get "/articles", ArticlesController, :index
    get "/articles/tags", ArticlesController, :tags
    get "/articles/:slug", ArticlesController, :show

    # Unified search
    get "/search", SearchController, :search

    # Stats
    get "/stats", StatsController, :index
  end

  # OpenAPI docs (outside the API module scope to avoid module prefix)
  scope "/api/v1/docs" do
    pipe_through :api

    get "/openapi.json", OpenApiSpex.Plug.RenderSpec, []
    get "/", OpenApiSpex.Plug.SwaggerUI, path: "/api/v1/docs/openapi.json"
  end
end
