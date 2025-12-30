package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/jeff/oaks/cli/internal/models"
)

func setupSpeciesSourceTestData(t *testing.T, server *Server, database interface {
	SaveOakEntry(entry *models.OakEntry) error
	InsertSource(source *models.Source) (int64, error)
}) (string, int64) {
	t.Helper()

	// Create a species
	entry := &models.OakEntry{ScientificName: "alba"}
	if err := database.SaveOakEntry(entry); err != nil {
		t.Fatalf("failed to insert species: %v", err)
	}

	// Create a source
	source := &models.Source{
		SourceType: "website",
		Name:       "Test Source",
	}
	sourceID, err := database.InsertSource(source)
	if err != nil {
		t.Fatalf("failed to insert source: %v", err)
	}

	return "alba", sourceID
}

func TestListSpeciesSources_Empty(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	// Create species without any sources
	if err := database.SaveOakEntry(&models.OakEntry{ScientificName: "alba"}); err != nil {
		t.Fatalf("failed to insert species: %v", err)
	}

	req := httptest.NewRequest("GET", "/api/v1/species/alba/sources", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var resp []*models.SpeciesSource
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(resp) != 0 {
		t.Errorf("expected empty array, got %d items", len(resp))
	}
}

func TestListSpeciesSources_WithData(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	speciesName, sourceID := setupSpeciesSourceTestData(t, s, database)

	// Add species-source record
	ss := models.NewSpeciesSource(speciesName, sourceID)
	ss.LocalNames = []string{"white oak"}
	if err := database.SaveSpeciesSource(ss); err != nil {
		t.Fatalf("failed to save species source: %v", err)
	}

	req := httptest.NewRequest("GET", "/api/v1/species/alba/sources", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var resp []*models.SpeciesSource
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(resp) != 1 {
		t.Errorf("expected 1 item, got %d", len(resp))
	}
	if len(resp[0].LocalNames) != 1 || resp[0].LocalNames[0] != "white oak" {
		t.Errorf("expected local names ['white oak'], got %v", resp[0].LocalNames)
	}
}

func TestListSpeciesSources_SpeciesNotFound(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("GET", "/api/v1/species/nonexistent/sources", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}

func TestGetSpeciesSource_Found(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	speciesName, sourceID := setupSpeciesSourceTestData(t, s, database)

	// Add species-source record
	leaves := "5-9 lobed"
	ss := models.NewSpeciesSource(speciesName, sourceID)
	ss.Leaves = &leaves
	ss.IsPreferred = true
	if err := database.SaveSpeciesSource(ss); err != nil {
		t.Fatalf("failed to save species source: %v", err)
	}

	req := httptest.NewRequest("GET", "/api/v1/species/alba/sources/1", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d: %s", http.StatusOK, w.Code, w.Body.String())
	}

	var resp models.SpeciesSource
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if resp.ScientificName != "alba" {
		t.Errorf("expected scientific_name 'alba', got %q", resp.ScientificName)
	}
	if resp.Leaves == nil || *resp.Leaves != "5-9 lobed" {
		t.Errorf("expected leaves '5-9 lobed', got %v", resp.Leaves)
	}
	if !resp.IsPreferred {
		t.Error("expected is_preferred to be true")
	}
}

func TestGetSpeciesSource_NotFound(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	// Create species but no source link
	if err := database.SaveOakEntry(&models.OakEntry{ScientificName: "alba"}); err != nil {
		t.Fatalf("failed to insert species: %v", err)
	}

	req := httptest.NewRequest("GET", "/api/v1/species/alba/sources/999", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}

func TestGetSpeciesSource_SpeciesNotFound(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("GET", "/api/v1/species/nonexistent/sources/1", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}

func TestGetSpeciesSource_InvalidSourceID(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	if err := database.SaveOakEntry(&models.OakEntry{ScientificName: "alba"}); err != nil {
		t.Fatalf("failed to insert species: %v", err)
	}

	req := httptest.NewRequest("GET", "/api/v1/species/alba/sources/invalid", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}
}

func TestCreateSpeciesSource_Success(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	speciesName, sourceID := setupSpeciesSourceTestData(t, s, database)
	_ = speciesName

	leaves := "5-9 lobed"
	body := SpeciesSourceRequest{
		SourceID:   sourceID,
		LocalNames: []string{"white oak", "eastern white oak"},
		Leaves:     &leaves,
	}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest("POST", "/api/v1/species/alba/sources", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("expected status %d, got %d: %s", http.StatusCreated, w.Code, w.Body.String())
	}

	var resp models.SpeciesSource
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if resp.ScientificName != "alba" {
		t.Errorf("expected scientific_name 'alba', got %q", resp.ScientificName)
	}
	if resp.SourceID != sourceID {
		t.Errorf("expected source_id %d, got %d", sourceID, resp.SourceID)
	}
	if len(resp.LocalNames) != 2 {
		t.Errorf("expected 2 local names, got %d", len(resp.LocalNames))
	}
}

func TestCreateSpeciesSource_Conflict(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	speciesName, sourceID := setupSpeciesSourceTestData(t, s, database)

	// Add existing species-source record
	ss := models.NewSpeciesSource(speciesName, sourceID)
	if err := database.SaveSpeciesSource(ss); err != nil {
		t.Fatalf("failed to save species source: %v", err)
	}

	body := SpeciesSourceRequest{SourceID: sourceID}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest("POST", "/api/v1/species/alba/sources", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusConflict {
		t.Errorf("expected status %d, got %d", http.StatusConflict, w.Code)
	}
}

func TestCreateSpeciesSource_SpeciesNotFound(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	// Create source but not species
	source := &models.Source{SourceType: "website", Name: "Test"}
	sourceID, _ := database.InsertSource(source)

	body := SpeciesSourceRequest{SourceID: sourceID}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest("POST", "/api/v1/species/nonexistent/sources", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}

func TestCreateSpeciesSource_SourceNotFound(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	// Create species but not source
	if err := database.SaveOakEntry(&models.OakEntry{ScientificName: "alba"}); err != nil {
		t.Fatalf("failed to insert species: %v", err)
	}

	body := SpeciesSourceRequest{SourceID: 999}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest("POST", "/api/v1/species/alba/sources", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}

func TestCreateSpeciesSource_ValidationError(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	if err := database.SaveOakEntry(&models.OakEntry{ScientificName: "alba"}); err != nil {
		t.Fatalf("failed to insert species: %v", err)
	}

	// Missing/invalid source_id
	body := SpeciesSourceRequest{SourceID: 0}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest("POST", "/api/v1/species/alba/sources", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}
}

func TestCreateSpeciesSource_Unauthorized(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	body := SpeciesSourceRequest{SourceID: 1}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest("POST", "/api/v1/species/alba/sources", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	// No Authorization header
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}
}

func TestUpdateSpeciesSource_Success(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	speciesName, sourceID := setupSpeciesSourceTestData(t, s, database)

	// Add existing species-source record
	ss := models.NewSpeciesSource(speciesName, sourceID)
	ss.LocalNames = []string{"white oak"}
	if err := database.SaveSpeciesSource(ss); err != nil {
		t.Fatalf("failed to save species source: %v", err)
	}

	leaves := "5-9 lobed, deeply cut"
	body := SpeciesSourceRequest{
		SourceID:    sourceID,
		LocalNames:  []string{"white oak", "stave oak"},
		Leaves:      &leaves,
		IsPreferred: true,
	}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest("PUT", "/api/v1/species/alba/sources/1", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d: %s", http.StatusOK, w.Code, w.Body.String())
	}

	var resp models.SpeciesSource
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(resp.LocalNames) != 2 {
		t.Errorf("expected 2 local names, got %d", len(resp.LocalNames))
	}
	if resp.Leaves == nil || *resp.Leaves != "5-9 lobed, deeply cut" {
		t.Errorf("expected leaves '5-9 lobed, deeply cut', got %v", resp.Leaves)
	}
	if !resp.IsPreferred {
		t.Error("expected is_preferred to be true")
	}
}

func TestUpdateSpeciesSource_NotFound(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	// Create species but no source link
	if err := database.SaveOakEntry(&models.OakEntry{ScientificName: "alba"}); err != nil {
		t.Fatalf("failed to insert species: %v", err)
	}

	body := SpeciesSourceRequest{SourceID: 999}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest("PUT", "/api/v1/species/alba/sources/999", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}

func TestUpdateSpeciesSource_Unauthorized(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	body := SpeciesSourceRequest{SourceID: 1}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest("PUT", "/api/v1/species/alba/sources/1", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	// No Authorization header
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}
}

func TestDeleteSpeciesSource_Success(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	speciesName, sourceID := setupSpeciesSourceTestData(t, s, database)

	// Add species-source record
	ss := models.NewSpeciesSource(speciesName, sourceID)
	if err := database.SaveSpeciesSource(ss); err != nil {
		t.Fatalf("failed to save species source: %v", err)
	}

	req := httptest.NewRequest("DELETE", "/api/v1/species/alba/sources/1", http.NoBody)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Errorf("expected status %d, got %d", http.StatusNoContent, w.Code)
	}

	// Verify deletion
	result, _ := database.GetSpeciesSourceBySourceID(speciesName, sourceID)
	if result != nil {
		t.Error("expected species source to be deleted")
	}
}

func TestDeleteSpeciesSource_NotFound(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	// Create species but no source link
	if err := database.SaveOakEntry(&models.OakEntry{ScientificName: "alba"}); err != nil {
		t.Fatalf("failed to insert species: %v", err)
	}

	req := httptest.NewRequest("DELETE", "/api/v1/species/alba/sources/999", http.NoBody)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}

func TestDeleteSpeciesSource_SpeciesNotFound(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("DELETE", "/api/v1/species/nonexistent/sources/1", http.NoBody)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}

func TestDeleteSpeciesSource_Unauthorized(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	speciesName, sourceID := setupSpeciesSourceTestData(t, s, database)

	// Add species-source record
	ss := models.NewSpeciesSource(speciesName, sourceID)
	if err := database.SaveSpeciesSource(ss); err != nil {
		t.Fatalf("failed to save species source: %v", err)
	}

	req := httptest.NewRequest("DELETE", "/api/v1/species/alba/sources/1", http.NoBody)
	// No Authorization header
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}

	// Verify record still exists
	result, _ := database.GetSpeciesSourceBySourceID(speciesName, sourceID)
	if result == nil {
		t.Error("expected species source to still exist")
	}
}
