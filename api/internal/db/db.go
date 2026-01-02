package db

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/jeff/oaks/api/internal/models"

	_ "github.com/mattn/go-sqlite3" // SQLite driver
)

// escapeLike escapes special characters in SQL LIKE patterns.
// This prevents user input from manipulating query semantics.
// The escape character is '\' which must be specified in the LIKE clause.
func escapeLike(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `%`, `\%`)
	s = strings.ReplaceAll(s, `_`, `\_`)
	return s
}

// sliceContains checks if a string slice contains a value
func sliceContains(slice []string, value string) bool {
	for _, v := range slice {
		if v == value {
			return true
		}
	}
	return false
}

// sliceRemove removes a value from a string slice, returning the new slice
func sliceRemove(slice []string, value string) []string {
	result := make([]string, 0, len(slice))
	for _, v := range slice {
		if v != value {
			result = append(result, v)
		}
	}
	return result
}

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

// Ping verifies the database connection is alive
func (db *Database) Ping() error {
	return db.conn.Ping()
}

func (db *Database) initializeSchema() error {
	statements := []string{
		// Taxa reference table for validation
		// Hierarchy: Genus (Quercus) -> Subgenus -> Section -> Subsection -> Complex -> Species
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
			notes TEXT,
			license TEXT,
			license_url TEXT
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
			synonyms TEXT,
			external_links TEXT
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
			bark TEXT,
			twigs TEXT,
			buds TEXT,
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

		// Import metadata for tracking incremental imports
		`CREATE TABLE IF NOT EXISTS import_metadata (
			key TEXT PRIMARY KEY,
			value TEXT
		)`,
	}

	for _, stmt := range statements {
		if _, err := db.conn.Exec(stmt); err != nil {
			return fmt.Errorf("failed to execute schema statement: %w", err)
		}
	}

	// Run migrations for new columns (ignore errors if column already exists)
	migrations := []string{
		`ALTER TABLE oak_entries ADD COLUMN external_links TEXT`,
	}
	for _, stmt := range migrations {
		_, _ = db.conn.Exec(stmt) // Ignore error - column may already exist
	}

	return nil
}

// InsertSource inserts a new source and returns its ID
func (db *Database) InsertSource(source *models.Source) (int64, error) {
	result, err := db.conn.Exec(
		`INSERT INTO sources (source_type, name, description, author, year, url, isbn, doi, notes, license, license_url)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		source.SourceType, source.Name, source.Description,
		source.Author, source.Year, source.URL, source.ISBN, source.DOI, source.Notes, source.License, source.LicenseURL,
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
		`SELECT id, source_type, name, description, author, year, url, isbn, doi, notes, license, license_url
		 FROM sources WHERE id = ?`,
		id,
	)

	var s models.Source
	err := row.Scan(&s.ID, &s.SourceType, &s.Name, &s.Description, &s.Author, &s.Year, &s.URL, &s.ISBN, &s.DOI, &s.Notes, &s.License, &s.LicenseURL)
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
		 SET source_type = ?, name = ?, description = ?, author = ?, year = ?, url = ?, isbn = ?, doi = ?, notes = ?, license = ?, license_url = ?
		 WHERE id = ?`,
		source.SourceType, source.Name, source.Description, source.Author, source.Year,
		source.URL, source.ISBN, source.DOI, source.Notes, source.License, source.LicenseURL, source.ID,
	)
	if err != nil {
		return fmt.Errorf("failed to update source: %w", err)
	}
	return nil
}

// ListSources lists all sources
func (db *Database) ListSources() ([]*models.Source, error) {
	rows, err := db.conn.Query(
		`SELECT id, source_type, name, description, author, year, url, isbn, doi, notes, license, license_url
		 FROM sources ORDER BY name`,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to list sources: %w", err)
	}
	defer rows.Close()

	var sources []*models.Source
	for rows.Next() {
		var s models.Source
		if err := rows.Scan(&s.ID, &s.SourceType, &s.Name, &s.Description, &s.Author, &s.Year, &s.URL, &s.ISBN, &s.DOI, &s.Notes, &s.License, &s.LicenseURL); err != nil {
			return nil, fmt.Errorf("failed to scan source: %w", err)
		}
		sources = append(sources, &s)
	}
	return sources, rows.Err()
}

// DeleteSource deletes a source by ID
func (db *Database) DeleteSource(id int64) error {
	result, err := db.conn.Exec(`DELETE FROM sources WHERE id = ?`, id)
	if err != nil {
		return fmt.Errorf("failed to delete source: %w", err)
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("source not found: %d", id)
	}
	return nil
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
		`SELECT t.name, t.level, t.parent, t.author, t.notes, t.links,
		        (SELECT COUNT(*) FROM oak_entries o WHERE
		            (t.level = 'subgenus' AND o.subgenus = t.name) OR
		            (t.level = 'section' AND o.section = t.name) OR
		            (t.level = 'subsection' AND o.subsection = t.name) OR
		            (t.level = 'complex' AND o.complex = t.name)
		        ) as species_count
		 FROM taxa t WHERE t.name = ? AND t.level = ?`,
		name, string(level),
	)

	var t models.Taxon
	var levelStr string
	var linksJSON sql.NullString
	err := row.Scan(&t.Name, &levelStr, &t.Parent, &t.Author, &t.Notes, &linksJSON, &t.SpeciesCount)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get taxon: %w", err)
	}
	t.Level = models.TaxonLevel(levelStr)

	if linksJSON.Valid && linksJSON.String != "" {
		if err := json.Unmarshal([]byte(linksJSON.String), &t.Links); err != nil {
			return nil, fmt.Errorf("failed to unmarshal taxon links for %s: %w", t.Name, err)
		}
	}
	if t.Links == nil {
		t.Links = []models.TaxonLink{}
	}

	return &t, nil
}

