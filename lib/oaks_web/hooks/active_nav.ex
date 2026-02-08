defmodule OaksWeb.Hooks.ActiveNav do
  @moduledoc false

  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> assign(:current_path, nil)
     |> attach_hook(:active_nav_path, :handle_params, fn _params, uri, socket ->
       {:cont, assign(socket, :current_path, URI.parse(uri).path)}
     end)}
  end
end
