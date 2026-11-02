defmodule Oaks.JsonList do
  @moduledoc """
  Changeset support for TEXT columns that hold a JSON array of names
  (species relationships, synonyms, local names).

  Forms let people type either a JSON array or a comma-separated list.
  `cast/3` turns either into a normalized JSON array string, clears blank
  input to nil, and adds a visible error for anything else so bad input is
  never stored and later silently read back as an empty list.
  """

  import Ecto.Changeset

  @doc """
  Normalizes a changed JSON-list field on the changeset.

  ## Options
    * `:allow_objects` - also accept `%{"name" => ...}` entries (used by synonyms)
  """
  @spec cast(Ecto.Changeset.t(), atom(), keyword()) :: Ecto.Changeset.t()
  def cast(changeset, field, opts \\ []) do
    case fetch_change(changeset, field) do
      {:ok, value} when is_binary(value) ->
        case normalize(value, opts) do
          {:ok, normalized} -> put_change(changeset, field, normalized)
          {:error, message} -> add_error(changeset, field, message)
        end

      _ ->
        changeset
    end
  end

  @doc """
  Normalizes raw list input. Returns `{:ok, json_or_nil}` or `{:error, message}`.

      iex> Oaks.JsonList.normalize(" alba, rubra ,, ")
      {:ok, ~s(["alba","rubra"])}

      iex> Oaks.JsonList.normalize(~s(["alba"]))
      {:ok, ~s(["alba"])}

      iex> Oaks.JsonList.normalize("")
      {:ok, nil}
  """
  @spec normalize(String.t(), keyword()) :: {:ok, String.t() | nil} | {:error, String.t()}
  def normalize(value, opts \\ []) do
    trimmed = String.trim(value)

    cond do
      trimmed in ["", "null", "[]"] -> {:ok, nil}
      String.starts_with?(trimmed, "[") -> normalize_json(trimmed, opts)
      true -> trimmed |> String.split(",") |> encode_entries(opts)
    end
  end

  defp normalize_json(json, opts) do
    case Jason.decode(json) do
      {:ok, list} when is_list(list) -> encode_entries(list, opts)
      _ -> {:error, "must be a JSON array or a comma-separated list"}
    end
  end

  defp encode_entries(entries, opts) do
    allow_objects = Keyword.get(opts, :allow_objects, false)

    if Enum.all?(entries, &valid_entry?(&1, allow_objects)) do
      entries
      |> Enum.map(&clean_entry/1)
      |> Enum.reject(&(&1 == ""))
      |> case do
        [] -> {:ok, nil}
        list -> {:ok, Jason.encode!(list)}
      end
    else
      {:error, "must contain only names"}
    end
  end

  defp valid_entry?(entry, _allow_objects) when is_binary(entry), do: true

  defp valid_entry?(%{"name" => name}, true) when is_binary(name), do: true
  defp valid_entry?(_entry, _allow_objects), do: false

  defp clean_entry(entry) when is_binary(entry), do: entry |> String.split() |> Enum.join(" ")
  defp clean_entry(entry), do: entry
end