// TaxaListParams contains optional filters for listing taxa
type TaxaListParams struct {
	Level  *models.TaxonLevel
	Parent *string
}

// ListTaxa lists all taxa, optionally filtered by level and parent
func (db *Database) ListTaxa(params *TaxaListParams) ([]*models.Taxon, error) {
	var rows *sql.Rows
	var err error
	var args []interface{}

	// Base query with species count subquery
	baseQuery := `SELECT t.name, t.level, t.parent, t.author, t.notes, t.links,
	                     (SELECT COUNT(*) FROM oak_entries o WHERE
	                         (t.level = 'subgenus' AND o.subgenus = t.name) OR
	                         (t.level = 'section' AND o.section = t.name) OR
	                         (t.level = 'subsection' AND o.subsection = t.name) OR
	                         (t.level = 'complex' AND o.complex = t.name)
	                     ) as species_count
	              FROM taxa t`

	// Build WHERE clause
	var conditions []string
	if params != nil && params.Level != nil {
		conditions = append(conditions, "t.level = ?")
		args = append(args, string(*params.Level))
	}
	if params != nil && params.Parent != nil {
		conditions = append(conditions, "t.parent = ?")
		args = append(args, *params.Parent)
	}

	query := baseQuery
	if len(conditions) > 0 {
		query += " WHERE " + strings.Join(conditions, " AND ")
	}
	query += " ORDER BY t.name"

	rows, err = db.conn.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list taxa: %w", err)
	}
	defer rows.Close()

	var taxa []*models.Taxon
	for rows.Next() {
		var t models.Taxon
		var levelStr string
		var linksJSON sql.NullString
		if err := rows.Scan(&t.Name, &levelStr, &t.Parent, &t.Author, &t.Notes, &linksJSON, &t.SpeciesCount); err != nil {
			return nil, fmt.Errorf("failed to scan taxon: %w", err)
		}
		t.Level = models.TaxonLevel(levelStr)

		if linksJSON.Valid && linksJSON.String != "" {
			if err := json.Unmarshal([]byte(linksJSON.String), &t.Links); err != nil {
				return nil, fmt.Errorf("failed to unmarshal taxon links for %s: %w", t.Name, err)
			}
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

// DeleteTaxon deletes a taxon by name and level
func (db *Database) DeleteTaxon(name string, level models.TaxonLevel) error {
	result, err := db.conn.Exec(
		`DELETE FROM taxa WHERE name = ? AND level = ?`,
		name, string(level),
	)
	if err != nil {
		return fmt.Errorf("failed to delete taxon: %w", err)
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("taxon not found: %s [%s]", name, level)
	}
	return nil
}

// SearchTaxa searches taxa by name pattern (case-insensitive)
func (db *Database) SearchTaxa(query string) ([]*models.Taxon, error) {
	pattern := "%" + escapeLike(query) + "%"
	rows, err := db.conn.Query(
		`SELECT name, level, parent, author, notes, links FROM taxa
		 WHERE name LIKE ? ESCAPE '\' ORDER BY level, name`,
		pattern,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to search taxa: %w", err)
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
			if err := json.Unmarshal([]byte(linksJSON.String), &t.Links); err != nil {
				return nil, fmt.Errorf("failed to unmarshal taxon links for %s: %w", t.Name, err)
			}
		}
		if t.Links == nil {
			t.Links = []models.TaxonLink{}
		}

		taxa = append(taxa, &t)
	}
	return taxa, rows.Err()
}

// SaveOakEntry saves or updates a complete oak entry.
// It also maintains bidirectional parent-child relationships:
// when a hybrid's parents are set/changed, the parents' hybrids lists are updated.
func (db *Database) SaveOakEntry(entry *models.OakEntry) error {
	// Start transaction for atomic updates
	tx, err := db.conn.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	// Get existing entry to compare parents (for bidirectional relationship updates)
	existingEntry, err := db.getOakEntryTx(tx, entry.ScientificName)
	if err != nil {
		return fmt.Errorf("failed to get existing entry: %w", err)
	}

	// Compute parent changes
	oldParents := make(map[string]bool)
	newParents := make(map[string]bool)

	if existingEntry != nil {
		if existingEntry.Parent1 != nil && *existingEntry.Parent1 != "" {
			oldParents[*existingEntry.Parent1] = true
		}
		if existingEntry.Parent2 != nil && *existingEntry.Parent2 != "" {
			oldParents[*existingEntry.Parent2] = true
		}
	}

	if entry.Parent1 != nil && *entry.Parent1 != "" {
		newParents[*entry.Parent1] = true
	}
	if entry.Parent2 != nil && *entry.Parent2 != "" {
		newParents[*entry.Parent2] = true
	}

	// Remove hybrid from parents that are no longer in the list
	for parent := range oldParents {
		if !newParents[parent] {
			if err := db.removeHybridFromParentTx(tx, parent, entry.ScientificName); err != nil {
				return fmt.Errorf("failed to remove hybrid from parent %s: %w", parent, err)
			}
		}
	}

	// Add hybrid to new parents
	for parent := range newParents {
		if !oldParents[parent] {
			if err := db.addHybridToParentTx(tx, parent, entry.ScientificName); err != nil {
				return fmt.Errorf("failed to add hybrid to parent %s: %w", parent, err)
			}
		}
	}

	// Save the entry itself
	if err := db.saveOakEntryTx(tx, entry); err != nil {
		return err
	}

	return tx.Commit()
}

// getOakEntryTx gets an oak entry within a transaction
func (db *Database) getOakEntryTx(tx *sql.Tx, scientificName string) (*models.OakEntry, error) {
	row := tx.QueryRow(
		`SELECT scientific_name, author, is_hybrid, conservation_status,
		        subgenus, section, subsection, complex,
		        parent1, parent2, hybrids, closely_related_to, subspecies_varieties, synonyms, external_links
		 FROM oak_entries WHERE scientific_name = ?`,
		scientificName,
	)

	var entry models.OakEntry
	var isHybrid int
	var hybridsJSON, relatedJSON, subspeciesJSON, synonymsJSON, externalLinksJSON sql.NullString

	if err := row.Scan(
		&entry.ScientificName, &entry.Author, &isHybrid, &entry.ConservationStatus,
		&entry.Subgenus, &entry.Section, &entry.Subsection, &entry.Complex,
		&entry.Parent1, &entry.Parent2, &hybridsJSON, &relatedJSON, &subspeciesJSON, &synonymsJSON, &externalLinksJSON,
	); err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get oak entry: %w", err)
	}

	entry.IsHybrid = isHybrid != 0

	// Unmarshal JSON arrays
	if hybridsJSON.Valid {
		if err := json.Unmarshal([]byte(hybridsJSON.String), &entry.Hybrids); err != nil {
			return nil, fmt.Errorf("failed to unmarshal hybrids for %s: %w", entry.ScientificName, err)
		}
	}
	if entry.Hybrids == nil {
		entry.Hybrids = []string{}
	}

	if relatedJSON.Valid {
		if err := json.Unmarshal([]byte(relatedJSON.String), &entry.CloselyRelatedTo); err != nil {
			return nil, fmt.Errorf("failed to unmarshal closely_related_to for %s: %w", entry.ScientificName, err)
		}
	}
	if entry.CloselyRelatedTo == nil {
		entry.CloselyRelatedTo = []string{}
	}

	if subspeciesJSON.Valid {
		if err := json.Unmarshal([]byte(subspeciesJSON.String), &entry.SubspeciesVarieties); err != nil {
			return nil, fmt.Errorf("failed to unmarshal subspecies_varieties for %s: %w", entry.ScientificName, err)
		}
	}
	if entry.SubspeciesVarieties == nil {
		entry.SubspeciesVarieties = []string{}
	}

	if synonymsJSON.Valid {
		if err := json.Unmarshal([]byte(synonymsJSON.String), &entry.Synonyms); err != nil {
			return nil, fmt.Errorf("failed to unmarshal synonyms for %s: %w", entry.ScientificName, err)
		}
	}
	if entry.Synonyms == nil {
		entry.Synonyms = []string{}
	}

	if externalLinksJSON.Valid {
		if err := json.Unmarshal([]byte(externalLinksJSON.String), &entry.ExternalLinks); err != nil {
			return nil, fmt.Errorf("failed to unmarshal external_links for %s: %w", entry.ScientificName, err)
		}
	}
	if entry.ExternalLinks == nil {
		entry.ExternalLinks = []models.ExternalLink{}
	}

	return &entry, nil
}

