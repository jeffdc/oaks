defmodule OakCompendium.Taxonomy do
  @moduledoc """
  The Taxonomy context.

  Provides functions for querying the taxonomic hierarchy
  (subgenus, section, subsection, complex).
  """

  import Ecto.Query

  alias OakCompendium.Repo
  alias OakCompendium.Taxonomy.Taxon

  @valid_levels ~w(subgenus section subsection complex)

  # -- List --

  @doc """
  Returns all taxa, optionally filtered by level and/or parent.

  ## Options
    * `"level"` - filter by taxonomic level
    * `"parent"` - filter by parent taxon name
  """
  @spec list_taxa(map()) :: [Taxon.t()]
  def list_taxa(params \\ %{}) do
    Taxon
    |> maybe_filter_level(params["level"])
    |> maybe_filter_parent(params["parent"])
    |> order_by([t], asc: t.level, asc: t.name)
    |> Repo.all()
  end

  @doc """
  Returns a taxon by level and name, or nil if not found.
  """
  @spec get_taxon(String.t(), String.t()) :: Taxon.t() | nil
  def get_taxon(level, name) do
    if level in @valid_levels do
      Repo.get_by(Taxon, level: level, name: name)
    end
  end

  @doc """
  Returns a taxon by ID, or nil if not found.
  """
  @spec get_taxon_by_id(integer()) :: Taxon.t() | nil
  def get_taxon_by_id(id) do
    Repo.get(Taxon, id)
  end

  @doc """
  Returns the total count of taxa.
  """
  @spec count() :: integer()
  def count do
    Repo.aggregate(Taxon, :count)
  end

  @doc """
  Returns the list of valid taxonomic levels.
  """
  @spec valid_levels() :: [String.t()]
  def valid_levels, do: @valid_levels

  # -- Serialization --

  @doc """
  Converts a taxon struct to an API response map.
  """
  @spec to_map(Taxon.t()) :: map()
  def to_map(taxon) do
    links = parse_json(taxon.links)

    %{
      id: taxon.id,
      name: taxon.name,
      level: taxon.level,
      parent: taxon.parent,
      author: taxon.author,
      content: taxon.content,
      content_updated_at: taxon.content_updated_at,
      links: links
    }
  end

  # -- Private --

  defp maybe_filter_level(query, nil), do: query
  defp maybe_filter_level(query, ""), do: query

  defp maybe_filter_level(query, level) do
    if level in @valid_levels do
      where(query, [t], t.level == ^level)
    else
      query
    end
  end

  defp maybe_filter_parent(query, nil), do: query
  defp maybe_filter_parent(query, ""), do: query
  defp maybe_filter_parent(query, parent), do: where(query, [t], t.parent == ^parent)

  defp parse_json(nil), do: nil
  defp parse_json(""), do: nil

  defp parse_json(str) when is_binary(str) do
    case Jason.decode(str) do
      {:ok, data} -> data
      _ -> nil
    end
  end
end
