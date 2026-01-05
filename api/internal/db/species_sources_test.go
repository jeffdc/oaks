package db

import (
	"testing"

	"github.com/jeff/oaks/api/internal/models"
)

func TestSaveSpeciesSourcePreservesID(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create a species
	entry := &models.Species{
		ScientificName:      "alba",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	if err := db.SaveSpecies(entry); err != nil {
		t.Fatalf("SaveSpecies failed: %v", err)
	}

	// Create a source
	source := &models.Source{
		SourceType:  "website",
		Name:        "Test Source",
		Description: nil,
	}
	sourceID, err := db.InsertSource(source)
	if err != nil {
		t.Fatalf("InsertSource failed: %v", err)
	}

	// Create a species source
	ss := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       sourceID,
		LocalNames:     []string{"white oak"},
		Range:          strPtr("Eastern North America"),
		IsPreferred:    true,
	}
	if err := db.SaveSpeciesSource(ss); err != nil {
		t.Fatalf("SaveSpeciesSource failed: %v", err)
	}

	// Get the original ID
	originalID := ss.ID
	if originalID == 0 {
		t.Fatal("expected non-zero ID after first save")
	}

	// Update the species source (same species + source combination)
	ss.LocalNames = []string{"white oak", "eastern white oak"}
	ss.Range = strPtr("Updated range")
	if err := db.SaveSpeciesSource(ss); err != nil {
		t.Fatalf("SaveSpeciesSource update failed: %v", err)
	}

	// Verify the ID is preserved (not a new auto-incremented ID)
	// With ON CONFLICT DO UPDATE, the ID should remain the same
	sources, err := db.GetSpeciesSources("alba")
	if err != nil {
		t.Fatalf("GetSpeciesSources failed: %v", err)
	}
	if len(sources) != 1 {
		t.Fatalf("expected 1 source, got %d", len(sources))
	}
	if sources[0].ID != originalID {
		t.Errorf("ID changed from %d to %d after update (INSERT OR REPLACE bug)", originalID, sources[0].ID)
	}

	// Verify the data was updated
	if len(sources[0].LocalNames) != 2 {
		t.Errorf("LocalNames len = %d, want 2", len(sources[0].LocalNames))
	}
	if *sources[0].Range != "Updated range" {
		t.Errorf("Range = %q, want 'Updated range'", *sources[0].Range)
	}
}
