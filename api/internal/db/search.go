package db

import (
	"database/sql"
	"encoding/json"
	"fmt"

	"github.com/jeff/oaks/api/internal/models"
)

// Stats contains aggregate counts for the database
type Stats struct {
	SpeciesCount int `json:"species_count"`
	HybridCount  int `json:"hybrid_count"`
	TaxaCount    int `json:"taxa_count"`
	SourceCount  int `json:"source_count"`
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

	// Compute ancestry paths for taxa results
	if len(result.Taxa) > 0 {
		if err := db.computeTaxaPaths(result.Taxa); err != nil {
			return nil, fmt.Errorf("failed to compute taxa paths: %w", err)
		}
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

// taxonKey creates a composite key for taxon lookup (name + level)
type taxonKey struct {
	name  string
	level string
}

// taxonInfo stores parent info for path computation
type taxonInfo struct {
	parent      *string
	parentLevel string
}

// computeTaxaPaths computes the full ancestry path for each taxon in the slice.
// The path is an array like ["Quercus", "Lobatae", "Phellos"] for URL construction.
func (db *Database) computeTaxaPaths(taxa []models.Taxon) error {
	// Build a lookup map of all taxa by (name, level) -> parent info
	// We need this to walk up the parent chain correctly when there are
	// multiple taxa with the same name at different levels (e.g., "Quercus")
	rows, err := db.conn.Query(`SELECT name, level, parent FROM taxa`)
	if err != nil {
		return fmt.Errorf("failed to fetch taxa for path computation: %w", err)
	}
	defer rows.Close()

	// Map from (name, level) to parent info
	taxaMap := make(map[taxonKey]taxonInfo)
	for rows.Next() {
		var name, level string
		var parent *string
		if err := rows.Scan(&name, &level, &parent); err != nil {
			return fmt.Errorf("failed to scan taxon: %w", err)
		}
		taxaMap[taxonKey{name, level}] = taxonInfo{
			parent:      parent,
			parentLevel: getParentLevel(level),
		}
	}
	if err := rows.Err(); err != nil {
		return err
	}

	// Compute path for each taxon by walking up the parent chain
	for i := range taxa {
		path := []string{}
		currentName := taxa[i].Name
		currentLevel := string(taxa[i].Level)

		// Walk up to ancestors, building path in reverse
		// Use a visited set to prevent infinite loops
		visited := make(map[taxonKey]bool)
		for {
			key := taxonKey{currentName, currentLevel}
			if visited[key] {
				break // Cycle detected
			}
			visited[key] = true

			path = append([]string{currentName}, path...) // prepend

			info, exists := taxaMap[key]
			if !exists || info.parent == nil {
				break
			}
			currentName = *info.parent
			currentLevel = info.parentLevel
		}

		taxa[i].Path = path
	}

	return nil
}

// getParentLevel returns the parent level for a given taxon level
func getParentLevel(level string) string {
	switch level {
	case "complex":
		return "subsection"
	case "subsection":
		return "section"
	case "section":
		return "subgenus"
	case "subgenus":
		return "" // No parent level
	default:
		return ""
	}
}

// SpeciesReference represents a species that references another species
type SpeciesReference struct {
	ScientificName string `json:"scientific_name"`
	ReferenceType  string `json:"reference_type"` // parent1, parent2, hybrids, closely_related_to
}

// GetSpeciesReferences returns all species that reference the given name
// in parent1, parent2, hybrids, or closely_related_to fields
func (db *Database) GetSpeciesReferences(name string) ([]SpeciesReference, error) {
	// Search string fields (parent1, parent2) with exact match
	// and JSON arrays (hybrids, closely_related_to) with LIKE pattern
	// The JSON pattern matches "name" in the array to avoid partial matches
	jsonPattern := "%\"" + escapeLike(name) + "\"%"

	rows, err := db.conn.Query(
		`SELECT scientific_name,
		        CASE
		            WHEN parent1 = ? THEN 'parent1'
		            WHEN parent2 = ? THEN 'parent2'
		            WHEN hybrids LIKE ? ESCAPE '\' THEN 'hybrids'
		            WHEN closely_related_to LIKE ? ESCAPE '\' THEN 'closely_related_to'
		        END as reference_type
		 FROM species
		 WHERE parent1 = ? OR parent2 = ? OR hybrids LIKE ? ESCAPE '\' OR closely_related_to LIKE ? ESCAPE '\'
		 ORDER BY scientific_name`,
		name, name, jsonPattern, jsonPattern,
		name, name, jsonPattern, jsonPattern,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get species references: %w", err)
	}
	defer rows.Close()

	var refs []SpeciesReference
	for rows.Next() {
		var ref SpeciesReference
		if err := rows.Scan(&ref.ScientificName, &ref.ReferenceType); err != nil {
			return nil, fmt.Errorf("failed to scan species reference: %w", err)
		}
		refs = append(refs, ref)
	}

	if refs == nil {
		refs = []SpeciesReference{}
	}

	return refs, rows.Err()
}
