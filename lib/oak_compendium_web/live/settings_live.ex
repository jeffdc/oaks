defmodule OakCompendiumWeb.SettingsLive do
  use OakCompendiumWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Settings",
       verify_status: nil,
       save_status: nil,
       show_password: false,
       authenticated: false
     )}
  end

  @impl true
  def handle_event("save_result", %{"status" => status}, socket) do
    save_status =
      case status do
        "saved" -> :saved
        "cleared" -> :cleared
      end

    authenticated = status == "saved"

    {:noreply,
     assign(socket, save_status: save_status, verify_status: nil, authenticated: authenticated)}
  end

  @impl true
  def handle_event("verify_result", %{"status" => status}, socket) do
    verify_status =
      case status do
        "ok" -> :ok
        "invalid" -> :invalid
        "error" -> :error
      end

    authenticated = if status == "ok", do: true, else: socket.assigns.authenticated

    {:noreply,
     assign(socket, verify_status: verify_status, save_status: nil, authenticated: authenticated)}
  end

  @impl true
  def handle_event("auth_status", %{"authenticated" => authenticated}, socket) do
    {:noreply, assign(socket, authenticated: authenticated)}
  end

  @impl true
  def handle_event("toggle_password", _params, socket) do
    {:noreply, assign(socket, show_password: !socket.assigns.show_password)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="settings-container" id="settings-page" phx-hook="ApiKeySettings">
      <h1 class="settings-title">Settings</h1>

      <section class="card p-6">
        <h2 class="section-title" style="margin-bottom: 0.5rem;">API Authentication</h2>
        <p class="settings-description">
          Enter your API key to enable editing features. Keys are validated before saving.
        </p>

        <div class="settings-form-group">
          <label for="api-key-input" class="settings-form-label">API Key</label>
          <div class="settings-input-wrapper">
            <input
              type={if @show_password, do: "text", else: "password"}
              id="api-key-input"
              class="settings-form-input"
              placeholder="Enter your API key"
              autocomplete="off"
            />
            <button
              type="button"
              phx-click="toggle_password"
              class="settings-toggle-visibility"
              aria-label={if @show_password, do: "Hide API key", else: "Show API key"}
            >
              <svg
                :if={!@show_password}
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="settings-icon"
              >
                <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                <circle cx="12" cy="12" r="3" />
              </svg>
              <svg
                :if={@show_password}
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="settings-icon"
              >
                <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" />
                <line x1="1" y1="1" x2="23" y2="23" />
              </svg>
            </button>
          </div>
        </div>

        <div
          :if={@verify_status == :invalid}
          class="settings-message settings-message-error"
          role="alert"
        >
          API key is invalid.
        </div>
        <div
          :if={@verify_status == :error}
          class="settings-message settings-message-error"
          role="alert"
        >
          Unable to reach the API server. Check your connection.
        </div>
        <div
          :if={@save_status == :saved}
          class="settings-message settings-message-success"
          role="status"
        >
          API key verified and saved.
        </div>
        <div
          :if={@save_status == :cleared}
          class="settings-message settings-message-success"
          role="status"
        >
          API key cleared.
        </div>

        <div class="settings-button-group">
          <button id="save-api-key" class="settings-btn settings-btn-primary">
            Save
          </button>
          <button id="clear-api-key" class="settings-btn settings-btn-secondary">
            Clear API Key
          </button>
        </div>

        <div class="settings-info-box">
          <h3 class="settings-info-title">Session Information</h3>
          <dl class="settings-info-list">
            <div class="settings-info-item">
              <dt>Status</dt>
              <dd>
                <span
                  :if={@authenticated}
                  class="settings-status-badge settings-status-authenticated"
                >
                  Authenticated
                </span>
                <span
                  :if={!@authenticated}
                  class="settings-status-badge settings-status-not-authenticated"
                >
                  Not authenticated
                </span>
              </dd>
            </div>
            <div :if={@authenticated} class="settings-info-item">
              <dt>Time Remaining</dt>
              <dd>
                <span id="session-time-remaining" class="settings-time-remaining"></span>
                <button
                  type="button"
                  id="reset-session-btn"
                  class="settings-btn-inline"
                  title="Extend session"
                >
                  Reset
                </button>
              </dd>
            </div>
            <div class="settings-info-item">
              <dt>Session Timeout</dt>
              <dd>
                <select id="session-timeout-select" class="settings-timeout-select">
                  <option value="1">1 hour</option>
                  <option value="4">4 hours</option>
                  <option value="8">8 hours</option>
                  <option value="24">24 hours</option>
                  <option value="48">48 hours</option>
                  <option value="168">1 week</option>
                </select>
              </dd>
            </div>
          </dl>
        </div>

        <div class="settings-security-note">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="settings-note-icon"
          >
            <circle cx="12" cy="12" r="10" />
            <line x1="12" y1="16" x2="12" y2="12" />
            <line x1="12" y1="8" x2="12.01" y2="8" />
          </svg>
          <div>
            <strong>Security Note:</strong> Your API key is stored in your browser's localStorage.
            It persists across sessions but is only accessible from this device and domain.
            Clear your browser data or use the "Clear API Key" button to remove it.
          </div>
        </div>
      </section>
    </div>
    """
  end
end
