package db

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/jeff/oaks/cli/internal/models"
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

// Source tests

func TestSourceCRUD(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create
	desc := "Test description"
	author := "Test Author"
	year := 2024
	url := "https://example.com"
	source := &models.Source{
		SourceType:  "Website",
		Name:        "Test Source",
		Description: &desc,
		Author:      &author,
		Year:        &year,
		URL:         &url,
	}

	id, err := db.InsertSource(source)
	if err != nil {
		t.Fatalf("InsertSource failed: %v", err)
	}
	if id <= 0 {
		t.Errorf("expected positive ID, got %d", id)
	}

	// Read
	got, err := db.GetSource(id)
	if err != nil {
		t.Fatalf("GetSource failed: %v", err)
	}
	if got == nil {
		t.Fatal("expected non-nil source")
	}
	if got.Name != source.Name {
		t.Errorf("Name = %q, want %q", got.Name, source.Name)
	}
	if got.SourceType != source.SourceType {
		t.Errorf("SourceType = %q, want %q", got.SourceType, source.SourceType)
	}
	if *got.Author != *source.Author {
		t.Errorf("Author = %q, want %q", *got.Author, *source.Author)
	}

	// Update
	newDesc := "Updated description"
	got.Description = &newDesc
	if err := db.UpdateSource(got); err != nil {
		t.Fatalf("UpdateSource failed: %v", err)
	}

	updated, err := db.GetSource(id)
	if err != nil {
		t.Fatalf("GetSource after update failed: %v", err)
	}
	if *updated.Description != newDesc {
		t.Errorf("Description = %q, want %q", *updated.Description, newDesc)
	}
}

func TestGetSourceNotFound(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	got, err := db.GetSource(999)
	if err != nil {
		t.Fatalf("GetSource failed: %v", err)
	}
	if got != nil {
		t.Error("expected nil for non-existent source")
	}
}

// Taxon tests

func TestTaxonCRUD(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	parent := "Quercus"
	author := "Oerst."
	notes := "Red oaks and relatives"
	links := []models.TaxonLink{
		{Label: "iNaturalist", URL: "https://inaturalist.org/taxa/12345"},
	}

	taxon := &models.Taxon{
		Name:   "Lobatae",
		Level:  models.TaxonLevelSection,
		Parent: &parent,
		Author: &author,
		Notes:  &notes,
		Links:  links,
	}

	// Insert
	if err := db.InsertTaxon(taxon); err != nil {
		t.Fatalf("InsertTaxon failed: %v", err)
	}

	// Get
	got, err := db.GetTaxon("Lobatae", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("GetTaxon failed: %v", err)
	}
	if got == nil {
		t.Fatal("expected non-nil taxon")
	}
	if got.Name != taxon.Name {
		t.Errorf("Name = %q, want %q", got.Name, taxon.Name)
	}
	if got.Level != taxon.Level {
		t.Errorf("Level = %q, want %q", got.Level, taxon.Level)
	}
	if *got.Parent != *taxon.Parent {
		t.Errorf("Parent = %q, want %q", *got.Parent, *taxon.Parent)
	}
	if len(got.Links) != len(taxon.Links) {
		t.Errorf("Links len = %d, want %d", len(got.Links), len(taxon.Links))
	}

	// Update
	newNotes := "Updated notes"
	got.Notes = &newNotes
	if err := db.UpdateTaxon(got); err != nil {
		t.Fatalf("UpdateTaxon failed: %v", err)
	}

	updated, err := db.GetTaxon("Lobatae", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("GetTaxon after update failed: %v", err)
	}
	if *updated.Notes != newNotes {
		t.Errorf("Notes = %q, want %q", *updated.Notes, newNotes)
	}

	// Validate
	valid, err := db.ValidateTaxon("Lobatae", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("ValidateTaxon failed: %v", err)
	}
	if !valid {
		t.Error("expected taxon to be valid")
	}

	valid, err = db.ValidateTaxon("Nonexistent", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("ValidateTaxon failed: %v", err)
	}
	if valid {
		t.Error("expected taxon to be invalid")
	}
}

func TestClearTaxa(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Add some taxa
	if err := db.InsertTaxon(&models.Taxon{Name: "Test", Level: models.TaxonLevelSubgenus}); err != nil {
		t.Fatalf("InsertTaxon failed: %v", err)
	}

	// Clear
	if err := db.ClearTaxa(); err != nil {
		t.Fatalf("ClearTaxa failed: %v", err)
	}

	// Verify cleared - getting the taxon should return nil
	got, err := db.GetTaxon("Test", models.TaxonLevelSubgenus)
	if err != nil {
		t.Fatalf("GetTaxon failed: %v", err)
	}
	if got != nil {
		t.Error("expected taxon to be cleared")
	}
}

