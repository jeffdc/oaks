defmodule OakCompendium.Sources do
  @moduledoc """
  The Sources context.

  Provides functions for querying data sources and species-source
  junction records.
  """

  import Ecto.Query

  alias OakCompendium.Repo
  alias OakCompendium.Sources.{Source, SpeciesSource}
  alias OakCompendium.Species.Species

  # -- List --

  @doc """
  Returns all sources ordered by name.
  """
  @spec list_sources() :: [Source.t()]
  def list_sources do
    from(s in Source, order_by: [asc: s.name])
    |> Repo.all()
  end

  @doc """
  Returns all sources ordered by name, each with a virtual `species_count`.

  Returns a list of maps with source fields plus `:species_count`.
  """
  @spec list_sources_with_species_count() :: [map()]
  def list_sources_with_species_count do
    from(s in Source,
      left_join: ss in SpeciesSource,
      on: ss.source_id == s.id,
      group_by: s.id,
      order_by: [asc: s.name],
      select: %{
        id: s.id,
        source_type: s.source_type,
        name: s.name,
        description: s.description,
        author: s.author,
        year: s.year,
        url: s.url,
        species_count: count(ss.id)
      }
    )
    |> Repo.all()
  end

  @doc """
  Returns a source by ID, or nil if not found.
  """
  @spec get_source(integer()) :: Source.t() | nil
  def get_source(id) do
    Repo.get(Source, id)
  end

  @doc """
  Returns species associated with a given source, ordered by scientific name.

  Each species is returned with basic fields needed for display and linking.
  """
  @spec get_species_for_source(integer()) :: [Species.t()]
  def get_species_for_source(source_id) do
    from(sp in Species,
      join: ss in SpeciesSource,
      on: ss.species_id == sp.id,
      where: ss.source_id == ^source_id,
      order_by: [asc: sp.scientific_name],
      select: sp
    )
    |> Repo.all()
  end

  @doc """
  Returns the total count of sources.
  """
  @spec count() :: integer()
  def count do
    Repo.aggregate(Source, :count)
  end

  # -- Serialization --

  @doc """
  Converts a source struct to an API response map.
  """
  @spec to_map(Source.t()) :: map()
  def to_map(source) do
    %{
      id: source.id,
      source_type: source.source_type,
      name: source.name,
      description: source.description,
      author: source.author,
      year: source.year,
      url: source.url,
      isbn: source.isbn,
      doi: source.doi,
      notes: source.notes,
      license: source.license,
      license_url: source.license_url
    }
  end
end
