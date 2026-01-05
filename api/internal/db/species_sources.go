package db

import (
	"database/sql"
	"encoding/json"
	"fmt"

	"github.com/jeff/oaks/api/internal/models"
)

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