// OakEntry tests

func TestOakEntryCRUD(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	author := "L. 1753"
	subgenus := "Quercus"
	section := "Quercus"
	entry := &models.OakEntry{
		ScientificName:      "alba",
		Author:              &author,
		IsHybrid:            false,
		Subgenus:            &subgenus,
		Section:             &section,
		Hybrids:             []string{"bebbiana", "jackiana"},
		CloselyRelatedTo:    []string{"stellata"},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{"alba var. repanda"},
		ExternalLinks: []models.ExternalLink{
			{Name: "Wikipedia", URL: "https://en.wikipedia.org/wiki/Quercus_alba"},
		},
	}

	// Save
	if err := db.SaveOakEntry(entry); err != nil {
		t.Fatalf("SaveOakEntry failed: %v", err)
	}

	// Get
	got, err := db.GetOakEntry("alba")
	if err != nil {
		t.Fatalf("GetOakEntry failed: %v", err)
	}
	if got == nil {
		t.Fatal("expected non-nil entry")
	}
	if got.ScientificName != entry.ScientificName {
		t.Errorf("ScientificName = %q, want %q", got.ScientificName, entry.ScientificName)
	}
	if *got.Author != *entry.Author {
		t.Errorf("Author = %q, want %q", *got.Author, *entry.Author)
	}
	if got.IsHybrid != entry.IsHybrid {
		t.Errorf("IsHybrid = %v, want %v", got.IsHybrid, entry.IsHybrid)
	}
	if len(got.Hybrids) != len(entry.Hybrids) {
		t.Errorf("Hybrids len = %d, want %d", len(got.Hybrids), len(entry.Hybrids))
	}
	if len(got.Synonyms) != len(entry.Synonyms) {
		t.Errorf("Synonyms len = %d, want %d", len(got.Synonyms), len(entry.Synonyms))
	}
	if len(got.ExternalLinks) != len(entry.ExternalLinks) {
		t.Errorf("ExternalLinks len = %d, want %d", len(got.ExternalLinks), len(entry.ExternalLinks))
	}

	// Update (via SaveOakEntry which uses INSERT OR REPLACE)
	got.Hybrids = append(got.Hybrids, "fernowii")
	if err := db.SaveOakEntry(got); err != nil {
		t.Fatalf("SaveOakEntry update failed: %v", err)
	}

	updated, err := db.GetOakEntry("alba")
	if err != nil {
		t.Fatalf("GetOakEntry after update failed: %v", err)
	}
	if len(updated.Hybrids) != 3 {
		t.Errorf("Hybrids len = %d, want 3", len(updated.Hybrids))
	}

	// Delete
	if err := db.DeleteOakEntry("alba"); err != nil {
		t.Fatalf("DeleteOakEntry failed: %v", err)
	}

	deleted, err := db.GetOakEntry("alba")
	if err != nil {
		t.Fatalf("GetOakEntry after delete failed: %v", err)
	}
	if deleted != nil {
		t.Error("expected nil after delete")
	}
}

func TestOakEntryHybrid(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	parent1 := "alba"
	parent2 := "macrocarpa"
	entry := &models.OakEntry{
		ScientificName:      "× bebbiana",
		IsHybrid:            true,
		Parent1:             &parent1,
		Parent2:             &parent2,
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}

	if err := db.SaveOakEntry(entry); err != nil {
		t.Fatalf("SaveOakEntry failed: %v", err)
	}

	got, err := db.GetOakEntry("× bebbiana")
	if err != nil {
		t.Fatalf("GetOakEntry failed: %v", err)
	}
	if !got.IsHybrid {
		t.Error("expected IsHybrid = true")
	}
	if *got.Parent1 != parent1 {
		t.Errorf("Parent1 = %q, want %q", *got.Parent1, parent1)
	}
	if *got.Parent2 != parent2 {
		t.Errorf("Parent2 = %q, want %q", *got.Parent2, parent2)
	}
}

