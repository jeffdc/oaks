package db

import (
	"database/sql"
	"fmt"

	"github.com/jeff/oaks/api/internal/models"
)

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
