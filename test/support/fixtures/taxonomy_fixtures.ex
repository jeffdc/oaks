defmodule Oaks.TaxonomyFixtures do
  @moduledoc """
  Taxa for tests (`Oaks.Taxonomy`).

  Every taxon gets a unique name. Never create a subgenus named "Quercus"
  or "Lobatae": the seeds hold those two roots, and a taxon's name and
  level are unique together.

  A taxon hangs from the genus row unless `:parent_id` names another taxon;
  `:parent` may be a `%Taxon{}` too. The rank rule still applies: the parent
  must rank above the child.
  """

  alias Oaks.Taxonomy
  alias Oaks.Taxonomy.Taxon

  @doc "A unique taxon name."
  def unique_taxon_name, do: "Taxon#{System.unique_integer([:positive])}"

  @doc """
  Creates a taxon through `Taxonomy.create_taxon/1`. Defaults: a unique
  `name`, `level: "subgenus"`, and the genus row as parent. `:parent_id` may
  be another taxon's id, and `:parent` may be a `%Taxon{}`.
  """
  @spec taxon_fixture(map() | keyword()) :: Taxon.t()
  def taxon_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Map.new()
      |> then(fn attrs ->
        case Map.pop(attrs, :parent) do
          {nil, attrs} -> attrs
          {%Taxon{id: id}, attrs} -> Map.put(attrs, :parent_id, id)
          {id, attrs} when is_integer(id) -> Map.put(attrs, :parent_id, id)
        end
      end)

    defaults = %{name: unique_taxon_name(), level: "subgenus", parent_id: genus_id()}

    {:ok, taxon} = defaults |> Map.merge(attrs) |> Taxonomy.create_taxon()
    taxon
  end

  @doc "The genus row's id, the root every taxon hangs from."
  def genus_id, do: Taxonomy.get_genus().id

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
        parent_id: subgenus.id
      })

    subsection =
      taxon_fixture(%{
        name: attrs[:subsection] || unique_taxon_name(),
        level: "subsection",
        parent_id: section.id
      })

    %{subgenus: subgenus, section: section, subsection: subsection}
  end
end
