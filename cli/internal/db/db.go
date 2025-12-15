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
			PRIMARY KEY (name, level)
		)`,
		`CREATE INDEX IF NOT EXISTS idx_taxa_level ON taxa(level)`,
		`CREATE INDEX IF NOT EXISTS idx_taxa_parent ON taxa(parent)`,

		// Sources table
		`CREATE TABLE IF NOT EXISTS sources (
			source_id TEXT PRIMARY KEY,
			source_type TEXT NOT NULL,
			name TEXT NOT NULL,
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

		// Data points for source-attributed fields
		`CREATE TABLE IF NOT EXISTS data_points (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			scientific_name TEXT NOT NULL,
			field_name TEXT NOT NULL,
			value TEXT NOT NULL,
			source_id TEXT NOT NULL,
			page_number TEXT,
			FOREIGN KEY (scientific_name) REFERENCES oak_entries(scientific_name) ON DELETE CASCADE,
			FOREIGN KEY (source_id) REFERENCES sources(source_id),
			UNIQUE(scientific_name, field_name, source_id)
		)`,
		`CREATE INDEX IF NOT EXISTS idx_data_points_name ON data_points(scientific_name)`,
		`CREATE INDEX IF NOT EXISTS idx_data_points_source ON data_points(source_id)`,
	}

	for _, stmt := range statements {
		if _, err := db.conn.Exec(stmt); err != nil {
			return fmt.Errorf("failed to execute schema statement: %w", err)
		}
	}

	return nil
}

// InsertSource inserts a new source
func (db *Database) InsertSource(source *models.Source) error {
	_, err := db.conn.Exec(
		`INSERT INTO sources (source_id, source_type, name, author, year, url, isbn, doi, notes)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		source.SourceID, source.SourceType, source.Name,
		source.Author, source.Year, source.URL, source.ISBN, source.DOI, source.Notes,
	)
	if err != nil {
		return fmt.Errorf("failed to insert source: %w", err)
	}
	return nil
}

// GetSource gets a source by ID
func (db *Database) GetSource(sourceID string) (*models.Source, error) {
	row := db.conn.QueryRow(
		`SELECT source_id, source_type, name, author, year, url, isbn, doi, notes
		 FROM sources WHERE source_id = ?`,
		sourceID,
	)

	var s models.Source
	err := row.Scan(&s.SourceID, &s.SourceType, &s.Name, &s.Author, &s.Year, &s.URL, &s.ISBN, &s.DOI, &s.Notes)
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
		 SET source_type = ?, name = ?, author = ?, year = ?, url = ?, isbn = ?, doi = ?, notes = ?
		 WHERE source_id = ?`,
		source.SourceType, source.Name, source.Author, source.Year,
		source.URL, source.ISBN, source.DOI, source.Notes, source.SourceID,
	)
	if err != nil {
		return fmt.Errorf("failed to update source: %w", err)
	}
	return nil
}

// ListSources lists all sources
func (db *Database) ListSources() ([]*models.Source, error) {
	rows, err := db.conn.Query(
		`SELECT source_id, source_type, name, author, year, url, isbn, doi, notes
		 FROM sources ORDER BY name`,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to list sources: %w", err)
	}
	defer rows.Close()

	var sources []*models.Source
	for rows.Next() {
		var s models.Source
		if err := rows.Scan(&s.SourceID, &s.SourceType, &s.Name, &s.Author, &s.Year, &s.URL, &s.ISBN, &s.DOI, &s.Notes); err != nil {
			return nil, fmt.Errorf("failed to scan source: %w", err)
		}
		sources = append(sources, &s)
	}
	return sources, rows.Err()
}

// InsertTaxon inserts a new taxon into the reference table
func (db *Database) InsertTaxon(taxon *models.Taxon) error {
	_, err := db.conn.Exec(
		`INSERT INTO taxa (name, level, parent, author, notes) VALUES (?, ?, ?, ?, ?)`,
		taxon.Name, string(taxon.Level), taxon.Parent, taxon.Author, taxon.Notes,
	)
	if err != nil {
		return fmt.Errorf("failed to insert taxon: %w", err)
	}
	return nil
}