// removeHybridFromParentTx removes a hybrid from a parent's hybrids list within a transaction
func (db *Database) removeHybridFromParentTx(tx *sql.Tx, parentName, hybridName string) error {
	// Get parent's current hybrids list
	var hybridsJSON sql.NullString
	err := tx.QueryRow(
		`SELECT hybrids FROM oak_entries WHERE scientific_name = ?`,
		parentName,
	).Scan(&hybridsJSON)
	if err != nil {
		if err == sql.ErrNoRows {
			// Parent doesn't exist, nothing to do
			return nil
		}
		return fmt.Errorf("failed to get parent hybrids: %w", err)
	}

	var hybrids []string
	if hybridsJSON.Valid {
		if err := json.Unmarshal([]byte(hybridsJSON.String), &hybrids); err != nil {
			return fmt.Errorf("failed to unmarshal hybrids: %w", err)
		}
	}

	// Remove the hybrid from the list
	hybrids = sliceRemove(hybrids, hybridName)

	// Save updated list
	updatedJSON, err := json.Marshal(hybrids)
	if err != nil {
		return fmt.Errorf("failed to marshal hybrids: %w", err)
	}

	_, err = tx.Exec(
		`UPDATE oak_entries SET hybrids = ? WHERE scientific_name = ?`,
		string(updatedJSON), parentName,
	)
	return err
}

// addHybridToParentTx adds a hybrid to a parent's hybrids list within a transaction
func (db *Database) addHybridToParentTx(tx *sql.Tx, parentName, hybridName string) error {
	// Get parent's current hybrids list
	var hybridsJSON sql.NullString
	err := tx.QueryRow(
		`SELECT hybrids FROM oak_entries WHERE scientific_name = ?`,
		parentName,
	).Scan(&hybridsJSON)
	if err != nil {
		if err == sql.ErrNoRows {
			// Parent doesn't exist, nothing to do
			return nil
		}
		return fmt.Errorf("failed to get parent hybrids: %w", err)
	}

	var hybrids []string
	if hybridsJSON.Valid {
		if err := json.Unmarshal([]byte(hybridsJSON.String), &hybrids); err != nil {
			return fmt.Errorf("failed to unmarshal hybrids: %w", err)
		}
	}

	// Add the hybrid if not already present
	if !sliceContains(hybrids, hybridName) {
		hybrids = append(hybrids, hybridName)
	}

	// Save updated list
	updatedJSON, err := json.Marshal(hybrids)
	if err != nil {
		return fmt.Errorf("failed to marshal hybrids: %w", err)
	}

	_, err = tx.Exec(
		`UPDATE oak_entries SET hybrids = ? WHERE scientific_name = ?`,
		string(updatedJSON), parentName,
	)
	return err
}

