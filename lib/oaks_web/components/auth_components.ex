defmodule OaksWeb.AuthComponents do
  @moduledoc """
  Pieces shared by the login, setup and security settings pages
  (`OaksWeb.UserSessionController`, `OaksWeb.UserSetupController`,
  `OaksWeb.UserSettingsController`). They reuse the settings page styles.
  """
  use Phoenix.Component

  @doc "A labelled input for a form field, with its errors."
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :rest, :global, include: ~w(autocomplete inputmode autofocus required spellcheck)

  def auth_field(assigns) do
    assigns = assign(assigns, :errors, Enum.map(assigns.field.errors, &translate_error/1))

    ~H"""
    <div class="settings-form-group">
      <label for={@field.id} class="settings-form-label">{@label}</label>
      <input
        type={@type}
        id={@field.id}
        name={@field.name}
        value={if @type == "password", do: nil, else: @field.value}
        class="settings-form-input"
        {@rest}
      />
      <p :for={error <- @errors} class="settings-message settings-message-error" role="alert">
        {error}
      </p>
    </div>
    """
  end

  @doc "A message box: an error or a confirmation."
  attr :kind, :atom, values: [:error, :success], default: :error
  slot :inner_block, required: true

  def auth_message(assigns) do
    ~H"""
    <div
      class={["settings-message", "settings-message-#{@kind}"]}
      role={if @kind == :error, do: "alert", else: "status"}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Recovery codes, shown once, with how to use them."
  attr :codes, :list, required: true

  def recovery_code_list(assigns) do
    ~H"""
    <p class="settings-description">
      Save these recovery codes somewhere safe, such as a password manager. Each one
      works once in place of a code from your authenticator app. They won't be shown again.
    </p>
    <ol id="recovery-codes" class="settings-info-box" style="font-family: ui-monospace, monospace;">
      <li :for={code <- @codes}>{code}</li>
    </ol>
    """
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
