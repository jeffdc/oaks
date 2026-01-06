package db

import (
	"testing"

	"github.com/jeff/oaks/api/internal/models"
)

// createTestSpeciesAndSource is a helper to set up a species and source for testing
func createTestSpeciesAndSource(t *testing.T, db *Database) (int64, int64) {
	t.Helper()

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
		SourceType: "website",
		Name:       "Test Source",
	}
	sourceID, err := db.InsertSource(source)
	if err != nil {
		t.Fatalf("InsertSource failed: %v", err)
	}

	return entry.ID, sourceID
}

func TestSaveSpeciesSourcePreservesID(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	_, sourceID := createTestSpeciesAndSource(t, db)

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

func TestGetSpeciesSources(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	_, sourceID := createTestSpeciesAndSource(t, db)

	// Create another source
	source2 := &models.Source{SourceType: "book", Name: "Book Source"}
	sourceID2, _ := db.InsertSource(source2)

	// Create two species sources
	ss1 := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       sourceID,
		LocalNames:     []string{"white oak"},
		IsPreferred:    true,
	}
	ss2 := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       sourceID2,
		LocalNames:     []string{"eastern white oak"},
		IsPreferred:    false,
	}

	if err := db.SaveSpeciesSource(ss1); err != nil {
		t.Fatalf("SaveSpeciesSource 1 failed: %v", err)
	}
	if err := db.SaveSpeciesSource(ss2); err != nil {
		t.Fatalf("SaveSpeciesSource 2 failed: %v", err)
	}

	// Get all sources for species
	sources, err := db.GetSpeciesSources("alba")
	if err != nil {
		t.Fatalf("GetSpeciesSources failed: %v", err)
	}
	if len(sources) != 2 {
		t.Errorf("expected 2 sources, got %d", len(sources))
	}

	// Preferred should come first
	if !sources[0].IsPreferred {
		t.Error("first source should be preferred")
	}
}

func TestGetSpeciesSourcesEmpty(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	createTestSpeciesAndSource(t, db)

	// Get sources for species with no sources
	sources, err := db.GetSpeciesSources("alba")
	if err != nil {
		t.Fatalf("GetSpeciesSources failed: %v", err)
	}
	if sources != nil && len(sources) != 0 {
		t.Errorf("expected 0 sources, got %d", len(sources))
	}
}

func TestGetSpeciesSourceBySourceID(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	_, sourceID := createTestSpeciesAndSource(t, db)

	// Create a species source
	ss := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       sourceID,
		LocalNames:     []string{"white oak"},
		IsPreferred:    true,
	}
	ss.Range = strPtr("Eastern North America")
	if err := db.SaveSpeciesSource(ss); err != nil {
		t.Fatalf("SaveSpeciesSource failed: %v", err)
	}

	// Get by specific source ID
	result, err := db.GetSpeciesSourceBySourceID("alba", sourceID)
	if err != nil {
		t.Fatalf("GetSpeciesSourceBySourceID failed: %v", err)
	}
	if result == nil {
		t.Fatal("expected non-nil result")
	}
	if result.SourceID != sourceID {
		t.Errorf("expected source ID %d, got %d", sourceID, result.SourceID)
	}
	if len(result.LocalNames) != 1 {
		t.Errorf("expected 1 local name, got %d", len(result.LocalNames))
	}
}

func TestGetSpeciesSourceBySourceIDNotFound(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	createTestSpeciesAndSource(t, db)

	result, err := db.GetSpeciesSourceBySourceID("alba", 99999)
	if err != nil {
		t.Fatalf("GetSpeciesSourceBySourceID failed: %v", err)
	}
	if result != nil {
		t.Errorf("expected nil for non-existent source ID, got %+v", result)
	}
}

func TestGetPreferredSpeciesSource(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	_, sourceID := createTestSpeciesAndSource(t, db)

	// Create another source
	source2 := &models.Source{SourceType: "book", Name: "Book Source"}
	sourceID2, _ := db.InsertSource(source2)

	// Create two species sources, second one is preferred
	ss1 := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       sourceID,
		LocalNames:     []string{"white oak"},
		IsPreferred:    false,
	}
	ss2 := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       sourceID2,
		LocalNames:     []string{"eastern white oak"},
		IsPreferred:    true,
	}

	if err := db.SaveSpeciesSource(ss1); err != nil {
		t.Fatalf("SaveSpeciesSource 1 failed: %v", err)
	}
	if err := db.SaveSpeciesSource(ss2); err != nil {
		t.Fatalf("SaveSpeciesSource 2 failed: %v", err)
	}

	// Get preferred source
	result, err := db.GetPreferredSpeciesSource("alba")
	if err != nil {
		t.Fatalf("GetPreferredSpeciesSource failed: %v", err)
	}
	if result == nil {
		t.Fatal("expected non-nil result")
	}
	if !result.IsPreferred {
		t.Error("expected preferred source")
	}
	if result.SourceID != sourceID2 {
		t.Errorf("expected source ID %d (preferred), got %d", sourceID2, result.SourceID)
	}
}

func TestGetPreferredSpeciesSourceNotFound(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	createTestSpeciesAndSource(t, db)

	result, err := db.GetPreferredSpeciesSource("alba")
	if err != nil {
		t.Fatalf("GetPreferredSpeciesSource failed: %v", err)
	}
	if result != nil {
		t.Errorf("expected nil for species with no sources, got %+v", result)
	}
}

