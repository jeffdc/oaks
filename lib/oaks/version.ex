defmodule Oaks.Version do
  @moduledoc """
  Version information for the Oak Compendium, shown on the About page.

  - **App version**: CalVer (YYYY.M.D) of the build date, fixed at compile
    time. Production images are compiled fresh on every deploy, so in
    production this is the date the running release was deployed. It matches
    the CalVer tags of GitHub releases. The OpenAPI spec uses it too.

  Mirrors `Gallformers.Version`'s app version.
  """

  @app_version (
                 date = Date.utc_today()
                 "#{date.year}.#{date.month}.#{date.day}"
               )

  @doc """
  Returns the application version in CalVer format, e.g. `"2026.11.2"`.
  """
  @spec app_version() :: String.t()
  def app_version, do: @app_version
end
