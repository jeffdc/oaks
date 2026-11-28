defmodule Oaks.Repo.Migrations.AddSpeciesKeys do
  @moduledoc """
  Adds the species' keys: `taxon_id` (the lowest taxon it sits in),
  `parent1_id` and `parent2_id` (its hybrid parents), each indexed and
  restricted on delete.

  `taxon_id` is the taxon matching the lowest non-empty of `complex`,
  `subsection`, `section` and `subgenus`, by name and level. The parent
  keys match `scientific_name` exactly. The old columns stay, unread, until
  they are dropped.

  The checks are structural, so they hold on any database, the empty test
  database included: every species with a stored rank has its taxon, and
  every non-empty parent name has its key.
  """
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE species ADD COLUMN taxon_id INTEGER REFERENCES taxa(id) ON DELETE RESTRICT
    """)

    execute("""
    ALTER TABLE species ADD COLUMN parent1_id INTEGER REFERENCES species(id) ON DELETE RESTRICT
    """)

    execute("""
    ALTER TABLE species ADD COLUMN parent2_id INTEGER REFERENCES species(id) ON DELETE RESTRICT
    """)

    execute("CREATE INDEX idx_species_taxon ON species(taxon_id)")
    execute("CREATE INDEX idx_species_parent1 ON species(parent1_id)")
    execute("CREATE INDEX idx_species_parent2 ON species(parent2_id)")

    # The queries below read and write the new columns, so the ALTERs must
    # have run: Ecto queues them until a flush.
    flush()

    place_species()
    link_parents()
    check!()
  end

  def down do
    raise Ecto.MigrationError, "the species key migration can't be rolled back"
  end

  defp place_species do
    %{rows: rows} =
      repo().query!(
        "SELECT id, scientific_name, complex, subsection, section, subgenus FROM species"
      )

    for [id, name, complex, subsection, section, subgenus] <- rows do
      stored = [complex: complex, subsection: subsection, section: section, subgenus: subgenus]

      case Enum.find(stored, fn {_field, value} -> present?(value) end) do
        nil ->
          :ok

        {level, value} ->
          case taxon_id(level, value) do
            nil ->
              raise "species: #{inspect(name)} is stored at #{level} #{inspect(value)}, " <>
                      "which matches no taxon at that level"

            taxon_id ->
              repo().query!("UPDATE species SET taxon_id = ?2 WHERE id = ?1", [id, taxon_id])
          end
      end
    end
  end

  defp taxon_id(level, name) do
    %{rows: rows} =
      repo().query!("SELECT id FROM taxa WHERE level = ?1 AND name = ?2", [level, name])

    case rows do
      [[id]] -> id
      [] -> nil
    end
  end

  defp link_parents do
    for field <- ["parent1", "parent2"] do
      repo().query!("""
      UPDATE species
      SET #{field}_id = (SELECT p.id FROM species p WHERE p.scientific_name = species.#{field})
      WHERE COALESCE(species.#{field}, '') <> ''
      """)
    end
  end

  defp check! do
    %{rows: [[unplaced]]} =
      repo().query!("""
      SELECT COUNT(*) FROM species
      WHERE (COALESCE(complex, '') <> '' OR COALESCE(subsection, '') <> '' OR
             COALESCE(section, '') <> '' OR COALESCE(subgenus, '') <> '')
        AND taxon_id IS NULL
      """)

    if unplaced != 0 do
      raise "species: #{unplaced} species with a stored rank have no taxon_id"
    end

    for field <- ["parent1", "parent2"] do
      %{rows: [[unlinked]]} =
        repo().query!("""
        SELECT COUNT(*) FROM species
        WHERE COALESCE(#{field}, '') <> '' AND #{field}_id IS NULL
        """)

      if unlinked != 0 do
        raise "species: #{unlinked} species have a #{field} with no #{field}_id"
      end
    end
  end

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end
