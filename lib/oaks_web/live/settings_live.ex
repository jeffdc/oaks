defmodule OaksWeb.SettingsLive do
  @moduledoc """
  Account settings page.

  Logged in: shows the account email with links to the password,
  recovery-code and agent-token pages and a log-out link. Logged out: points to the login page.
  """

  use OaksWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Settings")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="settings-container" id="settings-page">
      <h1 class="settings-title">Settings</h1>

      <section class="card p-6">
        <h2 class="section-title" style="margin-bottom: 0.5rem;">Account</h2>

        <%= if @current_scope do %>
          <p class="settings-description" id="settings-logged-in">
            Logged in as <strong>{@current_scope.user.email}</strong>
          </p>

          <div class="settings-button-group">
            <.link
              href={~p"/users/settings/password"}
              class="settings-btn settings-btn-secondary"
              style="text-decoration: none;"
            >
              Change password
            </.link>
            <.link
              href={~p"/users/settings/recovery-codes"}
              class="settings-btn settings-btn-secondary"
              style="text-decoration: none;"
            >
              Recovery codes
            </.link>
            <.link
              href={~p"/users/settings/api-tokens"}
              class="settings-btn settings-btn-secondary"
              style="text-decoration: none;"
            >
              Agent tokens
            </.link>
          </div>

          <.link
            href={~p"/users/log-out"}
            method="delete"
            class="settings-btn settings-btn-primary"
            style="text-decoration: none;"
          >
            Log out
          </.link>
        <% else %>
          <p class="settings-description" id="settings-logged-out">
            Log in to edit species, sources, taxonomy and articles.
          </p>

          <.link
            href={~p"/users/log-in"}
            class="settings-btn settings-btn-primary"
            style="text-decoration: none;"
          >
            Log in
          </.link>
        <% end %>
      </section>
    </div>
    """
  end
end
