defmodule Oaks.Species.References do
  @moduledoc """
  Finds and rewrites the places where species refer to each other by name.

  Species point at each other by scientific name, not by id: `parent1` and
  `parent2`, and the JSON name lists `hybrids`, `closely_related_to`, and
  `subspecies_varieties`. Renaming, deleting, or merging a species has to
  update those mentions in other species, or their links break. This module
  is the single place that knows where those mentions live.

  Names are compared ignoring case, surrounding and repeated whitespace, and
  the spacing after the hybrid sign, so `"× numidica"` matches `"×numidica"`.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Oaks.Repo
  alias Oaks.Species.Species

  @parent_fields [:parent1, :parent2]
  @list_fields [:hybrids, :closely_related_to, :subspecies_varieties]

  @typedoc "A species that mentions a name, and the fields it's mentioned in."
  @type mention :: %{species: Species.t(), fields: [atom()]}

  @doc """
  Returns every other species that mentions `name`, with the fields that
  mention it, ordered by scientific name.
  """
  @spec find(String.t()) :: [mention()]
  def find(name) do
    target = key(name)

    from(s in Species, order_by: s.scientific_name)
    |> Repo.all()
    |> Enum.reject(&(key(&1.scientific_name) == target))
    |> Enum.flat_map(fn species ->
      case Enum.filter(@parent_fields ++ @list_fields, &mentions?(species, &1, target)) do
        [] -> []
        fields -> [%{species: species, fields: fields}]
      end
    end)
  end

  @doc """
  Adds steps to `multi` that point every mention of `old_name` at `new_name`,
  or remove the mentions when `new_name` is nil.

  Species whose ids are in `:except` are skipped (e.g. the species being
  renamed or merged, which the caller updates itself). A species never ends
  up listing itself, and duplicate list entries are dropped.
  """
  @spec rewrite(Multi.t(), String.t(), String.t() | nil, keyword()) :: Multi.t()
  def rewrite(multi, old_name, new_name, opts \\ []) do
    except = MapSet.new(Keyword.get(opts, :except, []))

    old_name
    |> find()
    |> Enum.reject(&MapSet.member?(except, &1.species.id))
    |> Enum.reduce(multi, fn %{species: species}, multi ->
      changes = changes_for(species, key(old_name), new_name)
      Multi.update(multi, {:reference, species.id}, Ecto.Changeset.change(species, changes))
    end)
  end

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

  defp mentions?(species, field, target) when field in @parent_fields do
    case Map.get(species, field) do
      name when is_binary(name) -> key(name) == target
      _ -> false
    end
  end

  defp mentions?(species, field, target) do
    species |> Map.get(field) |> decode() |> Enum.any?(&(is_binary(&1) and key(&1) == target))
  end

  defp changes_for(species, old_key, new_name) do
    own_key = key(species.scientific_name)

    parent_changes =
      for field <- @parent_fields,
          (value = Map.get(species, field)) |> is_binary(),
          key(value) == old_key,
          into: %{} do
        replacement = if new_name && key(new_name) != own_key, do: new_name
        {field, replacement}
      end

    list_changes =
      for field <- @list_fields,
          list = decode(Map.get(species, field)),
          Enum.any?(list, &(is_binary(&1) and key(&1) == old_key)),
          into: %{},
          do: {field, encode(rewrite_list(list, old_key, new_name, own_key))}

    Map.merge(parent_changes, list_changes)
  end

  # Replaces (or drops, when new_name is nil) entries matching old_key, then
  # drops self mentions and duplicates. Non-string entries are kept as-is.
  defp rewrite_list(list, old_key, new_name, own_key) do
    list
    |> Enum.flat_map(&replace_entry(&1, old_key, new_name))
    |> Enum.reject(&(is_binary(&1) and key(&1) == own_key))
    |> Enum.uniq_by(&if(is_binary(&1), do: key(&1), else: &1))
  end

  defp replace_entry(entry, old_key, new_name) when is_binary(entry) do
    if key(entry) == old_key, do: List.wrap(new_name), else: [entry]
  end

  defp replace_entry(entry, _old_key, _new_name), do: [entry]
end
