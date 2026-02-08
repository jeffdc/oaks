defmodule OaksWeb.Layouts do
  @moduledoc """
  Layouts and related components for the Oak Compendium.

  Two layouts are provided:

  * `:root` — the HTML skeleton (head, body, scripts). Set via
    `put_root_layout` in the router pipeline.
  * `:app`  — the application chrome (nav, main). Rendered
    from `app.html.heex` via `embed_templates`.
  """
  use OaksWeb, :html

  embed_templates "layouts/*"

  @doc false
  def nav_class(current_path, link_path) do
    if nav_active?(current_path, link_path), do: "nav-link nav-link-active", else: "nav-link"
  end

  @doc false
  def nav_icon_class(current_path, link_path) do
    if nav_active?(current_path, link_path),
      do: "nav-icon-link nav-icon-link-active",
      else: "nav-icon-link"
  end

  defp nav_active?(nil, _link_path), do: false

  defp nav_active?(current_path, "/list") do
    current_path == "/list" or
      String.starts_with?(current_path, "/species/") or
      String.starts_with?(current_path, "/compare/")
  end

  defp nav_active?(current_path, link_path) do
    current_path == link_path or String.starts_with?(current_path, link_path <> "/")
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
