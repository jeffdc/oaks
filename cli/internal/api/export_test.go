package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/jeff/oaks/cli/internal/db"
	"github.com/jeff/oaks/cli/internal/export"
	"github.com/jeff/oaks/cli/internal/models"
)

func setupExportTestServer(t *testing.T) (*Server, *db.Database) {
	database, err := db.New(":memory:")
	if err != nil {
		t.Fatalf("failed to create database: %v", err)
	}
	server := New(database, "test-api-key", nil, WithoutMiddleware())
	return server, database
}

func TestExport_Empty(t *testing.T) {
	s, database := setupExportTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("GET", "/api/v1/export", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	// Check Content-Type header
	if ct := w.Header().Get("Content-Type"); ct != "application/json" {
		t.Errorf("expected Content-Type 'application/json', got %q", ct)
	}

	// Check ETag header is present
	if etag := w.Header().Get("ETag"); etag == "" {
		t.Error("expected ETag header to be present")
	}

	// Parse response
	var result export.File
	if err := json.Unmarshal(w.Body.Bytes(), &result); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	// Verify structure
	if result.Metadata.SpeciesCount != 0 {
		t.Errorf("expected 0 species, got %d", result.Metadata.SpeciesCount)
	}
	if result.Metadata.Version == "" {
		t.Error("expected non-empty version")
	}
	if result.Metadata.ExportedAt == "" {
		t.Error("expected non-empty exported_at")
	}
	if result.Species == nil {
		t.Error("expected species array to be non-nil")
	}
	if result.Sources == nil {
		t.Error("expected sources array to be non-nil")
	}
}

func TestExport_WithData(t *testing.T) {
	s, database := setupExportTestServer(t)
	defer database.Close()

	// Insert test source
	source := &models.Source{
		SourceType: "website",
		Name:       "Test Source",
	}
	sourceID, err := database.InsertSource(source)
	if err != nil {
		t.Fatalf("failed to insert source: %v", err)
	}

	// Insert test species
	entry := models.NewOakEntry("alba")
	subgenus := "Quercus"
	entry.Subgenus = &subgenus
	if err := database.SaveOakEntry(entry); err != nil {
		t.Fatalf("failed to insert entry: %v", err)
	}

	// Insert species source data
	speciesSource := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       sourceID,
		IsPreferred:    true,
		LocalNames:     []string{"white oak"},
	}
	if err := database.SaveSpeciesSource(speciesSource); err != nil {
		t.Fatalf("failed to insert species source: %v", err)
	}

	req := httptest.NewRequest("GET", "/api/v1/export", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d: %s", http.StatusOK, w.Code, w.Body.String())
	}

	var result export.File
	if err := json.Unmarshal(w.Body.Bytes(), &result); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	// Verify metadata
	if result.Metadata.SpeciesCount != 1 {
		t.Errorf("expected 1 species, got %d", result.Metadata.SpeciesCount)
	}

	// Verify sources
	if len(result.Sources) != 1 {
		t.Errorf("expected 1 source, got %d", len(result.Sources))
	}
	if result.Sources[0].Name != "Test Source" {
		t.Errorf("expected source name 'Test Source', got %q", result.Sources[0].Name)
	}

	// Verify species
	if len(result.Species) != 1 {
		t.Errorf("expected 1 species, got %d", len(result.Species))
	}
	if result.Species[0].Name != "alba" {
		t.Errorf("expected species name 'alba', got %q", result.Species[0].Name)
	}
	if result.Species[0].Taxonomy.Genus != "Quercus" {
		t.Errorf("expected genus 'Quercus', got %q", result.Species[0].Taxonomy.Genus)
	}
	if result.Species[0].Taxonomy.Subgenus == nil || *result.Species[0].Taxonomy.Subgenus != "Quercus" {
		t.Errorf("expected subgenus 'Quercus', got %v", result.Species[0].Taxonomy.Subgenus)
	}

	// Verify species sources
	if len(result.Species[0].Sources) != 1 {
		t.Errorf("expected 1 species source, got %d", len(result.Species[0].Sources))
	}
	if result.Species[0].Sources[0].SourceName != "Test Source" {
		t.Errorf("expected source name 'Test Source', got %q", result.Species[0].Sources[0].SourceName)
	}
	if len(result.Species[0].Sources[0].LocalNames) != 1 || result.Species[0].Sources[0].LocalNames[0] != "white oak" {
		t.Errorf("expected local names ['white oak'], got %v", result.Species[0].Sources[0].LocalNames)
	}
}

func TestExport_ETagCaching(t *testing.T) {
	s, database := setupExportTestServer(t)
	defer database.Close()

	// First request - get ETag
	req1 := httptest.NewRequest("GET", "/api/v1/export", http.NoBody)
	w1 := httptest.NewRecorder()
	s.Router().ServeHTTP(w1, req1)

	if w1.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, w1.Code)
	}

	etag := w1.Header().Get("ETag")
	if etag == "" {
		t.Fatal("expected ETag header")
	}

	// Second request with If-None-Match - should return 304
	req2 := httptest.NewRequest("GET", "/api/v1/export", http.NoBody)
	req2.Header.Set("If-None-Match", etag)
	w2 := httptest.NewRecorder()
	s.Router().ServeHTTP(w2, req2)

	if w2.Code != http.StatusNotModified {
		t.Errorf("expected status %d, got %d", http.StatusNotModified, w2.Code)
	}

	// Third request with wrong ETag - should return 200
	req3 := httptest.NewRequest("GET", "/api/v1/export", http.NoBody)
	req3.Header.Set("If-None-Match", `"wrong-etag"`)
	w3 := httptest.NewRecorder()
	s.Router().ServeHTTP(w3, req3)

	if w3.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w3.Code)
	}
}

func TestExport_Headers(t *testing.T) {
	s, database := setupExportTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("GET", "/api/v1/export", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	// Check all expected headers
	headers := map[string]bool{
		"Content-Type":  true,
		"ETag":          true,
		"Last-Modified": true,
		"Cache-Control": true,
	}

	for header := range headers {
		if w.Header().Get(header) == "" {
			t.Errorf("expected %s header to be present", header)
		}
	}

	// Verify Cache-Control value
	if cc := w.Header().Get("Cache-Control"); cc != "public, max-age=300" {
		t.Errorf("expected Cache-Control 'public, max-age=300', got %q", cc)
	}
}

func TestExport_MultipleSpecies(t *testing.T) {
	s, database := setupExportTestServer(t)
	defer database.Close()

	// Insert multiple species
	species := []string{"alba", "rubra", "robur", "palustris", "coccinea"}
	for _, name := range species {
		entry := models.NewOakEntry(name)
		if err := database.SaveOakEntry(entry); err != nil {
			t.Fatalf("failed to insert entry %s: %v", name, err)
		}
	}

	req := httptest.NewRequest("GET", "/api/v1/export", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var result export.File
	if err := json.Unmarshal(w.Body.Bytes(), &result); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if result.Metadata.SpeciesCount != len(species) {
		t.Errorf("expected %d species, got %d", len(species), result.Metadata.SpeciesCount)
	}

	if len(result.Species) != len(species) {
		t.Errorf("expected %d species in array, got %d", len(species), len(result.Species))
	}
}
