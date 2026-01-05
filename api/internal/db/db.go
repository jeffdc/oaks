package db

import (
	"database/sql"
	_ "embed"
	"fmt"
	"strings"

	_ "github.com/mattn/go-sqlite3" // SQLite driver
)

//go:embed schema/schema.sql
var schemaSQL string

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

// BeginTx starts a transaction for bulk operations
func (db *Database) BeginTx() (*sql.Tx, error) {
	return db.conn.Begin()
}

func (db *Database) initializeSchema() error {
	// Split the schema SQL into individual statements
	// SQLite requires executing statements one at a time
	statements := strings.Split(schemaSQL, ";")
	for _, stmt := range statements {
		// Remove comment lines from the statement
		var cleanedLines []string
		for _, line := range strings.Split(stmt, "\n") {
			trimmedLine := strings.TrimSpace(line)
			if trimmedLine != "" && !strings.HasPrefix(trimmedLine, "--") {
				cleanedLines = append(cleanedLines, line)
			}
		}
		cleanedStmt := strings.TrimSpace(strings.Join(cleanedLines, "\n"))
		if cleanedStmt == "" {
			continue
		}
		if _, err := db.conn.Exec(cleanedStmt); err != nil {
			return fmt.Errorf("failed to execute schema statement: %w", err)
		}
	}
	return nil
}

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
