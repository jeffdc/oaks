package db

import (
	"database/sql"
	"fmt"
)

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
