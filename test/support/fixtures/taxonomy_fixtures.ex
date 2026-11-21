defmodule Oaks.TaxonomyFixtures do
  @moduledoc """
  Taxa for tests (`Oaks.Taxonomy`).

  Every taxon gets a unique name. Never create a subgenus named "Quercus"
  or "Lobatae": the seeds hold those two roots, and a taxon's name and
  level are unique together.
  """

  alias Oaks.Taxonomy
  alias Oaks.Taxonomy.Taxon

  @doc "A unique taxon name."
  def unique_taxon_name, do: "Taxon#{System.unique_integer([:positive])}"

  @doc """
  Creates a taxon through `Taxonomy.create_taxon/1`. Defaults: a unique
  `name`, `level: "subgenus"` and no parent. `:parent` may be a `%Taxon{}`,
  which becomes its name.
  """
  @spec taxon_fixture(map() | keyword()) :: Taxon.t()
  def taxon_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Map.new()
      |> Map.update(:parent, nil, fn
        %Taxon{name: name} -> name
        parent -> parent
      end)

    defaults = %{name: unique_taxon_name(), level: "subgenus"}

    {:ok, taxon} = defaults |> Map.merge(attrs) |> Taxonomy.create_taxon()
    taxon
  end

  @doc """
  Creates a subgenus, a section under it and a subsection under that, each
  with a unique name unless `attrs` names it (`:subgenus`, `:section`,
  `:subsection`). Returns `%{subgenus:, section:, subsection:}`.
  """
  @spec taxon_tree_fixture(map() | keyword()) :: %{
          subgenus: Taxon.t(),
          section: Taxon.t(),
          subsection: Taxon.t()
        }
  def taxon_tree_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)

    subgenus =
      taxon_fixture(%{name: attrs[:subgenus] || unique_taxon_name(), level: "subgenus"})

    section =
      taxon_fixture(%{
        name: attrs[:section] || unique_taxon_name(),
        level: "section",
        parent: subgenus
      })

    subsection =
      taxon_fixture(%{
        name: attrs[:subsection] || unique_taxon_name(),
        level: "subsection",
        parent: section
      })

    %{subgenus: subgenus, section: section, subsection: subsection}
  end
end
