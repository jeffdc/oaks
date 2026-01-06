package db

import (
	"testing"

	"github.com/jeff/oaks/api/internal/models"
)

func TestTaxonCRUD(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	author := "Oerst."
	taxon := &models.Taxon{
		Name:   "Lobatae",
		Level:  models.TaxonLevelSection,
		Author: &author,
		Links: []models.TaxonLink{
			{Label: "Wikipedia", URL: "https://en.wikipedia.org/wiki/Lobatae"},
		},
	}

	// Insert
	err := db.InsertTaxon(taxon)
	if err != nil {
		t.Fatalf("InsertTaxon failed: %v", err)
	}

	// Get
	retrieved, err := db.GetTaxon("Lobatae", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("GetTaxon failed: %v", err)
	}
	if retrieved == nil {
		t.Fatal("expected non-nil taxon")
	}
	if retrieved.Name != "Lobatae" {
		t.Errorf("Name = %q, want 'Lobatae'", retrieved.Name)
	}
	if retrieved.Level != models.TaxonLevelSection {
		t.Errorf("Level = %q, want 'section'", retrieved.Level)
	}
	if *retrieved.Author != "Oerst." {
		t.Errorf("Author = %q, want 'Oerst.'", *retrieved.Author)
	}
	if len(retrieved.Links) != 1 {
		t.Errorf("Links len = %d, want 1", len(retrieved.Links))
	}

	// Update
	newAuthor := "Updated Author"
	retrieved.Author = &newAuthor
	content := "Red oak section content"
	retrieved.Content = &content
	err = db.UpdateTaxon(retrieved)
	if err != nil {
		t.Fatalf("UpdateTaxon failed: %v", err)
	}

	// Verify update
	updated, err := db.GetTaxon("Lobatae", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("GetTaxon after update failed: %v", err)
	}
	if *updated.Author != "Updated Author" {
		t.Errorf("Author after update = %q, want 'Updated Author'", *updated.Author)
	}
	if *updated.Content != "Red oak section content" {
		t.Errorf("Content after update = %q, want 'Red oak section content'", *updated.Content)
	}

	// Delete
	err = db.DeleteTaxon("Lobatae", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("DeleteTaxon failed: %v", err)
	}

	// Verify deleted
	deleted, err := db.GetTaxon("Lobatae", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("GetTaxon after delete failed: %v", err)
	}
	if deleted != nil {
		t.Error("expected nil after delete")
	}
}

func TestGetTaxonByID(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	author := "Oerst."
	taxon := &models.Taxon{
		Name:   "Quercus",
		Level:  models.TaxonLevelSubgenus,
		Author: &author,
		Links:  []models.TaxonLink{},
	}

	// Save
	if err := db.InsertTaxon(taxon); err != nil {
		t.Fatalf("InsertTaxon failed: %v", err)
	}

	// Get by name/level first to find the ID
	byNameLevel, err := db.GetTaxon("Quercus", models.TaxonLevelSubgenus)
	if err != nil {
		t.Fatalf("GetTaxon failed: %v", err)
	}
	if byNameLevel == nil {
		t.Fatal("expected non-nil taxon")
	}

	// Get by ID
	byID, err := db.GetTaxonByID(byNameLevel.ID)
	if err != nil {
		t.Fatalf("GetTaxonByID failed: %v", err)
	}
	if byID == nil {
		t.Fatal("expected non-nil taxon from GetTaxonByID")
	}

	// Verify fields match
	if byID.Name != byNameLevel.Name {
		t.Errorf("Name = %q, want %q", byID.Name, byNameLevel.Name)
	}
	if byID.ID != byNameLevel.ID {
		t.Errorf("ID = %d, want %d", byID.ID, byNameLevel.ID)
	}
	if byID.Level != byNameLevel.Level {
		t.Errorf("Level = %q, want %q", byID.Level, byNameLevel.Level)
	}
	if *byID.Author != *byNameLevel.Author {
		t.Errorf("Author = %q, want %q", *byID.Author, *byNameLevel.Author)
	}
}

