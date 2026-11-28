defmodule Oaks.Species.References do
  @moduledoc """
  Name helpers for species.

  Links between species and taxa are keys now, so this module no longer
  finds or rewrites name mentions. It keeps `key/1`, the normalized form
  names are compared by (case, surrounding and repeated whitespace, and the
  spacing after the hybrid sign), and the synonym list's `decode/1` and
  `encode/1`, until the names table takes the synonym lists over.
  """

  @doc """
  Normalizes a name for comparison.

      iex> Oaks.Species.References.key(" ×  Numidica ")
      "×numidica"
  """
  @spec key(String.t()) :: String.t()
  def key(name) do
    name
    |> String.split()
    |> Enum.join(" ")
    |> String.replace(~r/^×\s*/u, "×")
    |> String.downcase()
  end

  @doc """
  Parses a JSON name list column, keeping non-string entries untouched.
  """
  @spec decode(String.t() | nil) :: list()
  def decode(nil), do: []

  def decode(raw) do
    case Jason.decode(raw) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
  end

  @doc """
  Encodes a name list for storage; an empty list is stored as nil.
  """
  @spec encode(list()) :: String.t() | nil
  def encode([]), do: nil
  def encode(list), do: Jason.encode!(list)
end
