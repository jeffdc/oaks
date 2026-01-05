package db

import (
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
	_ = tx.Rollback()
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
