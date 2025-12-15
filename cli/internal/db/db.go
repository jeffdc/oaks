package db

import (
	"database/sql"
	"encoding/json"
	"fmt"

	"github.com/jeff/oaks/cli/internal/models"
	_ "github.com/mattn/go-sqlite3"
)

// Database wraps the SQLite connection
type Database struct {
	conn *sql.DB
}

// New creates a new database connection and initializes schema
func New(dbPath string) (*Database, error) {
	conn, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	db := &Database{conn: conn}
	if err := db.initializeSchema(); err != nil {
		conn.Close()
		return nil, err
	}
	if err := db.runMigrations(); err != nil {
		conn.Close()
		return nil, err
	}

	return db, nil
}

// Close closes the database connection
func (db *Database) Close() error {
	return db.conn.Close()
}

func (db *Database) initializeSchema() error {
	statements := []string{
		// Taxa reference table for validation
		// Hierarchy: Genus (Quercus) → Subgenus → Section → Subsection → Complex → Species
		`CREATE TABLE IF NOT EXISTS taxa (
			name TEXT NOT NULL,
			level TEXT NOT NULL CHECK(level IN ('subgenus', 'section', 'subsection', 'complex')),
			parent TEXT,
			author TEXT,
			notes TEXT,
			links TEXT,
			PRIMARY KEY (name, level)
		)`,
		`CREATE INDEX IF NOT EXISTS idx_taxa_level ON taxa(level)`,
		`CREATE INDEX IF NOT EXISTS idx_taxa_parent ON taxa(parent)`,

		// Sources table
		`CREATE TABLE IF NOT EXISTS sources (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			source_type TEXT NOT NULL,
			name TEXT NOT NULL,
			description TEXT,
			author TEXT,
			year INTEGER,
			url TEXT,
			isbn TEXT,
			doi TEXT,
			notes TEXT
		)`,

		// Oak entries with taxonomy and hybrid support
		`CREATE TABLE IF NOT EXISTS oak_entries (
			scientific_name TEXT PRIMARY KEY,
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
			synonyms TEXT
		)`,
		`CREATE INDEX IF NOT EXISTS idx_oak_entries_subgenus ON oak_entries(subgenus)`,
		`CREATE INDEX IF NOT EXISTS idx_oak_entries_section ON oak_entries(section)`,
		`CREATE INDEX IF NOT EXISTS idx_oak_entries_hybrid ON oak_entries(is_hybrid)`,

		// Species-source junction table for source-attributed descriptive data
		// One row = everything source X says about species Y
		`CREATE TABLE IF NOT EXISTS species_sources (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			scientific_name TEXT NOT NULL,
			source_id INTEGER NOT NULL,
			local_names TEXT,
			range TEXT,
			growth_habit TEXT,
			leaves TEXT,
			flowers TEXT,
			fruits TEXT,
			bark_twigs_buds TEXT,
			hardiness_habitat TEXT,
			miscellaneous TEXT,
			url TEXT,
			is_preferred INTEGER NOT NULL DEFAULT 0,
			FOREIGN KEY (scientific_name) REFERENCES oak_entries(scientific_name) ON DELETE CASCADE,
			FOREIGN KEY (source_id) REFERENCES sources(id),
			UNIQUE(scientific_name, source_id)
		)`,
		`CREATE INDEX IF NOT EXISTS idx_species_sources_name ON species_sources(scientific_name)`,
		`CREATE INDEX IF NOT EXISTS idx_species_sources_source ON species_sources(source_id)`,
	}

	for _, stmt := range statements {
		if _, err := db.conn.Exec(stmt); err != nil {
			return fmt.Errorf("failed to execute schema statement: %w", err)
		}
	}

	return nil
}

// runMigrations applies schema migrations for existing databases
func (db *Database) runMigrations() error {
	// Migration 1: Add links column to taxa table if it doesn't exist
	if !db.columnExists("taxa", "links") {
		if _, err := db.conn.Exec(`ALTER TABLE taxa ADD COLUMN links TEXT`); err != nil {
			return fmt.Errorf("failed to add links column to taxa: %w", err)
		}
	}

	// Migration 2: Convert sources from TEXT source_id to INTEGER id
	// Check if old schema exists (has source_id column instead of id)
	if db.columnExists("sources", "source_id") && !db.columnExists("sources", "id") {
		if err := db.migrateSourcesSchema(); err != nil {
			return fmt.Errorf("failed to migrate sources schema: %w", err)
		}
	}

	// Migration 3: Replace data_points with species_sources
	// Drop old data_points table if it exists (data will be re-imported)
	if db.tableExists("data_points") {
		if _, err := db.conn.Exec(`DROP TABLE data_points`); err != nil {
			return fmt.Errorf("failed to drop data_points table: %w", err)
		}
		fmt.Println("Migrated: dropped old data_points table (replaced by species_sources)")
	}

	return nil
}

