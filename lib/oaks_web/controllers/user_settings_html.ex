defmodule OaksWeb.UserSettingsHTML do
  use OaksWeb, :html

  import OaksWeb.AuthComponents

  alias Oaks.Accounts.ApiToken

  embed_templates "user_settings_html/*"

  @scope_descriptions %{
    "materials:read" => "read private material",
    "packages:submit" => "submit import packages"
  }

  defp scope_description(scope), do: Map.fetch!(@scope_descriptions, scope)

  defp date(%DateTime{} = dt), do: Calendar.strftime(dt, "%-d %b %Y")

  defp expired?(token), do: ApiToken.expired?(token)
end
