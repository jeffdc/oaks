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

func setupTestServer(t *testing.T) (*Server, *db.Database) {
	t.Helper()
	database, err := db.New(":memory:")
	if err != nil {
		t.Fatalf("failed to create database: %v", err)
	}
	server := New(database, "test-api-key", nil, WithoutMiddleware())
	return server, database
}

func TestListSpecies_Empty(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("GET", "/api/v1/species", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var resp ListResponse[*models.OakEntry]
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(resp.Data) != 0 {
		t.Errorf("expected empty data, got %d items", len(resp.Data))
	}
	if resp.Pagination.Total != 0 {
		t.Errorf("expected total 0, got %d", resp.Pagination.Total)
	}
}

func TestListSpecies_WithData(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	// Insert test data
	subgenus := "Quercus"
	entries := []*models.OakEntry{
		{ScientificName: "alba", Subgenus: &subgenus},
		{ScientificName: "rubra", Subgenus: &subgenus},
		{ScientificName: "robur", Subgenus: &subgenus},
	}
	for _, e := range entries {
		if err := database.SaveOakEntry(e); err != nil {
			t.Fatalf("failed to insert entry: %v", err)
		}
	}

	req := httptest.NewRequest("GET", "/api/v1/species", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var resp ListResponse[*models.OakEntry]
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(resp.Data) != 3 {
		t.Errorf("expected 3 items, got %d", len(resp.Data))
	}
	if resp.Pagination.Total != 3 {
		t.Errorf("expected total 3, got %d", resp.Pagination.Total)
	}
}

func TestListSpecies_Pagination(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	// Insert 5 entries
	for i := 0; i < 5; i++ {
		entry := &models.OakEntry{ScientificName: string(rune('a'+i)) + "species"}
		if err := database.SaveOakEntry(entry); err != nil {
			t.Fatalf("failed to insert entry: %v", err)
		}
	}

	req := httptest.NewRequest("GET", "/api/v1/species?limit=2&offset=1", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var resp ListResponse[*models.OakEntry]
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(resp.Data) != 2 {
		t.Errorf("expected 2 items, got %d", len(resp.Data))
	}
	if resp.Pagination.Total != 5 {
		t.Errorf("expected total 5, got %d", resp.Pagination.Total)
	}
	if resp.Pagination.Offset != 1 {
		t.Errorf("expected offset 1, got %d", resp.Pagination.Offset)
	}
	if !resp.Pagination.HasMore {
		t.Error("expected HasMore to be true")
	}
}

func TestListSpecies_FilterBySubgenus(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	subgenus1 := "Quercus"
	subgenus2 := "Cerris"
	entries := []*models.OakEntry{
		{ScientificName: "alba", Subgenus: &subgenus1},
		{ScientificName: "suber", Subgenus: &subgenus2},
		{ScientificName: "rubra", Subgenus: &subgenus1},
	}
	for _, e := range entries {
		if err := database.SaveOakEntry(e); err != nil {
			t.Fatalf("failed to insert entry: %v", err)
		}
	}

	req := httptest.NewRequest("GET", "/api/v1/species?subgenus=Quercus", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var resp ListResponse[*models.OakEntry]
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(resp.Data) != 2 {
		t.Errorf("expected 2 items, got %d", len(resp.Data))
	}
	if resp.Pagination.Total != 2 {
		t.Errorf("expected total 2, got %d", resp.Pagination.Total)
	}
}

func TestListSpecies_FilterByHybrid(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	entries := []*models.OakEntry{
		{ScientificName: "alba", IsHybrid: false},
		{ScientificName: "x bebbiana", IsHybrid: true},
		{ScientificName: "rubra", IsHybrid: false},
	}
	for _, e := range entries {
		if err := database.SaveOakEntry(e); err != nil {
			t.Fatalf("failed to insert entry: %v", err)
		}
	}

	req := httptest.NewRequest("GET", "/api/v1/species?hybrid=true", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var resp ListResponse[*models.OakEntry]
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(resp.Data) != 1 {
		t.Errorf("expected 1 item, got %d", len(resp.Data))
	}
	if resp.Data[0].ScientificName != "x bebbiana" {
		t.Errorf("expected 'x bebbiana', got %q", resp.Data[0].ScientificName)
	}
}

func TestListSpecies_InvalidLimit(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("GET", "/api/v1/species?limit=-1", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}
}

func TestGetSpecies_Found(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	subgenus := "Quercus"
	author := "L. 1753"
	entry := &models.OakEntry{
		ScientificName: "alba",
		Author:         &author,
		Subgenus:       &subgenus,
		Synonyms:       []string{"alba var. repanda"},
	}
	if err := database.SaveOakEntry(entry); err != nil {
		t.Fatalf("failed to insert entry: %v", err)
	}

	req := httptest.NewRequest("GET", "/api/v1/species/alba", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var resp models.OakEntry
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if resp.ScientificName != "alba" {
		t.Errorf("expected 'alba', got %q", resp.ScientificName)
	}
	if resp.Author == nil || *resp.Author != "L. 1753" {
		t.Errorf("expected author 'L. 1753', got %v", resp.Author)
	}
}

func TestGetSpecies_NotFound(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("GET", "/api/v1/species/nonexistent", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}

	var resp ErrorResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if resp.Error.Code != ErrCodeNotFound {
		t.Errorf("expected error code %q, got %q", ErrCodeNotFound, resp.Error.Code)
	}
}

func TestSearchSpecies_Success(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	entries := []*models.OakEntry{
		{ScientificName: "alba"},
		{ScientificName: "rubra"},
		{ScientificName: "robur"},
		{ScientificName: "palustris"},
	}
	for _, e := range entries {
		if err := database.SaveOakEntry(e); err != nil {
			t.Fatalf("failed to insert entry: %v", err)
		}
	}

	req := httptest.NewRequest("GET", "/api/v1/species/search?q=rub", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var resp struct {
		Data  []*models.OakEntry `json:"data"`
		Query string             `json:"query"`
		Count int                `json:"count"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(resp.Data) != 1 {
		t.Errorf("expected 1 result, got %d", len(resp.Data))
	}
	if resp.Query != "rub" {
		t.Errorf("expected query 'rub', got %q", resp.Query)
	}
}

func TestSearchSpecies_MissingQuery(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("GET", "/api/v1/species/search", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}
}

func TestCreateSpecies_Success(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	subgenus := "Quercus"
	author := "L. 1753"
	body := SpeciesRequest{
		ScientificName: "alba",
		Author:         &author,
		Subgenus:       &subgenus,
	}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest("POST", "/api/v1/species", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("expected status %d, got %d: %s", http.StatusCreated, w.Code, w.Body.String())
	}

	// Verify in database
	entry, err := database.GetOakEntry("alba")
	if err != nil {
		t.Fatalf("failed to get entry: %v", err)
	}
	if entry == nil {
		t.Fatal("expected entry to be created")
	}
	if entry.Author == nil || *entry.Author != "L. 1753" {
		t.Errorf("expected author 'L. 1753', got %v", entry.Author)
	}
}

func TestCreateSpecies_Conflict(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	// Insert existing entry
	if err := database.SaveOakEntry(&models.OakEntry{ScientificName: "alba"}); err != nil {
		t.Fatalf("failed to insert entry: %v", err)
	}

	body := SpeciesRequest{ScientificName: "alba"}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest("POST", "/api/v1/species", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusConflict {
		t.Errorf("expected status %d, got %d", http.StatusConflict, w.Code)
	}
}

func TestCreateSpecies_ValidationError(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	// Missing scientific_name
	body := SpeciesRequest{}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest("POST", "/api/v1/species", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}

	var resp ErrorResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if resp.Error.Code != ErrCodeValidation {
		t.Errorf("expected error code %q, got %q", ErrCodeValidation, resp.Error.Code)
	}
}

func TestCreateSpecies_InvalidSubgenus(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	invalidSubgenus := "InvalidSubgenus"
	body := SpeciesRequest{
		ScientificName: "alba",
		Subgenus:       &invalidSubgenus,
	}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest("POST", "/api/v1/species", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}
}

func TestCreateSpecies_Unauthorized(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	body := SpeciesRequest{ScientificName: "alba"}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest("POST", "/api/v1/species", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	// No Authorization header
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}
}

func TestUpdateSpecies_Success(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	// Insert existing entry
	if err := database.SaveOakEntry(&models.OakEntry{ScientificName: "alba"}); err != nil {
		t.Fatalf("failed to insert entry: %v", err)
	}

	author := "L. 1753"
	subgenus := "Quercus"
	body := SpeciesRequest{
		Author:   &author,
		Subgenus: &subgenus,
	}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest("PUT", "/api/v1/species/alba", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d: %s", http.StatusOK, w.Code, w.Body.String())
	}

	// Verify update
	entry, _ := database.GetOakEntry("alba")
	if entry.Author == nil || *entry.Author != "L. 1753" {
		t.Errorf("expected author 'L. 1753', got %v", entry.Author)
	}
}

func TestUpdateSpecies_NotFound(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	body := SpeciesRequest{}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest("PUT", "/api/v1/species/nonexistent", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}

func TestDeleteSpecies_Success(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	// Insert entry
	if err := database.SaveOakEntry(&models.OakEntry{ScientificName: "alba"}); err != nil {
		t.Fatalf("failed to insert entry: %v", err)
	}

	req := httptest.NewRequest("DELETE", "/api/v1/species/alba", http.NoBody)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Errorf("expected status %d, got %d", http.StatusNoContent, w.Code)
	}

	// Verify deletion
	entry, _ := database.GetOakEntry("alba")
	if entry != nil {
		t.Error("expected entry to be deleted")
	}
}

func TestDeleteSpecies_NotFound(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("DELETE", "/api/v1/species/nonexistent", http.NoBody)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}

func TestDeleteSpecies_Unauthorized(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	// Insert entry
	if err := database.SaveOakEntry(&models.OakEntry{ScientificName: "alba"}); err != nil {
		t.Fatalf("failed to insert entry: %v", err)
	}

	req := httptest.NewRequest("DELETE", "/api/v1/species/alba", http.NoBody)
	// No Authorization header
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}

	// Verify entry still exists
	entry, _ := database.GetOakEntry("alba")
	if entry == nil {
		t.Error("expected entry to still exist")
	}
}
