defmodule Oaks.SourcesFixtures do
  @moduledoc """
  Sources and species–source links for tests (`Oaks.Sources`).

  Every source gets a unique name, so tests never depend on the seeded
  sources.
  """

  alias Oaks.Sources
  alias Oaks.Sources.{Source, SpeciesSource}
  alias Oaks.Species.Species

  @doc """
  Creates a source through `Sources.create_source/1`. Defaults: a unique
  `name` and `source_type: "website"`, with no URL.
  """
  @spec source_fixture(map() | keyword()) :: Source.t()
  def source_fixture(attrs \\ %{}) do
    defaults = %{
      name: "Source #{System.unique_integer([:positive])}",
      source_type: "website"
    }

    {:ok, source} = defaults |> Map.merge(Map.new(attrs)) |> Sources.create_source()
    source
  end

  @doc """
  Links `species` to `source` through `Sources.create_species_source/1`,
  with any per-source data in `attrs`. A list given for `local_names` is
  encoded as JSON.
  """
  @spec species_source_fixture(Species.t(), Source.t(), map() | keyword()) :: SpeciesSource.t()
  def species_source_fixture(%Species{} = species, %Source{} = source, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.new()
      |> Map.update(:local_names, nil, fn
        names when is_list(names) -> Jason.encode!(names)
        names -> names
      end)

    {:ok, species_source} =
      attrs
      |> Map.merge(%{species_id: species.id, source_id: source.id})
      |> Sources.create_species_source()

    species_source
  end
end