// migrateSourcesSchema converts sources table from TEXT source_id to INTEGER id
func (db *Database) migrateSourcesSchema() error {
	// Use a transaction for the entire migration
	tx, err := db.conn.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Step 1: Create new sources table with integer ID
	_, err = tx.Exec(`
		CREATE TABLE sources_new (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			old_source_id TEXT,
			source_type TEXT NOT NULL,
			name TEXT NOT NULL,
			description TEXT,
			author TEXT,
			year INTEGER,
			url TEXT,
			isbn TEXT,
			doi TEXT,
			notes TEXT
		)
	`)
	if err != nil {
		return fmt.Errorf("failed to create sources_new: %w", err)
	}

	// Step 2: Copy data from old sources to new, preserving old_source_id for mapping
	_, err = tx.Exec(`
		INSERT INTO sources_new (old_source_id, source_type, name, author, year, url, isbn, doi, notes)
		SELECT source_id, source_type, name, author, year, url, isbn, doi, notes
		FROM sources
	`)
	if err != nil {
		return fmt.Errorf("failed to copy sources data: %w", err)
	}

	// Step 3: Create new data_points table with integer source_id
	_, err = tx.Exec(`
		CREATE TABLE data_points_new (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			scientific_name TEXT NOT NULL,
			field_name TEXT NOT NULL,
			value TEXT NOT NULL,
			source_id INTEGER NOT NULL,
			page_number TEXT,
			FOREIGN KEY (scientific_name) REFERENCES oak_entries(scientific_name) ON DELETE CASCADE,
			FOREIGN KEY (source_id) REFERENCES sources_new(id),
			UNIQUE(scientific_name, field_name, source_id)
		)
	`)
	if err != nil {
		return fmt.Errorf("failed to create data_points_new: %w", err)
	}

	// Step 4: Copy data_points with mapped source IDs
	_, err = tx.Exec(`
		INSERT INTO data_points_new (scientific_name, field_name, value, source_id, page_number)
		SELECT dp.scientific_name, dp.field_name, dp.value, sn.id, dp.page_number
		FROM data_points dp
		JOIN sources_new sn ON dp.source_id = sn.old_source_id
	`)
	if err != nil {
		return fmt.Errorf("failed to copy data_points data: %w", err)
	}

	// Step 5: Drop old tables
	_, err = tx.Exec(`DROP TABLE data_points`)
	if err != nil {
		return fmt.Errorf("failed to drop old data_points: %w", err)
	}

	_, err = tx.Exec(`DROP TABLE sources`)
	if err != nil {
		return fmt.Errorf("failed to drop old sources: %w", err)
	}

	// Step 6: Rename new tables
	_, err = tx.Exec(`ALTER TABLE data_points_new RENAME TO data_points`)
	if err != nil {
		return fmt.Errorf("failed to rename data_points_new: %w", err)
	}

	_, err = tx.Exec(`ALTER TABLE sources_new RENAME TO sources`)
	if err != nil {
		return fmt.Errorf("failed to rename sources_new: %w", err)
	}

	// Step 7: Remove the temporary old_source_id column by recreating the table
	// (SQLite doesn't support DROP COLUMN in older versions)
	_, err = tx.Exec(`
		CREATE TABLE sources_final (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			source_type TEXT NOT NULL,
			name TEXT NOT NULL,
			description TEXT,
			author TEXT,
			year INTEGER,
			url TEXT,
			isbn TEXT,
			doi TEXT,
			notes TEXT
		)
	`)
	if err != nil {
		return fmt.Errorf("failed to create sources_final: %w", err)
	}

	_, err = tx.Exec(`
		INSERT INTO sources_final (id, source_type, name, author, year, url, isbn, doi, notes)
		SELECT id, source_type, name, author, year, url, isbn, doi, notes
		FROM sources
	`)
	if err != nil {
		return fmt.Errorf("failed to copy to sources_final: %w", err)
	}

	_, err = tx.Exec(`DROP TABLE sources`)
	if err != nil {
		return fmt.Errorf("failed to drop sources: %w", err)
	}

	_, err = tx.Exec(`ALTER TABLE sources_final RENAME TO sources`)
	if err != nil {
		return fmt.Errorf("failed to rename sources_final: %w", err)
	}

	// Step 8: Recreate indexes
	_, err = tx.Exec(`CREATE INDEX IF NOT EXISTS idx_data_points_name ON data_points(scientific_name)`)
	if err != nil {
		return fmt.Errorf("failed to create idx_data_points_name: %w", err)
	}

	_, err = tx.Exec(`CREATE INDEX IF NOT EXISTS idx_data_points_source ON data_points(source_id)`)
	if err != nil {
		return fmt.Errorf("failed to create idx_data_points_source: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit migration: %w", err)
	}

	fmt.Println("Successfully migrated sources schema to use integer IDs")
	return nil
}