func TestBidirectionalHybridParentRelationship(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create parent species first
	alba := &models.OakEntry{
		ScientificName:      "alba",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	macrocarpa := &models.OakEntry{
		ScientificName:      "macrocarpa",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	rubra := &models.OakEntry{
		ScientificName:      "rubra",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}

	for _, e := range []*models.OakEntry{alba, macrocarpa, rubra} {
		if err := db.SaveOakEntry(e); err != nil {
			t.Fatalf("SaveOakEntry(%s) failed: %v", e.ScientificName, err)
		}
	}

	// Create hybrid with parents
	parent1 := "alba"
	parent2 := "macrocarpa"
	hybrid := &models.OakEntry{
		ScientificName:      "× bebbiana",
		IsHybrid:            true,
		Parent1:             &parent1,
		Parent2:             &parent2,
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}

	if err := db.SaveOakEntry(hybrid); err != nil {
		t.Fatalf("SaveOakEntry(hybrid) failed: %v", err)
	}

	// Verify parents now have the hybrid in their hybrids list
	gotAlba, err := db.GetOakEntry("alba")
	if err != nil {
		t.Fatalf("GetOakEntry(alba) failed: %v", err)
	}
	if !sliceContains(gotAlba.Hybrids, "× bebbiana") {
		t.Errorf("alba.Hybrids = %v, want to contain '× bebbiana'", gotAlba.Hybrids)
	}

	gotMacrocarpa, err := db.GetOakEntry("macrocarpa")
	if err != nil {
		t.Fatalf("GetOakEntry(macrocarpa) failed: %v", err)
	}
	if !sliceContains(gotMacrocarpa.Hybrids, "× bebbiana") {
		t.Errorf("macrocarpa.Hybrids = %v, want to contain '× bebbiana'", gotMacrocarpa.Hybrids)
	}

	// Change one parent from macrocarpa to rubra
	newParent2 := "rubra"
	hybrid.Parent2 = &newParent2
	if err := db.SaveOakEntry(hybrid); err != nil {
		t.Fatalf("SaveOakEntry(hybrid with changed parent) failed: %v", err)
	}

	// Verify macrocarpa no longer has the hybrid
	gotMacrocarpa, err = db.GetOakEntry("macrocarpa")
	if err != nil {
		t.Fatalf("GetOakEntry(macrocarpa) failed: %v", err)
	}
	if sliceContains(gotMacrocarpa.Hybrids, "× bebbiana") {
		t.Errorf("macrocarpa.Hybrids = %v, want NOT to contain '× bebbiana' after parent change", gotMacrocarpa.Hybrids)
	}

	// Verify rubra now has the hybrid
	gotRubra, err := db.GetOakEntry("rubra")
	if err != nil {
		t.Fatalf("GetOakEntry(rubra) failed: %v", err)
	}
	if !sliceContains(gotRubra.Hybrids, "× bebbiana") {
		t.Errorf("rubra.Hybrids = %v, want to contain '× bebbiana'", gotRubra.Hybrids)
	}

	// Verify alba still has the hybrid (unchanged)
	gotAlba, err = db.GetOakEntry("alba")
	if err != nil {
		t.Fatalf("GetOakEntry(alba) failed: %v", err)
	}
	if !sliceContains(gotAlba.Hybrids, "× bebbiana") {
		t.Errorf("alba.Hybrids = %v, want to contain '× bebbiana' (unchanged)", gotAlba.Hybrids)
	}

	// Remove parent2 entirely
	hybrid.Parent2 = nil
	if err := db.SaveOakEntry(hybrid); err != nil {
		t.Fatalf("SaveOakEntry(hybrid with nil parent2) failed: %v", err)
	}

	// Verify rubra no longer has the hybrid
	gotRubra, err = db.GetOakEntry("rubra")
	if err != nil {
		t.Fatalf("GetOakEntry(rubra) failed: %v", err)
	}
	if sliceContains(gotRubra.Hybrids, "× bebbiana") {
		t.Errorf("rubra.Hybrids = %v, want NOT to contain '× bebbiana' after parent removal", gotRubra.Hybrids)
	}

	// Verify alba still has the hybrid
	gotAlba, err = db.GetOakEntry("alba")
	if err != nil {
		t.Fatalf("GetOakEntry(alba) failed: %v", err)
	}
	if !sliceContains(gotAlba.Hybrids, "× bebbiana") {
		t.Errorf("alba.Hybrids = %v, want to contain '× bebbiana' (still parent1)", gotAlba.Hybrids)
	}
}

// SpeciesSource tests

func TestSpeciesSourceCRUD(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// First create the oak entry and source
	if err := db.SaveOakEntry(&models.OakEntry{
		ScientificName: "alba",
		Hybrids:        []string{}, CloselyRelatedTo: []string{}, SubspeciesVarieties: []string{}, Synonyms: []string{}, ExternalLinks: []models.ExternalLink{},
	}); err != nil {
		t.Fatalf("SaveOakEntry failed: %v", err)
	}

	sourceID, err := db.InsertSource(&models.Source{
		SourceType: "Website",
		Name:       "Test Source",
	})
	if err != nil {
		t.Fatalf("InsertSource failed: %v", err)
	}

	rng := "Eastern North America"
	leaves := "8-20 cm long"
	ss := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       sourceID,
		LocalNames:     []string{"white oak", "eastern white oak"},
		Range:          &rng,
		Leaves:         &leaves,
		IsPreferred:    true,
	}

	// Save
	if err := db.SaveSpeciesSource(ss); err != nil {
		t.Fatalf("SaveSpeciesSource failed: %v", err)
	}

	// Get by source ID
	got, err := db.GetSpeciesSourceBySourceID("alba", sourceID)
	if err != nil {
		t.Fatalf("GetSpeciesSourceBySourceID failed: %v", err)
	}
	if got == nil {
		t.Fatal("expected non-nil species source")
	}
	if len(got.LocalNames) != 2 {
		t.Errorf("LocalNames len = %d, want 2", len(got.LocalNames))
	}
	if *got.Range != rng {
		t.Errorf("Range = %q, want %q", *got.Range, rng)
	}
	if !got.IsPreferred {
		t.Error("expected IsPreferred = true")
	}

	// Get all sources for species
	sources, err := db.GetSpeciesSources("alba")
	if err != nil {
		t.Fatalf("GetSpeciesSources failed: %v", err)
	}
	if len(sources) != 1 {
		t.Errorf("expected 1 source, got %d", len(sources))
	}

	// Get preferred
	preferred, err := db.GetPreferredSpeciesSource("alba")
	if err != nil {
		t.Fatalf("GetPreferredSpeciesSource failed: %v", err)
	}
	if preferred == nil {
		t.Fatal("expected non-nil preferred source")
	}
	if !preferred.IsPreferred {
		t.Error("expected IsPreferred = true")
	}
}

func TestListAllSpeciesSources(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Setup
	if err := db.SaveOakEntry(&models.OakEntry{
		ScientificName: "alba",
		Hybrids:        []string{}, CloselyRelatedTo: []string{}, SubspeciesVarieties: []string{}, Synonyms: []string{}, ExternalLinks: []models.ExternalLink{},
	}); err != nil {
		t.Fatalf("SaveOakEntry failed: %v", err)
	}

	sourceID, _ := db.InsertSource(&models.Source{SourceType: "Website", Name: "Test"})

	ss := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       sourceID,
		LocalNames:     []string{},
	}
	if err := db.SaveSpeciesSource(ss); err != nil {
		t.Fatalf("SaveSpeciesSource failed: %v", err)
	}

	all, err := db.ListAllSpeciesSources()
	if err != nil {
		t.Fatalf("ListAllSpeciesSources failed: %v", err)
	}
	if len(all) != 1 {
		t.Errorf("expected 1 source, got %d", len(all))
	}
}