func TestGetTaxonByIDNotFound(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Try to get non-existent ID
	got, err := db.GetTaxonByID(99999)
	if err != nil {
		t.Fatalf("GetTaxonByID should not error for non-existent ID: %v", err)
	}
	if got != nil {
		t.Error("expected nil for non-existent ID")
	}
}

func TestGetTaxonNotFound(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	got, err := db.GetTaxon("NonExistent", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("GetTaxon should not error for non-existent taxon: %v", err)
	}
	if got != nil {
		t.Error("expected nil for non-existent taxon")
	}
}

func TestListTaxa(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create taxa hierarchy
	taxa := []*models.Taxon{
		{Name: "Quercus", Level: models.TaxonLevelSubgenus, Links: []models.TaxonLink{}},
		{Name: "Lobatae", Level: models.TaxonLevelSection, Links: []models.TaxonLink{}},
		{Name: "Quercus", Level: models.TaxonLevelSection, Links: []models.TaxonLink{}},
		{Name: "Agrifoliae", Level: models.TaxonLevelSubsection, Links: []models.TaxonLink{}},
	}

	for _, t := range taxa {
		if err := db.InsertTaxon(t); err != nil {
			panic(err)
		}
	}

	// List all
	all, err := db.ListTaxa(nil)
	if err != nil {
		t.Fatalf("ListTaxa failed: %v", err)
	}
	if len(all) != 4 {
		t.Errorf("expected 4 taxa, got %d", len(all))
	}
}

func TestListTaxaByLevel(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create taxa at different levels
	taxa := []*models.Taxon{
		{Name: "Quercus", Level: models.TaxonLevelSubgenus, Links: []models.TaxonLink{}},
		{Name: "Lobatae", Level: models.TaxonLevelSection, Links: []models.TaxonLink{}},
		{Name: "Quercus", Level: models.TaxonLevelSection, Links: []models.TaxonLink{}},
	}

	for _, taxon := range taxa {
		if err := db.InsertTaxon(taxon); err != nil {
			t.Fatalf("InsertTaxon failed: %v", err)
		}
	}

	// List only sections
	level := models.TaxonLevelSection
	sections, err := db.ListTaxa(&TaxaListParams{Level: &level})
	if err != nil {
		t.Fatalf("ListTaxa by level failed: %v", err)
	}
	if len(sections) != 2 {
		t.Errorf("expected 2 sections, got %d", len(sections))
	}
	for _, s := range sections {
		if s.Level != models.TaxonLevelSection {
			t.Errorf("expected section level, got %s", s.Level)
		}
	}
}

func TestListTaxaByParent(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create hierarchy
	parent := "Quercus"
	taxa := []*models.Taxon{
		{Name: "Quercus", Level: models.TaxonLevelSubgenus, Links: []models.TaxonLink{}},
		{Name: "Lobatae", Level: models.TaxonLevelSection, Parent: &parent, Links: []models.TaxonLink{}},
		{Name: "Quercus", Level: models.TaxonLevelSection, Parent: &parent, Links: []models.TaxonLink{}},
		{Name: "Orphan", Level: models.TaxonLevelSection, Links: []models.TaxonLink{}},
	}

	for _, taxon := range taxa {
		if err := db.InsertTaxon(taxon); err != nil {
			t.Fatalf("InsertTaxon failed: %v", err)
		}
	}

	// List children of Quercus
	children, err := db.ListTaxa(&TaxaListParams{Parent: &parent})
	if err != nil {
		t.Fatalf("ListTaxa by parent failed: %v", err)
	}
	if len(children) != 2 {
		t.Errorf("expected 2 children of Quercus, got %d", len(children))
	}
}

