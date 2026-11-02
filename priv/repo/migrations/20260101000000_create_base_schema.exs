defmodule Oaks.Repo.Migrations.CreateBaseSchema do
  @moduledoc """
  Baseline schema for the tables that predate Ecto migrations.

  Production already has these tables (they were created from the old
  structure.sql), so every statement uses IF NOT EXISTS: there this migration
  only records itself as run, while fresh databases (dev, test, CI) get the
  full schema. Its version sorts before the page_views migration, and
  `mix ecto.migrate` runs any pending migration regardless of order.
  """
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE IF NOT EXISTS sources (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_type TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        author TEXT,
        year INTEGER,
        url TEXT,
        isbn TEXT,
        doi TEXT,
        notes TEXT,
        license TEXT,
        license_url TEXT
    )
    """)

    execute("""
    CREATE TABLE IF NOT EXISTS import_metadata (
        key TEXT PRIMARY KEY,
        value TEXT
    )
    """)

    execute("""
    CREATE TABLE IF NOT EXISTS articles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        slug TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        content TEXT,
        tags TEXT,
        is_published INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        published_at TEXT
    )
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS idx_articles_slug ON articles(slug)
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS idx_articles_published ON articles(is_published)
    """)

    execute("""
    CREATE TABLE IF NOT EXISTS species (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scientific_name TEXT NOT NULL UNIQUE,
        author TEXT,
        is_hybrid INTEGER NOT NULL DEFAULT 0,
        conservation_status TEXT,
        subgenus TEXT,
        section TEXT,
        subsection TEXT,
        complex TEXT,
        parent1 TEXT,
        parent2 TEXT,
        hybrids TEXT,
        closely_related_to TEXT,
        subspecies_varieties TEXT,
        synonyms TEXT,
        external_links TEXT
    )
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS idx_species_subgenus ON species(subgenus)
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS idx_species_section ON species(section)
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS idx_species_hybrid ON species(is_hybrid)
    """)

    execute("""
    CREATE TABLE IF NOT EXISTS taxa (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        level TEXT NOT NULL CHECK(level IN ('subgenus', 'section', 'subsection', 'complex')),
        parent TEXT,
        author TEXT,
        content TEXT,
        content_updated_at TEXT,
        links TEXT,
        UNIQUE(name, level)
    )
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS idx_taxa_level ON taxa(level)
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS idx_taxa_parent ON taxa(parent)
    """)

    execute("""
    CREATE TABLE IF NOT EXISTS species_sources (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        species_id INTEGER NOT NULL,
        source_id INTEGER NOT NULL,
        local_names TEXT,
        range TEXT,
        growth_habit TEXT,
        leaves TEXT,
        flowers TEXT,
        fruits TEXT,
        bark TEXT,
        twigs TEXT,
        buds TEXT,
        hardiness_habitat TEXT,
        miscellaneous TEXT,
        url TEXT,
        is_preferred INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (species_id) REFERENCES species(id) ON DELETE CASCADE,
        FOREIGN KEY (source_id) REFERENCES sources(id),
        UNIQUE(species_id, source_id)
    )
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS idx_species_sources_species ON species_sources(species_id)
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS idx_species_sources_source ON species_sources(source_id)
    """)
  end

  def down do
    raise Ecto.MigrationError, "the baseline schema can't be rolled back"
  end
end
