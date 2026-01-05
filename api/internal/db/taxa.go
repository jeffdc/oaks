package db

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/jeff/oaks/api/internal/models"
)

// TaxaListParams contains optional filters for listing taxa
type TaxaListParams struct {
	Level  *models.TaxonLevel
	Parent *string
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
