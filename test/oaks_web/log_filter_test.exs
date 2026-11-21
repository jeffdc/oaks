defmodule OaksWeb.LogFilterTest do
  @moduledoc """
  Guards against secrets showing up in request and socket connect logs.
  """
  use ExUnit.Case

  test "login and password-change params are redacted in logs" do
    filtered =
      Phoenix.Logger.filter_values(%{
        "user" => %{
          "email" => "editor@example.com",
          "password" => "secret-password",
          "password_confirmation" => "secret-password",
          "current_password" => "old-password"
        },
        "_csrf_token" => "csrf",
        "q" => "alba"
      })

    assert filtered["user"]["password"] == "[FILTERED]"
    assert filtered["user"]["password_confirmation"] == "[FILTERED]"
    assert filtered["user"]["current_password"] == "[FILTERED]"
    assert filtered["user"]["email"] == "editor@example.com"
    assert filtered["_csrf_token"] == "[FILTERED]"
    assert filtered["q"] == "alba"
  end

  test "token and api_key params are redacted in logs" do
    filtered =
      Phoenix.Logger.filter_values(%{
        "token" => "setup-link-token",
        "user_token" => "session-token",
        "api_key" => "secret-key"
      })

    assert filtered["token"] == "[FILTERED]"
    assert filtered["user_token"] == "[FILTERED]"
    assert filtered["api_key"] == "[FILTERED]"
  end
end
