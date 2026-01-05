package db

import (
	"database/sql"
	"os"
	"path/filepath"
	"testing"

	_ "github.com/mattn/go-sqlite3" // SQLite driver
)

// testDB creates a temporary database for testing
func testDB(t *testing.T) (*Database, func()) { //nolint:gocritic // unnamedResult is fine for test helpers
	t.Helper()

	// Create temp file for SQLite
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	db, err := New(dbPath)
	if err != nil {
		t.Fatalf("failed to create test database: %v", err)
	}

	cleanup := func() {
		db.Close()
		os.Remove(dbPath)
	}

	return db, cleanup
}

func TestNew(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	if db == nil {
		t.Fatal("expected non-nil database")
	}
	if db.conn == nil {
		t.Fatal("expected non-nil connection")
	}
}

func TestNewWithInvalidPath(t *testing.T) {
	_, err := New("/nonexistent/path/to/db.sqlite")
	if err == nil {
		t.Fatal("expected error for invalid path")
	}
}

func TestBeginTx(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	tx, err := db.BeginTx()
	if err != nil {
		t.Fatalf("BeginTx failed: %v", err)
	}
	if tx == nil {
		t.Fatal("expected non-nil transaction")
	}

	// Rollback to clean up
	tx.Rollback()
}

// createOldSchemaDB creates a database with the old schema (oak_entries table, no species table)
// This simulates opening an existing database that needs migration
func createOldSchemaDB(t *testing.T) (*Database, func()) {
	t.Helper()

	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test_old_schema.db")

	// Open raw connection to create old schema
	conn, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		t.Fatalf("failed to open database: %v", err)
	}

	// Create old schema manually (bypass initializeSchema)
	oldSchemaStatements := []string{
		`CREATE TABLE taxa (
			name TEXT NOT NULL,
			level TEXT NOT NULL CHECK(level IN ('subgenus', 'section', 'subsection', 'complex')),
			parent TEXT,
			author TEXT,
			content TEXT,
			content_updated_at TEXT,
			links TEXT,
			PRIMARY KEY (name, level)
		)`,
		`CREATE TABLE sources (
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
		`CREATE TABLE oak_entries (
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
		`CREATE TABLE species_sources (
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
		`CREATE TABLE import_metadata (
			key TEXT PRIMARY KEY,
			value TEXT
		)`,
	}

	for _, stmt := range oldSchemaStatements {
		if _, err := conn.Exec(stmt); err != nil {
			conn.Close()
			t.Fatalf("failed to create old schema: %v", err)
		}
	}

	conn.Close()

	// Now open with the Database wrapper which will run migration
	db, err := New(dbPath)
	if err != nil {
		t.Fatalf("failed to open database after creating old schema: %v", err)
	}

	cleanup := func() {
		db.Close()
		os.Remove(dbPath)
	}

	return db, cleanup
}

func TestFreshDatabaseSchema(t *testing.T) {
	// Fresh database should use new schema with species table and integer IDs
	db, cleanup := testDB(t)
	defer cleanup()

	var tableName string

	// species table should exist (fresh DBs use new schema)
	err := db.conn.QueryRow(`SELECT name FROM sqlite_master WHERE type='table' AND name='species'`).Scan(&tableName)
	if err != nil {
		t.Fatalf("fresh database should have species table: %v", err)
	}

	// oak_entries table should NOT exist (fresh DBs use new schema)
	err = db.conn.QueryRow(`SELECT name FROM sqlite_master WHERE type='table' AND name='oak_entries'`).Scan(&tableName)
	if err == nil {
		t.Fatal("fresh database should NOT have oak_entries table (old schema)")
	}

	// species table should have id column (integer primary key)
	var cid int
	var name, typ string
	var notnull, pk int
	var dfltValue interface{}
	err = db.conn.QueryRow(`PRAGMA table_info(species)`).Scan(&cid, &name, &typ, &notnull, &dfltValue, &pk)
	if err != nil {
		t.Fatalf("failed to get species table info: %v", err)
	}
	if name != "id" || pk != 1 {
		t.Fatalf("species table first column should be 'id' primary key, got %s (pk=%d)", name, pk)
	}
}

// strPtr is a helper to create a string pointer
func strPtr(s string) *string {
	return &s
}
