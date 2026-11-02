defmodule Oaks.Repo.Migrations.MergePowoSynonymHybrids do
  @moduledoc """
  Folds two hybrid names that POWO treats as synonyms into the accepted name
  (Jeff's 2026-11 parentage research):

    * × columnaris Laughlin → × richteri Baen. (palustris × rubra)
    * × subglaucescens → × anselmii (canariensis × pubescens)

  The synonym's name is added to the accepted hybrid's synonyms (so old links
  redirect), any mention of it in other species is pointed at the accepted
  name, and the synonym's record is deleted. A merge is skipped if the
  synonym has source data, so nothing is dropped silently. No-op when either
  species is missing, including on empty databases and when run again.

  Self-contained on purpose (no application modules), so later code changes
  can't alter what it did.
  """
  use Ecto.Migration

  @merges [{"× columnaris", "× richteri"}, {"× subglaucescens", "× anselmii"}]
  @parent_fields ~w(parent1 parent2)
  @list_fields ~w(hybrids closely_related_to subspecies_varieties)

  def up do
    for {synonym, accepted} <- @merges,
        mergeable?(synonym, accepted),
        do: merge(synonym, accepted)
  end

  def down, do: :ok

  defp mergeable?(synonym, accepted) do
    exists?("SELECT 1 FROM species WHERE scientific_name = ?1", [accepted]) and
      exists?("SELECT 1 FROM species WHERE scientific_name = ?1", [synonym]) and
      not exists?(
        """
        SELECT 1 FROM species_sources ss JOIN species s ON s.id = ss.species_id
        WHERE s.scientific_name = ?1
        """,
        [synonym]
      )
  end

  defp merge(synonym, accepted) do
    add_synonym(accepted, synonym)
    repoint_parents(synonym, accepted)
    repoint_lists(synonym, accepted)
    repo().query!("DELETE FROM species WHERE scientific_name = ?1", [synonym])
  end

  defp add_synonym(accepted, synonym) do
    [[synonyms]] = rows("SELECT synonyms FROM species WHERE scientific_name = ?1", [accepted])
    list = decode(synonyms)

    unless Enum.any?(list, &same?(&1, synonym)) do
      repo().query!("UPDATE species SET synonyms = ?1 WHERE scientific_name = ?2", [
        Jason.encode!(list ++ [synonym]),
        accepted
      ])
    end
  end

  defp repoint_parents(synonym, accepted) do
    for field <- @parent_fields do
      repo().query!(
        "UPDATE species SET #{field} = ?1 WHERE #{field} = ?2 AND scientific_name != ?1",
        [accepted, synonym]
      )
    end
  end

  defp repoint_lists(synonym, accepted) do
    for field <- @list_fields,
        [id, name, raw] <-
          rows("SELECT id, scientific_name, #{field} FROM species WHERE #{field} IS NOT NULL", []),
        list = decode(raw),
        Enum.any?(list, &same?(&1, synonym)) do
      updated =
        list
        |> Enum.map(&if(same?(&1, synonym), do: accepted, else: &1))
        |> Enum.reject(&same?(&1, name))
        |> Enum.uniq_by(&if(is_binary(&1), do: key(&1), else: &1))

      value = if updated == [], do: nil, else: Jason.encode!(updated)
      repo().query!("UPDATE species SET #{field} = ?1 WHERE id = ?2", [value, id])
    end
  end

  defp same?(entry, name), do: is_binary(entry) and key(entry) == key(name)

  defp exists?(sql, params), do: rows(sql, params) != []
  defp rows(sql, params), do: repo().query!(sql, params).rows

  defp decode(nil), do: []

  defp decode(raw) do
    case Jason.decode(raw) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
  end

  defp key(name),
    do:
      name
      |> String.split()
      |> Enum.join(" ")
      |> String.replace(~r/^×\s*/u, "×")
      |> String.downcase()
end