// saveOakEntryTx saves an oak entry within a transaction
func (db *Database) saveOakEntryTx(tx *sql.Tx, entry *models.OakEntry) error {
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
	externalLinksJSON, err := json.Marshal(entry.ExternalLinks)
	if err != nil {
		return fmt.Errorf("failed to marshal external_links: %w", err)
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
			parent1, parent2, hybrids, closely_related_to, subspecies_varieties, synonyms, external_links
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		entry.ScientificName, entry.Author, isHybrid, entry.ConservationStatus,
		entry.Subgenus, entry.Section, entry.Subsection, entry.Complex,
		entry.Parent1, entry.Parent2, string(hybridsJSON), string(relatedJSON),
		string(subspeciesJSON), string(synonymsJSON), string(externalLinksJSON),
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
		        parent1, parent2, hybrids, closely_related_to, subspecies_varieties, synonyms, external_links
		 FROM oak_entries WHERE scientific_name = ?`,
		scientificName,
	)

	var entry models.OakEntry
	var isHybrid int
	var hybridsJSON, relatedJSON, subspeciesJSON, synonymsJSON, externalLinksJSON sql.NullString

	if err := row.Scan(
		&entry.ScientificName, &entry.Author, &isHybrid, &entry.ConservationStatus,
		&entry.Subgenus, &entry.Section, &entry.Subsection, &entry.Complex,
		&entry.Parent1, &entry.Parent2, &hybridsJSON, &relatedJSON, &subspeciesJSON, &synonymsJSON, &externalLinksJSON,
	); err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get oak entry: %w", err)
	}

	entry.IsHybrid = isHybrid != 0

	// Unmarshal JSON arrays
	if hybridsJSON.Valid {
		if err := json.Unmarshal([]byte(hybridsJSON.String), &entry.Hybrids); err != nil {
			return nil, fmt.Errorf("failed to unmarshal hybrids for %s: %w", entry.ScientificName, err)
		}
	}
	if entry.Hybrids == nil {
		entry.Hybrids = []string{}
	}

	if relatedJSON.Valid {
		if err := json.Unmarshal([]byte(relatedJSON.String), &entry.CloselyRelatedTo); err != nil {
			return nil, fmt.Errorf("failed to unmarshal closely_related_to for %s: %w", entry.ScientificName, err)
		}
	}
	if entry.CloselyRelatedTo == nil {
		entry.CloselyRelatedTo = []string{}
	}

	if subspeciesJSON.Valid {
		if err := json.Unmarshal([]byte(subspeciesJSON.String), &entry.SubspeciesVarieties); err != nil {
			return nil, fmt.Errorf("failed to unmarshal subspecies_varieties for %s: %w", entry.ScientificName, err)
		}
	}
	if entry.SubspeciesVarieties == nil {
		entry.SubspeciesVarieties = []string{}
	}

	if synonymsJSON.Valid {
		if err := json.Unmarshal([]byte(synonymsJSON.String), &entry.Synonyms); err != nil {
			return nil, fmt.Errorf("failed to unmarshal synonyms for %s: %w", entry.ScientificName, err)
		}
	}
	if entry.Synonyms == nil {
		entry.Synonyms = []string{}
	}

	if externalLinksJSON.Valid {
		if err := json.Unmarshal([]byte(externalLinksJSON.String), &entry.ExternalLinks); err != nil {
			return nil, fmt.Errorf("failed to unmarshal external_links for %s: %w", entry.ScientificName, err)
		}
	}
	if entry.ExternalLinks == nil {
		entry.ExternalLinks = []models.ExternalLink{}
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
	pattern := "%" + escapeLike(query) + "%"
	rows, err := db.conn.Query(
		`SELECT scientific_name FROM oak_entries
		 WHERE scientific_name LIKE ? ESCAPE '\' ORDER BY scientific_name`,
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

// OakEntryFilter contains filter criteria for listing oak entries
type OakEntryFilter struct {
	Subgenus   *string
	Section    *string
	Subsection *string
	Complex    *string
	Hybrid     *bool
}

// ListOakEntriesPaginated returns a paginated list of oak entries with optional filters
func (db *Database) ListOakEntriesPaginated(limit, offset int, filter *OakEntryFilter) ([]*models.OakEntry, error) {
	query := `SELECT scientific_name, author, is_hybrid, conservation_status,
		        subgenus, section, subsection, complex,
		        parent1, parent2, hybrids, closely_related_to, subspecies_varieties, synonyms, external_links
		 FROM oak_entries`

	var args []interface{}
	var conditions []string

	if filter != nil {
		if filter.Subgenus != nil {
			conditions = append(conditions, "subgenus = ?")
			args = append(args, *filter.Subgenus)
		}
		if filter.Section != nil {
			conditions = append(conditions, "section = ?")
			args = append(args, *filter.Section)
		}
		if filter.Subsection != nil {
			conditions = append(conditions, "subsection = ?")
			args = append(args, *filter.Subsection)
		}
		if filter.Complex != nil {
			conditions = append(conditions, "complex = ?")
			args = append(args, *filter.Complex)
		}
		if filter.Hybrid != nil {
			conditions = append(conditions, "is_hybrid = ?")
			if *filter.Hybrid {
				args = append(args, 1)
			} else {
				args = append(args, 0)
			}
		}
	}

	if len(conditions) > 0 {
		query += " WHERE " + strings.Join(conditions, " AND ")
	}

	query += " ORDER BY scientific_name LIMIT ? OFFSET ?"
	args = append(args, limit, offset)

	rows, err := db.conn.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list oak entries: %w", err)
	}
	defer rows.Close()

	return scanOakEntries(rows)
}

// CountOakEntries returns the total count of oak entries matching the filter
func (db *Database) CountOakEntries(filter *OakEntryFilter) (int, error) {
	query := `SELECT COUNT(*) FROM oak_entries`

	var args []interface{}
	var conditions []string

	if filter != nil {
		if filter.Subgenus != nil {
			conditions = append(conditions, "subgenus = ?")
			args = append(args, *filter.Subgenus)
		}
		if filter.Section != nil {
			conditions = append(conditions, "section = ?")
			args = append(args, *filter.Section)
		}
		if filter.Subsection != nil {
			conditions = append(conditions, "subsection = ?")
			args = append(args, *filter.Subsection)
		}
		if filter.Complex != nil {
			conditions = append(conditions, "complex = ?")
			args = append(args, *filter.Complex)
		}
		if filter.Hybrid != nil {
			conditions = append(conditions, "is_hybrid = ?")
			if *filter.Hybrid {
				args = append(args, 1)
			} else {
				args = append(args, 0)
			}
		}
	}

	if len(conditions) > 0 {
		query += " WHERE " + strings.Join(conditions, " AND ")
	}

	var count int
	if err := db.conn.QueryRow(query, args...).Scan(&count); err != nil {
		return 0, fmt.Errorf("failed to count oak entries: %w", err)
	}
	return count, nil
}

// SearchOakEntriesFull searches for oak entries by name pattern and returns full entries
func (db *Database) SearchOakEntriesFull(query string, limit int) ([]*models.OakEntry, error) {
	pattern := "%" + escapeLike(query) + "%"
	rows, err := db.conn.Query(
		`SELECT scientific_name, author, is_hybrid, conservation_status,
		        subgenus, section, subsection, complex,
		        parent1, parent2, hybrids, closely_related_to, subspecies_varieties, synonyms, external_links
		 FROM oak_entries
		 WHERE scientific_name LIKE ? ESCAPE '\'
		 ORDER BY scientific_name LIMIT ?`,
		pattern, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to search oak entries: %w", err)
	}
	defer rows.Close()

	return scanOakEntries(rows)
}

// OakEntryExists checks if an oak entry exists by scientific name
func (db *Database) OakEntryExists(scientificName string) (bool, error) {
	var count int
	err := db.conn.QueryRow(
		`SELECT COUNT(*) FROM oak_entries WHERE scientific_name = ?`,
		scientificName,
	).Scan(&count)
	if err != nil {
		return false, fmt.Errorf("failed to check oak entry existence: %w", err)
	}
	return count > 0, nil
}

// scanOakEntries is a helper that scans rows into OakEntry objects
func scanOakEntries(rows *sql.Rows) ([]*models.OakEntry, error) {
	var entries []*models.OakEntry
	for rows.Next() {
		var entry models.OakEntry
		var isHybrid int
		var hybridsJSON, relatedJSON, subspeciesJSON, synonymsJSON, externalLinksJSON sql.NullString

		if err := rows.Scan(
			&entry.ScientificName, &entry.Author, &isHybrid, &entry.ConservationStatus,
			&entry.Subgenus, &entry.Section, &entry.Subsection, &entry.Complex,
			&entry.Parent1, &entry.Parent2, &hybridsJSON, &relatedJSON, &subspeciesJSON, &synonymsJSON, &externalLinksJSON,
		); err != nil {
			return nil, fmt.Errorf("failed to scan oak entry: %w", err)
		}

		entry.IsHybrid = isHybrid != 0

		// Unmarshal JSON arrays
		if hybridsJSON.Valid {
			if err := json.Unmarshal([]byte(hybridsJSON.String), &entry.Hybrids); err != nil {
				return nil, fmt.Errorf("failed to unmarshal hybrids for %s: %w", entry.ScientificName, err)
			}
		}
		if entry.Hybrids == nil {
			entry.Hybrids = []string{}
		}

		if relatedJSON.Valid {
			if err := json.Unmarshal([]byte(relatedJSON.String), &entry.CloselyRelatedTo); err != nil {
				return nil, fmt.Errorf("failed to unmarshal closely_related_to for %s: %w", entry.ScientificName, err)
			}
		}
		if entry.CloselyRelatedTo == nil {
			entry.CloselyRelatedTo = []string{}
		}

		if subspeciesJSON.Valid {
			if err := json.Unmarshal([]byte(subspeciesJSON.String), &entry.SubspeciesVarieties); err != nil {
				return nil, fmt.Errorf("failed to unmarshal subspecies_varieties for %s: %w", entry.ScientificName, err)
			}
		}
		if entry.SubspeciesVarieties == nil {
			entry.SubspeciesVarieties = []string{}
		}

		if synonymsJSON.Valid {
			if err := json.Unmarshal([]byte(synonymsJSON.String), &entry.Synonyms); err != nil {
				return nil, fmt.Errorf("failed to unmarshal synonyms for %s: %w", entry.ScientificName, err)
			}
		}
		if entry.Synonyms == nil {
			entry.Synonyms = []string{}
		}

		if externalLinksJSON.Valid {
			if err := json.Unmarshal([]byte(externalLinksJSON.String), &entry.ExternalLinks); err != nil {
				return nil, fmt.Errorf("failed to unmarshal external_links for %s: %w", entry.ScientificName, err)
			}
		}
		if entry.ExternalLinks == nil {
			entry.ExternalLinks = []models.ExternalLink{}
		}

		entries = append(entries, &entry)
	}

	return entries, rows.Err()
}

// SearchSources searches for sources by name pattern
func (db *Database) SearchSources(query string) ([]int64, error) {
	pattern := "%" + escapeLike(query) + "%"
	rows, err := db.conn.Query(
		`SELECT id FROM sources
		 WHERE name LIKE ? ESCAPE '\' ORDER BY name`,
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
		        parent1, parent2, hybrids, closely_related_to, subspecies_varieties, synonyms, external_links
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
		var hybridsJSON, relatedJSON, subspeciesJSON, synonymsJSON, externalLinksJSON sql.NullString

		if err := rows.Scan(
			&entry.ScientificName, &entry.Author, &isHybrid, &entry.ConservationStatus,
			&entry.Subgenus, &entry.Section, &entry.Subsection, &entry.Complex,
			&entry.Parent1, &entry.Parent2, &hybridsJSON, &relatedJSON, &subspeciesJSON, &synonymsJSON, &externalLinksJSON,
		); err != nil {
			return nil, fmt.Errorf("failed to scan oak entry: %w", err)
		}

		entry.IsHybrid = isHybrid != 0

		// Unmarshal JSON arrays
		if hybridsJSON.Valid {
			if err := json.Unmarshal([]byte(hybridsJSON.String), &entry.Hybrids); err != nil {
				return nil, fmt.Errorf("failed to unmarshal hybrids for %s: %w", entry.ScientificName, err)
			}
		}
		if entry.Hybrids == nil {
			entry.Hybrids = []string{}
		}

		if relatedJSON.Valid {
			if err := json.Unmarshal([]byte(relatedJSON.String), &entry.CloselyRelatedTo); err != nil {
				return nil, fmt.Errorf("failed to unmarshal closely_related_to for %s: %w", entry.ScientificName, err)
			}
		}
		if entry.CloselyRelatedTo == nil {
			entry.CloselyRelatedTo = []string{}
		}

		if subspeciesJSON.Valid {
			if err := json.Unmarshal([]byte(subspeciesJSON.String), &entry.SubspeciesVarieties); err != nil {
				return nil, fmt.Errorf("failed to unmarshal subspecies_varieties for %s: %w", entry.ScientificName, err)
			}
		}
		if entry.SubspeciesVarieties == nil {
			entry.SubspeciesVarieties = []string{}
		}

		if synonymsJSON.Valid {
			if err := json.Unmarshal([]byte(synonymsJSON.String), &entry.Synonyms); err != nil {
				return nil, fmt.Errorf("failed to unmarshal synonyms for %s: %w", entry.ScientificName, err)
			}
		}
		if entry.Synonyms == nil {
			entry.Synonyms = []string{}
		}

		if externalLinksJSON.Valid {
			if err := json.Unmarshal([]byte(externalLinksJSON.String), &entry.ExternalLinks); err != nil {
				return nil, fmt.Errorf("failed to unmarshal external_links for %s: %w", entry.ScientificName, err)
			}
		}
		if entry.ExternalLinks == nil {
			entry.ExternalLinks = []models.ExternalLink{}
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
			leaves, flowers, fruits, bark, twigs, buds, hardiness_habitat,
			miscellaneous, url, is_preferred
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		ss.ScientificName, ss.SourceID, string(localNamesJSON), ss.Range, ss.GrowthHabit,
		ss.Leaves, ss.Flowers, ss.Fruits, ss.Bark, ss.Twigs, ss.Buds, ss.HardinessHabitat,
		ss.Miscellaneous, ss.URL, isPreferred,
	)
	if err != nil {
		return fmt.Errorf("failed to save species source: %w", err)
	}

	if ss.ID == 0 {
		id, err := result.LastInsertId()
		if err != nil {
			return fmt.Errorf("failed to get last insert id: %w", err)
		}
		ss.ID = id
	}
	return nil
}

// GetSpeciesSources returns all source data for a species
func (db *Database) GetSpeciesSources(scientificName string) ([]*models.SpeciesSource, error) {
	rows, err := db.conn.Query(
		`SELECT id, scientific_name, source_id, local_names, range, growth_habit,
		        leaves, flowers, fruits, bark, twigs, buds, hardiness_habitat,
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

// GetSpeciesSourceBySourceID returns source data for a specific species+source combination
func (db *Database) GetSpeciesSourceBySourceID(scientificName string, sourceID int64) (*models.SpeciesSource, error) {
	row := db.conn.QueryRow(
		`SELECT id, scientific_name, source_id, local_names, range, growth_habit,
		        leaves, flowers, fruits, bark, twigs, buds, hardiness_habitat,
		        miscellaneous, url, is_preferred
		 FROM species_sources WHERE scientific_name = ? AND source_id = ?`,
		scientificName, sourceID,
	)

	ss := &models.SpeciesSource{}
	var localNamesJSON sql.NullString
	var isPreferred int

	err := row.Scan(
		&ss.ID, &ss.ScientificName, &ss.SourceID, &localNamesJSON, &ss.Range, &ss.GrowthHabit,
		&ss.Leaves, &ss.Flowers, &ss.Fruits, &ss.Bark, &ss.Twigs, &ss.Buds, &ss.HardinessHabitat,
		&ss.Miscellaneous, &ss.URL, &isPreferred,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get species source: %w", err)
	}

	ss.IsPreferred = isPreferred != 0
	if localNamesJSON.Valid {
		if err := json.Unmarshal([]byte(localNamesJSON.String), &ss.LocalNames); err != nil {
			return nil, fmt.Errorf("failed to unmarshal local_names for %s: %w", ss.ScientificName, err)
		}
	}
	if ss.LocalNames == nil {
		ss.LocalNames = []string{}
	}

	return ss, nil
}

// GetPreferredSpeciesSource returns the preferred source data for a species
func (db *Database) GetPreferredSpeciesSource(scientificName string) (*models.SpeciesSource, error) {
	row := db.conn.QueryRow(
		`SELECT id, scientific_name, source_id, local_names, range, growth_habit,
		        leaves, flowers, fruits, bark, twigs, buds, hardiness_habitat,
		        miscellaneous, url, is_preferred
		 FROM species_sources WHERE scientific_name = ? ORDER BY is_preferred DESC LIMIT 1`,
		scientificName,
	)

	ss := &models.SpeciesSource{}
	var localNamesJSON sql.NullString
	var isPreferred int

	err := row.Scan(
		&ss.ID, &ss.ScientificName, &ss.SourceID, &localNamesJSON, &ss.Range, &ss.GrowthHabit,
		&ss.Leaves, &ss.Flowers, &ss.Fruits, &ss.Bark, &ss.Twigs, &ss.Buds, &ss.HardinessHabitat,
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
		if err := json.Unmarshal([]byte(localNamesJSON.String), &ss.LocalNames); err != nil {
			return nil, fmt.Errorf("failed to unmarshal local_names for %s: %w", ss.ScientificName, err)
		}
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
		&ss.Leaves, &ss.Flowers, &ss.Fruits, &ss.Bark, &ss.Twigs, &ss.Buds, &ss.HardinessHabitat,
		&ss.Miscellaneous, &ss.URL, &isPreferred,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to scan species source: %w", err)
	}

	ss.IsPreferred = isPreferred != 0
	if localNamesJSON.Valid {
		if err := json.Unmarshal([]byte(localNamesJSON.String), &ss.LocalNames); err != nil {
			return nil, fmt.Errorf("failed to unmarshal local_names for %s: %w", ss.ScientificName, err)
		}
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
		        leaves, flowers, fruits, bark, twigs, buds, hardiness_habitat,
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

// DeleteSpeciesSource deletes a species-source record by scientific name and source ID
func (db *Database) DeleteSpeciesSource(scientificName string, sourceID int64) error {
	result, err := db.conn.Exec(
		`DELETE FROM species_sources WHERE scientific_name = ? AND source_id = ?`,
		scientificName, sourceID,
	)
	if err != nil {
		return fmt.Errorf("failed to delete species source: %w", err)
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("species source not found: %s (source %d)", scientificName, sourceID)
	}
	return nil
}

// GetMetadata retrieves a metadata value by key
func (db *Database) GetMetadata(key string) (string, error) {
	var value sql.NullString
	err := db.conn.QueryRow(
		`SELECT value FROM import_metadata WHERE key = ?`,
		key,
	).Scan(&value)
	if err == sql.ErrNoRows {
		return "", nil
	}
	if err != nil {
		return "", fmt.Errorf("failed to get metadata: %w", err)
	}
	if !value.Valid {
		return "", nil
	}
	return value.String, nil
}

// SetMetadata sets a metadata key-value pair
func (db *Database) SetMetadata(key, value string) error {
	_, err := db.conn.Exec(
		`INSERT OR REPLACE INTO import_metadata (key, value) VALUES (?, ?)`,
		key, value,
	)
	if err != nil {
		return fmt.Errorf("failed to set metadata: %w", err)
	}
	return nil
}

// DeleteMetadata removes a metadata key
func (db *Database) DeleteMetadata(key string) error {
	_, err := db.conn.Exec(
		`DELETE FROM import_metadata WHERE key = ?`,
		key,
	)
	if err != nil {
		return fmt.Errorf("failed to delete metadata: %w", err)
	}
	return nil
}

// GetOakEntryWithSources returns a species with all its source data embedded
// Sources are ordered by is_preferred DESC, source_id ASC
func (db *Database) GetOakEntryWithSources(scientificName string) (*models.SpeciesWithSources, error) {
	// Get the species entry first
	entry, err := db.GetOakEntry(scientificName)
	if err != nil {
		return nil, err
	}
	if entry == nil {
		return nil, nil
	}

	// Get sources with source metadata via join
	rows, err := db.conn.Query(
		`SELECT ss.id, ss.scientific_name, ss.source_id, ss.local_names, ss.range, ss.growth_habit,
		        ss.leaves, ss.flowers, ss.fruits, ss.bark, ss.twigs, ss.buds, ss.hardiness_habitat,
		        ss.miscellaneous, ss.url, ss.is_preferred,
		        s.name, s.url
		 FROM species_sources ss
		 JOIN sources s ON ss.source_id = s.id
		 WHERE ss.scientific_name = ?
		 ORDER BY ss.is_preferred DESC, ss.source_id ASC`,
		scientificName,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get species sources with metadata: %w", err)
	}
	defer rows.Close()

	var sources []models.SpeciesSourceWithMeta
	for rows.Next() {
		var ssm models.SpeciesSourceWithMeta
		var localNamesJSON sql.NullString
		var isPreferred int

		err := rows.Scan(
			&ssm.ID, &ssm.ScientificName, &ssm.SourceID, &localNamesJSON, &ssm.Range, &ssm.GrowthHabit,
			&ssm.Leaves, &ssm.Flowers, &ssm.Fruits, &ssm.Bark, &ssm.Twigs, &ssm.Buds, &ssm.HardinessHabitat,
			&ssm.Miscellaneous, &ssm.URL, &isPreferred,
			&ssm.SourceName, &ssm.SourceURL,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan species source with metadata: %w", err)
		}

		ssm.IsPreferred = isPreferred != 0
		if localNamesJSON.Valid {
			if err := json.Unmarshal([]byte(localNamesJSON.String), &ssm.LocalNames); err != nil {
				return nil, fmt.Errorf("failed to unmarshal local_names: %w", err)
			}
		}
		if ssm.LocalNames == nil {
			ssm.LocalNames = []string{}
		}

		sources = append(sources, ssm)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	// Ensure empty sources array instead of nil
	if sources == nil {
		sources = []models.SpeciesSourceWithMeta{}
	}

	return &models.SpeciesWithSources{
		OakEntry: *entry,
		Sources:  sources,
	}, nil
}

// Stats contains aggregate counts for the database
type Stats struct {
	SpeciesCount int `json:"species_count"`
	HybridCount  int `json:"hybrid_count"`
	TaxaCount    int `json:"taxa_count"`
	SourceCount  int `json:"source_count"`
}

// GetStats returns aggregate counts for species, hybrids, taxa, and sources
func (db *Database) GetStats() (*Stats, error) {
	stats := &Stats{}

	// Count species (non-hybrids)
	if err := db.conn.QueryRow(`SELECT COUNT(*) FROM oak_entries WHERE is_hybrid = 0`).Scan(&stats.SpeciesCount); err != nil {
		return nil, fmt.Errorf("failed to count species: %w", err)
	}

	// Count hybrids
	if err := db.conn.QueryRow(`SELECT COUNT(*) FROM oak_entries WHERE is_hybrid = 1`).Scan(&stats.HybridCount); err != nil {
		return nil, fmt.Errorf("failed to count hybrids: %w", err)
	}

	// Count taxa
	if err := db.conn.QueryRow(`SELECT COUNT(*) FROM taxa`).Scan(&stats.TaxaCount); err != nil {
		return nil, fmt.Errorf("failed to count taxa: %w", err)
	}

	// Count sources
	if err := db.conn.QueryRow(`SELECT COUNT(*) FROM sources`).Scan(&stats.SourceCount); err != nil {
		return nil, fmt.Errorf("failed to count sources: %w", err)
	}

	return stats, nil
}

// GetHybridsReferencingParent returns all hybrids that reference the given species as parent1 or parent2
func (db *Database) GetHybridsReferencingParent(scientificName string) ([]string, error) {
	rows, err := db.conn.Query(
		`SELECT scientific_name FROM oak_entries
		 WHERE is_hybrid = 1 AND (parent1 = ? OR parent2 = ?)
		 ORDER BY scientific_name`,
		scientificName, scientificName,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get hybrids referencing parent: %w", err)
	}
	defer rows.Close()

	var hybrids []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, fmt.Errorf("failed to scan hybrid name: %w", err)
		}
		hybrids = append(hybrids, name)
	}
	return hybrids, rows.Err()
}

// UnifiedSearch searches across species, taxa, and sources
// Species are searched by: scientific_name, author, synonyms, local_names (from species_sources)
// Taxa are searched by: name
// Sources are searched by: name, author
func (db *Database) UnifiedSearch(query string, limit int) (*models.UnifiedSearchResults, error) {
	result := &models.UnifiedSearchResults{
		Query:   query,
		Species: []models.OakEntry{},
		Taxa:    []models.Taxon{},
		Sources: []models.Source{},
	}

	pattern := "%" + escapeLike(query) + "%"

	// Search species: scientific_name, author, synonyms (JSON), local_names (via species_sources)
	speciesRows, err := db.conn.Query(
		`SELECT DISTINCT o.scientific_name, o.author, o.is_hybrid, o.conservation_status,
		        o.subgenus, o.section, o.subsection, o.complex,
		        o.parent1, o.parent2, o.hybrids, o.closely_related_to, o.subspecies_varieties, o.synonyms, o.external_links
		 FROM oak_entries o
		 LEFT JOIN species_sources ss ON o.scientific_name = ss.scientific_name
		 WHERE o.scientific_name LIKE ? ESCAPE '\'
		    OR o.author LIKE ? ESCAPE '\'
		    OR o.synonyms LIKE ? ESCAPE '\'
		    OR ss.local_names LIKE ? ESCAPE '\'
		 ORDER BY o.scientific_name LIMIT ?`,
		pattern, pattern, pattern, pattern, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to search species: %w", err)
	}
	defer speciesRows.Close()

	entries, err := scanOakEntries(speciesRows)
	if err != nil {
		return nil, err
	}
	for _, e := range entries {
		result.Species = append(result.Species, *e)
	}

	// Search taxa by name
	taxaRows, err := db.conn.Query(
		`SELECT t.name, t.level, t.parent, t.author, t.notes, t.links,
		        (SELECT COUNT(*) FROM oak_entries o WHERE
		            (t.level = 'subgenus' AND o.subgenus = t.name) OR
		            (t.level = 'section' AND o.section = t.name) OR
		            (t.level = 'subsection' AND o.subsection = t.name) OR
		            (t.level = 'complex' AND o.complex = t.name)
		        ) as species_count
		 FROM taxa t
		 WHERE t.name LIKE ? ESCAPE '\'
		 ORDER BY t.level, t.name LIMIT ?`,
		pattern, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to search taxa: %w", err)
	}
	defer taxaRows.Close()

	for taxaRows.Next() {
		var t models.Taxon
		var levelStr string
		var linksJSON sql.NullString
		if err := taxaRows.Scan(&t.Name, &levelStr, &t.Parent, &t.Author, &t.Notes, &linksJSON, &t.SpeciesCount); err != nil {
			return nil, fmt.Errorf("failed to scan taxon: %w", err)
		}
		t.Level = models.TaxonLevel(levelStr)

		if linksJSON.Valid && linksJSON.String != "" {
			if err := json.Unmarshal([]byte(linksJSON.String), &t.Links); err != nil {
				return nil, fmt.Errorf("failed to unmarshal taxon links for %s: %w", t.Name, err)
			}
		}
		if t.Links == nil {
			t.Links = []models.TaxonLink{}
		}

		result.Taxa = append(result.Taxa, t)
	}
	if err := taxaRows.Err(); err != nil {
		return nil, err
	}

	// Search sources by name and author
	sourceRows, err := db.conn.Query(
		`SELECT id, source_type, name, description, author, year, url, isbn, doi, notes, license, license_url
		 FROM sources
		 WHERE name LIKE ? ESCAPE '\' OR author LIKE ? ESCAPE '\'
		 ORDER BY name LIMIT ?`,
		pattern, pattern, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to search sources: %w", err)
	}
	defer sourceRows.Close()

	for sourceRows.Next() {
		var s models.Source
		if err := sourceRows.Scan(&s.ID, &s.SourceType, &s.Name, &s.Description, &s.Author, &s.Year, &s.URL, &s.ISBN, &s.DOI, &s.Notes, &s.License, &s.LicenseURL); err != nil {
			return nil, fmt.Errorf("failed to scan source: %w", err)
		}
		result.Sources = append(result.Sources, s)
	}
	if err := sourceRows.Err(); err != nil {
		return nil, err
	}

	// Set counts
	result.Counts.Species = len(result.Species)
	result.Counts.Taxa = len(result.Taxa)
	result.Counts.Sources = len(result.Sources)
	result.Counts.Total = result.Counts.Species + result.Counts.Taxa + result.Counts.Sources

	return result, nil
}
