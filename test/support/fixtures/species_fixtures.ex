defmodule Oaks.SpeciesFixtures do
  @moduledoc """
  Species and hybrids for tests (`Oaks.Species`).

  Every fixture gets a unique name, so tests never depend on what the seeds
  hold. Pass an Elixir list for `synonyms`; it's encoded before the insert.
  """

  alias Oaks.Species
  alias Oaks.Species.Species, as: SpeciesSchema

  @json_list_fields [:synonyms]

  @doc "A unique species name (no ×), for fixtures and form input."
  def unique_species_name, do: "species#{System.unique_integer([:positive])}"

  @doc """
  Creates a non-hybrid species through `Species.create_species/1`.
  Defaults: a unique `scientific_name` and `is_hybrid: false`.
  """
  @spec species_fixture(map() | keyword()) :: SpeciesSchema.t()
  def species_fixture(attrs \\ %{}) do
    create(%{scientific_name: unique_species_name(), is_hybrid: false}, attrs)
  end

  @doc """
  Creates a hybrid through `Species.create_species/1`. Defaults: a unique
  `scientific_name` starting with × and `is_hybrid: true`.
  """
  @spec hybrid_fixture(map() | keyword()) :: SpeciesSchema.t()
  def hybrid_fixture(attrs \\ %{}) do
    name = "×hybrid#{System.unique_integer([:positive])}"
    create(%{scientific_name: name, is_hybrid: true}, attrs)
  end

  defp create(defaults, attrs) do
    attrs =
      attrs
      |> Map.new()
      |> Map.new(fn
        {key, value} when key in @json_list_fields and is_list(value) ->
          {key, Jason.encode!(value)}

        pair ->
          pair
      end)

    {:ok, species} = defaults |> Map.merge(attrs) |> Species.create_species()
    species
  end
end
