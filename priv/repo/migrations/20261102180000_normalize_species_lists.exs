defmodule Oaks.Repo.Migrations.NormalizeSpeciesLists do
  @moduledoc """
  One-time data cleanup from the 2026-11 audit (mechanical fixes only).

    * JSON list columns: blank values ("", "null", "[]", lists of blanks)
      become NULL; entries are re-encoded as UTF-8 (no `\\u00d7` escapes)
      with whitespace runs collapsed, which removes scraper newlines.
    * Species authors: whitespace runs collapsed.
    * Hybrid back-links: a hybrid's parents list it in their `hybrids`.
    * A species never lists itself in its own `hybrids`.

  Every change is computed from the existing rows, so this is a no-op on an
  empty database and safe to run again. It doesn't depend on application
  modules, so later code changes can't alter what it does.
  """
  use Ecto.Migration

  @species_list_columns ~w(hybrids closely_related_to subspecies_varieties synonyms external_links)

  def up do
    for column <- @species_list_columns, do: normalize_column("species", column)
    normalize_column("species_sources", "local_names")
    collapse_author_whitespace()
    add_hybrid_back_links()
  end

  def down, do: :ok

  defp normalize_column(table, column) do
    %{rows: rows} =
      repo().query!("SELECT id, #{column} FROM #{table} WHERE #{column} IS NOT NULL")

    for [id, raw] <- rows, (normalized = normalize(raw)) != raw do
      repo().query!("UPDATE #{table} SET #{column} = ?1 WHERE id = ?2", [normalized, id])
    end
  end

  # Returns the normalized JSON text, nil for blank lists, or the original
  # value when it isn't a JSON list (left for manual review).
  defp normalize(raw) do
    case Jason.decode(raw) do
      {:ok, list} when is_list(list) ->
        list
        |> Enum.map(&clean_entry/1)
        |> Enum.reject(&(&1 in ["", nil]))
        |> case do
          [] -> nil
          entries -> Jason.encode!(entries)
        end

      {:ok, nil} ->
        nil

      _ ->
        if String.trim(raw) == "", do: nil, else: raw
    end
  end

  defp clean_entry(entry) when is_binary(entry), do: collapse(entry)
  defp clean_entry(entry), do: entry

  defp collapse(text), do: text |> String.split() |> Enum.join(" ")

  defp collapse_author_whitespace do
    %{rows: rows} = repo().query!("SELECT id, author FROM species WHERE author IS NOT NULL")

    for [id, author] <- rows, (collapsed = collapse(author)) != author do
      repo().query!("UPDATE species SET author = ?1 WHERE id = ?2", [nullify(collapsed), id])
    end
  end

  defp nullify(""), do: nil
  defp nullify(text), do: text

  defp add_hybrid_back_links do
    %{rows: rows} =
      repo().query!("SELECT scientific_name, hybrids, parent1, parent2 FROM species")

    by_key = Map.new(rows, fn [name, hybrids, _, _] -> {key(name), {name, decode(hybrids)}} end)
    wanted = hybrids_by_parent(rows, by_key)

    for {parent_key, {parent_name, current}} <- by_key,
        (updated = with_back_links(current, parent_key, Map.get(wanted, parent_key, []))) !=
          current do
      value = if updated == [], do: nil, else: Jason.encode!(updated)

      repo().query!("UPDATE species SET hybrids = ?1 WHERE scientific_name = ?2", [
        value,
        parent_name
      ])
    end
  end

  # %{parent key => [hybrid names that list it as a parent]}, in row order
  defp hybrids_by_parent(rows, by_key) do
    for [name, _, parent1, parent2] <- rows,
        parent <- [parent1, parent2],
        is_binary(parent) and Map.has_key?(by_key, key(parent)) and key(parent) != key(name),
        reduce: %{} do
      acc -> Map.update(acc, key(parent), [name], &(&1 ++ [name]))
    end
  end

  # Drops a self-reference and appends hybrids not already listed.
  defp with_back_links(current, parent_key, hybrids) do
    kept = Enum.reject(current, &(is_binary(&1) and key(&1) == parent_key))
    existing = MapSet.new(for h <- kept, is_binary(h), do: key(h))

    missing =
      hybrids
      |> Enum.reject(&MapSet.member?(existing, key(&1)))
      |> Enum.uniq_by(&key/1)

    kept ++ missing
  end

  defp decode(nil), do: []

  defp decode(raw) do
    case Jason.decode(raw) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
  end

  # Compares names ignoring case, spacing, and the hybrid sign's spacing.
  defp key(name),
    do: name |> String.replace(~r/^\s*×\s*/u, "×") |> collapse() |> String.downcase()
end
