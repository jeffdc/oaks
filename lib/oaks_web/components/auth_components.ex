defmodule OaksWeb.AuthComponents do
  @moduledoc """
  Pieces shared by the login, setup and security settings pages
  (`OaksWeb.UserSessionController`, `OaksWeb.UserSetupController`,
  `OaksWeb.UserSettingsController`). Fields are the system field
  (CoreComponents' `oc-` field classes); the rest uses the settings page
  styles in app.css.
  """
  use Phoenix.Component

  @doc "A labelled input for a form field, with its errors."
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :rest, :global, include: ~w(autocomplete inputmode autofocus required spellcheck)

  def auth_field(assigns) do
    ~H"""
    <div class="oc-field">
      <label for={@field.id} class="oc-label">{@label}</label>
      <input
        type={@type}
        id={@field.id}
        name={@field.name}
        value={if @type == "password", do: nil, else: @field.value}
        class="oc-input"
        aria-invalid={@field.errors != [] && "true"}
        {@rest}
      />
      <.field_errors field={@field} />
    </div>
    """
  end

  @doc "A form field's errors, marked as CoreComponents marks them: bold ink and a drawn sign."
  attr :field, Phoenix.HTML.FormField, required: true

  def field_errors(assigns) do
    assigns = assign(assigns, :errors, Enum.map(assigns.field.errors, &translate_error/1))

    ~H"""
    <p :for={error <- @errors} class="oc-error" role="alert">
      <svg viewBox="0 0 14 14" aria-hidden="true">
        <circle cx="7" cy="7" r="6" fill="none" stroke="currentColor" stroke-width="1.6" />
        <path d="M7 3.6v4.2" stroke="currentColor" stroke-width="1.8" />
        <circle cx="7" cy="10.2" r="1" fill="currentColor" />
      </svg>
      {error}
    </p>
    """
  end

  @doc "A message: an error (an ink plate) or a confirmation (an ink outline)."
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
    <ol id="recovery-codes" class="settings-codes">
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
