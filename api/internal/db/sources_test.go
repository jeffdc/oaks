package db

import (
	"testing"

	"github.com/jeff/oaks/api/internal/models"
)

func TestSourceCRUD(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create a source
	source := &models.Source{
		SourceType: "website",
		Name:       "Test Source",
	}
	source.Description = strPtr("A test source")
	source.Author = strPtr("Test Author")
	year := 2024
	source.Year = &year
	source.URL = strPtr("https://example.com")

	id, err := db.InsertSource(source)
	if err != nil {
		t.Fatalf("InsertSource failed: %v", err)
	}
	if id == 0 {
		t.Fatal("expected non-zero ID")
	}
	if source.ID != id {
		t.Errorf("source.ID not updated: expected %d, got %d", id, source.ID)
	}

	// Read it back
	retrieved, err := db.GetSource(id)
	if err != nil {
		t.Fatalf("GetSource failed: %v", err)
	}
	if retrieved == nil {
		t.Fatal("expected source, got nil")
	}
	if retrieved.Name != "Test Source" {
		t.Errorf("expected 'Test Source', got '%s'", retrieved.Name)
	}
	if retrieved.SourceType != "website" {
		t.Errorf("expected 'website', got '%s'", retrieved.SourceType)
	}
	if *retrieved.Description != "A test source" {
		t.Errorf("expected 'A test source', got '%s'", *retrieved.Description)
	}

	// Update it
	retrieved.Name = "Updated Source"
	retrieved.Description = strPtr("Updated description")
	err = db.UpdateSource(retrieved)
	if err != nil {
		t.Fatalf("UpdateSource failed: %v", err)
	}

	// Verify update
	updated, err := db.GetSource(id)
	if err != nil {
		t.Fatalf("GetSource after update failed: %v", err)
	}
	if updated.Name != "Updated Source" {
		t.Errorf("expected 'Updated Source', got '%s'", updated.Name)
	}
	if *updated.Description != "Updated description" {
		t.Errorf("expected 'Updated description', got '%s'", *updated.Description)
	}

	// Delete it
	err = db.DeleteSource(id)
	if err != nil {
		t.Fatalf("DeleteSource failed: %v", err)
	}

	// Verify deleted
	deleted, err := db.GetSource(id)
	if err != nil {
		t.Fatalf("GetSource after delete failed: %v", err)
	}
	if deleted != nil {
		t.Errorf("expected nil after delete, got %+v", deleted)
	}
}

func TestSourceGetNonExistent(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	source, err := db.GetSource(99999)
	if err != nil {
		t.Fatalf("GetSource failed: %v", err)
	}
	if source != nil {
		t.Errorf("expected nil for non-existent source, got %+v", source)
	}
}

func TestSourceDeleteNonExistent(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	err := db.DeleteSource(99999)
	if err == nil {
		t.Fatal("expected error deleting non-existent source")
	}
}

func TestSourceList(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create multiple sources
	sources := []*models.Source{
		{SourceType: "website", Name: "Alpha Source"},
		{SourceType: "book", Name: "Beta Source"},
		{SourceType: "journal", Name: "Gamma Source"},
	}

	for _, s := range sources {
		_, err := db.InsertSource(s)
		if err != nil {
			t.Fatalf("InsertSource failed: %v", err)
		}
	}

	// List all sources
	list, err := db.ListSources()
	if err != nil {
		t.Fatalf("ListSources failed: %v", err)
	}
	if len(list) != 3 {
		t.Errorf("expected 3 sources, got %d", len(list))
	}

	// Should be ordered by name (Alpha, Beta, Gamma)
	if list[0].Name != "Alpha Source" {
		t.Errorf("expected first source to be 'Alpha Source', got '%s'", list[0].Name)
	}
	if list[1].Name != "Beta Source" {
		t.Errorf("expected second source to be 'Beta Source', got '%s'", list[1].Name)
	}
	if list[2].Name != "Gamma Source" {
		t.Errorf("expected third source to be 'Gamma Source', got '%s'", list[2].Name)
	}
}

func TestSourceListEmpty(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	list, err := db.ListSources()
	if err != nil {
		t.Fatalf("ListSources failed: %v", err)
	}
	// Empty result can be nil or empty slice - both are acceptable
	if len(list) != 0 {
		t.Errorf("expected 0 sources, got %d", len(list))
	}
}

