defmodule OakCompendiumWeb.PageController do
  use OakCompendiumWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
