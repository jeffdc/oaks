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
    plug :require_auth
  end

  pipeline :api_force_auth do
    plug :accepts, ["json"]
    plug :force_auth
  end

  # Public browser routes
  scope "/", OakCompendiumWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/settings", SettingsLive
  end

  # Auth verification (requires auth on all methods)
  scope "/api/v1/auth", OakCompendiumWeb do
    pipe_through :api_force_auth

    get "/verify", AuthController, :verify
    post "/verify", AuthController, :verify
  end

  # API routes (public reads, auth required for writes)
  scope "/api/v1", OakCompendiumWeb do
    pipe_through :api
  end
end
