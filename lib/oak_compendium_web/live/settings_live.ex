defmodule OakCompendiumWeb.SettingsLive do
  use OakCompendiumWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Settings", verify_status: nil)}
  end

  @impl true
  def handle_event("verify_result", %{"status" => status}, socket) do
    verify_status =
      case status do
        "ok" -> :ok
        "invalid" -> :invalid
        "error" -> :error
      end

    {:noreply, assign(socket, verify_status: verify_status)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto" id="settings-page" phx-hook="ApiKeySettings">
      <h1 class="text-2xl font-bold mb-6">Settings</h1>

      <div class="space-y-4">
        <div>
          <label for="api-key-input" class="block text-sm font-medium mb-1">
            API Key
          </label>
          <p class="text-sm text-gray-500 mb-2">
            Required for editing species, articles, and other write operations.
            Stored locally in your browser.
          </p>
          <div class="flex gap-2">
            <input
              type="password"
              id="api-key-input"
              class="flex-1 rounded border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Enter your API key"
            />
            <button
              id="save-api-key"
              class="rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
            >
              Save
            </button>
            <button
              id="verify-api-key"
              class="rounded border border-gray-300 px-4 py-2 text-sm font-medium hover:bg-gray-50"
            >
              Verify
            </button>
          </div>
        </div>

        <div
          :if={@verify_status == :ok}
          class="rounded bg-green-50 border border-green-200 p-3 text-sm text-green-800"
        >
          API key is valid.
        </div>
        <div
          :if={@verify_status == :invalid}
          class="rounded bg-red-50 border border-red-200 p-3 text-sm text-red-800"
        >
          API key is invalid.
        </div>
        <div
          :if={@verify_status == :error}
          class="rounded bg-yellow-50 border border-yellow-200 p-3 text-sm text-yellow-800"
        >
          Could not verify API key. Check your connection.
        </div>

        <div class="text-sm text-gray-500">
          <p>
            Your API key is stored only in this browser's localStorage.
            It is sent as a Bearer token in the Authorization header for write requests.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
