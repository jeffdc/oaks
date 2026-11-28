defmodule Oaks.Repo.Migrations.RebuildTaxaWithKeys do
  @moduledoc """
  Rebuilds `taxa` so links between taxa are keys: `level` admits `genus`,
  `parent_id` points at the parent row, and one `genus` row (*Quercus*) is
  the root.

  SQLite can't change a `CHECK`, so the table is rebuilt: rows are copied
  with their ids, `parent_id` is filled after the rename (foreign keys are
  on, and rows can't point at the old table while it is dropped), then the
  old indexes are recreated and `parent_id` gets its own.

  Every taxon's `parent_id` is the taxon named in its `parent` at the
  nearest rank above it, since names repeat across ranks ("Quercus" is a
  subgenus and a section). The `parent` column stays, unread, until it is
  dropped.

  The checks are structural, so they hold on any database, the empty test
  database included: there is exactly one genus, only it has no parent,
  and every parent ranks above its child.
  """
  use Ecto.Migration

  @levels ~w(genus subgenus section subsection complex)
  @genus "Quercus"

  def up do
    execute("""
    CREATE TABLE taxa_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        level TEXT NOT NULL CHECK(level IN ('genus', 'subgenus', 'section', 'subsection', 'complex')),
        parent_id INTEGER REFERENCES taxa(id) ON DELETE RESTRICT,
        parent TEXT,
        author TEXT,
        content TEXT,
        content_updated_at TEXT,
        links TEXT,
        UNIQUE(name, level)
    )
    """)

    execute("""
    INSERT INTO taxa_new (id, name, level, parent, author, content, content_updated_at, links)
    SELECT id, name, level, parent, author, content, content_updated_at, links FROM taxa
    """)

    execute("DROP TABLE taxa")
    execute("ALTER TABLE taxa_new RENAME TO taxa")

    execute("CREATE INDEX idx_taxa_level ON taxa(level)")
    execute("CREATE INDEX idx_taxa_parent ON taxa(parent)")
    execute("CREATE INDEX idx_taxa_parent_id ON taxa(parent_id)")
    execute("CREATE UNIQUE INDEX idx_taxa_genus ON taxa(level) WHERE level = 'genus'")

    execute("INSERT INTO taxa (name, level) VALUES ('#{@genus}', 'genus')")

    # The two subgenera rank directly under the genus. Every other taxon is
    # resolved from the name in `parent`, at the nearest rank above it.
    execute("""
    UPDATE taxa
    SET parent_id = (SELECT id FROM taxa WHERE level = 'genus' AND name = '#{@genus}')
    WHERE level = 'subgenus'
    """)

    # The queries below read the table, so the DDL and inserts above must
    # have run: Ecto queues them until a flush.
    flush()

    rank = @levels |> Enum.with_index() |> Map.new()

    %{rows: rows} =
      repo().query!("SELECT id, name, level, parent FROM taxa WHERE level <> 'genus'")

    for [id, name, level, parent] <- rows, level != "subgenus" do
      parent_id = resolve_parent(rows, rank, id, name, level, parent)
      repo().query!("UPDATE taxa SET parent_id = ?2 WHERE id = ?1", [id, parent_id])
    end

    check!(rows, rank)
  end

  def down do
    raise Ecto.MigrationError, "the taxa key rebuild can't be rolled back"
  end

  # The parent is the taxon named in `parent` at the nearest rank above this
  # one; `rank` runs from the genus (0) down.
  defp resolve_parent(rows, rank, id, name, level, parent) do
    candidates =
      for [other_id, other_name, other_level, _parent] <- rows,
          other_id != id,
          other_name == parent,
          Map.fetch!(rank, other_level) < Map.fetch!(rank, level),
          do: {other_id, Map.fetch!(rank, other_level)}

    case Enum.max_by(candidates, &elem(&1, 1), fn -> nil end) do
      nil ->
        raise "taxa: #{level} #{inspect(name)} has parent #{inspect(parent)}, " <>
                "which names no taxon ranked above it"

      {parent_id, _rank} ->
        parent_id
    end
  end

  defp check!(_rows, rank) do
    %{rows: [[genera]]} = repo().query!("SELECT COUNT(*) FROM taxa WHERE level = 'genus'")

    if genera != 1 do
      raise "taxa: expected exactly one genus, found #{genera}"
    end

    %{rows: orphans} =
      repo().query!("SELECT id FROM taxa WHERE level <> 'genus' AND parent_id IS NULL")

    if orphans != [] do
      raise "taxa: #{length(orphans)} taxa ranked below the genus have no parent"
    end

    %{rows: all} = repo().query!("SELECT id, level FROM taxa")
    parents = Map.new(all, fn [id, level] -> {id, level} end)

    %{rows: filled} =
      repo().query!("SELECT id, level, parent_id FROM taxa WHERE parent_id IS NOT NULL")

    for [id, level, parent_id] <- filled do
      parent_level = Map.fetch!(parents, parent_id)

      if Map.fetch!(rank, parent_level) >= Map.fetch!(rank, level) do
        raise "taxa: #{level} #{id} has parent #{parent_level} #{parent_id}, which does not rank above it"
      end
    end
  end
end
