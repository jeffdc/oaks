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
	// First, check if we need to run the integer ID migration
	// This must happen before creating tables with the old schema
	migrated, err := db.migrateToIntegerIDs()
	if err != nil {
		return fmt.Errorf("migration to integer IDs failed: %w", err)
	}

	// If migration ran, the new schema is already in place
	if migrated {
		// Just ensure additional tables exist (import_metadata, articles)
		additionalStatements := []string{
			// Import metadata for tracking incremental imports
			`CREATE TABLE IF NOT EXISTS import_metadata (
				key TEXT PRIMARY KEY,
				value TEXT
			)`,

			// Articles table for reference articles (guides, book reviews, etc.)
			`CREATE TABLE IF NOT EXISTS articles (
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
			)`,
			`CREATE INDEX IF NOT EXISTS idx_articles_slug ON articles(slug)`,
			`CREATE INDEX IF NOT EXISTS idx_articles_published ON articles(is_published)`,
		}

		for _, stmt := range additionalStatements {
			if _, err := db.conn.Exec(stmt); err != nil {
				return fmt.Errorf("failed to execute schema statement: %w", err)
			}
		}
		return nil
	}

	// For new databases (no oak_entries or species table exists), use new schema
	// This also handles the case where species table already exists
	return db.ensureNewSchema()
}

