defmodule OaksWeb.Params do
  @moduledoc """
  Helpers for reading untrusted request, URL, and LiveView event params.

  Query strings can carry lists or maps (`?q[]=x`), and event values can be
  anything a client sends, so read them through these instead of assuming a
  string or calling `String.to_integer/1`.
  """

  @doc """
  Returns the value if it is a string, otherwise the default.
  """
  @spec string(term(), String.t() | nil) :: String.t() | nil
  def string(value, default \\ "")
  def string(value, _default) when is_binary(value), do: value
  def string(_value, default), do: default

  @doc """
  Parses a whole-number string (or passes through an integer). Returns nil otherwise.
  """
  @spec int(term()) :: integer() | nil
  def int(value) when is_integer(value), do: value

  def int(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> nil
    end
  end

  def int(_value), do: nil
end
