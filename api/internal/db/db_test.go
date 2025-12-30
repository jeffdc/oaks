package db

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/jeff/oaks/api/internal/models"
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

func TestBidirectionalHybridDoesNotDuplicateExisting(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create parent species with pre-existing hybrid in list
	alba := &models.OakEntry{
		ScientificName:      "alba",
		Hybrids:             []string{"× bebbiana"},
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

	for _, e := range []*models.OakEntry{alba, macrocarpa} {
		if err := db.SaveOakEntry(e); err != nil {
			t.Fatalf("SaveOakEntry(%s) failed: %v", e.ScientificName, err)
		}
	}

	// Create hybrid that references alba (which already has it in list)
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

	// Verify alba still has only one instance of the hybrid
	gotAlba, err := db.GetOakEntry("alba")
	if err != nil {
		t.Fatalf("GetOakEntry(alba) failed: %v", err)
	}

	count := 0
	for _, h := range gotAlba.Hybrids {
		if h == "× bebbiana" {
			count++
		}
	}
	if count != 1 {
		t.Errorf("alba.Hybrids should have exactly 1 '× bebbiana', got %d (list: %v)", count, gotAlba.Hybrids)
	}
}

func TestBidirectionalHybridWithNonExistentParent(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create hybrid referencing non-existent parents
	// This should not fail, just skip updating the parents
	parent1 := "nonexistent1"
	parent2 := "nonexistent2"
	hybrid := &models.OakEntry{
		ScientificName:      "× testHybrid",
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
		t.Fatalf("SaveOakEntry(hybrid with non-existent parents) should not fail: %v", err)
	}

	// Verify the hybrid was saved correctly
	got, err := db.GetOakEntry("× testHybrid")
	if err != nil {
		t.Fatalf("GetOakEntry failed: %v", err)
	}
	if got == nil {
		t.Fatal("expected non-nil entry")
	}
	if *got.Parent1 != parent1 {
		t.Errorf("Parent1 = %q, want %q", *got.Parent1, parent1)
	}
}

func TestSearchOakEntries(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	entries := []*models.OakEntry{
		{ScientificName: "alba", Hybrids: []string{}, CloselyRelatedTo: []string{}, SubspeciesVarieties: []string{}, Synonyms: []string{}, ExternalLinks: []models.ExternalLink{}},
		{ScientificName: "rubra", Hybrids: []string{}, CloselyRelatedTo: []string{}, SubspeciesVarieties: []string{}, Synonyms: []string{}, ExternalLinks: []models.ExternalLink{}},
		{ScientificName: "palustris", Hybrids: []string{}, CloselyRelatedTo: []string{}, SubspeciesVarieties: []string{}, Synonyms: []string{}, ExternalLinks: []models.ExternalLink{}},
	}

	for _, e := range entries {
		if err := db.SaveOakEntry(e); err != nil {
			t.Fatalf("SaveOakEntry failed: %v", err)
		}
	}

	// Search for "a"
	results, err := db.SearchOakEntries("a")
	if err != nil {
		t.Fatalf("SearchOakEntries failed: %v", err)
	}
	if len(results) != 3 { // all contain "a"
		t.Errorf("expected 3 results, got %d", len(results))
	}

	// Search for "rub"
	results, err = db.SearchOakEntries("rub")
	if err != nil {
		t.Fatalf("SearchOakEntries failed: %v", err)
	}
	if len(results) != 1 {
		t.Errorf("expected 1 result, got %d", len(results))
	}
	if results[0] != "rubra" {
		t.Errorf("expected rubra, got %s", results[0])
	}
}

func TestListOakEntries(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	entries := []*models.OakEntry{
		{ScientificName: "alba", Hybrids: []string{}, CloselyRelatedTo: []string{}, SubspeciesVarieties: []string{}, Synonyms: []string{}, ExternalLinks: []models.ExternalLink{}},
		{ScientificName: "rubra", Hybrids: []string{}, CloselyRelatedTo: []string{}, SubspeciesVarieties: []string{}, Synonyms: []string{}, ExternalLinks: []models.ExternalLink{}},
	}

	for _, e := range entries {
		if err := db.SaveOakEntry(e); err != nil {
			t.Fatalf("SaveOakEntry failed: %v", err)
		}
	}

	all, err := db.ListOakEntries()
	if err != nil {
		t.Fatalf("ListOakEntries failed: %v", err)
	}
	if len(all) != 2 {
		t.Errorf("expected 2 entries, got %d", len(all))
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
