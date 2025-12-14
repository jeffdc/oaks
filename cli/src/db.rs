use anyhow::{Context, Result};
use rusqlite::{params, Connection, OptionalExtension};
use crate::models::{OakEntry, Source, DataPoint};

/// Database repository implementing the abstraction layer for data access
pub struct Database {
    conn: Connection,
}

impl Database {
    /// Create a new database connection and initialize schema
    pub fn new(db_path: &str) -> Result<Self> {
        let conn = Connection::open(db_path)
            .context("Failed to open database")?;

        let db = Database { conn };
        db.initialize_schema()?;
        Ok(db)
    }

    /// Initialize the database schema if it doesn't exist
    fn initialize_schema(&self) -> Result<()> {
        // Sources table
        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS sources (
                source_id TEXT PRIMARY KEY,
                source_type TEXT NOT NULL,
                name TEXT NOT NULL,
                author TEXT,
                year INTEGER,
                url TEXT,
                isbn TEXT,
                doi TEXT,
                notes TEXT
            )",
            [],
        )?;

        // Oak entries table
        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS oak_entries (
                scientific_name TEXT PRIMARY KEY,
                synonyms TEXT
            )",
            [],
        )?;

        // Data points table - stores all attributed data
        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS data_points (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                scientific_name TEXT NOT NULL,
                field_name TEXT NOT NULL,
                value TEXT NOT NULL,
                source_id TEXT NOT NULL,
                page_number TEXT,
                FOREIGN KEY (scientific_name) REFERENCES oak_entries(scientific_name) ON DELETE CASCADE,
                FOREIGN KEY (source_id) REFERENCES sources(source_id),
                UNIQUE(scientific_name, field_name, source_id)
            )",
            [],
        )?;

        // Create indexes for performance
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_data_points_name
             ON data_points(scientific_name)",
            [],
        )?;

        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_data_points_source
             ON data_points(source_id)",
            [],
        )?;

        Ok(())
    }

    // ========== Source Operations ==========

    /// Insert a new source
    pub fn insert_source(&self, source: &Source) -> Result<()> {
        self.conn.execute(
            "INSERT INTO sources (source_id, source_type, name, author, year, url, isbn, doi, notes)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
            params![
                source.source_id,
                source.source_type,
                source.name,
                source.author,
                source.year,
                source.url,
                source.isbn,
                source.doi,
                source.notes,
            ],
        )?;
        Ok(())
    }

    /// Get a source by ID
    pub fn get_source(&self, source_id: &str) -> Result<Option<Source>> {
        self.conn
            .query_row(
                "SELECT source_id, source_type, name, author, year, url, isbn, doi, notes
                 FROM sources WHERE source_id = ?1",
                params![source_id],
                |row| {
                    Ok(Source {
                        source_id: row.get(0)?,
                        source_type: row.get(1)?,
                        name: row.get(2)?,
                        author: row.get(3)?,
                        year: row.get(4)?,
                        url: row.get(5)?,
                        isbn: row.get(6)?,
                        doi: row.get(7)?,
                        notes: row.get(8)?,
                    })
                },
            )
            .optional()
            .context("Failed to get source")
    }

    /// Update an existing source
    pub fn update_source(&self, source: &Source) -> Result<()> {
        self.conn.execute(
            "UPDATE sources
             SET source_type = ?2, name = ?3, author = ?4, year = ?5,
                 url = ?6, isbn = ?7, doi = ?8, notes = ?9
             WHERE source_id = ?1",
            params![
                source.source_id,
                source.source_type,
                source.name,
                source.author,
                source.year,
                source.url,
                source.isbn,
                source.doi,
                source.notes,
            ],
        )?;
        Ok(())
    }

    /// List all sources
    pub fn list_sources(&self) -> Result<Vec<Source>> {
        let mut stmt = self.conn.prepare(
            "SELECT source_id, source_type, name, author, year, url, isbn, doi, notes
             FROM sources ORDER BY name"
        )?;

        let sources = stmt
            .query_map([], |row| {
                Ok(Source {
                    source_id: row.get(0)?,
                    source_type: row.get(1)?,
                    name: row.get(2)?,
                    author: row.get(3)?,
                    year: row.get(4)?,
                    url: row.get(5)?,
                    isbn: row.get(6)?,
                    doi: row.get(7)?,
                    notes: row.get(8)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(sources)
    }

    // ========== Oak Entry Operations ==========

    /// Insert or update a complete oak entry
    pub fn save_oak_entry(&self, entry: &OakEntry) -> Result<()> {
        let tx = self.conn.unchecked_transaction()?;

        // Insert or replace the main entry
        tx.execute(
            "INSERT OR REPLACE INTO oak_entries (scientific_name, synonyms)
             VALUES (?1, ?2)",
            params![
                entry.scientific_name,
                serde_json::to_string(&entry.synonyms)?,
            ],
        )?;

        // Helper function to save data points for a field
        let save_field = |field_name: &str, data_points: &[DataPoint]| -> Result<()> {
            // First, delete existing data points for this field
            tx.execute(
                "DELETE FROM data_points
                 WHERE scientific_name = ?1 AND field_name = ?2",
                params![entry.scientific_name, field_name],
            )?;

            // Insert new data points
            for dp in data_points {
                tx.execute(
                    "INSERT INTO data_points
                     (scientific_name, field_name, value, source_id, page_number)
                     VALUES (?1, ?2, ?3, ?4, ?5)",
                    params![
                        entry.scientific_name,
                        field_name,
                        dp.value,
                        dp.source_id,
                        dp.page_number,
                    ],
                )?;
            }
            Ok(())
        };

        save_field("common_names", &entry.common_names)?;
        save_field("leaf_color", &entry.leaf_color)?;
        save_field("bud_shape", &entry.bud_shape)?;
        save_field("leaf_shape", &entry.leaf_shape)?;
        save_field("bark_texture", &entry.bark_texture)?;
        save_field("habitat", &entry.habitat)?;
        save_field("native_range", &entry.native_range)?;
        save_field("height", &entry.height)?;

        tx.commit()?;
        Ok(())
    }

    /// Get an oak entry by scientific name
    pub fn get_oak_entry(&self, scientific_name: &str) -> Result<Option<OakEntry>> {
        // Check if entry exists
        let exists: bool = self.conn
            .query_row(
                "SELECT 1 FROM oak_entries WHERE scientific_name = ?1",
                params![scientific_name],
                |_| Ok(true),
            )
            .optional()?
            .unwrap_or(false);

        if !exists {
            return Ok(None);
        }

        // Get synonyms
        let synonyms: Vec<String> = self.conn
            .query_row(
                "SELECT synonyms FROM oak_entries WHERE scientific_name = ?1",
                params![scientific_name],
                |row| {
                    let json: String = row.get(0)?;
                    Ok(serde_json::from_str(&json).unwrap_or_default())
                },
            )?;

        // Helper to load data points for a field
        let load_field = |field_name: &str| -> Result<Vec<DataPoint>> {
            let mut stmt = self.conn.prepare(
                "SELECT value, source_id, page_number
                 FROM data_points
                 WHERE scientific_name = ?1 AND field_name = ?2"
            )?;

            let points = stmt
                .query_map(params![scientific_name, field_name], |row| {
                    Ok(DataPoint {
                        value: row.get(0)?,
                        source_id: row.get(1)?,
                        page_number: row.get(2)?,
                    })
                })?
                .collect::<Result<Vec<_>, _>>()?;

            Ok(points)
        };

        let entry = OakEntry {
            scientific_name: scientific_name.to_string(),
            synonyms,
            common_names: load_field("common_names")?,
            leaf_color: load_field("leaf_color")?,
            bud_shape: load_field("bud_shape")?,
            leaf_shape: load_field("leaf_shape")?,
            bark_texture: load_field("bark_texture")?,
            habitat: load_field("habitat")?,
            native_range: load_field("native_range")?,
            height: load_field("height")?,
        };

        Ok(Some(entry))
    }

    /// Delete an oak entry
    pub fn delete_oak_entry(&self, scientific_name: &str) -> Result<()> {
        self.conn.execute(
            "DELETE FROM oak_entries WHERE scientific_name = ?1",
            params![scientific_name],
        )?;
        Ok(())
    }

    /// Search for oak entries by name pattern
    pub fn search_oak_entries(&self, query: &str) -> Result<Vec<String>> {
        let pattern = format!("%{}%", query);
        let mut stmt = self.conn.prepare(
            "SELECT scientific_name FROM oak_entries
             WHERE scientific_name LIKE ?1
             ORDER BY scientific_name"
        )?;

        let names = stmt
            .query_map(params![pattern], |row| row.get(0))?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(names)
    }

    /// Search for sources by name pattern
    pub fn search_sources(&self, query: &str) -> Result<Vec<String>> {
        let pattern = format!("%{}%", query);
        let mut stmt = self.conn.prepare(
            "SELECT source_id FROM sources
             WHERE name LIKE ?1 OR source_id LIKE ?1
             ORDER BY name"
        )?;

        let ids = stmt
            .query_map(params![pattern], |row| row.get(0))?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(ids)
    }

    /// Begin a transaction for bulk operations
    pub fn begin_transaction(&mut self) -> Result<Transaction> {
        Ok(Transaction {
            tx: Some(self.conn.unchecked_transaction()?),
        })
    }
}

/// Transaction wrapper for bulk operations
pub struct Transaction<'a> {
    tx: Option<rusqlite::Transaction<'a>>,
}

impl<'a> Transaction<'a> {
    /// Commit the transaction
    pub fn commit(mut self) -> Result<()> {
        if let Some(tx) = self.tx.take() {
            tx.commit()?;
        }
        Ok(())
    }

    /// Rollback the transaction (happens automatically on drop)
    pub fn rollback(mut self) -> Result<()> {
        if let Some(tx) = self.tx.take() {
            tx.rollback()?;
        }
        Ok(())
    }
}