// columnExists checks if a column exists in a table
func (db *Database) columnExists(table, column string) bool {
	rows, err := db.conn.Query(fmt.Sprintf("PRAGMA table_info(%s)", table))
	if err != nil {
		return false
	}
	defer rows.Close()

	for rows.Next() {
		var cid int
		var name, ctype string
		var notnull, pk int
		var dfltValue interface{}
		if err := rows.Scan(&cid, &name, &ctype, &notnull, &dfltValue, &pk); err != nil {
			continue
		}
		if name == column {
			return true
		}
	}
	return false
}

// tableExists checks if a table exists in the database
func (db *Database) tableExists(table string) bool {
	var count int
	err := db.conn.QueryRow(
		`SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?`,
		table,
	).Scan(&count)
	if err != nil {
		return false
	}
	return count > 0
}

// InsertSource inserts a new source and returns its ID
func (db *Database) InsertSource(source *models.Source) (int64, error) {
	result, err := db.conn.Exec(
		`INSERT INTO sources (source_type, name, description, author, year, url, isbn, doi, notes)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		source.SourceType, source.Name, source.Description,
		source.Author, source.Year, source.URL, source.ISBN, source.DOI, source.Notes,
	)
	if err != nil {
		return 0, fmt.Errorf("failed to insert source: %w", err)
	}
	id, err := result.LastInsertId()
	if err != nil {
		return 0, fmt.Errorf("failed to get last insert id: %w", err)
	}
	source.ID = id
	return id, nil
}

// GetSource gets a source by ID
func (db *Database) GetSource(id int64) (*models.Source, error) {
	row := db.conn.QueryRow(
		`SELECT id, source_type, name, description, author, year, url, isbn, doi, notes
		 FROM sources WHERE id = ?`,
		id,
	)

	var s models.Source
	err := row.Scan(&s.ID, &s.SourceType, &s.Name, &s.Description, &s.Author, &s.Year, &s.URL, &s.ISBN, &s.DOI, &s.Notes)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get source: %w", err)
	}
	return &s, nil
}

// UpdateSource updates an existing source
func (db *Database) UpdateSource(source *models.Source) error {
	_, err := db.conn.Exec(
		`UPDATE sources
		 SET source_type = ?, name = ?, description = ?, author = ?, year = ?, url = ?, isbn = ?, doi = ?, notes = ?
		 WHERE id = ?`,
		source.SourceType, source.Name, source.Description, source.Author, source.Year,
		source.URL, source.ISBN, source.DOI, source.Notes, source.ID,
	)
	if err != nil {
		return fmt.Errorf("failed to update source: %w", err)
	}
	return nil
}

// ListSources lists all sources
func (db *Database) ListSources() ([]*models.Source, error) {
	rows, err := db.conn.Query(
		`SELECT id, source_type, name, description, author, year, url, isbn, doi, notes
		 FROM sources ORDER BY name`,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to list sources: %w", err)
	}
	defer rows.Close()

	var sources []*models.Source
	for rows.Next() {
		var s models.Source
		if err := rows.Scan(&s.ID, &s.SourceType, &s.Name, &s.Description, &s.Author, &s.Year, &s.URL, &s.ISBN, &s.DOI, &s.Notes); err != nil {
			return nil, fmt.Errorf("failed to scan source: %w", err)
		}
		sources = append(sources, &s)
	}
	return sources, rows.Err()
}

// InsertTaxon inserts a new taxon into the reference table
func (db *Database) InsertTaxon(taxon *models.Taxon) error {
	var linksJSON *string
	if len(taxon.Links) > 0 {
		data, err := json.Marshal(taxon.Links)
		if err != nil {
			return fmt.Errorf("failed to marshal links: %w", err)
		}
		s := string(data)
		linksJSON = &s
	}

	_, err := db.conn.Exec(
		`INSERT INTO taxa (name, level, parent, author, notes, links) VALUES (?, ?, ?, ?, ?, ?)`,
		taxon.Name, string(taxon.Level), taxon.Parent, taxon.Author, taxon.Notes, linksJSON,
	)
	if err != nil {
		return fmt.Errorf("failed to insert taxon: %w", err)
	}
	return nil
}

// UpdateTaxon updates an existing taxon
func (db *Database) UpdateTaxon(taxon *models.Taxon) error {
	var linksJSON *string
	if len(taxon.Links) > 0 {
		data, err := json.Marshal(taxon.Links)
		if err != nil {
			return fmt.Errorf("failed to marshal links: %w", err)
		}
		s := string(data)
		linksJSON = &s
	}

	_, err := db.conn.Exec(
		`UPDATE taxa SET parent = ?, author = ?, notes = ?, links = ? WHERE name = ? AND level = ?`,
		taxon.Parent, taxon.Author, taxon.Notes, linksJSON, taxon.Name, string(taxon.Level),
	)
	if err != nil {
		return fmt.Errorf("failed to update taxon: %w", err)
	}
	return nil
}

// GetTaxon gets a taxon by name and level
func (db *Database) GetTaxon(name string, level models.TaxonLevel) (*models.Taxon, error) {
	row := db.conn.QueryRow(
		`SELECT name, level, parent, author, notes, links FROM taxa WHERE name = ? AND level = ?`,
		name, string(level),
	)

	var t models.Taxon
	var levelStr string
	var linksJSON sql.NullString
	err := row.Scan(&t.Name, &levelStr, &t.Parent, &t.Author, &t.Notes, &linksJSON)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get taxon: %w", err)
	}
	t.Level = models.TaxonLevel(levelStr)

	if linksJSON.Valid && linksJSON.String != "" {
		json.Unmarshal([]byte(linksJSON.String), &t.Links)
	}
	if t.Links == nil {
		t.Links = []models.TaxonLink{}
	}

	return &t, nil
}

// ListTaxa lists all taxa, optionally filtered by level
func (db *Database) ListTaxa(level *models.TaxonLevel) ([]*models.Taxon, error) {
	var rows *sql.Rows
	var err error

	if level != nil {
		rows, err = db.conn.Query(
			`SELECT name, level, parent, author, notes, links FROM taxa WHERE level = ? ORDER BY name`,
			string(*level),
		)
	} else {
		rows, err = db.conn.Query(
			`SELECT name, level, parent, author, notes, links FROM taxa ORDER BY level, name`,
		)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to list taxa: %w", err)
	}
	defer rows.Close()

	var taxa []*models.Taxon
	for rows.Next() {
		var t models.Taxon
		var levelStr string
		var linksJSON sql.NullString
		if err := rows.Scan(&t.Name, &levelStr, &t.Parent, &t.Author, &t.Notes, &linksJSON); err != nil {
			return nil, fmt.Errorf("failed to scan taxon: %w", err)
		}
		t.Level = models.TaxonLevel(levelStr)

		if linksJSON.Valid && linksJSON.String != "" {
			json.Unmarshal([]byte(linksJSON.String), &t.Links)
		}
		if t.Links == nil {
			t.Links = []models.TaxonLink{}
		}

		taxa = append(taxa, &t)
	}
	return taxa, rows.Err()
}

// ValidateTaxon checks if a taxon exists in the reference table
func (db *Database) ValidateTaxon(name string, level models.TaxonLevel) (bool, error) {
	var count int
	err := db.conn.QueryRow(
		`SELECT COUNT(*) FROM taxa WHERE name = ? AND level = ?`,
		name, string(level),
	).Scan(&count)
	if err != nil {
		return false, fmt.Errorf("failed to validate taxon: %w", err)
	}
	return count > 0, nil
}

// ClearTaxa removes all taxa from the reference table
func (db *Database) ClearTaxa() error {
	_, err := db.conn.Exec(`DELETE FROM taxa`)
	if err != nil {
		return fmt.Errorf("failed to clear taxa: %w", err)
	}
	return nil
}

// SaveOakEntry saves or updates a complete oak entry
func (db *Database) SaveOakEntry(entry *models.OakEntry) error {
	// Marshal JSON arrays
	synonymsJSON, err := json.Marshal(entry.Synonyms)
	if err != nil {
		return fmt.Errorf("failed to marshal synonyms: %w", err)
	}
	hybridsJSON, err := json.Marshal(entry.Hybrids)
	if err != nil {
		return fmt.Errorf("failed to marshal hybrids: %w", err)
	}
	relatedJSON, err := json.Marshal(entry.CloselyRelatedTo)
	if err != nil {
		return fmt.Errorf("failed to marshal closely_related_to: %w", err)
	}
	subspeciesJSON, err := json.Marshal(entry.SubspeciesVarieties)
	if err != nil {
		return fmt.Errorf("failed to marshal subspecies_varieties: %w", err)
	}

	// Convert bool to int for SQLite
	isHybrid := 0
	if entry.IsHybrid {
		isHybrid = 1
	}

	_, err = db.conn.Exec(
		`INSERT OR REPLACE INTO oak_entries (
			scientific_name, author, is_hybrid, conservation_status,
			subgenus, section, subsection, complex,
			parent1, parent2, hybrids, closely_related_to, subspecies_varieties, synonyms
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		entry.ScientificName, entry.Author, isHybrid, entry.ConservationStatus,
		entry.Subgenus, entry.Section, entry.Subsection, entry.Complex,
		entry.Parent1, entry.Parent2, string(hybridsJSON), string(relatedJSON),
		string(subspeciesJSON), string(synonymsJSON),
	)
	if err != nil {
		return fmt.Errorf("failed to insert oak entry: %w", err)
	}

	return nil
}

// GetOakEntry gets an oak entry by scientific name
func (db *Database) GetOakEntry(scientificName string) (*models.OakEntry, error) {
	row := db.conn.QueryRow(
		`SELECT scientific_name, author, is_hybrid, conservation_status,
		        subgenus, section, subsection, complex,
		        parent1, parent2, hybrids, closely_related_to, subspecies_varieties, synonyms
		 FROM oak_entries WHERE scientific_name = ?`,
		scientificName,
	)

	var entry models.OakEntry
	var isHybrid int
	var hybridsJSON, relatedJSON, subspeciesJSON, synonymsJSON sql.NullString

	if err := row.Scan(
		&entry.ScientificName, &entry.Author, &isHybrid, &entry.ConservationStatus,
		&entry.Subgenus, &entry.Section, &entry.Subsection, &entry.Complex,
		&entry.Parent1, &entry.Parent2, &hybridsJSON, &relatedJSON, &subspeciesJSON, &synonymsJSON,
	); err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get oak entry: %w", err)
	}

	entry.IsHybrid = isHybrid != 0

	// Unmarshal JSON arrays
	if hybridsJSON.Valid {
		json.Unmarshal([]byte(hybridsJSON.String), &entry.Hybrids)
	}
	if entry.Hybrids == nil {
		entry.Hybrids = []string{}
	}

	if relatedJSON.Valid {
		json.Unmarshal([]byte(relatedJSON.String), &entry.CloselyRelatedTo)
	}
	if entry.CloselyRelatedTo == nil {
		entry.CloselyRelatedTo = []string{}
	}

	if subspeciesJSON.Valid {
		json.Unmarshal([]byte(subspeciesJSON.String), &entry.SubspeciesVarieties)
	}
	if entry.SubspeciesVarieties == nil {
		entry.SubspeciesVarieties = []string{}
	}

	if synonymsJSON.Valid {
		json.Unmarshal([]byte(synonymsJSON.String), &entry.Synonyms)
	}
	if entry.Synonyms == nil {
		entry.Synonyms = []string{}
	}

	return &entry, nil
}