// ensureNewSchema creates all tables using the new schema (with integer IDs)
func (db *Database) ensureNewSchema() error {
	statements := []string{
		// Taxa reference table with integer ID
		`CREATE TABLE IF NOT EXISTS taxa (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL,
			level TEXT NOT NULL CHECK(level IN ('subgenus', 'section', 'subsection', 'complex')),
			parent TEXT,
			author TEXT,
			content TEXT,
			content_updated_at TEXT,
			links TEXT,
			UNIQUE(name, level)
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

		// Species table (renamed from oak_entries) with integer ID
		`CREATE TABLE IF NOT EXISTS species (
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
		)`,
		`CREATE INDEX IF NOT EXISTS idx_species_subgenus ON species(subgenus)`,
		`CREATE INDEX IF NOT EXISTS idx_species_section ON species(section)`,
		`CREATE INDEX IF NOT EXISTS idx_species_hybrid ON species(is_hybrid)`,

		// Species-source junction table with species_id FK
		`CREATE TABLE IF NOT EXISTS species_sources (
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
		)`,
		`CREATE INDEX IF NOT EXISTS idx_species_sources_species ON species_sources(species_id)`,
		`CREATE INDEX IF NOT EXISTS idx_species_sources_source ON species_sources(source_id)`,

		// Import metadata for tracking incremental imports
		`CREATE TABLE IF NOT EXISTS import_metadata (
			key TEXT PRIMARY KEY,
			value TEXT
		)`,

		// Articles table for reference articles (guides, book reviews, etc.)
		`CREATE TABLE IF NOT EXISTS articles (
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
		)`,
		`CREATE INDEX IF NOT EXISTS idx_articles_slug ON articles(slug)`,
		`CREATE INDEX IF NOT EXISTS idx_articles_published ON articles(is_published)`,
	}

	for _, stmt := range statements {
		if _, err := db.conn.Exec(stmt); err != nil {
			return fmt.Errorf("failed to execute schema statement: %w", err)
		}
	}

	return nil
}

// migrateToIntegerIDs migrates from the old schema (text PKs) to new schema (integer IDs).
// Returns true if migration was performed, false if no migration was needed.
// The migration is idempotent - safe to run multiple times.
func (db *Database) migrateToIntegerIDs() (bool, error) {
	// Check if migration is needed:
	// - oak_entries table exists (old schema)
	// - species table does NOT exist (new schema)
	var oakEntriesExists, speciesExists bool

	var tableName string
	err := db.conn.QueryRow(`SELECT name FROM sqlite_master WHERE type='table' AND name='oak_entries'`).Scan(&tableName)
	oakEntriesExists = (err == nil)

	err = db.conn.QueryRow(`SELECT name FROM sqlite_master WHERE type='table' AND name='species'`).Scan(&tableName)
	speciesExists = (err == nil)

	// If species already exists, migration has already been done
	if speciesExists {
		return false, nil
	}

	// If oak_entries doesn't exist, this is a fresh database - no migration needed
	if !oakEntriesExists {
		return false, nil
	}

	// Pre-flight check: verify no orphaned species_sources rows
	var orphanedCount int
	err = db.conn.QueryRow(`
		SELECT COUNT(*) FROM species_sources ss
		WHERE NOT EXISTS (SELECT 1 FROM oak_entries o WHERE o.scientific_name = ss.scientific_name)
	`).Scan(&orphanedCount)
	if err != nil {
		// species_sources might not exist yet
		if !strings.Contains(err.Error(), "no such table") {
			return false, fmt.Errorf("pre-flight check failed: %w", err)
		}
		orphanedCount = 0
	}

	if orphanedCount > 0 {
		return false, fmt.Errorf("pre-flight check failed: found %d orphaned species_sources rows (scientific_name not in oak_entries). Clean up orphaned data before migration", orphanedCount)
	}

	// Start transaction for atomic migration
	tx, err := db.conn.Begin()
	if err != nil {
		return false, fmt.Errorf("failed to start migration transaction: %w", err)
	}
	defer tx.Rollback()

	// Step 1: Migrate oak_entries -> species
	// Create new species table with integer ID
	_, err = tx.Exec(`
		CREATE TABLE species (
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
	`)
	if err != nil {
		return false, fmt.Errorf("failed to create species table: %w", err)
	}

	// Copy data from oak_entries to species (IDs will be auto-generated)
	_, err = tx.Exec(`
		INSERT INTO species (scientific_name, author, is_hybrid, conservation_status,
			subgenus, section, subsection, complex, parent1, parent2,
			hybrids, closely_related_to, subspecies_varieties, synonyms, external_links)
		SELECT scientific_name, author, is_hybrid, conservation_status,
			subgenus, section, subsection, complex, parent1, parent2,
			hybrids, closely_related_to, subspecies_varieties, synonyms, external_links
		FROM oak_entries
		ORDER BY scientific_name
	`)
	if err != nil {
		return false, fmt.Errorf("failed to copy data to species table: %w", err)
	}

	// Create indexes on species table
	_, err = tx.Exec(`CREATE INDEX idx_species_subgenus ON species(subgenus)`)
	if err != nil {
		return false, fmt.Errorf("failed to create species subgenus index: %w", err)
	}
	_, err = tx.Exec(`CREATE INDEX idx_species_section ON species(section)`)
	if err != nil {
		return false, fmt.Errorf("failed to create species section index: %w", err)
	}
	_, err = tx.Exec(`CREATE INDEX idx_species_hybrid ON species(is_hybrid)`)
	if err != nil {
		return false, fmt.Errorf("failed to create species hybrid index: %w", err)
	}

	// Drop old oak_entries table
	_, err = tx.Exec(`DROP TABLE oak_entries`)
	if err != nil {
		return false, fmt.Errorf("failed to drop oak_entries table: %w", err)
	}

	// Step 2: Migrate taxa table to add integer ID
	// Check if taxa table has data
	var taxaCount int
	err = tx.QueryRow(`SELECT COUNT(*) FROM taxa`).Scan(&taxaCount)
	if err != nil && !strings.Contains(err.Error(), "no such table") {
		return false, fmt.Errorf("failed to count taxa: %w", err)
	}

	if taxaCount > 0 || err == nil {
		// Create new taxa table with integer ID
		_, err = tx.Exec(`
			CREATE TABLE taxa_new (
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
		`)
		if err != nil {
			return false, fmt.Errorf("failed to create taxa_new table: %w", err)
		}

		// Copy data from taxa to taxa_new
		_, err = tx.Exec(`
			INSERT INTO taxa_new (name, level, parent, author, content, content_updated_at, links)
			SELECT name, level, parent, author, content, content_updated_at, links
			FROM taxa
			ORDER BY name, level
		`)
		if err != nil {
			return false, fmt.Errorf("failed to copy data to taxa_new table: %w", err)
		}

		// Drop old taxa table and rename new one
		_, err = tx.Exec(`DROP TABLE taxa`)
		if err != nil {
			return false, fmt.Errorf("failed to drop taxa table: %w", err)
		}

		_, err = tx.Exec(`ALTER TABLE taxa_new RENAME TO taxa`)
		if err != nil {
			return false, fmt.Errorf("failed to rename taxa_new to taxa: %w", err)
		}

		// Recreate indexes on taxa
		_, err = tx.Exec(`CREATE INDEX idx_taxa_level ON taxa(level)`)
		if err != nil {
			return false, fmt.Errorf("failed to create taxa level index: %w", err)
		}
		_, err = tx.Exec(`CREATE INDEX idx_taxa_parent ON taxa(parent)`)
		if err != nil {
			return false, fmt.Errorf("failed to create taxa parent index: %w", err)
		}
	}

	// Step 3: Migrate species_sources to use species_id instead of scientific_name
	// Check if species_sources table exists
	var speciesSourcesExists bool
	err = tx.QueryRow(`SELECT name FROM sqlite_master WHERE type='table' AND name='species_sources'`).Scan(&tableName)
	speciesSourcesExists = (err == nil)

	if speciesSourcesExists {
		// Create new species_sources table with species_id
		_, err = tx.Exec(`
			CREATE TABLE species_sources_new (
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
		`)
		if err != nil {
			return false, fmt.Errorf("failed to create species_sources_new table: %w", err)
		}

		// Copy data from species_sources to species_sources_new, joining with species to get species_id
		_, err = tx.Exec(`
			INSERT INTO species_sources_new (species_id, source_id, local_names, range, growth_habit,
				leaves, flowers, fruits, bark, twigs, buds, hardiness_habitat, miscellaneous, url, is_preferred)
			SELECT s.id, ss.source_id, ss.local_names, ss.range, ss.growth_habit,
				ss.leaves, ss.flowers, ss.fruits, ss.bark, ss.twigs, ss.buds,
				ss.hardiness_habitat, ss.miscellaneous, ss.url, ss.is_preferred
			FROM species_sources ss
			JOIN species s ON ss.scientific_name = s.scientific_name
		`)
		if err != nil {
			return false, fmt.Errorf("failed to copy data to species_sources_new table: %w", err)
		}

		// Drop old species_sources table and rename new one
		_, err = tx.Exec(`DROP TABLE species_sources`)
		if err != nil {
			return false, fmt.Errorf("failed to drop species_sources table: %w", err)
		}

		_, err = tx.Exec(`ALTER TABLE species_sources_new RENAME TO species_sources`)
		if err != nil {
			return false, fmt.Errorf("failed to rename species_sources_new to species_sources: %w", err)
		}

		// Recreate indexes on species_sources
		_, err = tx.Exec(`CREATE INDEX idx_species_sources_species ON species_sources(species_id)`)
		if err != nil {
			return false, fmt.Errorf("failed to create species_sources species index: %w", err)
		}
		_, err = tx.Exec(`CREATE INDEX idx_species_sources_source ON species_sources(source_id)`)
		if err != nil {
			return false, fmt.Errorf("failed to create species_sources source index: %w", err)
		}
	}

	// Commit the migration
	if err := tx.Commit(); err != nil {
		return false, fmt.Errorf("failed to commit migration: %w", err)
	}

	return true, nil
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
		`INSERT INTO taxa (name, level, parent, author, content, content_updated_at, links) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		taxon.Name, string(taxon.Level), taxon.Parent, taxon.Author, taxon.Content, taxon.ContentUpdatedAt, linksJSON,
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
		`UPDATE taxa SET parent = ?, author = ?, content = ?, content_updated_at = ?, links = ? WHERE name = ? AND level = ?`,
		taxon.Parent, taxon.Author, taxon.Content, taxon.ContentUpdatedAt, linksJSON, taxon.Name, string(taxon.Level),
	)
	if err != nil {
		return fmt.Errorf("failed to update taxon: %w", err)
	}
	return nil
}

// GetTaxon gets a taxon by name and level
func (db *Database) GetTaxon(name string, level models.TaxonLevel) (*models.Taxon, error) {
	row := db.conn.QueryRow(
		`SELECT t.id, t.name, t.level, t.parent, t.author, t.content, t.content_updated_at, t.links,
		        (SELECT COUNT(*) FROM species sp WHERE
		            (t.level = 'subgenus' AND sp.subgenus = t.name) OR
		            (t.level = 'section' AND sp.section = t.name) OR
		            (t.level = 'subsection' AND sp.subsection = t.name) OR
		            (t.level = 'complex' AND sp.complex = t.name)
		        ) as species_count
		 FROM taxa t WHERE t.name = ? AND t.level = ?`,
		name, string(level),
	)

	var t models.Taxon
	var levelStr string
	var linksJSON sql.NullString
	err := row.Scan(&t.ID, &t.Name, &levelStr, &t.Parent, &t.Author, &t.Content, &t.ContentUpdatedAt, &linksJSON, &t.SpeciesCount)
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

// GetTaxonByID retrieves a taxon by its integer ID
func (db *Database) GetTaxonByID(id int64) (*models.Taxon, error) {
	row := db.conn.QueryRow(
		`SELECT t.id, t.name, t.level, t.parent, t.author, t.content, t.content_updated_at, t.links,
		        (SELECT COUNT(*) FROM species sp WHERE
		            (t.level = 'subgenus' AND sp.subgenus = t.name) OR
		            (t.level = 'section' AND sp.section = t.name) OR
		            (t.level = 'subsection' AND sp.subsection = t.name) OR
		            (t.level = 'complex' AND sp.complex = t.name)
		        ) as species_count
		 FROM taxa t WHERE t.id = ?`,
		id,
	)

	var t models.Taxon
	var levelStr string
	var linksJSON sql.NullString
	err := row.Scan(&t.ID, &t.Name, &levelStr, &t.Parent, &t.Author, &t.Content, &t.ContentUpdatedAt, &linksJSON, &t.SpeciesCount)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get taxon by ID: %w", err)
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
	baseQuery := `SELECT t.id, t.name, t.level, t.parent, t.author, t.content, t.content_updated_at, t.links,
	                     (SELECT COUNT(*) FROM species sp WHERE
	                         (t.level = 'subgenus' AND sp.subgenus = t.name) OR
	                         (t.level = 'section' AND sp.section = t.name) OR
	                         (t.level = 'subsection' AND sp.subsection = t.name) OR
	                         (t.level = 'complex' AND sp.complex = t.name)
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
		if err := rows.Scan(&t.ID, &t.Name, &levelStr, &t.Parent, &t.Author, &t.Content, &t.ContentUpdatedAt, &linksJSON, &t.SpeciesCount); err != nil {
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
		`SELECT name, level, parent, author, content, content_updated_at, links FROM taxa
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
		if err := rows.Scan(&t.Name, &levelStr, &t.Parent, &t.Author, &t.Content, &t.ContentUpdatedAt, &linksJSON); err != nil {
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

// SaveSpecies saves or updates a complete species entry.
// It also maintains bidirectional parent-child relationships:
// when a hybrid's parents are set/changed, the parents' hybrids lists are updated.
func (db *Database) SaveSpecies(entry *models.Species) error {
	// Start transaction for atomic updates
	tx, err := db.conn.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	// Get existing entry to compare parents (for bidirectional relationship updates)
	existingEntry, err := db.getSpeciesTx(tx, entry.ScientificName)
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
	if err := db.saveSpeciesTx(tx, entry); err != nil {
		return err
	}

	return tx.Commit()
}

// getSpeciesTx gets a species within a transaction
func (db *Database) getSpeciesTx(tx *sql.Tx, scientificName string) (*models.Species, error) {
	row := tx.QueryRow(
		`SELECT id, scientific_name, author, is_hybrid, conservation_status,
		        subgenus, section, subsection, complex,
		        parent1, parent2, hybrids, closely_related_to, subspecies_varieties, synonyms, external_links
		 FROM species WHERE scientific_name = ?`,
		scientificName,
	)

	var entry models.Species
	var isHybrid int
	var hybridsJSON, relatedJSON, subspeciesJSON, synonymsJSON, externalLinksJSON sql.NullString

	if err := row.Scan(
		&entry.ID, &entry.ScientificName, &entry.Author, &isHybrid, &entry.ConservationStatus,
		&entry.Subgenus, &entry.Section, &entry.Subsection, &entry.Complex,
		&entry.Parent1, &entry.Parent2, &hybridsJSON, &relatedJSON, &subspeciesJSON, &synonymsJSON, &externalLinksJSON,
	); err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get species: %w", err)
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
		`SELECT hybrids FROM species WHERE scientific_name = ?`,
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
		`UPDATE species SET hybrids = ? WHERE scientific_name = ?`,
		string(updatedJSON), parentName,
	)
	return err
}

// addHybridToParentTx adds a hybrid to a parent's hybrids list within a transaction
func (db *Database) addHybridToParentTx(tx *sql.Tx, parentName, hybridName string) error {
	// Get parent's current hybrids list
	var hybridsJSON sql.NullString
	err := tx.QueryRow(
		`SELECT hybrids FROM species WHERE scientific_name = ?`,
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
		`UPDATE species SET hybrids = ? WHERE scientific_name = ?`,
		string(updatedJSON), parentName,
	)
	return err
}

// saveSpeciesTx saves a species within a transaction
func (db *Database) saveSpeciesTx(tx *sql.Tx, entry *models.Species) error {
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

	// Use INSERT OR REPLACE, which handles the unique constraint on scientific_name
	// If entry.ID is 0, this is a new entry; otherwise we're updating
	if entry.ID == 0 {
		result, err := tx.Exec(
			`INSERT INTO species (
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
			return fmt.Errorf("failed to insert species: %w", err)
		}
		id, err := result.LastInsertId()
		if err != nil {
			return fmt.Errorf("failed to get last insert id: %w", err)
		}
		entry.ID = id
	} else {
		_, err = tx.Exec(
			`UPDATE species SET
				author = ?, is_hybrid = ?, conservation_status = ?,
				subgenus = ?, section = ?, subsection = ?, complex = ?,
				parent1 = ?, parent2 = ?, hybrids = ?, closely_related_to = ?,
				subspecies_varieties = ?, synonyms = ?, external_links = ?
			WHERE id = ?`,
			entry.Author, isHybrid, entry.ConservationStatus,
			entry.Subgenus, entry.Section, entry.Subsection, entry.Complex,
			entry.Parent1, entry.Parent2, string(hybridsJSON), string(relatedJSON),
			string(subspeciesJSON), string(synonymsJSON), string(externalLinksJSON),
			entry.ID,
		)
		if err != nil {
			return fmt.Errorf("failed to update species: %w", err)
		}
	}

	return nil
}

// GetSpecies gets a species by scientific name
func (db *Database) GetSpecies(scientificName string) (*models.Species, error) {
	row := db.conn.QueryRow(
		`SELECT id, scientific_name, author, is_hybrid, conservation_status,
		        subgenus, section, subsection, complex,
		        parent1, parent2, hybrids, closely_related_to, subspecies_varieties, synonyms, external_links
		 FROM species WHERE scientific_name = ?`,
		scientificName,
	)

	var entry models.Species
	var isHybrid int
	var hybridsJSON, relatedJSON, subspeciesJSON, synonymsJSON, externalLinksJSON sql.NullString

	if err := row.Scan(
		&entry.ID, &entry.ScientificName, &entry.Author, &isHybrid, &entry.ConservationStatus,
		&entry.Subgenus, &entry.Section, &entry.Subsection, &entry.Complex,
		&entry.Parent1, &entry.Parent2, &hybridsJSON, &relatedJSON, &subspeciesJSON, &synonymsJSON, &externalLinksJSON,
	); err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get species: %w", err)
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

// GetSpeciesByID retrieves a species by its integer ID
func (db *Database) GetSpeciesByID(id int64) (*models.Species, error) {
	row := db.conn.QueryRow(
		`SELECT id, scientific_name, author, is_hybrid, conservation_status,
		        subgenus, section, subsection, complex,
		        parent1, parent2, hybrids, closely_related_to, subspecies_varieties, synonyms, external_links
		 FROM species WHERE id = ?`,
		id,
	)

	var entry models.Species
	var isHybrid int
	var hybridsJSON, relatedJSON, subspeciesJSON, synonymsJSON, externalLinksJSON sql.NullString

	if err := row.Scan(
		&entry.ID, &entry.ScientificName, &entry.Author, &isHybrid, &entry.ConservationStatus,
		&entry.Subgenus, &entry.Section, &entry.Subsection, &entry.Complex,
		&entry.Parent1, &entry.Parent2, &hybridsJSON, &relatedJSON, &subspeciesJSON, &synonymsJSON, &externalLinksJSON,
	); err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get species by ID: %w", err)
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

// DeleteSpecies deletes a species
func (db *Database) DeleteSpecies(scientificName string) error {
	_, err := db.conn.Exec(
		`DELETE FROM species WHERE scientific_name = ?`,
		scientificName,
	)
	if err != nil {
		return fmt.Errorf("failed to delete species: %w", err)
	}
	return nil
}

// SearchSpeciesNames searches for species by name pattern
func (db *Database) SearchSpeciesNames(query string) ([]string, error) {
	pattern := "%" + escapeLike(query) + "%"
	rows, err := db.conn.Query(
		`SELECT scientific_name FROM species
		 WHERE scientific_name LIKE ? ESCAPE '\' ORDER BY scientific_name`,
		pattern,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to search species: %w", err)
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

// SpeciesFilter contains filter criteria for listing species
type SpeciesFilter struct {
	Subgenus     *string
	Section      *string
	Subsection   *string
	Complex      *string
	Hybrid       *bool
	SourceID     *int64
	NoSubgenus   bool // Filter for species with NULL subgenus
	NoSection    bool // Filter for species with NULL section
	NoSubsection bool // Filter for species with NULL subsection
	NoComplex    bool // Filter for species with NULL complex
}

// ListSpeciesPaginated returns a paginated list of species with optional filters
func (db *Database) ListSpeciesPaginated(limit, offset int, filter *SpeciesFilter) ([]*models.Species, error) {
	// Base SELECT - use DISTINCT when joining with species_sources
	selectClause := `SELECT id, scientific_name, author, is_hybrid, conservation_status,
		        subgenus, section, subsection, complex,
		        parent1, parent2, hybrids, closely_related_to, subspecies_varieties, synonyms, external_links
		 FROM species`

	var args []interface{}
	var conditions []string
	needsJoin := false

	if filter != nil {
		// Check if we need to join with species_sources
		if filter.SourceID != nil {
			needsJoin = true
			selectClause = `SELECT DISTINCT species.id, species.scientific_name, species.author, species.is_hybrid, species.conservation_status,
				species.subgenus, species.section, species.subsection, species.complex,
				species.parent1, species.parent2, species.hybrids, species.closely_related_to, species.subspecies_varieties, species.synonyms, species.external_links
			 FROM species
			 INNER JOIN species_sources ON species.id = species_sources.species_id`
			conditions = append(conditions, "species_sources.source_id = ?")
			args = append(args, *filter.SourceID)
		}

		if filter.Subgenus != nil {
			if needsJoin {
				conditions = append(conditions, "species.subgenus = ?")
			} else {
				conditions = append(conditions, "subgenus = ?")
			}
			args = append(args, *filter.Subgenus)
		}
		if filter.Section != nil {
			if needsJoin {
				conditions = append(conditions, "species.section = ?")
			} else {
				conditions = append(conditions, "section = ?")
			}
			args = append(args, *filter.Section)
		}
		if filter.Subsection != nil {
			if needsJoin {
				conditions = append(conditions, "species.subsection = ?")
			} else {
				conditions = append(conditions, "subsection = ?")
			}
			args = append(args, *filter.Subsection)
		}
		if filter.Complex != nil {
			if needsJoin {
				conditions = append(conditions, "species.complex = ?")
			} else {
				conditions = append(conditions, "complex = ?")
			}
			args = append(args, *filter.Complex)
		}
		if filter.Hybrid != nil {
			if needsJoin {
				conditions = append(conditions, "species.is_hybrid = ?")
			} else {
				conditions = append(conditions, "is_hybrid = ?")
			}
			if *filter.Hybrid {
				args = append(args, 1)
			} else {
				args = append(args, 0)
			}
		}

		// Handle "no_*" filters for NULL taxonomy levels
		if filter.NoSubgenus {
			if needsJoin {
				conditions = append(conditions, "(species.subgenus IS NULL OR species.subgenus = '')")
			} else {
				conditions = append(conditions, "(subgenus IS NULL OR subgenus = '')")
			}
		}
		if filter.NoSection {
			if needsJoin {
				conditions = append(conditions, "(species.section IS NULL OR species.section = '')")
			} else {
				conditions = append(conditions, "(section IS NULL OR section = '')")
			}
		}
		if filter.NoSubsection {
			if needsJoin {
				conditions = append(conditions, "(species.subsection IS NULL OR species.subsection = '')")
			} else {
				conditions = append(conditions, "(subsection IS NULL OR subsection = '')")
			}
		}
		if filter.NoComplex {
			if needsJoin {
				conditions = append(conditions, "(species.complex IS NULL OR species.complex = '')")
			} else {
				conditions = append(conditions, "(complex IS NULL OR complex = '')")
			}
		}
	}

	query := selectClause
	if len(conditions) > 0 {
		query += " WHERE " + strings.Join(conditions, " AND ")
	}

	if needsJoin {
		query += " ORDER BY species.scientific_name LIMIT ? OFFSET ?"
	} else {
		query += " ORDER BY scientific_name LIMIT ? OFFSET ?"
	}
	args = append(args, limit, offset)

	rows, err := db.conn.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list species: %w", err)
	}
	defer rows.Close()

	return scanSpecies(rows)
}

// CountSpecies returns the total count of species matching the filter
func (db *Database) CountSpecies(filter *SpeciesFilter) (int, error) {
	baseQuery := `SELECT COUNT(*) FROM species`

	var args []interface{}
	var conditions []string
	needsJoin := false

	if filter != nil {
		// Check if we need to join with species_sources
		if filter.SourceID != nil {
			needsJoin = true
			baseQuery = `SELECT COUNT(DISTINCT species.id) FROM species
			 INNER JOIN species_sources ON species.id = species_sources.species_id`
			conditions = append(conditions, "species_sources.source_id = ?")
			args = append(args, *filter.SourceID)
		}

		if filter.Subgenus != nil {
			if needsJoin {
				conditions = append(conditions, "species.subgenus = ?")
			} else {
				conditions = append(conditions, "subgenus = ?")
			}
			args = append(args, *filter.Subgenus)
		}
		if filter.Section != nil {
			if needsJoin {
				conditions = append(conditions, "species.section = ?")
			} else {
				conditions = append(conditions, "section = ?")
			}
			args = append(args, *filter.Section)
		}
		if filter.Subsection != nil {
			if needsJoin {
				conditions = append(conditions, "species.subsection = ?")
			} else {
				conditions = append(conditions, "subsection = ?")
			}
			args = append(args, *filter.Subsection)
		}
		if filter.Complex != nil {
			if needsJoin {
				conditions = append(conditions, "species.complex = ?")
			} else {
				conditions = append(conditions, "complex = ?")
			}
			args = append(args, *filter.Complex)
		}
		if filter.Hybrid != nil {
			if needsJoin {
				conditions = append(conditions, "species.is_hybrid = ?")
			} else {
				conditions = append(conditions, "is_hybrid = ?")
			}
			if *filter.Hybrid {
				args = append(args, 1)
			} else {
				args = append(args, 0)
			}
		}

		// Handle "no_*" filters for NULL taxonomy levels
		if filter.NoSubgenus {
			if needsJoin {
				conditions = append(conditions, "(species.subgenus IS NULL OR species.subgenus = '')")
			} else {
				conditions = append(conditions, "(subgenus IS NULL OR subgenus = '')")
			}
		}
		if filter.NoSection {
			if needsJoin {
				conditions = append(conditions, "(species.section IS NULL OR species.section = '')")
			} else {
				conditions = append(conditions, "(section IS NULL OR section = '')")
			}
		}
		if filter.NoSubsection {
			if needsJoin {
				conditions = append(conditions, "(species.subsection IS NULL OR species.subsection = '')")
			} else {
				conditions = append(conditions, "(subsection IS NULL OR subsection = '')")
			}
		}
		if filter.NoComplex {
			if needsJoin {
				conditions = append(conditions, "(species.complex IS NULL OR species.complex = '')")
			} else {
				conditions = append(conditions, "(complex IS NULL OR complex = '')")
			}
		}
	}

	query := baseQuery
	if len(conditions) > 0 {
		query += " WHERE " + strings.Join(conditions, " AND ")
	}

	var count int
	if err := db.conn.QueryRow(query, args...).Scan(&count); err != nil {
		return 0, fmt.Errorf("failed to count species: %w", err)
	}
	return count, nil
}

// SearchSpeciesFull searches for species by name pattern and returns full entries
func (db *Database) SearchSpeciesFull(query string, limit int) ([]*models.Species, error) {
	pattern := "%" + escapeLike(query) + "%"
	rows, err := db.conn.Query(
		`SELECT id, scientific_name, author, is_hybrid, conservation_status,
		        subgenus, section, subsection, complex,
		        parent1, parent2, hybrids, closely_related_to, subspecies_varieties, synonyms, external_links
		 FROM species
		 WHERE scientific_name LIKE ? ESCAPE '\'
		 ORDER BY scientific_name LIMIT ?`,
		pattern, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to search species: %w", err)
	}
	defer rows.Close()

	return scanSpecies(rows)
}

// SpeciesExists checks if a species exists by scientific name
func (db *Database) SpeciesExists(scientificName string) (bool, error) {
	var count int
	err := db.conn.QueryRow(
		`SELECT COUNT(*) FROM species WHERE scientific_name = ?`,
		scientificName,
	).Scan(&count)
	if err != nil {
		return false, fmt.Errorf("failed to check species existence: %w", err)
	}
	return count > 0, nil
}

// scanSpecies is a helper that scans rows into Species objects
func scanSpecies(rows *sql.Rows) ([]*models.Species, error) {
	var entries []*models.Species
	for rows.Next() {
		var entry models.Species
		var isHybrid int
		var hybridsJSON, relatedJSON, subspeciesJSON, synonymsJSON, externalLinksJSON sql.NullString

		if err := rows.Scan(
			&entry.ID, &entry.ScientificName, &entry.Author, &isHybrid, &entry.ConservationStatus,
			&entry.Subgenus, &entry.Section, &entry.Subsection, &entry.Complex,
			&entry.Parent1, &entry.Parent2, &hybridsJSON, &relatedJSON, &subspeciesJSON, &synonymsJSON, &externalLinksJSON,
		); err != nil {
			return nil, fmt.Errorf("failed to scan species: %w", err)
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

// ListAllSpecies returns all species (for export)
func (db *Database) ListAllSpecies() ([]*models.Species, error) {
	rows, err := db.conn.Query(
		`SELECT id, scientific_name, author, is_hybrid, conservation_status,
		        subgenus, section, subsection, complex,
		        parent1, parent2, hybrids, closely_related_to, subspecies_varieties, synonyms, external_links
		 FROM species ORDER BY scientific_name`,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to list species: %w", err)
	}
	defer rows.Close()

	return scanSpecies(rows)
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

	// First, look up the species_id from the scientific_name
	var speciesID int64
	err = db.conn.QueryRow(`SELECT id FROM species WHERE scientific_name = ?`, ss.ScientificName).Scan(&speciesID)
	if err != nil {
		return fmt.Errorf("failed to find species %s: %w", ss.ScientificName, err)
	}

	result, err := db.conn.Exec(
		`INSERT INTO species_sources (
			species_id, source_id, local_names, range, growth_habit,
			leaves, flowers, fruits, bark, twigs, buds, hardiness_habitat,
			miscellaneous, url, is_preferred
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(species_id, source_id) DO UPDATE SET
			local_names = excluded.local_names,
			range = excluded.range,
			growth_habit = excluded.growth_habit,
			leaves = excluded.leaves,
			flowers = excluded.flowers,
			fruits = excluded.fruits,
			bark = excluded.bark,
			twigs = excluded.twigs,
			buds = excluded.buds,
			hardiness_habitat = excluded.hardiness_habitat,
			miscellaneous = excluded.miscellaneous,
			url = excluded.url,
			is_preferred = excluded.is_preferred`,
		speciesID, ss.SourceID, string(localNamesJSON), ss.Range, ss.GrowthHabit,
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
		`SELECT ss.id, sp.scientific_name, ss.source_id, ss.local_names, ss.range, ss.growth_habit,
		        ss.leaves, ss.flowers, ss.fruits, ss.bark, ss.twigs, ss.buds, ss.hardiness_habitat,
		        ss.miscellaneous, ss.url, ss.is_preferred
		 FROM species_sources ss
		 JOIN species sp ON ss.species_id = sp.id
		 WHERE sp.scientific_name = ? ORDER BY ss.is_preferred DESC, ss.source_id`,
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
		`SELECT ss.id, sp.scientific_name, ss.source_id, ss.local_names, ss.range, ss.growth_habit,
		        ss.leaves, ss.flowers, ss.fruits, ss.bark, ss.twigs, ss.buds, ss.hardiness_habitat,
		        ss.miscellaneous, ss.url, ss.is_preferred
		 FROM species_sources ss
		 JOIN species sp ON ss.species_id = sp.id
		 WHERE sp.scientific_name = ? AND ss.source_id = ?`,
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
		`SELECT ss.id, sp.scientific_name, ss.source_id, ss.local_names, ss.range, ss.growth_habit,
		        ss.leaves, ss.flowers, ss.fruits, ss.bark, ss.twigs, ss.buds, ss.hardiness_habitat,
		        ss.miscellaneous, ss.url, ss.is_preferred
		 FROM species_sources ss
		 JOIN species sp ON ss.species_id = sp.id
		 WHERE sp.scientific_name = ? ORDER BY ss.is_preferred DESC LIMIT 1`,
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
		`SELECT ss.id, sp.scientific_name, ss.source_id, ss.local_names, ss.range, ss.growth_habit,
		        ss.leaves, ss.flowers, ss.fruits, ss.bark, ss.twigs, ss.buds, ss.hardiness_habitat,
		        ss.miscellaneous, ss.url, ss.is_preferred
		 FROM species_sources ss
		 JOIN species sp ON ss.species_id = sp.id
		 ORDER BY sp.scientific_name, ss.is_preferred DESC`,
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
		`DELETE FROM species_sources
		 WHERE species_id = (SELECT id FROM species WHERE scientific_name = ?)
		 AND source_id = ?`,
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

// GetSpeciesWithSources returns a species with all its source data embedded
// Sources are ordered by is_preferred DESC, source_id ASC
func (db *Database) GetSpeciesWithSources(scientificName string) (*models.SpeciesWithSources, error) {
	// Get the species entry first
	entry, err := db.GetSpecies(scientificName)
	if err != nil {
		return nil, err
	}
	if entry == nil {
		return nil, nil
	}

	// Get sources with source metadata via join
	rows, err := db.conn.Query(
		`SELECT ss.id, sp.scientific_name, ss.source_id, ss.local_names, ss.range, ss.growth_habit,
		        ss.leaves, ss.flowers, ss.fruits, ss.bark, ss.twigs, ss.buds, ss.hardiness_habitat,
		        ss.miscellaneous, ss.url, ss.is_preferred,
		        s.name, s.url
		 FROM species_sources ss
		 JOIN species sp ON ss.species_id = sp.id
		 JOIN sources s ON ss.source_id = s.id
		 WHERE sp.scientific_name = ?
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
		Species: *entry,
		Sources: sources,
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
	if err := db.conn.QueryRow(`SELECT COUNT(*) FROM species WHERE is_hybrid = 0`).Scan(&stats.SpeciesCount); err != nil {
		return nil, fmt.Errorf("failed to count species: %w", err)
	}

	// Count hybrids
	if err := db.conn.QueryRow(`SELECT COUNT(*) FROM species WHERE is_hybrid = 1`).Scan(&stats.HybridCount); err != nil {
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
		`SELECT scientific_name FROM species
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
		Species: []models.Species{},
		Taxa:    []models.Taxon{},
		Sources: []models.Source{},
	}

	pattern := "%" + escapeLike(query) + "%"

	// Search species: scientific_name, author, synonyms (JSON), local_names (via species_sources)
	speciesRows, err := db.conn.Query(
		`SELECT DISTINCT sp.id, sp.scientific_name, sp.author, sp.is_hybrid, sp.conservation_status,
		        sp.subgenus, sp.section, sp.subsection, sp.complex,
		        sp.parent1, sp.parent2, sp.hybrids, sp.closely_related_to, sp.subspecies_varieties, sp.synonyms, sp.external_links
		 FROM species sp
		 LEFT JOIN species_sources ss ON sp.id = ss.species_id
		 WHERE sp.scientific_name LIKE ? ESCAPE '\'
		    OR sp.author LIKE ? ESCAPE '\'
		    OR sp.synonyms LIKE ? ESCAPE '\'
		    OR ss.local_names LIKE ? ESCAPE '\'
		 ORDER BY sp.scientific_name LIMIT ?`,
		pattern, pattern, pattern, pattern, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to search species: %w", err)
	}
	defer speciesRows.Close()

	entries, err := scanSpecies(speciesRows)
	if err != nil {
		return nil, err
	}
	for _, e := range entries {
		result.Species = append(result.Species, *e)
	}

	// Search taxa by name
	taxaRows, err := db.conn.Query(
		`SELECT t.id, t.name, t.level, t.parent, t.author, t.content, t.content_updated_at, t.links,
		        (SELECT COUNT(*) FROM species sp WHERE
		            (t.level = 'subgenus' AND sp.subgenus = t.name) OR
		            (t.level = 'section' AND sp.section = t.name) OR
		            (t.level = 'subsection' AND sp.subsection = t.name) OR
		            (t.level = 'complex' AND sp.complex = t.name)
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
		if err := taxaRows.Scan(&t.ID, &t.Name, &levelStr, &t.Parent, &t.Author, &t.Content, &t.ContentUpdatedAt, &linksJSON, &t.SpeciesCount); err != nil {
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

// GenerateSlug creates a URL-friendly slug from a title.
// Converts to lowercase, replaces spaces with hyphens, removes special chars.
func GenerateSlug(title string) string {
	slug := strings.ToLower(title)
	// Replace spaces and underscores with hyphens
	slug = strings.ReplaceAll(slug, " ", "-")
	slug = strings.ReplaceAll(slug, "_", "-")
	// Remove characters that aren't alphanumeric or hyphens
	var result strings.Builder
	for _, r := range slug {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' {
			result.WriteRune(r)
		}
	}
	slug = result.String()
	// Collapse multiple hyphens into one
	for strings.Contains(slug, "--") {
		slug = strings.ReplaceAll(slug, "--", "-")
	}
	// Trim leading/trailing hyphens
	slug = strings.Trim(slug, "-")
	return slug
}

// GenerateUniqueSlug creates a unique slug, appending -2, -3, etc. if collision
func (db *Database) GenerateUniqueSlug(title string, excludeID int64) (string, error) {
	baseSlug := GenerateSlug(title)
	if baseSlug == "" {
		baseSlug = "article"
	}

	slug := baseSlug
	suffix := 1

	for {
		var count int
		var err error
		if excludeID > 0 {
			// When updating, exclude the current article from collision check
			err = db.conn.QueryRow(
				`SELECT COUNT(*) FROM articles WHERE slug = ? AND id != ?`,
				slug, excludeID,
			).Scan(&count)
		} else {
			err = db.conn.QueryRow(
				`SELECT COUNT(*) FROM articles WHERE slug = ?`,
				slug,
			).Scan(&count)
		}
		if err != nil {
			return "", fmt.Errorf("failed to check slug uniqueness: %w", err)
		}

		if count == 0 {
			return slug, nil
		}

		suffix++
		slug = fmt.Sprintf("%s-%d", baseSlug, suffix)
	}
}

// ArticleListParams contains optional filters for listing articles
type ArticleListParams struct {
	Tag         *string
	IsPublished *bool
}

// InsertArticle inserts a new article and returns the created article
func (db *Database) InsertArticle(article *models.Article) error {
	// Generate unique slug from title
	slug, err := db.GenerateUniqueSlug(article.Title, 0)
	if err != nil {
		return err
	}
	article.Slug = slug

	// Marshal tags to JSON
	tagsJSON, err := json.Marshal(article.Tags)
	if err != nil {
		return fmt.Errorf("failed to marshal tags: %w", err)
	}

	isPublished := 0
	if article.IsPublished {
		isPublished = 1
	}

	result, err := db.conn.Exec(
		`INSERT INTO articles (slug, title, author, content, tags, is_published, created_at, updated_at, published_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		article.Slug, article.Title, article.Author, article.Content, string(tagsJSON),
		isPublished, article.CreatedAt, article.UpdatedAt, article.PublishedAt,
	)
	if err != nil {
		return fmt.Errorf("failed to insert article: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return fmt.Errorf("failed to get last insert id: %w", err)
	}
	article.ID = id

	return nil
}

// GetArticle gets an article by slug
func (db *Database) GetArticle(slug string) (*models.Article, error) {
	row := db.conn.QueryRow(
		`SELECT id, slug, title, author, content, tags, is_published, created_at, updated_at, published_at
		 FROM articles WHERE slug = ?`,
		slug,
	)

	return scanArticle(row)
}

// GetArticleByID gets an article by ID
func (db *Database) GetArticleByID(id int64) (*models.Article, error) {
	row := db.conn.QueryRow(
		`SELECT id, slug, title, author, content, tags, is_published, created_at, updated_at, published_at
		 FROM articles WHERE id = ?`,
		id,
	)

	return scanArticle(row)
}

// scanArticle scans a single article row
func scanArticle(row *sql.Row) (*models.Article, error) {
	var a models.Article
	var tagsJSON sql.NullString
	var isPublished int

	err := row.Scan(
		&a.ID, &a.Slug, &a.Title, &a.Author, &a.Content, &tagsJSON,
		&isPublished, &a.CreatedAt, &a.UpdatedAt, &a.PublishedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get article: %w", err)
	}

	a.IsPublished = isPublished != 0
	if tagsJSON.Valid && tagsJSON.String != "" {
		if err := json.Unmarshal([]byte(tagsJSON.String), &a.Tags); err != nil {
			return nil, fmt.Errorf("failed to unmarshal tags: %w", err)
		}
	}
	if a.Tags == nil {
		a.Tags = []string{}
	}

	return &a, nil
}

// UpdateArticle updates an existing article
func (db *Database) UpdateArticle(article *models.Article) error {
	// Check if title changed and regenerate slug if needed
	existing, err := db.GetArticleByID(article.ID)
	if err != nil {
		return err
	}
	if existing == nil {
		return fmt.Errorf("article not found: %d", article.ID)
	}

	// If title changed, generate a new unique slug
	if article.Title != existing.Title {
		slug, err := db.GenerateUniqueSlug(article.Title, article.ID)
		if err != nil {
			return err
		}
		article.Slug = slug
	}

	// Marshal tags to JSON
	tagsJSON, err := json.Marshal(article.Tags)
	if err != nil {
		return fmt.Errorf("failed to marshal tags: %w", err)
	}

	isPublished := 0
	if article.IsPublished {
		isPublished = 1
	}

	_, err = db.conn.Exec(
		`UPDATE articles SET slug = ?, title = ?, author = ?, content = ?, tags = ?,
		 is_published = ?, updated_at = ?, published_at = ?
		 WHERE id = ?`,
		article.Slug, article.Title, article.Author, article.Content, string(tagsJSON),
		isPublished, article.UpdatedAt, article.PublishedAt, article.ID,
	)
	if err != nil {
		return fmt.Errorf("failed to update article: %w", err)
	}

	return nil
}

// DeleteArticle deletes an article by slug
func (db *Database) DeleteArticle(slug string) error {
	result, err := db.conn.Exec(`DELETE FROM articles WHERE slug = ?`, slug)
	if err != nil {
		return fmt.Errorf("failed to delete article: %w", err)
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("article not found: %s", slug)
	}
	return nil
}

// ListArticles lists articles with optional filters
func (db *Database) ListArticles(params *ArticleListParams) ([]*models.Article, error) {
	var args []interface{}
	var conditions []string

	baseQuery := `SELECT id, slug, title, author, content, tags, is_published, created_at, updated_at, published_at
	              FROM articles`

	if params != nil {
		if params.IsPublished != nil {
			conditions = append(conditions, "is_published = ?")
			if *params.IsPublished {
				args = append(args, 1)
			} else {
				args = append(args, 0)
			}
		}
		if params.Tag != nil && *params.Tag != "" {
			// Search for tag in JSON array
			// Using LIKE for simplicity with JSON array stored as string
			conditions = append(conditions, `tags LIKE ?`)
			args = append(args, "%\""+escapeLike(*params.Tag)+"\"%")
		}
	}

	query := baseQuery
	if len(conditions) > 0 {
		query += " WHERE " + strings.Join(conditions, " AND ")
	}
	query += " ORDER BY updated_at DESC"

	rows, err := db.conn.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list articles: %w", err)
	}
	defer rows.Close()

	var articles []*models.Article
	for rows.Next() {
		var a models.Article
		var tagsJSON sql.NullString
		var isPublished int

		if err := rows.Scan(
			&a.ID, &a.Slug, &a.Title, &a.Author, &a.Content, &tagsJSON,
			&isPublished, &a.CreatedAt, &a.UpdatedAt, &a.PublishedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan article: %w", err)
		}

		a.IsPublished = isPublished != 0
		if tagsJSON.Valid && tagsJSON.String != "" {
			if err := json.Unmarshal([]byte(tagsJSON.String), &a.Tags); err != nil {
				return nil, fmt.Errorf("failed to unmarshal tags: %w", err)
			}
		}
		if a.Tags == nil {
			a.Tags = []string{}
		}

		articles = append(articles, &a)
	}

	return articles, rows.Err()
}

// ListPublishedArticles returns only published articles (convenience method)
func (db *Database) ListPublishedArticles() ([]*models.Article, error) {
	published := true
	return db.ListArticles(&ArticleListParams{IsPublished: &published})
}

// ArticleTagCount represents a tag with its usage count
type ArticleTagCount struct {
	Tag   string `json:"tag"`
	Count int    `json:"count"`
}

// ListArticleTags returns all unique tags with counts
func (db *Database) ListArticleTags(publishedOnly bool) ([]ArticleTagCount, error) {
	query := `SELECT tags FROM articles`
	if publishedOnly {
		query += " WHERE is_published = 1"
	}

	rows, err := db.conn.Query(query)
	if err != nil {
		return nil, fmt.Errorf("failed to query article tags: %w", err)
	}
	defer rows.Close()

	// Count tags across all articles
	tagCounts := make(map[string]int)
	for rows.Next() {
		var tagsJSON sql.NullString
		if err := rows.Scan(&tagsJSON); err != nil {
			return nil, fmt.Errorf("failed to scan tags: %w", err)
		}

		if tagsJSON.Valid && tagsJSON.String != "" {
			var tags []string
			if err := json.Unmarshal([]byte(tagsJSON.String), &tags); err != nil {
				continue // Skip malformed tags
			}
			for _, tag := range tags {
				tagCounts[tag]++
			}
		}
	}

	// Convert to slice and sort by count descending
	var result []ArticleTagCount
	for tag, count := range tagCounts {
		result = append(result, ArticleTagCount{Tag: tag, Count: count})
	}

	// Sort by count descending, then alphabetically
	for i := 0; i < len(result); i++ {
		for j := i + 1; j < len(result); j++ {
			if result[j].Count > result[i].Count ||
				(result[j].Count == result[i].Count && result[j].Tag < result[i].Tag) {
				result[i], result[j] = result[j], result[i]
			}
		}
	}

	return result, rows.Err()
}
