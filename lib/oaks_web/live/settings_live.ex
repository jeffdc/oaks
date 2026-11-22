defmodule OaksWeb.SettingsLive do
  @moduledoc """
  Account settings page.

  Logged in: shows the account email with links to the password,
  recovery-code and agent-token pages and a log-out link. Logged out: redirects to the login page.
  """

  use OaksWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_scope] do
      {:ok, assign(socket, page_title: "Settings")}
    else
      {:ok,
       socket
       |> put_flash(:error, "You must log in to access this page.")
       |> redirect(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page width="form" id="settings-page">
      <:head>
        <.header>Settings</.header>
      </:head>

      <section class="settings-section">
        <.section_heading>Account</.section_heading>

        <p class="settings-description" id="settings-logged-in">
          Logged in as <strong>{@current_scope.user.email}</strong>
        </p>

        <div class="settings-button-group">
          <.button href={~p"/users/settings/password"}>Change password</.button>
          <.button href={~p"/users/settings/recovery-codes"}>Recovery codes</.button>
          <.button href={~p"/users/settings/api-tokens"}>Agent tokens</.button>
        </div>
      </section>

      <section class="settings-section settings-aside">
        <.button href={~p"/users/log-out"} method="delete">Log out</.button>
      </section>
    </.page>
    """
  end
end
