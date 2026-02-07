defmodule OakCompendium.Sources do
  @moduledoc """
  The Sources context.

  Provides functions for querying data sources and species-source
  junction records.
  """

  import Ecto.Query

  alias OakCompendium.Repo
  alias OakCompendium.Sources.Source

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
  Returns a source by ID, or nil if not found.
  """
  @spec get_source(integer()) :: Source.t() | nil
  def get_source(id) do
    Repo.get(Source, id)
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
