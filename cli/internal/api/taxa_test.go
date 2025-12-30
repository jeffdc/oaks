package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/jeff/oaks/cli/internal/db"
	"github.com/jeff/oaks/cli/internal/models"
)

func setupTaxaTestServer(t *testing.T) (*Server, *db.Database) {
	t.Helper()
	database, err := db.New(":memory:")
	if err != nil {
		t.Fatalf("failed to create database: %v", err)
	}
	s := New(database, "test-api-key", nil, WithoutMiddleware())
	return s, database
}

func TestListTaxa_Empty(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("GET", "/api/v1/taxa", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var resp ListResponse[TaxonResponse]
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(resp.Data) != 0 {
		t.Errorf("expected 0 taxa, got %d", len(resp.Data))
	}
	if resp.Pagination.Total != 0 {
		t.Errorf("expected total 0, got %d", resp.Pagination.Total)
	}
}

func TestListTaxa_WithData(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	// Insert test taxa
	taxa := []*models.Taxon{
		{Name: "Quercus", Level: models.TaxonLevelSubgenus, Links: []models.TaxonLink{}},
		{Name: "Lobatae", Level: models.TaxonLevelSection, Links: []models.TaxonLink{}},
		{Name: "Palustres", Level: models.TaxonLevelSubsection, Links: []models.TaxonLink{}},
	}
	for _, taxon := range taxa {
		if err := database.InsertTaxon(taxon); err != nil {
			t.Fatalf("failed to insert taxon: %v", err)
		}
	}

	req := httptest.NewRequest("GET", "/api/v1/taxa", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var resp ListResponse[TaxonResponse]
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(resp.Data) != 3 {
		t.Errorf("expected 3 taxa, got %d", len(resp.Data))
	}
	if resp.Pagination.Total != 3 {
		t.Errorf("expected total 3, got %d", resp.Pagination.Total)
	}
}

func TestListTaxa_FilterByLevel(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	// Insert test taxa at different levels
	taxa := []*models.Taxon{
		{Name: "Quercus", Level: models.TaxonLevelSubgenus, Links: []models.TaxonLink{}},
		{Name: "Cerris", Level: models.TaxonLevelSubgenus, Links: []models.TaxonLink{}},
		{Name: "Lobatae", Level: models.TaxonLevelSection, Links: []models.TaxonLink{}},
	}
	for _, taxon := range taxa {
		if err := database.InsertTaxon(taxon); err != nil {
			t.Fatalf("failed to insert taxon: %v", err)
		}
	}

	req := httptest.NewRequest("GET", "/api/v1/taxa?level=subgenus", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var resp ListResponse[TaxonResponse]
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(resp.Data) != 2 {
		t.Errorf("expected 2 subgenus taxa, got %d", len(resp.Data))
	}
	for _, taxon := range resp.Data {
		if taxon.Level != models.TaxonLevelSubgenus {
			t.Errorf("expected level subgenus, got %s", taxon.Level)
		}
	}
}

func TestListTaxa_InvalidLevel(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("GET", "/api/v1/taxa?level=invalid", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}

	var resp ErrorResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse error response: %v", err)
	}

	if resp.Error.Code != ErrCodeValidation {
		t.Errorf("expected error code %s, got %s", ErrCodeValidation, resp.Error.Code)
	}
}

func TestGetTaxon_Success(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	// Insert a taxon
	author := "Nixon"
	notes := "Red oaks group"
	taxon := &models.Taxon{
		Name:   "Lobatae",
		Level:  models.TaxonLevelSection,
		Author: &author,
		Notes:  &notes,
		Links:  []models.TaxonLink{{Label: "iNaturalist", URL: "https://inaturalist.org/taxa/123"}},
	}
	if err := database.InsertTaxon(taxon); err != nil {
		t.Fatalf("failed to insert taxon: %v", err)
	}

	req := httptest.NewRequest("GET", "/api/v1/taxa/section/Lobatae", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var resp TaxonResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if resp.Name != "Lobatae" {
		t.Errorf("expected name 'Lobatae', got %q", resp.Name)
	}
	if resp.Level != models.TaxonLevelSection {
		t.Errorf("expected level 'section', got %q", resp.Level)
	}
	if resp.Author == nil || *resp.Author != "Nixon" {
		t.Errorf("expected author 'Nixon', got %v", resp.Author)
	}
	if len(resp.Links) != 1 {
		t.Errorf("expected 1 link, got %d", len(resp.Links))
	}
}

func TestGetTaxon_NotFound(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("GET", "/api/v1/taxa/section/NonExistent", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}

	var resp ErrorResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse error response: %v", err)
	}

	if resp.Error.Code != ErrCodeNotFound {
		t.Errorf("expected error code %s, got %s", ErrCodeNotFound, resp.Error.Code)
	}
}

func TestGetTaxon_InvalidLevel(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("GET", "/api/v1/taxa/invalid/Lobatae", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}
}

func TestCreateTaxon_Success(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	body := `{"name":"Lobatae","level":"section","author":"Nixon"}`
	req := httptest.NewRequest("POST", "/api/v1/taxa", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("expected status %d, got %d: %s", http.StatusCreated, w.Code, w.Body.String())
	}

	var resp TaxonResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if resp.Name != "Lobatae" {
		t.Errorf("expected name 'Lobatae', got %q", resp.Name)
	}
	if resp.Level != models.TaxonLevelSection {
		t.Errorf("expected level 'section', got %q", resp.Level)
	}

	// Verify it was saved
	taxon, err := database.GetTaxon("Lobatae", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("failed to get taxon: %v", err)
	}
	if taxon == nil {
		t.Error("taxon was not saved to database")
	}
}

func TestCreateTaxon_WithLinks(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	body := `{"name":"Lobatae","level":"section","links":[{"label":"iNat","url":"https://inaturalist.org/taxa/123"}]}`
	req := httptest.NewRequest("POST", "/api/v1/taxa", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("expected status %d, got %d: %s", http.StatusCreated, w.Code, w.Body.String())
	}

	var resp TaxonResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(resp.Links) != 1 {
		t.Errorf("expected 1 link, got %d", len(resp.Links))
	}
	if resp.Links[0].Label != "iNat" {
		t.Errorf("expected link label 'iNat', got %q", resp.Links[0].Label)
	}
}

func TestCreateTaxon_Unauthorized(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	body := `{"name":"Lobatae","level":"section"}`
	req := httptest.NewRequest("POST", "/api/v1/taxa", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	// No auth header
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}
}

func TestCreateTaxon_InvalidAPIKey(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	body := `{"name":"Lobatae","level":"section"}`
	req := httptest.NewRequest("POST", "/api/v1/taxa", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer wrong-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}
}

func TestCreateTaxon_Conflict(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	// Insert a taxon first
	taxon := &models.Taxon{Name: "Lobatae", Level: models.TaxonLevelSection, Links: []models.TaxonLink{}}
	if err := database.InsertTaxon(taxon); err != nil {
		t.Fatalf("failed to insert taxon: %v", err)
	}

	// Try to create the same taxon
	body := `{"name":"Lobatae","level":"section"}`
	req := httptest.NewRequest("POST", "/api/v1/taxa", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusConflict {
		t.Errorf("expected status %d, got %d: %s", http.StatusConflict, w.Code, w.Body.String())
	}

	var resp ErrorResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse error response: %v", err)
	}

	if resp.Error.Code != ErrCodeConflict {
		t.Errorf("expected error code %s, got %s", ErrCodeConflict, resp.Error.Code)
	}
}

func TestCreateTaxon_ValidationError_MissingName(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	body := `{"level":"section"}`
	req := httptest.NewRequest("POST", "/api/v1/taxa", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}
}

func TestCreateTaxon_ValidationError_InvalidLevel(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	body := `{"name":"Lobatae","level":"invalid"}`
	req := httptest.NewRequest("POST", "/api/v1/taxa", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d: %s", http.StatusBadRequest, w.Code, w.Body.String())
	}
}

func TestCreateTaxon_InvalidJSON(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	body := `{invalid json}`
	req := httptest.NewRequest("POST", "/api/v1/taxa", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}
}

func TestUpdateTaxon_Success(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	// Insert a taxon first
	taxon := &models.Taxon{Name: "Lobatae", Level: models.TaxonLevelSection, Links: []models.TaxonLink{}}
	if err := database.InsertTaxon(taxon); err != nil {
		t.Fatalf("failed to insert taxon: %v", err)
	}

	// Update it
	body := `{"author":"Nixon","notes":"Red oaks"}`
	req := httptest.NewRequest("PUT", "/api/v1/taxa/section/Lobatae", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d: %s", http.StatusOK, w.Code, w.Body.String())
	}

	var resp TaxonResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if resp.Author == nil || *resp.Author != "Nixon" {
		t.Errorf("expected author 'Nixon', got %v", resp.Author)
	}
	if resp.Notes == nil || *resp.Notes != "Red oaks" {
		t.Errorf("expected notes 'Red oaks', got %v", resp.Notes)
	}

	// Verify in database
	updated, err := database.GetTaxon("Lobatae", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("failed to get taxon: %v", err)
	}
	if updated.Author == nil || *updated.Author != "Nixon" {
		t.Errorf("database author not updated")
	}
}

func TestUpdateTaxon_NotFound(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	body := `{"author":"Nixon"}`
	req := httptest.NewRequest("PUT", "/api/v1/taxa/section/NonExistent", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}

func TestUpdateTaxon_Unauthorized(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	body := `{"author":"Nixon"}`
	req := httptest.NewRequest("PUT", "/api/v1/taxa/section/Lobatae", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	// No auth header
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}
}

func TestUpdateTaxon_InvalidLevel(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	body := `{"author":"Nixon"}`
	req := httptest.NewRequest("PUT", "/api/v1/taxa/invalid/Lobatae", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}
}

func TestDeleteTaxon_Success(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	// Insert a taxon first
	taxon := &models.Taxon{Name: "Lobatae", Level: models.TaxonLevelSection, Links: []models.TaxonLink{}}
	if err := database.InsertTaxon(taxon); err != nil {
		t.Fatalf("failed to insert taxon: %v", err)
	}

	// Delete it
	req := httptest.NewRequest("DELETE", "/api/v1/taxa/section/Lobatae", http.NoBody)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Errorf("expected status %d, got %d: %s", http.StatusNoContent, w.Code, w.Body.String())
	}

	// Verify it was deleted
	taxon, err := database.GetTaxon("Lobatae", models.TaxonLevelSection)
	if err != nil {
		t.Fatalf("failed to get taxon: %v", err)
	}
	if taxon != nil {
		t.Error("taxon was not deleted from database")
	}
}

func TestDeleteTaxon_NotFound(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("DELETE", "/api/v1/taxa/section/NonExistent", http.NoBody)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}

func TestDeleteTaxon_Unauthorized(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("DELETE", "/api/v1/taxa/section/Lobatae", http.NoBody)
	// No auth header
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}
}

func TestDeleteTaxon_InvalidLevel(t *testing.T) {
	s, database := setupTaxaTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("DELETE", "/api/v1/taxa/invalid/Lobatae", http.NoBody)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}
}

func TestParseTaxonLevel(t *testing.T) {
	tests := []struct {
		input    string
		expected models.TaxonLevel
		valid    bool
	}{
		{"subgenus", models.TaxonLevelSubgenus, true},
		{"SUBGENUS", models.TaxonLevelSubgenus, true},
		{"Subgenus", models.TaxonLevelSubgenus, true},
		{"section", models.TaxonLevelSection, true},
		{"subsection", models.TaxonLevelSubsection, true},
		{"complex", models.TaxonLevelComplex, true},
		{"invalid", "", false},
		{"", "", false},
		{"species", "", false},
	}

	for _, tc := range tests {
		t.Run(tc.input, func(t *testing.T) {
			level, valid := parseTaxonLevel(tc.input)
			if valid != tc.valid {
				t.Errorf("parseTaxonLevel(%q) valid = %v, expected %v", tc.input, valid, tc.valid)
			}
			if tc.valid && level != tc.expected {
				t.Errorf("parseTaxonLevel(%q) = %q, expected %q", tc.input, level, tc.expected)
			}
		})
	}
}
