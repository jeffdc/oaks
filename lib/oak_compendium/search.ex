defmodule OakCompendium.Search do
  @moduledoc """
  Unified search across species, taxa, and sources.
  """

  import Ecto.Query

  alias OakCompendium.Repo
  alias OakCompendium.Sources.Source
  alias OakCompendium.Species.Species
  alias OakCompendium.Taxonomy.Taxon

  @default_limit 50
  @max_limit 500

  @doc """
  Searches across species, taxa, and sources. Returns results grouped by type.
  """
  @spec search(String.t(), integer()) :: map()
  def search(query, limit \\ @default_limit) do
    limit = min(max(limit, 1), @max_limit)
    term = "%#{String.downcase(query)}%"

    %{
      species: search_species(term, limit),
      taxa: search_taxa(term, limit),
      sources: search_sources(term, limit)
    }
  end

  defp search_species(term, limit) do
    from(s in Species,
      where: fragment("lower(?) LIKE ?", s.scientific_name, ^term),
      order_by: [asc: s.scientific_name],
      limit: ^limit,
      select: %{
        id: s.id,
        scientific_name: s.scientific_name,
        author: s.author,
        is_hybrid: s.is_hybrid,
        subgenus: s.subgenus,
        section: s.section
      }
    )
    |> Repo.all()
  end

  defp search_taxa(term, limit) do
    from(t in Taxon,
      where: fragment("lower(?) LIKE ?", t.name, ^term),
      order_by: [asc: t.name],
      limit: ^limit,
      select: %{
        id: t.id,
        name: t.name,
        level: t.level,
        parent: t.parent,
        author: t.author
      }
    )
    |> Repo.all()
  end

  defp search_sources(term, limit) do
    from(s in Source,
      where: fragment("lower(?) LIKE ?", s.name, ^term),
      order_by: [asc: s.name],
      limit: ^limit,
      select: %{
        id: s.id,
        name: s.name,
        source_type: s.source_type,
        url: s.url
      }
    )
    |> Repo.all()
  end
end
