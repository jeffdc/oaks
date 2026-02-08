defmodule Oaks.Stats do
  @moduledoc """
  Aggregate statistics for the database.
  """

  alias Oaks.Sources
  alias Oaks.Species
  alias Oaks.Taxonomy

  @doc """
  Returns aggregate counts for species, hybrids, taxa, and sources.
  """
  @spec get_stats() :: map()
  def get_stats do
    %{
      species_count: Species.count(),
      hybrid_count: Species.count_hybrids(),
      taxa_count: Taxonomy.count(),
      source_count: Sources.count()
    }
  end
end