func TestListTaxaCombinedFilters(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	parent := "Quercus"
	taxa := []*models.Taxon{
		{Name: "Quercus", Level: models.TaxonLevelSubgenus, Links: []models.TaxonLink{}},
		{Name: "Lobatae", Level: models.TaxonLevelSection, Parent: &parent, Links: []models.TaxonLink{}},
		{Name: "Quercus", Level: models.TaxonLevelSection, Parent: &parent, Links: []models.TaxonLink{}},
		{Name: "Alba", Level: models.TaxonLevelSubsection, Parent: &parent, Links: []models.TaxonLink{}},
	}

	for _, taxon := range taxa {
		if err := db.InsertTaxon(taxon); err != nil {
			t.Fatalf("InsertTaxon failed: %v", err)
		}
	}

	// List sections that are children of Quercus
	level := models.TaxonLevelSection
	results, err := db.ListTaxa(&TaxaListParams{Level: &level, Parent: &parent})
	if err != nil {
		t.Fatalf("ListTaxa with combined filters failed: %v", err)
	}
	if len(results) != 2 {
		t.Errorf("expected 2 sections under Quercus, got %d", len(results))
	}
}

func TestValidateTaxon(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	taxon := &models.Taxon{
		Name:  "Lobatae",
		Level: models.TaxonLevelSection,
		Links: []models.TaxonLink{},
	}
	if err := db.InsertTaxon(taxon); err != nil {
		t.Fatalf("InsertTaxon failed: %v", err)
	}

	// Valid taxon
	exists, err := db.ValidateTaxon("Lobatae", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("ValidateTaxon failed: %v", err)
	}
	if !exists {
		t.Error("expected taxon to exist")
	}

	// Wrong level
	exists, err = db.ValidateTaxon("Lobatae", models.TaxonLevelSubgenus)
	if err != nil {
		t.Fatalf("ValidateTaxon failed: %v", err)
	}
	if exists {
		t.Error("expected taxon NOT to exist at wrong level")
	}

	// Non-existent
	exists, err = db.ValidateTaxon("NonExistent", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("ValidateTaxon failed: %v", err)
	}
	if exists {
		t.Error("expected non-existent taxon to not exist")
	}
}

func TestClearTaxa(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create some taxa
	taxa := []*models.Taxon{
		{Name: "Quercus", Level: models.TaxonLevelSubgenus, Links: []models.TaxonLink{}},
		{Name: "Lobatae", Level: models.TaxonLevelSection, Links: []models.TaxonLink{}},
	}

	for _, taxon := range taxa {
		if err := db.InsertTaxon(taxon); err != nil {
			t.Fatalf("InsertTaxon failed: %v", err)
		}
	}

	// Verify they exist
	all, _ := db.ListTaxa(nil)
	if len(all) != 2 {
		t.Fatalf("expected 2 taxa before clear, got %d", len(all))
	}

	// Clear
	err := db.ClearTaxa()
	if err != nil {
		t.Fatalf("ClearTaxa failed: %v", err)
	}

	// Verify empty
	all, _ = db.ListTaxa(nil)
	if len(all) != 0 {
		t.Errorf("expected 0 taxa after clear, got %d", len(all))
	}
}

func TestDeleteTaxonNotFound(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	err := db.DeleteTaxon("NonExistent", models.TaxonLevelSection)
	if err == nil {
		t.Fatal("expected error deleting non-existent taxon")
	}
}

