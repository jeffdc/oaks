defmodule OaksWeb.Router do
  use OaksWeb, :router

  import OaksWeb.UserAuth,
    only: [fetch_current_scope_for_user: 2, require_authenticated_user: 2, require_sudo_mode: 2]

  # Scripts only from our own origin, so injected markup can't run code even if
  # it slips past markdown sanitizing. Inline styles are allowed because the
  # templates use style attributes; images may come from any HTTPS host
  # (iNaturalist photos in articles).
  @content_security_policy [
    "default-src 'self'",
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: https:",
    "font-src 'self' data:",
    "connect-src 'self'",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'self'"
  ]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OaksWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "content-security-policy" => Enum.join(@content_security_policy, "; ")
    }

    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug OaksWeb.Plugs.CORS
    plug OpenApiSpex.Plug.PutApiSpec, module: OaksWeb.ApiSpec
  end

  # The private API, for agents with a token (item fbd0). No CORS: callers
  # aren't browsers.
  pipeline :private_api do
    plug :accepts, ["json"]
    plug OaksWeb.Plugs.ApiToken
  end

  # Health check (no pipeline — lightweight for load balancers)
  get "/health", OaksWeb.HealthController, :check

  # Public browser routes
  scope "/", OaksWeb do
    pipe_through :browser

    # The species index was /list until item 3248.
    get "/list", RedirectController, :species_list

    live_session :default,
      on_mount: [
        OaksWeb.Hooks.ActiveNav,
        {OaksWeb.UserAuth, :mount_current_scope},
        {OaksWeb.Analytics.TrackPageView, :default}
      ] do
      live "/", HomeLive
      live "/species", SpeciesListLive
      live "/species/new", SpeciesFormLive, :new
      live "/species/:name/edit", SpeciesFormLive, :edit
      live "/species/:name", SpeciesDetailLive
      live "/species/:name/merge/:target", SpeciesMergeLive
      live "/species/:name/compare", SpeciesCompareLive
      live "/species/:name/sources/new", SpeciesSourceFormLive, :new
      live "/species/:name/sources/:source_id/edit", SpeciesSourceFormLive, :edit
      live "/taxonomy", TaxonomyLive
      live "/taxonomy/new", TaxonFormLive, :new
      live "/taxonomy/:id/edit", TaxonFormLive, :edit
      live "/taxonomy/*path", TaxonomyLive
      live "/articles", ArticlesLive
      live "/articles/new", ArticleFormLive, :new
      live "/articles/:slug/edit", ArticleFormLive, :edit
      live "/articles/:slug", ArticleLive
      live "/sources", SourcesLive
      live "/sources/new", SourceFormLive, :new
      live "/sources/:id/edit", SourceFormLive, :edit
      live "/sources/:id", SourceDetailLive
      live "/search", SearchLive
      live "/settings", SettingsLive
      live "/about", AboutLive
      live "/help/markdown", HelpMarkdownLive
      live "/analytics", AnalyticsLive, :index
      live "/privacy", PrivacyLive
    end
  end

  # API routes (public, read-only)
  scope "/api/v1", OaksWeb.API do
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

  # Private API (agent tokens; not in the OpenAPI spec)
  scope "/api/private/v1", OaksWeb.PrivateAPI do
    pipe_through :private_api

    get "/token", TokenController, :show
    post "/import", ImportController, :create
  end

  # OpenAPI docs (outside the API module scope to avoid module prefix)
  scope "/api/v1/docs" do
    pipe_through :api

    get "/openapi.json", OpenApiSpex.Plug.RenderSpec, []
    get "/", OpenApiSpex.Plug.SwaggerUI, path: "/api/v1/docs/openapi.json"
  end

  # Development-only routes: the one-click login (OaksWeb.DevLoginController)
  # and the component gallery. Compiled in only when dev_routes is set (dev
  # and test), never in a release.
  if Application.compile_env(:oaks, :dev_routes) do
    scope "/dev", OaksWeb do
      pipe_through :browser

      post "/log-in", DevLoginController, :create

      # The DESIGN.md component gallery (OaksWeb.DevComponentsLive, item 21b7).
      live "/components", DevComponentsLive
    end
  end

  ## Login (OaksWeb.UserAuth)

  # Logging in, out, and setup from a setup link. Plain controllers, not
  # LiveViews: each step writes the session cookie.
  scope "/users", OaksWeb do
    pipe_through :browser

    get "/log-in", UserSessionController, :new
    post "/log-in", UserSessionController, :create
    get "/log-in/code", UserSessionController, :code
    post "/log-in/code", UserSessionController, :verify_code
    delete "/log-out", UserSessionController, :delete

    get "/setup", UserSetupController, :edit
    post "/setup", UserSetupController, :update
    get "/setup/:token", UserSetupController, :start
  end

  # Security settings and agent tokens: logged in, and logged in recently
  # (sudo mode).
  scope "/users/settings", OaksWeb do
    pipe_through [:browser, :require_authenticated_user, :require_sudo_mode]

    get "/password", UserSettingsController, :edit_password
    put "/password", UserSettingsController, :update_password
    get "/recovery-codes", UserSettingsController, :recovery_codes
    post "/recovery-codes", UserSettingsController, :regenerate_recovery_codes
    get "/api-tokens", UserSettingsController, :api_tokens
    post "/api-tokens", UserSettingsController, :create_api_token
    delete "/api-tokens/:id", UserSettingsController, :delete_api_token
  end
end