// GetTaxon gets a taxon by name and level
func (db *Database) GetTaxon(name string, level models.TaxonLevel) (*models.Taxon, error) {
	row := db.conn.QueryRow(
		`SELECT name, level, parent, author, notes FROM taxa WHERE name = ? AND level = ?`,
		name, string(level),
	)

	var t models.Taxon
	var levelStr string
	err := row.Scan(&t.Name, &levelStr, &t.Parent, &t.Author, &t.Notes)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get taxon: %w", err)
	}
	t.Level = models.TaxonLevel(levelStr)
	return &t, nil
}

// ListTaxa lists all taxa, optionally filtered by level
func (db *Database) ListTaxa(level *models.TaxonLevel) ([]*models.Taxon, error) {
	var rows *sql.Rows
	var err error

	if level != nil {
		rows, err = db.conn.Query(
			`SELECT name, level, parent, author, notes FROM taxa WHERE level = ? ORDER BY name`,
			string(*level),
		)
	} else {
		rows, err = db.conn.Query(
			`SELECT name, level, parent, author, notes FROM taxa ORDER BY level, name`,
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
		if err := rows.Scan(&t.Name, &levelStr, &t.Parent, &t.Author, &t.Notes); err != nil {
			return nil, fmt.Errorf("failed to scan taxon: %w", err)
		}
		t.Level = models.TaxonLevel(levelStr)
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
	tx, err := db.conn.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

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

	_, err = tx.Exec(
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

	saveField := func(fieldName string, dataPoints []models.DataPoint) error {
		_, err := tx.Exec(
			`DELETE FROM data_points WHERE scientific_name = ? AND field_name = ?`,
			entry.ScientificName, fieldName,
		)
		if err != nil {
			return err
		}

		for _, dp := range dataPoints {
			_, err := tx.Exec(
				`INSERT INTO data_points (scientific_name, field_name, value, source_id, page_number)
				 VALUES (?, ?, ?, ?, ?)`,
				entry.ScientificName, fieldName, dp.Value, dp.SourceID, dp.PageNumber,
			)
			if err != nil {
				return err
			}
		}
		return nil
	}

	fields := map[string][]models.DataPoint{
		"common_names": entry.CommonNames,
		"leaf_color":   entry.LeafColor,
		"bud_shape":    entry.BudShape,
		"leaf_shape":   entry.LeafShape,
		"bark_texture": entry.BarkTexture,
		"habitat":      entry.Habitat,
		"native_range": entry.NativeRange,
		"height":       entry.Height,
	}

	for fieldName, dataPoints := range fields {
		if err := saveField(fieldName, dataPoints); err != nil {
			return fmt.Errorf("failed to save field %s: %w", fieldName, err)
		}
	}

	return tx.Commit()
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

	var synonyms []string
	if synonymsJSON.Valid {
		json.Unmarshal([]byte(synonymsJSON.String), &synonyms)
	}
	if synonyms == nil {
		synonyms = []string{}
	}

	entry.Synonyms = synonyms

	loadField := func(fieldName string) ([]models.DataPoint, error) {
		rows, err := db.conn.Query(
			`SELECT value, source_id, page_number FROM data_points
			 WHERE scientific_name = ? AND field_name = ?`,
			scientificName, fieldName,
		)
		if err != nil {
			return nil, err
		}
		defer rows.Close()

		var points []models.DataPoint
		for rows.Next() {
			var dp models.DataPoint
			if err := rows.Scan(&dp.Value, &dp.SourceID, &dp.PageNumber); err != nil {
				return nil, err
			}
			points = append(points, dp)
		}
		return points, rows.Err()
	}

	fieldPtrs := map[string]*[]models.DataPoint{
		"common_names": &entry.CommonNames,
		"leaf_color":   &entry.LeafColor,
		"bud_shape":    &entry.BudShape,
		"leaf_shape":   &entry.LeafShape,
		"bark_texture": &entry.BarkTexture,
		"habitat":      &entry.Habitat,
		"native_range": &entry.NativeRange,
		"height":       &entry.Height,
	}

	for fieldName, ptr := range fieldPtrs {
		points, err := loadField(fieldName)
		if err != nil {
			return nil, fmt.Errorf("failed to load field %s: %w", fieldName, err)
		}
		*ptr = points
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
func (db *Database) SearchSources(query string) ([]string, error) {
	pattern := "%" + query + "%"
	rows, err := db.conn.Query(
		`SELECT source_id FROM sources
		 WHERE name LIKE ? OR source_id LIKE ? ORDER BY name`,
		pattern, pattern,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to search sources: %w", err)
	}
	defer rows.Close()

	var ids []string
	for rows.Next() {
		var id string
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