func TestSearchTaxa(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	taxa := []*models.Taxon{
		{Name: "Lobatae", Level: models.TaxonLevelSection, Links: []models.TaxonLink{}},
		{Name: "Quercus", Level: models.TaxonLevelSubgenus, Links: []models.TaxonLink{}},
		{Name: "Quercus", Level: models.TaxonLevelSection, Links: []models.TaxonLink{}},
	}

	for _, taxon := range taxa {
		if err := db.InsertTaxon(taxon); err != nil {
			t.Fatalf("InsertTaxon failed: %v", err)
		}
	}

	// Search for "Quercus"
	results, err := db.SearchTaxa("Quercus")
	if err != nil {
		t.Fatalf("SearchTaxa failed: %v", err)
	}
	if len(results) != 2 {
		t.Errorf("expected 2 results for 'Quercus', got %d", len(results))
	}

	// Search for "Lob"
	results, err = db.SearchTaxa("Lob")
	if err != nil {
		t.Fatalf("SearchTaxa failed: %v", err)
	}
	if len(results) != 1 {
		t.Errorf("expected 1 result for 'Lob', got %d", len(results))
	}

	// Search for non-existent
	results, err = db.SearchTaxa("NonExistent")
	if err != nil {
		t.Fatalf("SearchTaxa failed: %v", err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results for 'NonExistent', got %d", len(results))
	}
}

func TestTaxonSpeciesCount(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create taxon
	taxon := &models.Taxon{
		Name:  "Lobatae",
		Level: models.TaxonLevelSection,
		Links: []models.TaxonLink{},
	}
	if err := db.InsertTaxon(taxon); err != nil {
		t.Fatalf("InsertTaxon failed: %v", err)
	}

	// Create species in that section
	section := "Lobatae"
	species := []*models.Species{
		{ScientificName: "rubra", Section: &section, Hybrids: []string{}, CloselyRelatedTo: []string{}, SubspeciesVarieties: []string{}, Synonyms: []string{}, ExternalLinks: []models.ExternalLink{}},
		{ScientificName: "palustris", Section: &section, Hybrids: []string{}, CloselyRelatedTo: []string{}, SubspeciesVarieties: []string{}, Synonyms: []string{}, ExternalLinks: []models.ExternalLink{}},
	}

	for _, sp := range species {
		if err := db.SaveSpecies(sp); err != nil {
			t.Fatalf("SaveSpecies failed: %v", err)
		}
	}

	// Get taxon and check species count
	retrieved, err := db.GetTaxon("Lobatae", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("GetTaxon failed: %v", err)
	}
	if retrieved.SpeciesCount != 2 {
		t.Errorf("expected species count 2, got %d", retrieved.SpeciesCount)
	}
}

func TestTaxonWithLinks(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	taxon := &models.Taxon{
		Name:  "Lobatae",
		Level: models.TaxonLevelSection,
		Links: []models.TaxonLink{
			{Label: "Wikipedia", URL: "https://en.wikipedia.org/wiki/Lobatae"},
			{Label: "iNaturalist", URL: "https://www.inaturalist.org/taxa/12345"},
		},
	}
	if err := db.InsertTaxon(taxon); err != nil {
		t.Fatalf("InsertTaxon failed: %v", err)
	}

	retrieved, err := db.GetTaxon("Lobatae", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("GetTaxon failed: %v", err)
	}
	if len(retrieved.Links) != 2 {
		t.Errorf("expected 2 links, got %d", len(retrieved.Links))
	}
	if retrieved.Links[0].Label != "Wikipedia" {
		t.Errorf("expected first link label 'Wikipedia', got '%s'", retrieved.Links[0].Label)
	}
}

func TestTaxonWithContent(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	content := "This is the red oak section, characterized by..."
	updatedAt := "2024-01-15T10:30:00Z"
	taxon := &models.Taxon{
		Name:             "Lobatae",
		Level:            models.TaxonLevelSection,
		Content:          &content,
		ContentUpdatedAt: &updatedAt,
		Links:            []models.TaxonLink{},
	}
	if err := db.InsertTaxon(taxon); err != nil {
		t.Fatalf("InsertTaxon failed: %v", err)
	}

	retrieved, err := db.GetTaxon("Lobatae", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("GetTaxon failed: %v", err)
	}
	if retrieved.Content == nil {
		t.Fatal("expected content to be set")
	}
	if *retrieved.Content != content {
		t.Errorf("content mismatch")
	}
	if *retrieved.ContentUpdatedAt != updatedAt {
		t.Errorf("content_updated_at mismatch")
	}
}
