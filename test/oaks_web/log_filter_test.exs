defmodule OaksWeb.LogFilterTest do
  @moduledoc """
  Guards against secrets showing up in request and socket connect logs.
  """
  use ExUnit.Case

  test "api_key connect param is redacted in logs" do
    filtered =
      Phoenix.Logger.filter_values(%{
        "api_key" => "secret-key",
        "_csrf_token" => "csrf",
        "q" => "alba"
      })

    assert filtered["api_key"] == "[FILTERED]"
    assert filtered["_csrf_token"] == "[FILTERED]"
    assert filtered["q"] == "alba"
  end
end
