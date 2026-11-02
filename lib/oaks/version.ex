defmodule Oaks.Version do
  @moduledoc """
  Version information for the Oak Compendium, shown on the About page.

  - **App version**: CalVer (YYYY.M.D) of the build date, fixed at compile
    time. Production images are compiled fresh on every deploy, so in
    production this is the date the running release was deployed. It matches
    the CalVer tags of GitHub releases.
  - **API version**: SemVer of the public REST API, also used by the OpenAPI
    spec (`OaksWeb.ApiSpec`).

  Mirrors `Gallformers.Version`.
  """

  @app_version (
                 date = Date.utc_today()
                 "#{date.year}.#{date.month}.#{date.day}"
               )

  @api_version "1.0.0"

  @doc """
  Returns the application version in CalVer format, e.g. `"2026.11.2"`.
  """
  @spec app_version() :: String.t()
  def app_version, do: @app_version

  @doc """
  Returns the REST API version, e.g. `"1.0.0"`.
  """
  @spec api_version() :: String.t()
  def api_version, do: @api_version
end