func TestSourceSearch(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create test sources
	sources := []*models.Source{
		{SourceType: "website", Name: "Oak Reference Database"},
		{SourceType: "book", Name: "Flora of North America"},
		{SourceType: "journal", Name: "Journal of Oak Studies"},
	}

	for _, s := range sources {
		_, err := db.InsertSource(s)
		if err != nil {
			t.Fatalf("InsertSource failed: %v", err)
		}
	}

	// Search for "Oak"
	ids, err := db.SearchSources("Oak")
	if err != nil {
		t.Fatalf("SearchSources failed: %v", err)
	}
	if len(ids) != 2 {
		t.Errorf("expected 2 results for 'Oak', got %d", len(ids))
	}

	// Search for "Flora"
	ids, err = db.SearchSources("Flora")
	if err != nil {
		t.Fatalf("SearchSources failed: %v", err)
	}
	if len(ids) != 1 {
		t.Errorf("expected 1 result for 'Flora', got %d", len(ids))
	}

	// Search for non-existent
	ids, err = db.SearchSources("NonExistent")
	if err != nil {
		t.Fatalf("SearchSources failed: %v", err)
	}
	if len(ids) != 0 {
		t.Errorf("expected 0 results for 'NonExistent', got %d", len(ids))
	}
}

func TestSourceSearchCaseInsensitive(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	source := &models.Source{
		SourceType: "website",
		Name:       "Oak Reference Database",
	}
	_, err := db.InsertSource(source)
	if err != nil {
		t.Fatalf("InsertSource failed: %v", err)
	}

	// Search with different case
	ids, err := db.SearchSources("oak")
	if err != nil {
		t.Fatalf("SearchSources failed: %v", err)
	}
	if len(ids) != 1 {
		t.Errorf("expected 1 result for case-insensitive search, got %d", len(ids))
	}
}

func TestSourceSearchSpecialCharacters(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	source := &models.Source{
		SourceType: "website",
		Name:       "100% Oak Database",
	}
	_, err := db.InsertSource(source)
	if err != nil {
		t.Fatalf("InsertSource failed: %v", err)
	}

	// Search with special character
	ids, err := db.SearchSources("100%")
	if err != nil {
		t.Fatalf("SearchSources failed: %v", err)
	}
	if len(ids) != 1 {
		t.Errorf("expected 1 result for special char search, got %d", len(ids))
	}
}

func TestSourceAllFields(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	year := 2023
	source := &models.Source{
		SourceType:  "journal",
		Name:        "Comprehensive Oak Journal",
		Description: strPtr("A thorough journal"),
		Author:      strPtr("Dr. Oak Expert"),
		Year:        &year,
		URL:         strPtr("https://oak-journal.example.com"),
		ISBN:        strPtr("978-3-16-148410-0"),
		DOI:         strPtr("10.1234/oak.2023"),
		Notes:       strPtr("Important source"),
		License:     strPtr("CC-BY-4.0"),
		LicenseURL:  strPtr("https://creativecommons.org/licenses/by/4.0/"),
	}

	id, err := db.InsertSource(source)
	if err != nil {
		t.Fatalf("InsertSource failed: %v", err)
	}

	retrieved, err := db.GetSource(id)
	if err != nil {
		t.Fatalf("GetSource failed: %v", err)
	}

	// Verify all fields
	if retrieved.SourceType != "journal" {
		t.Errorf("SourceType: expected 'journal', got '%s'", retrieved.SourceType)
	}
	if retrieved.Name != "Comprehensive Oak Journal" {
		t.Errorf("Name: expected 'Comprehensive Oak Journal', got '%s'", retrieved.Name)
	}
	if *retrieved.Description != "A thorough journal" {
		t.Errorf("Description: expected 'A thorough journal', got '%s'", *retrieved.Description)
	}
	if *retrieved.Author != "Dr. Oak Expert" {
		t.Errorf("Author: expected 'Dr. Oak Expert', got '%s'", *retrieved.Author)
	}
	if *retrieved.Year != 2023 {
		t.Errorf("Year: expected 2023, got %d", *retrieved.Year)
	}
	if *retrieved.URL != "https://oak-journal.example.com" {
		t.Errorf("URL: expected 'https://oak-journal.example.com', got '%s'", *retrieved.URL)
	}
	if *retrieved.ISBN != "978-3-16-148410-0" {
		t.Errorf("ISBN: expected '978-3-16-148410-0', got '%s'", *retrieved.ISBN)
	}
	if *retrieved.DOI != "10.1234/oak.2023" {
		t.Errorf("DOI: expected '10.1234/oak.2023', got '%s'", *retrieved.DOI)
	}
	if *retrieved.Notes != "Important source" {
		t.Errorf("Notes: expected 'Important source', got '%s'", *retrieved.Notes)
	}
	if *retrieved.License != "CC-BY-4.0" {
		t.Errorf("License: expected 'CC-BY-4.0', got '%s'", *retrieved.License)
	}
	if *retrieved.LicenseURL != "https://creativecommons.org/licenses/by/4.0/" {
		t.Errorf("LicenseURL: expected CC URL, got '%s'", *retrieved.LicenseURL)
	}
}