// DeleteOakEntry deletes an oak entry
func (db *Database) DeleteOakEntry(scientificName string) error {
	_, err := db.conn.Exec(
		`DELETE FROM oak_entries WHERE scientific_name = ?`,
		scientificName,
	)
	if err != nil {
		return fmt.Errorf("failed to delete oak entry: %w", err)
	}
	return nil
}

// SearchOakEntries searches for oak entries by name pattern
func (db *Database) SearchOakEntries(query string) ([]string, error) {
	pattern := "%" + query + "%"
	rows, err := db.conn.Query(
		`SELECT scientific_name FROM oak_entries
		 WHERE scientific_name LIKE ? ORDER BY scientific_name`,
		pattern,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to search oak entries: %w", err)
	}
	defer rows.Close()

	var names []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, err
		}
		names = append(names, name)
	}
	return names, rows.Err()
}

// SearchSources searches for sources by name pattern
func (db *Database) SearchSources(query string) ([]int64, error) {
	pattern := "%" + query + "%"
	rows, err := db.conn.Query(
		`SELECT id FROM sources
		 WHERE name LIKE ? ORDER BY name`,
		pattern,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to search sources: %w", err)
	}
	defer rows.Close()

	var ids []int64
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// BeginTx starts a transaction for bulk operations
func (db *Database) BeginTx() (*sql.Tx, error) {
	return db.conn.Begin()
}

// ListOakEntries returns all oak entries (for export)
func (db *Database) ListOakEntries() ([]*models.OakEntry, error) {
	rows, err := db.conn.Query(
		`SELECT scientific_name, author, is_hybrid, conservation_status,
		        subgenus, section, subsection, complex,
		        parent1, parent2, hybrids, closely_related_to, subspecies_varieties, synonyms
		 FROM oak_entries ORDER BY scientific_name`,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to list oak entries: %w", err)
	}
	defer rows.Close()

	var entries []*models.OakEntry
	for rows.Next() {
		var entry models.OakEntry
		var isHybrid int
		var hybridsJSON, relatedJSON, subspeciesJSON, synonymsJSON sql.NullString

		if err := rows.Scan(
			&entry.ScientificName, &entry.Author, &isHybrid, &entry.ConservationStatus,
			&entry.Subgenus, &entry.Section, &entry.Subsection, &entry.Complex,
			&entry.Parent1, &entry.Parent2, &hybridsJSON, &relatedJSON, &subspeciesJSON, &synonymsJSON,
		); err != nil {
			return nil, fmt.Errorf("failed to scan oak entry: %w", err)
		}

		entry.IsHybrid = isHybrid != 0

		// Unmarshal JSON arrays
		if hybridsJSON.Valid {
			json.Unmarshal([]byte(hybridsJSON.String), &entry.Hybrids)
		}
		if entry.Hybrids == nil {
			entry.Hybrids = []string{}
		}

		if relatedJSON.Valid {
			json.Unmarshal([]byte(relatedJSON.String), &entry.CloselyRelatedTo)
		}
		if entry.CloselyRelatedTo == nil {
			entry.CloselyRelatedTo = []string{}
		}

		if subspeciesJSON.Valid {
			json.Unmarshal([]byte(subspeciesJSON.String), &entry.SubspeciesVarieties)
		}
		if entry.SubspeciesVarieties == nil {
			entry.SubspeciesVarieties = []string{}
		}

		if synonymsJSON.Valid {
			json.Unmarshal([]byte(synonymsJSON.String), &entry.Synonyms)
		}
		if entry.Synonyms == nil {
			entry.Synonyms = []string{}
		}

		entries = append(entries, &entry)
	}

	return entries, rows.Err()
}

// SaveSpeciesSource saves or updates a species-source record
func (db *Database) SaveSpeciesSource(ss *models.SpeciesSource) error {
	localNamesJSON, err := json.Marshal(ss.LocalNames)
	if err != nil {
		return fmt.Errorf("failed to marshal local_names: %w", err)
	}

	isPreferred := 0
	if ss.IsPreferred {
		isPreferred = 1
	}

	result, err := db.conn.Exec(
		`INSERT OR REPLACE INTO species_sources (
			scientific_name, source_id, local_names, range, growth_habit,
			leaves, flowers, fruits, bark_twigs_buds, hardiness_habitat,
			miscellaneous, url, is_preferred
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		ss.ScientificName, ss.SourceID, string(localNamesJSON), ss.Range, ss.GrowthHabit,
		ss.Leaves, ss.Flowers, ss.Fruits, ss.BarkTwigsBuds, ss.HardinessHabitat,
		ss.Miscellaneous, ss.URL, isPreferred,
	)
	if err != nil {
		return fmt.Errorf("failed to save species source: %w", err)
	}

	if ss.ID == 0 {
		id, _ := result.LastInsertId()
		ss.ID = id
	}
	return nil
}

// GetSpeciesSources returns all source data for a species
func (db *Database) GetSpeciesSources(scientificName string) ([]*models.SpeciesSource, error) {
	rows, err := db.conn.Query(
		`SELECT id, scientific_name, source_id, local_names, range, growth_habit,
		        leaves, flowers, fruits, bark_twigs_buds, hardiness_habitat,
		        miscellaneous, url, is_preferred
		 FROM species_sources WHERE scientific_name = ? ORDER BY is_preferred DESC, source_id`,
		scientificName,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get species sources: %w", err)
	}
	defer rows.Close()

	var results []*models.SpeciesSource
	for rows.Next() {
		ss, err := scanSpeciesSource(rows)
		if err != nil {
			return nil, err
		}
		results = append(results, ss)
	}
	return results, rows.Err()
}

// GetPreferredSpeciesSource returns the preferred source data for a species
func (db *Database) GetPreferredSpeciesSource(scientificName string) (*models.SpeciesSource, error) {
	row := db.conn.QueryRow(
		`SELECT id, scientific_name, source_id, local_names, range, growth_habit,
		        leaves, flowers, fruits, bark_twigs_buds, hardiness_habitat,
		        miscellaneous, url, is_preferred
		 FROM species_sources WHERE scientific_name = ? ORDER BY is_preferred DESC LIMIT 1`,
		scientificName,
	)

	ss := &models.SpeciesSource{}
	var localNamesJSON sql.NullString
	var isPreferred int

	err := row.Scan(
		&ss.ID, &ss.ScientificName, &ss.SourceID, &localNamesJSON, &ss.Range, &ss.GrowthHabit,
		&ss.Leaves, &ss.Flowers, &ss.Fruits, &ss.BarkTwigsBuds, &ss.HardinessHabitat,
		&ss.Miscellaneous, &ss.URL, &isPreferred,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get preferred species source: %w", err)
	}

	ss.IsPreferred = isPreferred != 0
	if localNamesJSON.Valid {
		json.Unmarshal([]byte(localNamesJSON.String), &ss.LocalNames)
	}
	if ss.LocalNames == nil {
		ss.LocalNames = []string{}
	}

	return ss, nil
}

// scanSpeciesSource scans a row into a SpeciesSource
func scanSpeciesSource(rows *sql.Rows) (*models.SpeciesSource, error) {
	ss := &models.SpeciesSource{}
	var localNamesJSON sql.NullString
	var isPreferred int

	err := rows.Scan(
		&ss.ID, &ss.ScientificName, &ss.SourceID, &localNamesJSON, &ss.Range, &ss.GrowthHabit,
		&ss.Leaves, &ss.Flowers, &ss.Fruits, &ss.BarkTwigsBuds, &ss.HardinessHabitat,
		&ss.Miscellaneous, &ss.URL, &isPreferred,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to scan species source: %w", err)
	}

	ss.IsPreferred = isPreferred != 0
	if localNamesJSON.Valid {
		json.Unmarshal([]byte(localNamesJSON.String), &ss.LocalNames)
	}
	if ss.LocalNames == nil {
		ss.LocalNames = []string{}
	}

	return ss, nil
}

// ListAllSpeciesSources returns all species_sources records (for export)
func (db *Database) ListAllSpeciesSources() ([]*models.SpeciesSource, error) {
	rows, err := db.conn.Query(
		`SELECT id, scientific_name, source_id, local_names, range, growth_habit,
		        leaves, flowers, fruits, bark_twigs_buds, hardiness_habitat,
		        miscellaneous, url, is_preferred
		 FROM species_sources ORDER BY scientific_name, is_preferred DESC`,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to list species sources: %w", err)
	}
	defer rows.Close()

	var results []*models.SpeciesSource
	for rows.Next() {
		ss, err := scanSpeciesSource(rows)
		if err != nil {
			return nil, err
		}
		results = append(results, ss)
	}
	return results, rows.Err()
}