func TestListAllSpeciesSources(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	_, sourceID := createTestSpeciesAndSource(t, db)

	// Create another species
	rubra := &models.Species{
		ScientificName:      "rubra",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	if err := db.SaveSpecies(rubra); err != nil {
		t.Fatalf("SaveSpecies failed: %v", err)
	}

	// Create species sources for both species
	ss1 := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       sourceID,
		LocalNames:     []string{"white oak"},
		IsPreferred:    true,
	}
	ss2 := &models.SpeciesSource{
		ScientificName: "rubra",
		SourceID:       sourceID,
		LocalNames:     []string{"red oak"},
		IsPreferred:    true,
	}

	if err := db.SaveSpeciesSource(ss1); err != nil {
		t.Fatalf("SaveSpeciesSource 1 failed: %v", err)
	}
	if err := db.SaveSpeciesSource(ss2); err != nil {
		t.Fatalf("SaveSpeciesSource 2 failed: %v", err)
	}

	// List all
	all, err := db.ListAllSpeciesSources()
	if err != nil {
		t.Fatalf("ListAllSpeciesSources failed: %v", err)
	}
	if len(all) != 2 {
		t.Errorf("expected 2 species sources, got %d", len(all))
	}

	// Should be ordered by scientific name
	if all[0].ScientificName != "alba" {
		t.Errorf("expected first to be 'alba', got '%s'", all[0].ScientificName)
	}
}

func TestDeleteSpeciesSource(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	_, sourceID := createTestSpeciesAndSource(t, db)

	// Create a species source
	ss := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       sourceID,
		LocalNames:     []string{"white oak"},
		IsPreferred:    true,
	}
	if err := db.SaveSpeciesSource(ss); err != nil {
		t.Fatalf("SaveSpeciesSource failed: %v", err)
	}

	// Delete it
	err := db.DeleteSpeciesSource("alba", sourceID)
	if err != nil {
		t.Fatalf("DeleteSpeciesSource failed: %v", err)
	}

	// Verify deleted
	result, err := db.GetSpeciesSourceBySourceID("alba", sourceID)
	if err != nil {
		t.Fatalf("GetSpeciesSourceBySourceID failed: %v", err)
	}
	if result != nil {
		t.Error("expected nil after delete")
	}
}

func TestDeleteSpeciesSourceNotFound(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	createTestSpeciesAndSource(t, db)

	err := db.DeleteSpeciesSource("alba", 99999)
	if err == nil {
		t.Fatal("expected error deleting non-existent species source")
	}
}

func TestSaveSpeciesSourceAllFields(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	_, sourceID := createTestSpeciesAndSource(t, db)

	// Create species source with all fields
	ss := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       sourceID,
		LocalNames:     []string{"white oak", "stave oak"},
		IsPreferred:    true,
	}
	ss.Range = strPtr("Eastern North America")
	ss.GrowthHabit = strPtr("Large deciduous tree")
	ss.Leaves = strPtr("Lobed, 5-9 rounded lobes")
	ss.Flowers = strPtr("Monoecious catkins")
	ss.Fruits = strPtr("Acorns, 1-2 cm long")
	ss.Bark = strPtr("Light gray, scaly")
	ss.Twigs = strPtr("Reddish-brown, glabrous")
	ss.Buds = strPtr("Clustered at twig tips")
	ss.HardinessHabitat = strPtr("Zones 3-9, well-drained soils")
	ss.Miscellaneous = strPtr("Important timber species")
	ss.URL = strPtr("https://example.com/alba")

	if err := db.SaveSpeciesSource(ss); err != nil {
		t.Fatalf("SaveSpeciesSource failed: %v", err)
	}

	// Retrieve and verify all fields
	result, err := db.GetSpeciesSourceBySourceID("alba", sourceID)
	if err != nil {
		t.Fatalf("GetSpeciesSourceBySourceID failed: %v", err)
	}

	if len(result.LocalNames) != 2 {
		t.Errorf("LocalNames: expected 2, got %d", len(result.LocalNames))
	}
	if *result.Range != "Eastern North America" {
		t.Errorf("Range: expected 'Eastern North America', got '%s'", *result.Range)
	}
	if *result.GrowthHabit != "Large deciduous tree" {
		t.Errorf("GrowthHabit: expected 'Large deciduous tree', got '%s'", *result.GrowthHabit)
	}
	if *result.Leaves != "Lobed, 5-9 rounded lobes" {
		t.Errorf("Leaves mismatch")
	}
	if *result.Flowers != "Monoecious catkins" {
		t.Errorf("Flowers mismatch")
	}
	if *result.Fruits != "Acorns, 1-2 cm long" {
		t.Errorf("Fruits mismatch")
	}
	if *result.Bark != "Light gray, scaly" {
		t.Errorf("Bark mismatch")
	}
	if *result.Twigs != "Reddish-brown, glabrous" {
		t.Errorf("Twigs mismatch")
	}
	if *result.Buds != "Clustered at twig tips" {
		t.Errorf("Buds mismatch")
	}
	if *result.HardinessHabitat != "Zones 3-9, well-drained soils" {
		t.Errorf("HardinessHabitat mismatch")
	}
	if *result.Miscellaneous != "Important timber species" {
		t.Errorf("Miscellaneous mismatch")
	}
	if *result.URL != "https://example.com/alba" {
		t.Errorf("URL mismatch")
	}
}

func TestSaveSpeciesSourceNonExistentSpecies(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create a source
	source := &models.Source{SourceType: "website", Name: "Test Source"}
	sourceID, _ := db.InsertSource(source)

	// Try to create species source for non-existent species
	ss := &models.SpeciesSource{
		ScientificName: "nonexistent",
		SourceID:       sourceID,
		LocalNames:     []string{},
		IsPreferred:    true,
	}

	err := db.SaveSpeciesSource(ss)
	if err == nil {
		t.Fatal("expected error saving species source for non-existent species")
	}
}
