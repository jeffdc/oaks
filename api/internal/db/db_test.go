package db

import (
	"database/sql"
	"os"
	"path/filepath"
	"testing"

	"github.com/jeff/oaks/api/internal/models"

	_ "github.com/mattn/go-sqlite3" // SQLite driver
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
	entry := &models.Species{
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
	if err := db.SaveSpecies(entry); err != nil {
		t.Fatalf("SaveOakEntry failed: %v", err)
	}

	// Get
	got, err := db.GetSpecies("alba")
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
	if err := db.SaveSpecies(got); err != nil {
		t.Fatalf("SaveOakEntry update failed: %v", err)
	}

	updated, err := db.GetSpecies("alba")
	if err != nil {
		t.Fatalf("GetOakEntry after update failed: %v", err)
	}
	if len(updated.Hybrids) != 3 {
		t.Errorf("Hybrids len = %d, want 3", len(updated.Hybrids))
	}

	// Delete
	if err := db.DeleteSpecies("alba"); err != nil {
		t.Fatalf("DeleteOakEntry failed: %v", err)
	}

	deleted, err := db.GetSpecies("alba")
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
	entry := &models.Species{
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

	if err := db.SaveSpecies(entry); err != nil {
		t.Fatalf("SaveOakEntry failed: %v", err)
	}

	got, err := db.GetSpecies("× bebbiana")
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
	alba := &models.Species{
		ScientificName:      "alba",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	macrocarpa := &models.Species{
		ScientificName:      "macrocarpa",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	rubra := &models.Species{
		ScientificName:      "rubra",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}

	for _, e := range []*models.Species{alba, macrocarpa, rubra} {
		if err := db.SaveSpecies(e); err != nil {
			t.Fatalf("SaveOakEntry(%s) failed: %v", e.ScientificName, err)
		}
	}

	// Create hybrid with parents
	parent1 := "alba"
	parent2 := "macrocarpa"
	hybrid := &models.Species{
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

	if err := db.SaveSpecies(hybrid); err != nil {
		t.Fatalf("SaveOakEntry(hybrid) failed: %v", err)
	}

	// Verify parents now have the hybrid in their hybrids list
	gotAlba, err := db.GetSpecies("alba")
	if err != nil {
		t.Fatalf("GetOakEntry(alba) failed: %v", err)
	}
	if !sliceContains(gotAlba.Hybrids, "× bebbiana") {
		t.Errorf("alba.Hybrids = %v, want to contain '× bebbiana'", gotAlba.Hybrids)
	}

	gotMacrocarpa, err := db.GetSpecies("macrocarpa")
	if err != nil {
		t.Fatalf("GetOakEntry(macrocarpa) failed: %v", err)
	}
	if !sliceContains(gotMacrocarpa.Hybrids, "× bebbiana") {
		t.Errorf("macrocarpa.Hybrids = %v, want to contain '× bebbiana'", gotMacrocarpa.Hybrids)
	}

	// Change one parent from macrocarpa to rubra
	newParent2 := "rubra"
	hybrid.Parent2 = &newParent2
	if err := db.SaveSpecies(hybrid); err != nil {
		t.Fatalf("SaveOakEntry(hybrid with changed parent) failed: %v", err)
	}

	// Verify macrocarpa no longer has the hybrid
	gotMacrocarpa, err = db.GetSpecies("macrocarpa")
	if err != nil {
		t.Fatalf("GetOakEntry(macrocarpa) failed: %v", err)
	}
	if sliceContains(gotMacrocarpa.Hybrids, "× bebbiana") {
		t.Errorf("macrocarpa.Hybrids = %v, want NOT to contain '× bebbiana' after parent change", gotMacrocarpa.Hybrids)
	}

	// Verify rubra now has the hybrid
	gotRubra, err := db.GetSpecies("rubra")
	if err != nil {
		t.Fatalf("GetOakEntry(rubra) failed: %v", err)
	}
	if !sliceContains(gotRubra.Hybrids, "× bebbiana") {
		t.Errorf("rubra.Hybrids = %v, want to contain '× bebbiana'", gotRubra.Hybrids)
	}

	// Verify alba still has the hybrid (unchanged)
	gotAlba, err = db.GetSpecies("alba")
	if err != nil {
		t.Fatalf("GetOakEntry(alba) failed: %v", err)
	}
	if !sliceContains(gotAlba.Hybrids, "× bebbiana") {
		t.Errorf("alba.Hybrids = %v, want to contain '× bebbiana' (unchanged)", gotAlba.Hybrids)
	}

	// Remove parent2 entirely
	hybrid.Parent2 = nil
	if err := db.SaveSpecies(hybrid); err != nil {
		t.Fatalf("SaveOakEntry(hybrid with nil parent2) failed: %v", err)
	}

	// Verify rubra no longer has the hybrid
	gotRubra, err = db.GetSpecies("rubra")
	if err != nil {
		t.Fatalf("GetOakEntry(rubra) failed: %v", err)
	}
	if sliceContains(gotRubra.Hybrids, "× bebbiana") {
		t.Errorf("rubra.Hybrids = %v, want NOT to contain '× bebbiana' after parent removal", gotRubra.Hybrids)
	}

	// Verify alba still has the hybrid
	gotAlba, err = db.GetSpecies("alba")
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
	alba := &models.Species{
		ScientificName:      "alba",
		Hybrids:             []string{"× bebbiana"},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	macrocarpa := &models.Species{
		ScientificName:      "macrocarpa",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}

	for _, e := range []*models.Species{alba, macrocarpa} {
		if err := db.SaveSpecies(e); err != nil {
			t.Fatalf("SaveOakEntry(%s) failed: %v", e.ScientificName, err)
		}
	}

	// Create hybrid that references alba (which already has it in list)
	parent1 := "alba"
	parent2 := "macrocarpa"
	hybrid := &models.Species{
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

	if err := db.SaveSpecies(hybrid); err != nil {
		t.Fatalf("SaveOakEntry(hybrid) failed: %v", err)
	}

	// Verify alba still has only one instance of the hybrid
	gotAlba, err := db.GetSpecies("alba")
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
	hybrid := &models.Species{
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

	if err := db.SaveSpecies(hybrid); err != nil {
		t.Fatalf("SaveOakEntry(hybrid with non-existent parents) should not fail: %v", err)
	}

	// Verify the hybrid was saved correctly
	got, err := db.GetSpecies("× testHybrid")
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

	entries := []*models.Species{
		{ScientificName: "alba", Hybrids: []string{}, CloselyRelatedTo: []string{}, SubspeciesVarieties: []string{}, Synonyms: []string{}, ExternalLinks: []models.ExternalLink{}},
		{ScientificName: "rubra", Hybrids: []string{}, CloselyRelatedTo: []string{}, SubspeciesVarieties: []string{}, Synonyms: []string{}, ExternalLinks: []models.ExternalLink{}},
		{ScientificName: "palustris", Hybrids: []string{}, CloselyRelatedTo: []string{}, SubspeciesVarieties: []string{}, Synonyms: []string{}, ExternalLinks: []models.ExternalLink{}},
	}

	for _, e := range entries {
		if err := db.SaveSpecies(e); err != nil {
			t.Fatalf("SaveOakEntry failed: %v", err)
		}
	}

	// Search for "a"
	results, err := db.SearchSpeciesNames("a")
	if err != nil {
		t.Fatalf("SearchOakEntries failed: %v", err)
	}
	if len(results) != 3 { // all contain "a"
		t.Errorf("expected 3 results, got %d", len(results))
	}

	// Search for "rub"
	results, err = db.SearchSpeciesNames("rub")
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

	entries := []*models.Species{
		{ScientificName: "alba", Hybrids: []string{}, CloselyRelatedTo: []string{}, SubspeciesVarieties: []string{}, Synonyms: []string{}, ExternalLinks: []models.ExternalLink{}},
		{ScientificName: "rubra", Hybrids: []string{}, CloselyRelatedTo: []string{}, SubspeciesVarieties: []string{}, Synonyms: []string{}, ExternalLinks: []models.ExternalLink{}},
	}

	for _, e := range entries {
		if err := db.SaveSpecies(e); err != nil {
			t.Fatalf("SaveOakEntry failed: %v", err)
		}
	}

	all, err := db.ListAllSpecies()
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

// Migration tests

// createOldSchemaDB creates a database with the old schema (oak_entries table, no species table)
// This simulates opening an existing database that needs migration
func createOldSchemaDB(t *testing.T) (*Database, func()) {
	t.Helper()

	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test_old_schema.db")

	// Open raw connection to create old schema
	conn, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		t.Fatalf("failed to open database: %v", err)
	}

	// Create old schema manually (bypass initializeSchema)
	oldSchemaStatements := []string{
		`CREATE TABLE taxa (
			name TEXT NOT NULL,
			level TEXT NOT NULL CHECK(level IN ('subgenus', 'section', 'subsection', 'complex')),
			parent TEXT,
			author TEXT,
			content TEXT,
			content_updated_at TEXT,
			links TEXT,
			PRIMARY KEY (name, level)
		)`,
		`CREATE TABLE sources (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			source_type TEXT NOT NULL,
			name TEXT NOT NULL,
			description TEXT,
			author TEXT,
			year INTEGER,
			url TEXT,
			isbn TEXT,
			doi TEXT,
			notes TEXT,
			license TEXT,
			license_url TEXT
		)`,
		`CREATE TABLE oak_entries (
			scientific_name TEXT PRIMARY KEY,
			author TEXT,
			is_hybrid INTEGER NOT NULL DEFAULT 0,
			conservation_status TEXT,
			subgenus TEXT,
			section TEXT,
			subsection TEXT,
			complex TEXT,
			parent1 TEXT,
			parent2 TEXT,
			hybrids TEXT,
			closely_related_to TEXT,
			subspecies_varieties TEXT,
			synonyms TEXT,
			external_links TEXT
		)`,
		`CREATE TABLE species_sources (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			scientific_name TEXT NOT NULL,
			source_id INTEGER NOT NULL,
			local_names TEXT,
			range TEXT,
			growth_habit TEXT,
			leaves TEXT,
			flowers TEXT,
			fruits TEXT,
			bark TEXT,
			twigs TEXT,
			buds TEXT,
			hardiness_habitat TEXT,
			miscellaneous TEXT,
			url TEXT,
			is_preferred INTEGER NOT NULL DEFAULT 0,
			FOREIGN KEY (scientific_name) REFERENCES oak_entries(scientific_name) ON DELETE CASCADE,
			FOREIGN KEY (source_id) REFERENCES sources(id),
			UNIQUE(scientific_name, source_id)
		)`,
		`CREATE TABLE import_metadata (
			key TEXT PRIMARY KEY,
			value TEXT
		)`,
	}

	for _, stmt := range oldSchemaStatements {
		if _, err := conn.Exec(stmt); err != nil {
			conn.Close()
			t.Fatalf("failed to create old schema: %v", err)
		}
	}

	conn.Close()

	// Now open with the Database wrapper which will run migration
	db, err := New(dbPath)
	if err != nil {
		t.Fatalf("failed to open database after creating old schema: %v", err)
	}

	cleanup := func() {
		db.Close()
		os.Remove(dbPath)
	}

	return db, cleanup
}

func TestFreshDatabaseSchema(t *testing.T) {
	// Fresh database should use new schema with species table and integer IDs
	db, cleanup := testDB(t)
	defer cleanup()

	var tableName string

	// species table should exist (fresh DBs use new schema)
	err := db.conn.QueryRow(`SELECT name FROM sqlite_master WHERE type='table' AND name='species'`).Scan(&tableName)
	if err != nil {
		t.Fatalf("fresh database should have species table: %v", err)
	}

	// oak_entries table should NOT exist (fresh DBs use new schema)
	err = db.conn.QueryRow(`SELECT name FROM sqlite_master WHERE type='table' AND name='oak_entries'`).Scan(&tableName)
	if err == nil {
		t.Fatal("fresh database should NOT have oak_entries table (old schema)")
	}

	// species table should have id column (integer primary key)
	var cid int
	var name, typ string
	var notnull, pk int
	var dfltValue interface{}
	err = db.conn.QueryRow(`PRAGMA table_info(species)`).Scan(&cid, &name, &typ, &notnull, &dfltValue, &pk)
	if err != nil {
		t.Fatalf("failed to get species table info: %v", err)
	}
	if name != "id" || pk != 1 {
		t.Fatalf("species table first column should be 'id' primary key, got %s (pk=%d)", name, pk)
	}
}

// Tests for GetSpeciesByID and GetTaxonByID

func TestGetSpeciesByID(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	author := "L. 1753"
	subgenus := "Quercus"
	section := "Quercus"
	entry := &models.Species{
		ScientificName:      "alba",
		Author:              &author,
		IsHybrid:            false,
		Subgenus:            &subgenus,
		Section:             &section,
		Hybrids:             []string{"bebbiana"},
		CloselyRelatedTo:    []string{"stellata"},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{"alba var. repanda"},
		ExternalLinks:       []models.ExternalLink{},
	}

	// Save
	if err := db.SaveSpecies(entry); err != nil {
		t.Fatalf("SaveSpecies failed: %v", err)
	}

	// Get by name first to find the ID
	byName, err := db.GetSpecies("alba")
	if err != nil {
		t.Fatalf("GetSpecies failed: %v", err)
	}
	if byName == nil {
		t.Fatal("expected non-nil entry")
	}

	// Get by ID
	byID, err := db.GetSpeciesByID(byName.ID)
	if err != nil {
		t.Fatalf("GetSpeciesByID failed: %v", err)
	}
	if byID == nil {
		t.Fatal("expected non-nil entry from GetSpeciesByID")
	}

	// Verify fields match
	if byID.ScientificName != byName.ScientificName {
		t.Errorf("ScientificName = %q, want %q", byID.ScientificName, byName.ScientificName)
	}
	if byID.ID != byName.ID {
		t.Errorf("ID = %d, want %d", byID.ID, byName.ID)
	}
	if *byID.Author != *byName.Author {
		t.Errorf("Author = %q, want %q", *byID.Author, *byName.Author)
	}
	if len(byID.Hybrids) != len(byName.Hybrids) {
		t.Errorf("Hybrids len = %d, want %d", len(byID.Hybrids), len(byName.Hybrids))
	}
}

func TestGetSpeciesByIDNotFound(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Try to get non-existent ID
	got, err := db.GetSpeciesByID(99999)
	if err != nil {
		t.Fatalf("GetSpeciesByID should not error for non-existent ID: %v", err)
	}
	if got != nil {
		t.Error("expected nil for non-existent ID")
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

func strPtr(s string) *string {
	return &s
}
