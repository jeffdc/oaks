package db

import (
	"testing"

	"github.com/jeff/oaks/api/internal/models"
)

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
