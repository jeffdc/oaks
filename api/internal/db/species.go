package db

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/jeff/oaks/api/internal/models"
)

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

// SaveSpecies saves or updates a complete species entry.
// It also maintains bidirectional parent-child relationships:
// when a hybrid's parents are set/changed, the parents' hybrids lists are updated.
func (db *Database) SaveSpecies(entry *models.Species) error {
	// Start transaction for atomic updates
	tx, err := db.conn.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

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
				scientific_name = ?, author = ?, is_hybrid = ?, conservation_status = ?,
				subgenus = ?, section = ?, subsection = ?, complex = ?,
				parent1 = ?, parent2 = ?, hybrids = ?, closely_related_to = ?,
				subspecies_varieties = ?, synonyms = ?, external_links = ?
			WHERE id = ?`,
			entry.ScientificName, entry.Author, isHybrid, entry.ConservationStatus,
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