// Metadata tests

func TestMetadata(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Set
	if err := db.SetMetadata("test_key", "test_value"); err != nil {
		t.Fatalf("SetMetadata failed: %v", err)
	}

	// Get
	val, err := db.GetMetadata("test_key")
	if err != nil {
		t.Fatalf("GetMetadata failed: %v", err)
	}
	if val != "test_value" {
		t.Errorf("value = %q, want %q", val, "test_value")
	}

	// Get non-existent
	val, err = db.GetMetadata("nonexistent")
	if err != nil {
		t.Fatalf("GetMetadata failed: %v", err)
	}
	if val != "" {
		t.Errorf("expected empty string for non-existent key, got %q", val)
	}

	// Update
	if err := db.SetMetadata("test_key", "updated_value"); err != nil {
		t.Fatalf("SetMetadata update failed: %v", err)
	}
	val, _ = db.GetMetadata("test_key")
	if val != "updated_value" {
		t.Errorf("value = %q, want %q", val, "updated_value")
	}

	// Delete
	if err := db.DeleteMetadata("test_key"); err != nil {
		t.Fatalf("DeleteMetadata failed: %v", err)
	}
	val, _ = db.GetMetadata("test_key")
	if val != "" {
		t.Errorf("expected empty after delete, got %q", val)
	}
}

// Transaction tests

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
	tx.Rollback()
}
