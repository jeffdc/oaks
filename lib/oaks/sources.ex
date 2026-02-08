defmodule Oaks.Sources do
  @moduledoc """
  The Sources context.

  Provides functions for querying data sources and species-source
  junction records.
  """

  import Ecto.Query

  alias Oaks.Repo
  alias Oaks.Sources.{Source, SpeciesSource}
  alias Oaks.Species.Species

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

  # -- SpeciesSource queries --

  @doc """
  Returns a species_source by ID, preloading source and species.
  Raises if not found.
  """
  @spec get_species_source!(integer()) :: SpeciesSource.t()
  def get_species_source!(id) do
    SpeciesSource
    |> Repo.get!(id)
    |> Repo.preload([:source, :species])
  end

  @doc """
  Returns sources that are NOT already linked to the given species.
  """
  @spec available_sources_for_species(integer()) :: [Source.t()]
  def available_sources_for_species(species_id) do
    linked_source_ids =
      from(ss in SpeciesSource,
        where: ss.species_id == ^species_id,
        select: ss.source_id
      )

    from(s in Source,
      where: s.id not in subquery(linked_source_ids),
      order_by: [asc: s.name]
    )
    |> Repo.all()
  end

  # -- Changesets --

  @doc """
  Returns a changeset for tracking source changes.
  """
  @spec change_source(Source.t(), map()) :: Ecto.Changeset.t()
  def change_source(%Source{} = source, attrs \\ %{}) do
    Source.changeset(source, attrs)
  end

  @doc """
  Returns a changeset for tracking species_source changes.
  """
  @spec change_species_source(SpeciesSource.t(), map()) :: Ecto.Changeset.t()
  def change_species_source(%SpeciesSource{} = species_source, attrs \\ %{}) do
    SpeciesSource.changeset(species_source, attrs)
  end

  # -- Mutations --

  @doc """
  Creates a new source with the given attributes.
  """
  @spec create_source(map()) :: {:ok, Source.t()} | {:error, Ecto.Changeset.t()}
  def create_source(attrs) do
    %Source{}
    |> Source.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a source with the given attributes.
  """
  @spec update_source(Source.t(), map()) :: {:ok, Source.t()} | {:error, Ecto.Changeset.t()}
  def update_source(%Source{} = source, attrs) do
    source
    |> Source.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a source. Fails if species_sources reference it.
  """
  @spec delete_source(Source.t()) :: {:ok, Source.t()} | {:error, Ecto.Changeset.t()}
  def delete_source(%Source{} = source) do
    Repo.delete(source)
  end

  # -- SpeciesSource mutations --

  @doc """
  Creates a new species_source with the given attributes.
  """
  @spec create_species_source(map()) :: {:ok, SpeciesSource.t()} | {:error, Ecto.Changeset.t()}
  def create_species_source(attrs) do
    %SpeciesSource{}
    |> SpeciesSource.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a species_source with the given attributes.
  """
  @spec update_species_source(SpeciesSource.t(), map()) ::
          {:ok, SpeciesSource.t()} | {:error, Ecto.Changeset.t()}
  def update_species_source(%SpeciesSource{} = species_source, attrs) do
    species_source
    |> SpeciesSource.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a species_source record.
  """
  @spec delete_species_source(SpeciesSource.t()) ::
          {:ok, SpeciesSource.t()} | {:error, Ecto.Changeset.t()}
  def delete_species_source(%SpeciesSource{} = species_source) do
    Repo.delete(species_source)
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
